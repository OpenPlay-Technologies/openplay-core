# OpenPlay Core Security Audit — GPT-5.1 Codex

| Item | Detail |
| --- | --- |
| **Project** | OpenPlay Core (Sui Move) |
| **Commit** | `1e76099c30891013d9b51890ec20665576630265` |
| **Audit Window** | 4 Dec 2025 |
| **Auditors** | GPT-5.1 Codex |
| **Scope** | `/package/Move.toml`, `/package/sources/**/*`, `/package/tests/**/*`, `/scripts/**/*`, `/audit/guidelines_{1,2}.md` |

---

## 1. Executive Summary
- Protocol combines shared `House` objects, per-player `BalanceManager`s, and referral accounting inside the embedded `Vault`/`State` pair.
- Overall technical posture is **Medium Risk**: core accounting paths are well-covered by tests, but governance/bootstrap hardening and referral handling leave griefing avenues and observability gaps.
- No user-facing withdrawal blockers were identified; even when governance disables versions, `Participation` holders can unstake and claim.
- Five issues were recorded (2 Medium, 3 Low). None were fixed at the time of this report.

## 2. Methodology (SMS-2025 Alignment)
1. **Reconnaissance:** mapped all Move structs into the SMS object categories and traced capability flows per §§1.1-1.5 of `guidelines_1.md`/`guidelines_2.md`.
2. **Kill Chain Review:** evaluated each checklist item (Coin Smasher, capability leakage, oracle usage, etc.).
3. **Automation:** executed `sui move test` (full pass) and reviewed available unit tests; no Move Prover or fuzz specs exist yet.
4. **Reporting & Pre-flight:** produced this markdown following SMS-2025 §4-§5 format and revalidated upgrade/events/doS considerations prior to delivery.

## 3. Architecture & Recon
### 3.1 Object Ownership Map
| Object | Category | Notes |
| --- | --- | --- |
| `House` (shared) | Shared Object | Wraps `Vault` and `house_state::State`, orchestrates staking, gameplay settlement, fees. |
| `Vault` | Wrapped Object | Stores play/reserve balances plus fee buckets; never shared separately. |
| `house_state::State` | Wrapped Object | Tracks accounts, epoch volumes, and profit/loss distribution. |
| `BalanceManager` | Shared Object | Player-controlled wallet for game funds. |
| `BalanceManagerCap`, `PlayCap`, `HouseAdminCap`, `ReferralCap`, `OpenPlayAdminCap` | Owned Objects (caps) | Grant privileged flows (deposit/withdraw, tx allow, referral claims, protocol governance). |
| `HouseTransactionCap` | Wrapped (copyable struct) | Borrowed per allowed game to authorize settlement + fee claims. |
| `Participation` | Owned Object | Tracks each staker’s state, pending stake, and claimable balance. |
| `Registry` | Shared Object | Global governance (protocol fee, allowed versions, house roster). |
| `GameStatistics` | Shared Object | Per-game telemetry object updated during settlement. |
| `Referral` | Shared Object | Public referral handle; currently not referenced during fee accrual. |
| `ParameterStore` | Owned Object | Generic dynamic field bag (unused in scope). |

### 3.2 Capability Flow Highlights
- **Package Publish:** Intended to mint a single `Registry` shared object plus `OpenPlayAdminCap` via `registry::init`, but the function lacks `#[init]` so bootstrap currently depends on manual intervention (see Finding M-02).
- **House Creation:** Only `OpenPlayAdminCap` may call `house::openplay_admin_new_house`, returning `(House, HouseAdminCap)`. Operator must then call `house::share` to register with `Registry` and make the object shared.
- **Game Authorization:** House admin inserts `game_id` into `tx_allow_listed`. Any holder of that object’s `UID` may borrow unlimited `HouseTransactionCap`s (copyable struct) to settle gameplay or claim game fees.
- **Player Funds:** `BalanceManagerCap` mints `PlayCap`s; holders must participate in PTBs to sign off on settlement. Proofs are ephemeral (`PlayProof` lacks `store`).
- **Referral Flow:** Anybody may call `house::new_referral` when referral fees are enabled; referrals are not stored in House state, so fee accounting relies solely on the raw `ID` passed during settlement.

