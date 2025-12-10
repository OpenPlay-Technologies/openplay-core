# OpenPlay Core Security Audit Report (GPT-5.1)

**Auditor**: GPT-5.1 (AI Security Researcher)  
**Audit Date**: December 10, 2025  
**Framework**: Sui Move  
**Package Name**: `openplay_core`  
**Package Version**: 2.1  
**Branch**: `v3.1`  
**Target Commit**: _Not explicitly provided in repo metadata; assumed current HEAD of `v3.1` at audit time._

---

## 1. Executive Summary

### 1.1 Project Overview

OpenPlay Core is a GambleFi infrastructure protocol on Sui that provides:

- **House & Vault**: Shared-liquidity house with GGR-based fee model.
- **Share-based Staking**: Users buy/sell shares in a house, with NAV-backed accounting.
- **Balance Manager**: Shared user balance object with delegated access via PlayCaps.
- **Fee Collection**: Protocol, house, and collector fees calculated from epoch-based GGR.
- **Registry & Governance**: Central registry providing version control and protocol fee configuration.

The design is **trust-minimized at the protocol layer**: user funds live in shared on-chain objects, admins cannot arbitrarily seize balances or lock withdrawals, and users opt in only to games they wish to play from a whitelisted set. At the same time, individual games (off-chain backends) still need to be honest in how they generate and report outcomes, which is mitigated by stringent audit and whitelisting requirements rather than on-chain randomness or full outcome verification.

### 1.2 Methodology (SMS‑2025 Alignment)

This audit followed **SMS‑2025 (Sui & Move Smart Contract Security Standard) v1.1**, as specified in `guidelines_1.md` and `guidelines_2.md`:

1. **Pre-Audit Architecture & Recon**
   - Object Ownership Map (Owned / Shared / Immutable / Wrapped)
   - Capability (Cap) lifecycle and flow
   - Privileged roles & centralization matrix
   - Object lifecycle and concurrency analysis
2. **Kill-Chain Analysis**
   - General Sui Move vectors (Coin Smasher, function visibility, type confusion, transfer-to-object, cap leakage, storage DoS)
   - DeFi vectors (flash loan hot-potato, oracle use, invariants, liquidation races)
   - GambleFi vectors (randomness, shared object sequencing, replay/double-claim)
3. **Automated & Formal Verification (where available)**
   - `sui move test --path package` (unit tests & lints)
   - Manual review of arithmetic safety and invariants
4. **Reporting**
   - Findings with ID, severity, impact, PoC sketch, and remediation guidance
5. **Pre-Flight Checklist**
   - Upgradeability, events, slippage & fee logic, DoS/gas limits, centralization review.

### 1.3 Automated Verification Results

- **Build**: `sui move test --path package`
  - **Result**: ✅ Build successful.
- **Tests**:
  - **Result**: ✅ All tests passed.
  - **Total**: 303 tests; **Failed**: 0.
  - Coverage spans `house`, `vault`, `house_state`, `balance_manager`, `registry`, `calculations`, `transaction`, `game_stats`, `fee_collector`, and related helpers.

### 1.4 High-Level Risk Summary

**Overall Technical Security Posture**: **Strong**, with well-designed capability patterns, robust arithmetic, and defensive NAV / fee logic. 

However, the protocol intentionally embraces **centralized governance** at the OpenPlay admin level, and the economic model reflects standard **GambleFi house risk** rather than DeFi-style permissionless neutrality.

- 🔴 **Critical**: 0
- 🟠 **High**: 0
- 🟡 **Medium**: 2
- 🔵 **Low**: 3
- ℹ️ **Informational**: 9+

Compared to prior audits in this repo:

- Issues previously raised about **`HouseTransactionCap` replay** and **"free roll" withdrawal vs. settlement** were re-evaluated against the current implementation. In this version:
  - `HouseTransactionCap` has **no abilities** and is consumed by-value, providing strong hot-potato semantics.
  - Settlement flow enforces **balance sufficiency** on the `BalanceManager` before debiting; games must handle economic race conditions at the orchestration layer. This is considered a **design tradeoff**, not an exploitable protocol bug, under the documented trusted-game model.
