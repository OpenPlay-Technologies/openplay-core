# OpenPlay Core — Security Audit Report (GPT-5.1-CODEX-MAX)

**Date:** 2025-12-07  
**Auditor:** GPT-5.1-CODEX-MAX (automated)  
**Commit / Revision:** N/A (working tree not under git)  
**Scope:** `/package/sources` Move modules and docs; scripts not executed on-chain  
**Chain/Framework:** Sui / Move 2024.beta

## 1. Executive Summary
- Overall risk posture is **elevated** due to upgradeability and single-admin control over gameplay allowlists and protocol fees. No critical code-execution bugs were found in core logic.
- Core money-flow modules (`house`, `vault`, `balance_manager`, `house_state`, `participation`) implement capability checks and bounded collections, reducing common Sui object risks.
- PlayCap allowlist exhaustion risk is now mitigated by a new owner-only `prune_allow_list` but still requires correct operator usage.
- Automated assurance: unit tests now run and **all 181 tests pass**; Move Prover specs and fuzz/property tests remain absent.

## 2. Methodology
- Reviewed SMS-2025 guidelines (guidelines_1.md, guidelines_2.md).
- Manual code review of all Move modules in `package/sources` (objects, caps, kill-chain vectors, fee logic, epoch handling, dynamic fields).
- Executed `sui move test` locally; all 181 tests passed (see Testing section).
- No on-chain interactions or bytecode diffing were performed.

## 3. Architecture & Recon
### 3.1 Object Ownership Map
| Object | Type | Notes |
| --- | --- | --- |
| `Registry`, `House`, `GameStatistics`, `BalanceManager` | Shared | Entry points for gameplay & accounting. |
| `Vault`, `State`, `Account` | Wrapped (inside `House`) | Not independently addressable; lifecycle tied to `House`. |
| `Participation`, `ParameterStore` | Owned key objects | User staking receipts and config bag. |
| `OpenPlayAdminCap`, `HouseAdminCap`, `BalanceManagerCap`, `PlayCap` | Owned caps | Gate privileged ops; no shared storage of caps. |
| `PlayProof`, `HouseTransactionCap` | Ephemeral (no key) | Used per-transaction; not storable. |

### 3.2 Capability Flow
- `OpenPlayAdminCap` minted once at publish and sent to publisher address (`registry.init`).
- OpenPlay admin uses it to create Houses and to allow/disallow package versions and set protocol fees.
- `HouseAdminCap` minted on house creation and controls game allowlist and house fee claims.
- `HouseTransactionCap` is borrowed per game (`borrow_tx_cap`) after allow-listing; no persistence.
- `BalanceManagerCap` controls deposits/withdraws and PlayCap minting; `PlayCap` delegates gameplay access.

### 3.3 Privileged Roles & Centralization Matrix
| Role | Capability | Upgrade Code? | Pause Gameplay? | Move User Funds? |
| --- | --- | --- | --- | --- |
| OpenPlay Admin | `OpenPlayAdminCap` (+ external upgrade cap) | Yes (upgrade cap) | Yes (disable versions) | Indirect (set high protocol fees) |
| House Admin | `HouseAdminCap` | No | Yes (revoke game allowlist) | House fee withdrawal only |
| Game / Operator | `HouseTransactionCap` | No | No | Moves player funds within allowed transactions |

### 3.4 Lifecycle & Concurrency Notes
- Epoch-sensitive logic handled in `house.process_end_of_day` and `house_state.process_end_of_day`; vault/state epochs are synchronized per call.
- Collections are bounded: `MAX_TX_CAPS = 1000`, `MAX_PLAY_CAPS = 1000`; prevents unbounded growth but stale entries can exhaust limits (see Finding M-01).
- No randomness/oracle usage in core contracts (GambleFi randomness out-of-scope here).

## 4. Findings

### [H-01] High — Upgradeable package with single-admin control and fee/pause powers
**Location:**
- `registry.init` mints `OpenPlayAdminCap` to publisher address and marks current version allowed (upgradeable by design).
``` 
176:189:package/sources/registry.move
let registry = Registry { ... };
transfer::share_object(registry);
let admin = OpenPlayAdminCap { id: object::new(ctx) };
transfer::public_transfer(admin, ctx.sender());
```
- Upgrade rationale/process documented in `docs/upgrades.md` (upgradeable by design; version allowlist selectively pauses gameplay while keeping funds operable).
``` 
4:119:docs/upgrades.md
The OpenPlay Core package is upgradeable… Registry maintains allowed_versions… gameplay paused when version disabled… funds remain withdrawable.
```
**Description:** A single signer holding `OpenPlayAdminCap` (and the off-chain upgrade capability) can: (a) deploy new code without on-chain governance or delay, (b) disable versions to halt gameplay, and (c) set protocol fees up to 99.99%. The upgrade document explains the intent (rapid iteration; selective pause that never locks funds), but the centralized trust assumption remains.