### 3.3 Privileged Roles & Centralization Matrix
| Role | Capability | Upgrade Code? | Move User Funds? | Pause Gameplay? | Notes |
| --- | --- | --- | --- | --- | --- |
| OpenPlay Admin | `OpenPlayAdminCap` | Can gate versions (effectively pause) | Protocol fees only | Yes (via version disable) | Cannot seize user stakes or balances. |
| House Admin | `HouseAdminCap` | No | No | Controls game allow list/fees | Can make house private (staking restricted). |
| Game Operator | `HouseTransactionCap` | No | Can debit credit BalanceManagers / Vault per settlement | Indirect (malicious caps can drain vault) | Trust assumption: holder defines game outcomes. |
| Referral Owner | `ReferralCap` | No | Only own referral bucket | No | Can claim referral fees if referral_id exists. |
| Balance Manager Owner | `BalanceManagerCap` | No | Only own funds | No | Mints/revokes `PlayCap`s.

*Centralization Takeaway:* No single cap can both upgrade code and seize user deposits; however, governance can pause gameplay globally by disallowing package versions. Referral fee routing currently depends entirely on off-chain honesty of `HouseTransactionCap` holders.

### 3.4 Lifecycle & Concurrency Notes
- `House`, `BalanceManager`, `GameStatistics`, and `Registry` are shared objects; Sui’s shared-object locking guarantees exclusive mutation, mitigating race conditions noted in SMS §1.5.
- `Participation`/`BalanceManager` destruction paths exist but require zero balances; revoked `PlayCap`s leak storage (Finding L-02).
- No dynamic fields are used (aside from `ParameterStore`, not exercised) so orphaned child objects are not present.

## 4. Kill Chain Checklist Outcomes
| Kill Chain Item | Status | Notes |
| --- | --- | --- |
| Coin Smasher / partial balances | ✅ | Bets/wins mediated by `BalanceManager` proofs; staking accepts whole coins and tracks exact amounts. |
| Function visibility | ✅ | No sensitive helper marked plain `public` without capability gating. |
| Object masquerading | ⚠️ | `tx_admin_process_transactions_v2` trusts any `referral_id` `ID` without verifying existence (Finding M-01). |
| Transfer-to-object trap | ✅ | Only used in `registry::init` to hand out admin cap. |
| Phantom types | ✅ | No phantom misuse detected. |
| Capability leakage/cloning | ⚠️ | `HouseTransactionCap` is copyable, so once borrowed it can be duplicated indefinitely; mitigated only by allow-list revocation. |
| Storage growth DoS | ⚠️ | Referral ID spam expands `Vault.collected_referral_fees` unboundedly (Finding M-01). |
| Flash loan receipt abilities | N/A | Protocol does not expose flash loans. |
| Oracle handling | N/A | No on-chain oracle integration. |
| Dynamic field orphans | ✅ | Not applicable. |
| GambleFi randomness | ✅ | No pseudo-random logic in scope (deterministic settlement). |
| Shared object sequencing | ✅ | `House.process_end_of_day` synchronizes vault/state epochs before each mutation. |

## 5. Detailed Findings
Severity scale: Critical > High > Medium > Low > Informational.

### [M-01] Phantom Referral IDs Can Lock Fees & Grow Storage Unbounded (Open)
- **Location:** `package/sources/house.move`, `package/sources/vault.move`
- **Description:** Settlement accepts any `ID` inside `referral_id: Option<ID>` without verifying that a shared `Referral` object or `ReferralCap` exists for the given house. Every new `ID` causes `Vault::ensure_referral_fee_balance` to insert a fresh `Balance` entry.

```352:375:package/sources/house.move
    let referral_fee_factor;
    if (referral_id.is_some()) {
        self.assert_referral_active();
        referral_fee_factor = some(self.referral_fee_factor());
    } else {
        referral_fee_factor = none();
    };
    // ...
    if (referral_id.is_some()) {
        self.vault.process_referral_fee(*referral_id.borrow(), referral_fee);
    };
```