- Concerns about **quadratic gas in fee collector processing** have been mitigated: fee processing now operates over bounded collections (`MAX_GAMES = 500`) with straightforward loops, and the heaviest collector logic resides in `house_state::process_collector_end_of_day`, which operates only once per epoch transition and is covered by tests.

### 1.5 Top Recommendations (Non-Critical)

1. **Multi-sig governance for `OpenPlayAdminCap`** (Medium).
2. **Optional slippage parameters for share operations** (`buy_shares`, `sell_shares`) to protect users from NAV volatility (Low/UX).
3. **Historical storage pruning hooks** for long-term gas/storage hygiene (Low).

---

## 2. Architecture & Reconnaissance (SMS‑2025 §1)

### 2.1 Object Ownership Map (SMS‑2025 §1.1)

**Classification of key structs:**

| Object Type | Struct | Module | Ownership | Primary Risks |
|------------|--------|--------|-----------|---------------|
| **Shared** | `House` | `house` | Shared (`has key`) | Global liquidity pool; DoS and MEV on shared ops. |
| **Shared** | `Registry` | `registry` | Shared | Single point for version control & protocol fee configuration. |
| **Shared** | `BalanceManager` | `balance_manager` | Shared | User funds escrow; mis-use can drain or block user balances. |
| **Shared** | `FeeCollector` | `fee_collector` | Shared | Reference to collector fees; economic but not custodial risk. |
| **Shared** | `GameStatistics` | `game_stats` | Shared | Statistics only; DoS via growth over time. |
| **Owned** | `HouseAdminCap` | `house` | Owned | Controls fee config, game authorization. |
| **Owned** | `OpenPlayAdminCap` | `registry` | Owned | Protocol admin; version & protocol fee control. |
| **Owned** | `BalanceManagerCap` | `balance_manager` | Owned | Owns user funds in `BalanceManager`. |
| **Owned** | `PlayCap` | `balance_manager` | Owned | Delegated gameplay authority. |
| **Owned** | `FeeCollectorCap` | `fee_collector` | Owned | Claims fees from vault. |
| **Owned** | `Participation` | `participation` | Owned | Represents user’s house shares. |
| **Immutable / Config-like** | `ParameterStore` (when frozen) | `parameter_store` | Intended immutable after `freeze_` | Config storage. |
| **Wrapped** | `Vault` | `vault` | Stored in `House` | Holds SUI balances and fee balances; must not be orphaned. |
| **Wrapped** | `State` | `house_state` | Stored in `House` | Holds accounts, volumes, and GGR/fee state. |
| **Wrapped** | `Account` | `account` | In `State.accounts: Table<ID, Account>` | Per-`BalanceManager` accounting.

**Observations (SMS‑2025 Checklist):**

- **Orphaned Data / Wrapped Objects**
  - `Vault` and `State` live inside `House` and are never extracted as independent objects from public functions.
  - `Account` instances are dynamic-field-like entries in `State.accounts: Table<ID, Account>`; `State` never deletes them, but this is an economic/storage optimization issue, not a security bug.
- **Object Deletion**
  - Destructive functions are explicit and guarded:
    - `BalanceManager::destroy_empty` requires zero balance and valid cap.
    - `PlayCap::destroy_play_cap` and `destroy_play_cap_and_revoke` are explicit and evented.
    - No `House` destruction flow is exposed.
- **Object IDs as Arguments**
  - Public interfaces generally accept **structs or IDs tied to internal storage**, not arbitrary object IDs of externally defined types.
  - Dynamic field storage (`parameter_store`) uses the standard `df::add/borrow` API and does not accept arbitrary object IDs for core financial flows.

**Conclusion**: The object ownership model is clear and consistent with Sui best practices. No direct object-orphaning or transfer-to-object anti-patterns were found in critical financial flows.

### 2.2 Capability (Cap) Flow Analysis (SMS‑2025 §1.2)

**Cap lifecycle:**

- **Creation**
  - `Registry::init` (private) mints `OpenPlayAdminCap` and shares `Registry` via `transfer::share_object`.
  - `house::openplay_admin_new_house` mints `House` and `HouseAdminCap` under `OpenPlayAdminCap` control.
  - `balance_manager::new` mints `BalanceManager` + `BalanceManagerCap` pair.
  - `fee_collector::new` mints `FeeCollector` + `FeeCollectorCap` pair.
  - `balance_manager::mint_play_cap` mints `PlayCap` under `BalanceManagerCap`.