**Impact:** Centralized trust assumption; key compromise can pause all houses, redirect fee flows, or deploy malicious upgrades affecting all users and operators.

**Proof of Concept (conceptual):**
1. Call `registry.admin_disallow_version` to remove the active version — all `tx_admin_process_transactions_v2` abort because `registry.protocol_fee_bps()` fails. 
2. Deploy upgraded package with malicious fee logic; allow the new version; gameplay resumes under attacker-controlled code.

**Recommendation:**
- Move upgrade and admin operations behind a multi-signature and time-locked governance process.
- Cap protocol fees with tighter upper bounds or governance-controlled ceilings.
- Publish an immutable package for production deployments or add on-chain guard rails (e.g., version allowlist changes require multi-sig + delay, fee changes bounded and rate-limited).
- Document and monitor admin key handling; emit and monitor events for version/fee changes (per `docs/upgrades.md`).

**Status:** Acknowledged by design (upgradeable); not remediated.

---

### [M-01] Medium — PlayCap allowlist exhaustion mitigated but operator-dependent
**Location:**
- PlayCap mint bound and allowlist insert: `mint_play_cap` uses `tx_allow_listed.insert` and checks `MAX_PLAY_CAPS`.
- New mitigation: owner-only `prune_allow_list` clears the allow list and emits `PlayCapAllowListPrunedEvent`.
``` 
171:220:package/sources/balance_manager.move
public fun prune_allow_list(self: &mut BalanceManager, cap: &BalanceManagerCap) {
    self.validate_owner(cap);
    let pruned_count = self.tx_allow_listed.length();
    self.tx_allow_listed = vec_set::empty();
    emit(PlayCapAllowListPrunedEvent { balance_manager_id: self.id(), pruned_count });
}
```
**Description:** The raw `destroy_play_cap` still leaves IDs in `tx_allow_listed`, but owners can now reclaim capacity via `prune_allow_list` (or use `destroy_play_cap_and_revoke`). Risk now depends on operator behavior: if they destroy caps without revoke and never prune, the allowlist can still saturate.

**Impact:** Reduced to operational risk; self-DoS is avoidable with the new pruning function but remains possible with unsafe workflows.

**Recommendation:**
- Enforce or document a safe lifecycle: prefer `destroy_play_cap_and_revoke`; periodically call `prune_allow_list` when caps are rotated.
- Consider emitting a warning/event when `destroy_play_cap` is used while the ID remains in the allow list, or add an optional clean-up path there.

**Status:** Mitigated (requires operator discipline).

---

### [L-01] Low — Automated assurance and formal specs absent
**Description:** No Move Prover `spec` blocks or fuzz/property tests exist in the codebase. Unit test coverage is strong (181 tests) and all pass, but formal verification and fuzzing are still missing.

**Impact:** Invariants (solvency, epoch accounting, fee bounds) are enforced only by runtime asserts and unit tests; deeper edge cases may escape detection without specs/property testing.

**Recommendation:**
- Add Move Prover specs for vault/state balance invariants, fee non-negativity, and stake/unstake conservation.
- Add fuzz/property tests for rounding paths (`calculations`, `participation`, `house_state`) and transaction batch processing.
- Keep `sui move test` in CI; expand with property-based generators where possible.

**Status:** Open (tests pass; specs/fuzz missing).

## 5. Kill-Chain Checklist (coverage)
- Coin smasher / partial balances: Not applicable; all gameplay uses integer amounts and Balance operations, not assumed full wallet balances.
- Function visibility: Sensitive ops are gated by caps; no unexpected `public` entry points identified.
- Type confusion: All system types are fully qualified; no `Clock`/`Random` arguments found.
- Transfer-to-object trap: Shared objects are shared via `transfer::share_object`; no arbitrary transfers to object IDs observed.
- Flash loan receipts: Not implemented.
- Oracle freshness / randomness: Not used in core; ensure downstream game modules adopt VRF/pyth freshness when integrated.
- Storage growth: Allow lists bounded (1000) but see M-01 for stale entries; dynamic fields only in `parameter_store` with explicit freeze option.

## 6. Testing & Tooling
- `sui move test` — **run, all tests passed (181/181)**. Output available in terminal logs.
- No Move Prover specs or fuzz tests present. Recommend adding and running in CI.

## 7. Recommendations & Pre-Flight Checklist
- Governance: Introduce multi-sig + timelock for admin/upgrade; cap protocol fees.
- Mitigate PlayCap allowlist exhaustion (cleanup or pruning).
- Add Move Prover specs for solvency, fee bounds, epoch transitions; add fuzz/property tests for rounding and transaction batches.
- Monitoring: Emit/monitor events for version allowlist changes and fee updates; publish runbooks for pause/upgrade procedures.
- Upgrade posture: Plan path to immutability or audited governance before mainnet scale.

## 8. Disclaimer
This audit is a best-effort code review against SMS-2025 guidelines. It does not guarantee absence of vulnerabilities or protect against compromised keys or economic attacks outside the reviewed code.