```223:238:package/sources/vault.move
fun ensure_referral_fee_balance(self: &mut Vault, referral_id: ID) {
    if (!self.collected_referral_fees.contains(&referral_id)) {
        self.collected_referral_fees.insert(referral_id, balance::zero());
    };
}
```

- **Impact:** A malicious (or buggy) `HouseTransactionCap` holder can loop over arbitrary IDs (e.g., `object::id_from_address(@attacker)`) to create thousands of empty referral buckets. Each bucket permanently siphons referral fees away from legitimate partners because no `ReferralCap` exists to withdraw them. Storage and gas cost for `VecMap` operations grows linearly with each phantom entry, degrading house operations and potentially causing future settlements to exceed budget.
- **Proof of Concept:** Submit `tx_admin_process_transactions_v2` with normal bets/wins but set `referral_id = Option::some(object::id_from_address(@att))` for a new `@att` value each time. The transaction succeeds, `referral_fee` is deducted from the vault, but nobody can claim it.
- **Recommendation:** Require an actual `Referral` object reference (or `ReferralCap`) instead of a raw `ID`, and verify `referral.house_id == self.id()` before accruing fees. Alternatively, maintain a registry of valid referral IDs inside the house and reject unknown IDs; also consider capping the number of tracked referral buckets.

### [M-02] `registry::init` Missing `#[init]` Attribute Blocks Deterministic Bootstrap (Open)
- **Location:** `package/sources/registry.move`
- **Description:** The module defines a private `fun init(_: REGISTRY, ctx: &mut TxContext)` that mints the canonical shared `Registry` object and `OpenPlayAdminCap`, but the function lacks the `#[init]` attribute mandated by Sui for publish-time execution. No alternative `public entry` initializer exists, so new deployments cannot automatically produce the governance objects that the rest of the package assumes.

```95:111:package/sources/registry.move
fun init(_: REGISTRY, ctx: &mut TxContext) {
    let mut allowed_versions = vec_set::empty();
    allowed_versions.insert(current_version());

    let registry = Registry {
        id: object::new(ctx),
        allowed_versions,
        houses: vector::empty(),
        protocol_fee_bps: 0,
        game_stats_id: table::new(ctx),
    };
    transfer::share_object(registry);
    let admin = OpenPlayAdminCap { id: object::new(ctx) };
    transfer::public_transfer(admin, ctx.sender());
}
```

- **Impact:** Fresh environments (new networks, new addresses, test deployments) cannot mint the required shared objects without patching the source or exposing `init` as an entry function. This undermines upgrade reproducibility and invites governance chaos (e.g., someone could fork the package, add `#[init]`, and mint an indistinguishable registry/admin cap set). Existing deployments rely on historical objects, but future redeployments are blocked.
- **Recommendation:** Annotate the function with `#[init(only_once = true)]` and ensure the `REGISTRY` witness type does **not** expose `drop` so it cannot be instantiated outside module scope. Alternatively, provide an auditable `public entry` bootstrap that consumes a `OneTimeWitness` resource to mint the registry and admin cap exactly once.

### [L-01] Referral Fee in `TransactionsProcessedEvent` Always Zero (Open)
- **Location:** `package/sources/house.move`
- **Description:** The emitted event hardcodes `referral_fee: 0` even when referral fees are deducted, breaking analytics and revenue-sharing transparency.

```380:391:package/sources/house.move
emit(TransactionsProcessedEvent {
    house_id: self.id(),
    game_id: game_id,
    balance_manager_id: balance_manager.id(),
    referral_id: referral_id,
    transactions: *transactions,
    fees: Fees {
        protocol_fee: protocol_fee,
        game_fee: game_fee,
        referral_fee: 0,
    },
});
```

- **Impact:** Indexers cannot reconcile on-chain events with vault balances; referral partners cannot audit payouts.
- **Recommendation:** Emit the actual `referral_fee` value for both `tx_admin_process_transactions_v2` variants.