- **Distribution**
  - Admin caps are **owned** and never shared; they are transferred to caller (e.g., `OpenPlayAdminCap` via `public_transfer`).
  - `HouseTransactionCap` is **derived, not stored**: constructed by `borrow_tx_cap` and always passed by value into processing functions.
- **Use & Revocation**
  - `HouseTransactionCap` has **no abilities** and is passed by value into `assert_valid_tx_cap`, which destructures it and does not re-store it. This enforces hot-potato semantics.
  - `PlayCap` can be revoked via `revoke_play_cap`, `prune_allow_list`, or destroyed via `destroy_play_cap[_and_revoke]`.
  - `FeeCollectorCap` is validated via `fee_collector::assert_valid_cap` and never stored in shared state.
- **Destruction**
  - Caps are explicitly destroyed only in tests and in `destroy_empty` flows; no hidden re-mint paths.

**SMS‑2025 Cap Checklist:**

- [x] OTW pattern for protocol bootstrap (`REGISTRY` and `HOUSE` witness types) is present and correctly scoped.
- [x] Admin-like caps (`OpenPlayAdminCap`, `HouseAdminCap`, `BalanceManagerCap`, `FeeCollectorCap`) are **owned** and not stored in shared objects.
- [x] No public function returns new admin capabilities outside controlled creation flows.
- [x] Revocation mechanisms exist for `PlayCap` and indirectly control gameplay authorization.

### 2.3 Privileged Roles & Centralization Matrix (SMS‑2025 §1.3)

| Role | Capability | Upgrade Code?* | Move User Funds? | Pause Gameplay? | Other Powers |
|------|------------|----------------|------------------|-----------------|--------------|
| **OpenPlay Admin** | `OpenPlayAdminCap` | Indirect, via versioning & package upgrades (off-chain governance) | No direct arbitrary user-fund movement | Yes – can disable package version via registry | Set protocol fee bps (capped at 20%), allow/disallow package versions, create houses. |
| **House Admin** | `HouseAdminCap` | No | No direct user-fund seizure (only fee claims) | No | Configure house/collector fee bps, whitelist/revoke games, create fee collectors, claim house fees. |
| **Balance Manager Owner** | `BalanceManagerCap` | No | Yes, but only their own `BalanceManager` funds | No | Mint/revoke PlayCaps, prune allow list, deposit/withdraw, destroy empty manager. |
| **Fee Collector Owner** | `FeeCollectorCap` | No | Can claim fees owed to that collector from `Vault` | No | Claim collector GGR-based fees. |
| **Game Backend / Operator** | `HouseTransactionCap` + (shared `BalanceManager` + `PlayProof`) | No | Indirectly moves funds through gameplay settlement | No (but can choose not to process) | Processes game transactions, thereby pushing wins/losses between vault and balance managers. |

\*Upgrade code: On Sui, code upgrade is managed by package publication and registry versioning, not by a Move function. The admin’s practical control comes from deciding which versions are `allowed` in `Registry`.

**Centralization Assessment (per SMS‑2025 §5):**

- **Red Flag Condition (single cap can upgrade code _and_ move arbitrary user funds)**: **Not met.**
  - `OpenPlayAdminCap` controls versions and protocol fee but cannot arbitrarily transfer user `BalanceManager` funds or seize staker shares.
- **Practical Centralization Risk**: **Medium**.
  - A compromised `OpenPlayAdminCap` can:
    - Disable gameplay by disallowing the current `current_version()`.
    - Raise protocol fee to its configured maximum (20% bps) within contract-enforced bounds.
  - This is a **documented governance choice** rather than a hidden backdoor.

### 2.4 Object Lifecycle & Concurrency (SMS‑2025 §1.4–1.5)

- **Lifecycle**
  - `BalanceManager` and `Account` lifecycles are well defined; `Account` entries persist for the lifetime of `State`, avoiding loss of accounting history but accumulating storage over time.
  - `GameStatistics` tracks per-epoch and all-time metrics in `Table<u64, Volumes>`; historical entries are monotonic.
- **Concurrency / Parallel Execution**
  - Shared objects (`House`, `BalanceManager`, `Registry`, `GameStatistics`, `FeeCollector`) can be touched in parallel PTBs; code uses **deterministic arithmetic and epoch checks** (`State::assert_epoch_up_to_date`, `GameStatistics::update_epoch`) to maintain consistency.
  - Gameplay settlement uses **per-`BalanceManager` `Account` objects** keyed by balance manager ID, ensuring that multiple balance managers interacting with the same house do not corrupt each other’s accounting.

**Conclusion**: No concurrency or lifecycle issues rising to vulnerability level were identified. Economic outcomes may differ under different transaction orderings (inherent to shared-object systems), but invariants and solvency are maintained.

---

## 3. Kill-Chain Vulnerability Analysis (SMS‑2025 §2)

### 3.1 General Sui Move Vectors (SMS‑2025 §2.1)

#### [I-01] Coin Smasher / Partial Balance Handling

- **Description (Standard Vector)**: Protocols that assume an input `Coin<T>` represents a user’s entire balance can be exploited via tiny coins (micro-deposits) siphoning rewards.
- **Code Review:**
  - All significant flows use explicit `coin::value()` checks and/or convert `Coin<SUI>` to `Balance<SUI>` via `into_balance` before use:
    - `house::buy_shares` uses `deposit.value()` and asserts `> 0` before minting.
    - `vault::deposit` and `vault::withdraw` operate on `Balance<SUI>` and exact amounts.
  - No logic grants rewards simply for *participation* without scaling by the deposited amount.
- **Assessment:** ✅ **Not Vulnerable** (Informational).

#### [I-02] Function Visibility Abuse

- **Description:** Sensitive helpers accidentally marked `public` can be called by other modules and bypass intended entry checks.
- **Code Review:**
  - External-facing flows are careful about visibility:
    - Most sensitive bookkeeping functions are `public(package)` or private (`fun`).
    - No `public entry` functions exist; composition is via module functions expecting proper capability arguments.
  - Examples:
    - `house_state::process_transactions`, `mint_shares`, `burn_shares`, `calculate_total_pending_fees` are `public(package)`.
    - Vault settlement functions are `public(package)`.
- **Assessment:** ✅ **Secure** (Informational).

#### [I-03] Type Confusion / Object Masquerading

- **Description:** Accepting generic `Clock`/`Random` or similar structs without fully qualified types enables attackers to pass fake objects.
- **Code Review:**
  - No use of `Clock`, `Random`, or external system objects in critical financial logic.
  - The modules consistently use concrete types (`BalanceManager`, `PlayProof`, `House`, etc.) rather than generic IDs.
- **Assessment:** ✅ **Not Applicable** (Informational).

#### [I-04] Transfer-to-Object Trap

- **Description:** Using `transfer::public_transfer` to send objects to arbitrary object IDs can permanently lock assets.
- **Code Review:**
  - `transfer::public_transfer` and `transfer::share_object` are used **only** in safe patterns:
    - `Registry::init` shares `Registry` and transfers `OpenPlayAdminCap` to `ctx.sender()`.
    - `GameStatistics::share`, `FeeCollector::share`, `BalanceManager::share`, `House::share` use `share_object(self)`.
  - There is no transfer of fungible or NFT assets directly to arbitrary object IDs for dynamic field reception.
- **Assessment:** ✅ **Not Vulnerable** (Informational).

#### [I-05] Phantom Type Misuse

- **Description:** Incorrect use of phantom type parameters on token types/oracles can enable cross-asset confusion.
- **Code Review:**
  - The system uses only `Coin<SUI>` and `Balance<SUI>`; there is no generic `Coin<T>` user-defined token abstraction.
- **Assessment:** ✅ **Not Applicable**.

#### [L-01] Capability Leakage / Cloning

- **Description:** Storing caps in shared objects or enabling duplication may give arbitrary users admin powers.
- **Code Review:**
  - Caps (`OpenPlayAdminCap`, `HouseAdminCap`, `BalanceManagerCap`, `PlayCap`, `FeeCollectorCap`) all have `key, store` abilities (no `copy`), and none are stored inside shared objects.
  - `HouseTransactionCap` has **no abilities**, so it cannot be stored or copied; it is used in **hot-potato** fashion and consumed in `assert_valid_tx_cap`.