### [L-02] Revoking a `PlayCap` Leaves the Object Alive (Open)
- **Location:** `package/sources/balance_manager.move`
- **Description:** `revoke_play_cap` removes the ID from `tx_allow_listed` but never destroys the resource, so revoked caps accumulate in storage and can still be transferred (albeit unusable).

```172:182:package/sources/balance_manager.move
public fun revoke_play_cap(self: &mut BalanceManager, cap: &BalanceManagerCap, player_cap_id: &ID) {
    self.validate_owner(cap);
    assert!(self.tx_allow_listed.contains(player_cap_id), EPlayCapNotInList);
    self.tx_allow_listed.remove(player_cap_id);

    emit(PlayCapRevokedEvent { ... });
}
```

- **Impact:** Storage bloat and potential user confusion (they still hold an object that looks valid). It also complicates auditing because there is no canonical place to see which caps remain active.
- **Recommendation:** Provide a `destroy_play_cap` helper that consumes the `PlayCap`, removes its ID if present, and deletes the underlying `UID` to reclaim storage.

### [L-03] `Participation::claim_all` Emits No Event (Open)
- **Location:** `package/sources/participation.move`
- **Description:** Claiming profits simply zeroes the balance and returns a `Coin<SUI>`; there is no `ClaimProcessedEvent`, so withdrawals are invisible to indexers.

```295:304:package/sources/participation.move
public(package) fun claim_all(self: &mut Participation, ctx: &TxContext): u64 {
    assert!(self.last_updated_epoch == ctx.epoch(), EEpochMismatch);
    let claimable = self.claimable_balance;
    self.claimable_balance = 0;
    claimable
}
```

- **Impact:** Users and auditors cannot prove claims without replaying entire history; monitoring tools cannot alert on large withdrawals.
- **Recommendation:** Emit an event with `participation_id` and `amount` whenever `claim_all` succeeds.

## 6. Automated & Formal Verification Status
| Tooling | Status | Notes |
| --- | --- | --- |
| `sui move test` | ✅ Pass (Dec 4 2025, macOS 25.0) | 81 tests executed successfully. |
| Move Prover | ⚪ Not run | No `spec` blocks present; invariants (pool solvency, referral caps) unproven. |
| Fuzz / Property tests | ⚪ Not run | Consider fuzzing transaction settlement math and staking edge cases. |

## 7. Pre-Flight Checklist
- **Upgrade & Governance:** Package published without documented upgrade policy; governance objects can be paused by disallowing versions but withdrawals remain available.
- **Events:** Coverage is good for admin/game flows, but referral fee emission and participation claims lack accuracy (Findings L-01, L-03).
- **Slippage & Fees:** All fees are parameterized per house/protocol; users specify exact bets in `Transaction` vectors, so no implicit slippage.
- **DoS / Gas:** Core loops are bounded except for referral map growth (Finding M-01). Epoch catch-up loops in `update_participation` increment at most once per epoch and are currently acceptable given Sui epoch cadence.

## 8. Recommended Next Steps
1. **Referral Hardening:** Require concrete referral objects and prune orphaned entries to resolve M-01.
2. **Bootstrap Fix:** Add `#[init]` (or audited bootstrap) to `registry::init` before the next deployment to avoid governance deadlocks.
3. **Telemetry Improvements:** Patch findings L-01 through L-03 to improve monitoring and wallet UX.
4. **Capability Lifecycle:** Introduce `destroy_play_cap` and consider logging PlayCap mint/destroy counts for visibility.
5. **Formal Specs:** Add Move Prover invariants for vault solvency, fee non-negativity, and referral conservation; integrate into CI.

## 9. Environment & References
- **OS:** macOS (Darwin 25.0.0)
- **Sui CLI:** `sui move test` via `/Users/ralph/OpenPlay/openplay-core/package`
- **Guidelines:** `audit/guidelines_1.md`, `audit/guidelines_2.md` (SMS-2025)

---
*Prepared by GPT-5.1 Codex on 4 Dec 2025.*