- **Assessment:** 🔵 **Low** (positive finding) – best-practice cap management.

#### [L-02] Storage Growth DoS (Unbounded Structures)

- **Description:** Unbounded `Table` / `VecMap` / `VecSet` growth can cause long-term storage bloat and potential gas issues in loops.
- **Code Review:**
  - Bounded collections:
    - `House::game_fee_collectors: VecMap<ID, ID>` with `MAX_GAMES = 500`.
    - `BalanceManager::tx_allow_listed: VecSet<ID>` with `MAX_PLAY_CAPS = 1000`.
  - Potentially unbounded:
    - `State::accounts: Table<ID, Account>` keyed per `BalanceManager`.
    - `State::historic_volumes: Table<u64, Volumes>` and `historic_collector_ggr: Table<u64, VecMap<...>>`.
    - `GameStatistics::historic_volumes: Table<u64, Volumes>`.
  - Loops used in critical paths:
    - `house_state::calculate_pending_collector_fees` iterates over `VecMap` keys (bounded by number of collectors in current epoch).
    - `house_state::process_collector_end_of_day` iterates over current collectors to compute and store GGR.
- **Impact:**
  - Potential **long-term** storage growth and slightly increasing gas per epoch for large numbers of active collectors and long protocol lifetimes.
  - No immediate DoS: loops are bounded by **current** collector count and executed only on epoch transitions.
- **Assessment:** 🔵 **Low** (Storage hygiene).
  - **Recommendation**: Introduce admin- or governance-controlled pruning of very old historical epochs (e.g., keep latest 365 epochs by default).

### 3.2 DeFi-Specific Vectors (SMS‑2025 §2.2)

#### [I-06] Flash Loan Hot-Potato Enforcement

- **Observation:** While this protocol does not implement explicit flash loans, it uses a **hot-potato-style** capability (`HouseTransactionCap`) that obeys the same security principles:
  - `HouseTransactionCap` struct has **no abilities**, preventing storage, copying, or sharing.
  - `borrow_tx_cap` returns `HouseTransactionCap` by value, and `tx_admin_process_transactions_v2[_no_bm]` consume it, destructuring and validating parameters (`house_id`, `game_id`, `fee_collector_id`).
- **Assessment:** ✅ **Excellent** (Informational).

#### [I-07] Oracle Manipulation & Stale Data

- **Observation:** The protocol does **not** use external price oracles (Pyth/Switchboard/etc.). All pricing is internal NAV-based.
- **Assessment:** ✅ **Not Applicable**.

#### [I-08] Invariant Enforcement & Arithmetic Safety

- **Invariants (informal):**
  - Vault solvency: `house_balance` must always be sufficient for withdrawals and fee allocations (`EInsufficientFunds` enforced in `Vault`).
  - Fee invariants: Protocol + house + collector fees are capped and must not exceed 100% of GGR; house + collector fees ≤ 50% (with protocol 20% cap) leaves ≥30% to stakers.
  - NAV: Share mint/burn operations keep `total_shares` consistent with `Participation` balances.
- **Arithmetic:**
  - All fee and ratio calculations use `calculations::mul_floor` and `mul_ceil` with **u128 intermediates** and explicit overflow checks.
  - Basis-point helpers `mul_floor_bps` and `mul_ceil_bps` enforce safe denominators and caps.
- **Assessment:** ✅ **Secure** (Informational).

### 3.3 GambleFi-Specific Vectors (SMS‑2025 §2.3)

#### [I-09] Randomness Predictability & Scaling Bias

- **Observation:** The core protocol deliberately **does not implement RNG**. It assumes games handle randomness separately, often using `sui::random` or off-chain VRF.
- **Assessment:** ✅ **Correct-by-design** – randomness concerns are outside the scope of this package.

#### [M-01] Shared Object Sequencing & Front-Running (Design Risk)

- **Description:** Shared `House` and `BalanceManager` objects can be involved in sequences where the ordering of transactions affects payoffs.
- **Code Review:**
  - The protocol processes gameplay via `tx_admin_process_transactions_v2` / `_no_bm`, which:
    - Validate `HouseTransactionCap` and `GameStatistics` consistency.
    - Use `State::process_transactions` + `Vault::settle_balance_manager` atomically per PTB.
  - End-of-day logic (`House::process_end_of_day`) is triggered on demand by core operations (buy/sell/claim/settlement) when epoch changes.
- **Impact:**
  - Standard MEV risk: different transaction orderings can lead to slightly different NAV and fee outcomes across epochs.
  - No direct exploit that lets an attacker siphon funds beyond what is implied by house risk and game rules.
- **Assessment:** 🟡 **Medium (inherent design / centralization risk)** – see [M-02] below.

#### [L-03] Replay / Double-Claim Protection

- **Observation:**
  - `HouseTransactionCap` consumption ensures a cap cannot be reused.
  - `Account::settle` consumes and resets `credit_balance` and `debit_balance` per settlement.
  - `State` moves GGR and fees to history per epoch; fees cannot be double-counted.
- **Assessment:** ✅ **Secure** (Informational).

---

## 4. Detailed Findings (per SMS‑2025 §4)

Severity legend:

- **[C] Critical** – fund theft, permanent loss, or systemic break.
- **[H] High** – serious economic vulnerability or admin key abuse path.
- **[M] Medium** – design/centralization risks, or bounded but non-fatal issues.
- **[L] Low** – minor issues, UX, or storage gas inefficiencies.
- **[I] Informational** – best practices and positive findings.

### [M-01] Medium – OpenPlay Admin Centralization Risk

**Description:**  
`OpenPlayAdminCap` is a powerful governance capability:

- Can **allow/disallow package versions** via `admin_allow_version` / `admin_disallow_version`.
- Can **set protocol fee bps** via `update_protocol_fee_bps`, bounded by `max_protocol_fee_bps = 2000` (20%).

While this cap cannot arbitrarily seize user funds or halt `buy_shares`/`sell_shares`/claims, it can:

- Disable gameplay for a given version by disallowing `current_version()`.
- Turn protocol fees up to the hard-coded maximum.

**Impact:**

- A compromised or malicious admin key could:
  - Freeze all gameplay (new transaction processing) by disabling the active version.
  - Increase protocol fees to the maximum allowed, changing the protocol’s economics overnight.

**Proof-of-Concept Sketch:**

```move
// Assuming attacker controls OpenPlayAdminCap and Registry shared object
public fun grief(registry: &mut Registry, cap: &OpenPlayAdminCap, ctx: &mut TxContext) {
    // Disable current version
    registry.admin_disallow_version(cap, current_version(), ctx);

    // Set protocol fee to 20% (within allowed caps)
    registry.update_protocol_fee_bps(cap, max_protocol_fee_bps(), ctx);
}
```

**Recommendation:**

- Use **multi-signature control** (off-chain or higher-level) for `OpenPlayAdminCap`.
- Consider a **timelock** for large parameter changes (fee bps, version allow/disallow) with on-chain events used by watchdogs.
- Document governance clearly in public docs, stating who controls `OpenPlayAdminCap` and under which procedures.

**Client Status:** Design tradeoff (expected centralization for v3.1). No immediate code fix required, but governance mitigations recommended.

---

### [M-02] Medium – Economic & Sequencing Risk in Whitelisted Gameplay Model

**Description:**  
The protocol intentionally adopts a **whitelisted, audited gameplay model**:

- Off-chain games hold or derive `HouseTransactionCap` and submit batched `Transaction` vectors.
- `Vault::settle_balance_manager` honors debits and credits as reported by the game, using a `PlayProof` to link to a shared `BalanceManager`.

In this model:

- A malicious or compromised game backend can generate arbitrary `Transaction` vectors (e.g., always winning for the house or for the player) and submit them as long as they pass basic invariants.
- Games can selectively process or ignore transactions, effectively censoring or rewriting history from the user’s perspective.

**Impact:**

- If a game backend is untrusted or compromised, it can **drain user balances** present in the `BalanceManager` that is associated with its gameplay.
- This is **not** a bug in the on-chain code but is important to surface as a **design/centralization risk** in the audit report.

**Recommendation:**

- Clearly document that custody and core accounting are **trust-minimized and on-chain**, while **outcome fairness** still depends on whitelisted, audited game backends that implement their own verifiable randomness and integrity guarantees.
- For higher-assurance games, consider:
  - Commit–reveal schemes for result proofs.
  - On-chain verification of RNG where possible.
  - Separation of roles between dealer, verifier, and settlement engine.

**Client Status:** Acknowledged design choice; out of scope for v3.1 code changes.

---

### [L-01] Low – Unbounded Historical Storage Growth

**Description:**  
Several tables grow monotonically over time:

- `State.historic_volumes: Table<u64, Volumes>`.
- `State.historic_collector_ggr: Table<u64, VecMap<ID, CollectorGGR>>`.
- `GameStatistics.historic_volumes: Table<u64, Volumes>`.
- `State.accounts: Table<ID, Account>` may accumulate obsolete accounts for balance managers that are never used again.

**Impact:**

- Long-term storage growth leads to increased state size and may marginally increase gas costs for some operations.
- Does not pose a direct solvency or safety risk.

**Recommendation:**

- Add optional admin functions (gated to `OpenPlayAdminCap` and/or `HouseAdminCap`) to prune historical data older than a configured threshold (e.g., epochs older than N).
- Provide tooling/off-chain scripts to monitor and manage state size.

**Client Status:** Not addressed in current version; recommended for future improvements.

---

### [L-02] Low – Fixed Upper Bounds for Games and PlayCaps

**Description:**  
- `MAX_GAMES = 500` in `house.move` limits games per house.
- `MAX_PLAY_CAPS = 1000` in `balance_manager.move` limits minted PlayCaps per balance manager.

**Impact:**

- Extremely large deployments may hit these hard-coded limits, requiring manual cleanup or architectural workarounds.

**Recommendation:**

- Keep these limits but **document them clearly** in public documentation.
- For future versions, consider making these values configurable at house creation, within safe ranges.

**Client Status:** Known; documented as acceptable tradeoff.

---

### [L-03] Low – No User-Provided Slippage on Share Operations

**Description:**  
`house::buy_shares` and `house::sell_shares` compute shares and payouts based on current `effective_house_balance` and `total_shares`, after forcing a `process_end_of_day` when epochs changed.

- There are **no `min_shares_out` or `min_amount_out` parameters**.
- Users are exposed to NAV changes between transaction submission and execution.

**Impact:**

- Under volatile conditions or heavy gameplay activity, the NAV of house shares can move materially, and users have no on-chain guardrail to prevent adverse slippage.

**Recommendation:**

- Add optional parameters:
  - `min_shares_out` to `buy_shares`.
  - `min_amount_out` to `sell_shares`.
- Maintain backwards-compatible overloads or clearly document the change.

**Client Status:** Not yet implemented; recommended for user protection in future upgrades.

---

### Informational Positive Findings

- **[I-10] Excellent Hot-Potato Implementation for `HouseTransactionCap`** – No abilities; consumed by value.
- **[I-11] Strong Event Coverage** – Deposits, withdrawals, fee updates, end-of-day processing, and fee claims all emit events.
- **[I-12] Version Control Cannot Lock Funds** – Registry checks are only used for gameplay and house registration; share buy/sell and claims remain available even if gameplay is paused.
- **[I-13] Protocol-Favoring, Overflow-Safe Arithmetic** – `mul_floor` / `mul_ceil` use u128 intermediates and explicit overflow checks.
- **[I-14] PlayCap Equivocation Risk Acknowledged** – Comments explain Sui-specific concurrent-use risks and provide `prune_allow_list`.
- **[I-15] Comprehensive Test Suite** – 303 tests covering edge conditions for fees, NAV, GGR, and settlement.

---

## 5. Automated & Formal Verification (SMS‑2025 §3)

### 5.1 Sui Move Linter & Tests

- Command executed:

```bash
sui move test --path package
```

- Result:
  - ✅ Build successful.
  - ✅ All 303 tests passed.

No compiler or linter errors were observed. Test names show coverage over:

- Fee caps and boundary conditions.
- Epoch transitions and end-of-day logic.
- NAV behavior under profits and losses.
- Balance manager proofs and capability validity.

### 5.2 Move Prover / Formal Specs

- The current codebase does **not** include `spec` blocks or Move Prover configuration.
- Given the complexity of fee and NAV invariants, adding Prover specs would be valuable future work:
  - Invariants such as `vault.house_balance >= sum(all outstanding claims)` would be prime candidates.

---

## 6. Pre-Flight Checklist (SMS‑2025 §5)

### 6.1 Upgrade & Governance

| Check | Status | Notes |
|-------|--------|-------|
| Package immutable? | ⚠️ No | Upgradeable via new publishes + `Registry.allowed_versions`. |
| Upgrade governance documented? | ⚠️ Partial | Registry versioning in code; off-chain governance model unspecified. |
| Emergency pause mechanism? | ✅ Yes | `admin_disallow_version` pauses gameplay for given version. |
| Fund access during pause? | ✅ Yes | `buy_shares`/`sell_shares` and claims avoid `check_version`. |

### 6.2 Events

| Check | Status | Notes |
|-------|--------|-------|
| Deposits emit events? | ✅ Yes | `DepositCompletedEvent`. |
| Withdrawals emit events? | ✅ Yes | `WithdrawalProcessedEvent`. |
| Fee claims emit events? | ✅ Yes | Protocol, house, and collector fee claimed/processed events. |
| Admin actions emit events? | ✅ Yes | Fee update, version (dis)allow, house registration, game stats init, etc. |

### 6.3 Slippage & Fee Logic

| Check | Status | Notes |
|-------|--------|-------|
| Fees capped? | ✅ Yes | Protocol ≤20%, house+collector ≤50%. |
| User-specified slippage? | ⚠️ No | See [L-03]. |
| Fee invariants safe? | ✅ Yes | At least 30% of GGR remains to house/stakers by construction. |

### 6.4 DoS & Gas Limits

| Check | Status | Notes |
|-------|--------|-------|
| Unbounded loops over large vectors? | ⚠️ Bounded but notable | Collector loops limited by current collector count and MAX_GAMES. |
| Pagination for large state? | ❌ No | Not required for current on-chain flows. |

### 6.5 Centralization Review

| Check | Status | Notes |
|-------|--------|-------|
| Single party can rug user funds? | ❌ No | Admin cannot arbitrarily seize user `BalanceManager` funds or staker shares. |
| Single cap combines upgrade + fund seizure powers? | ❌ No | `OpenPlayAdminCap` controls versioning and protocol fee only. |
| Practical governance centralization? | ⚠️ Yes | `OpenPlayAdminCap` is powerful; multi-sig recommended. |

---

## 7. Conclusion

### 7.1 Overall Assessment

The `openplay_core` package demonstrates **mature, security-conscious design**:

- Robust capability patterns and hot-potato semantics.
- Arithmetic that is overflow-safe and protocol-favoring.
- GGR-based fee model with clear epoch semantics.
- Comprehensive unit test coverage for critical flows.

### 7.2 Deployment Readiness

Under the assumptions that:

1. `OpenPlayAdminCap` is protected via strong governance (multi-sig or similar), and
2. Games built atop OpenPlay Core are operated by trusted entities (or augmented with their own cryptographic fairness mechanisms),

**this version of OpenPlay Core is suitable for production deployment** with the non-critical recommendations noted above.

---

## 8. Appendix – SMS‑2025 Coverage Checklist

- **Architecture & Recon**
  - [x] Object Ownership Map
  - [x] Capability Lifecycle & Flow
  - [x] Privileged Roles & Centralization Matrix
  - [x] Object Lifecycle & Concurrency Analysis
- **Kill-Chain Analysis**
  - [x] General Sui Move Vectors (Coin Smasher, visibility, type confusion, transfer-to-object, caps, storage DoS)
  - [x] DeFi Vectors (invariants, arithmetic, hot-potato)
  - [x] GambleFi Vectors (shared-object sequencing, replay)
- **Automated & Formal**
  - [x] `sui move test`
  - [ ] Move Prover invariants (recommended for future work)
- **Reporting**
  - [x] Findings with ID, severity, impact, and recommendations
- **Pre-Flight Checklist**
  - [x] Upgrade & Governance
  - [x] Events
  - [x] Slippage & Fee Logic
  - [x] DoS & Gas Limits
  - [x] Centralization Review

---

**Disclaimer:** This audit reflects the code and configuration present in the repository at the time of review. It cannot guarantee the absence of all vulnerabilities, nor does it protect against private key compromise, governance failures, or vulnerabilities in dependent game contracts. Any future code changes, dependency upgrades, or governance changes require a fresh audit.