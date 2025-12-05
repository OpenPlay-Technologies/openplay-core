# OpenPlay Core Security Audit Report

---

## Executive Summary

| **Project**           | OpenPlay Core                                             |
|-----------------------|-----------------------------------------------------------|
| **Package Version**   | 1.1                                                       |
| **Commit Hash**       | `1e76099c30891013d9b51890ec20665576630265`                |
| **Audit Date**        | December 3, 2025                                          |
| **Auditor**           | Security Review (SMS-2025 Methodology)                    |
| **Language**          | Move (Sui Move 2024.beta edition)                         |
| **Risk Summary**      | **Low Risk** - Protocol is architecturally sound with proper capability patterns and well-designed pause mechanisms. No critical, high, or medium severity issues found. |

### Findings Summary

| Severity       | Count | Status       |
|----------------|-------|--------------|
| 🔴 Critical    | 0     | —            |
| 🟠 High        | 0     | —            |
| 🟡 Medium      | 0     | —            |
| 🔵 Low         | 3     | Open         |
| ⚪ Informational | 5   | Open         |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Scope](#2-scope)
3. [Methodology](#3-methodology)
4. [Architecture Overview](#4-architecture-overview)
5. [Privileged Roles & Centralization Analysis](#5-privileged-roles--centralization-analysis)
6. [Security Findings](#6-security-findings)
7. [Rounding Analysis Deep Dive](#7-rounding-analysis-deep-dive)
8. [Checklist Compliance](#8-checklist-compliance)
9. [Recommendations](#9-recommendations)
10. [Conclusion](#10-conclusion)
11. [Disclaimer](#11-disclaimer)

---

## 1. Introduction

OpenPlay Core is a GambleFi protocol built on the Sui blockchain that provides infrastructure for house-based gambling games. The protocol manages:

- **Balance Managers**: Shared objects for managing player balances
- **Houses**: Shared objects that process and settle transactions between vaults and balance managers
- **Participation**: Staking mechanism allowing users to participate in house profits/losses
- **Referral System**: Fee distribution for referrals
- **Registry**: Central registry for protocol configuration and version control

This audit was conducted following the **Sui & Move Smart Contract Security Standard (SMS-2025)** methodology, covering object lifecycle management, capability analysis, GambleFi-specific attack vectors, and formal verification considerations.

---

## 2. Scope

### Files In Scope

| File Path | Lines | Description |
|-----------|-------|-------------|
| `sources/balance_manager.move` | 344 | Player balance management |
| `sources/calculations.move` | 43 | Financial calculations |
| `sources/core_constants.move` | 37 | Protocol constants |
| `sources/game_stats.move` | 201 | Game statistics tracking |
| `sources/house.move` | 806 | Main house logic |
| `sources/parameter_store.move` | 49 | Parameter storage |
| `sources/participation.move` | 305 | Staking participation |
| `sources/referral.move` | 56 | Referral system |
| `sources/registry.move` | 141 | Protocol registry |
| `sources/state/account.move` | 59 | Account state |
| `sources/state/house_state.move` | 632 | House state management |
| `sources/transaction.move` | 58 | Transaction types |
| `sources/vault.move` | 293 | Asset vault |

**Total: 13 files, ~3,024 lines of code**

### Out of Scope

- Frontend applications
- Off-chain infrastructure
- Game implementations that integrate with the protocol
- Deployment scripts

---

## 3. Methodology

This audit followed the **SMS-2025** standard operating procedure:

1. **Phase 1: Architecture Reconnaissance**
   - Object ownership mapping
   - Capability flow analysis
   - Centralization matrix creation

2. **Phase 2: Kill Chain Analysis**
   - General Move/Sui logic vectors
   - GambleFi-specific attack vectors
   - Access control verification

3. **Phase 3: Automated Verification**
   - Test coverage review (81 tests, all passing)
   - Static analysis considerations

4. **Phase 4: Reporting**
   - Findings documentation
   - Recommendations

---

## 4. Architecture Overview

### 4.1 Object Ownership Map

| Struct | Type | Abilities | Ownership | Risk Assessment |
|--------|------|-----------|-----------|-----------------|
| `BalanceManager` | Shared | `key` | Shared via `share_object` | ✅ Proper validation |
| `BalanceManagerCap` | Owned | `key, store` | User-owned | ✅ Proper ownership |
| `PlayCap` | Owned | `key, store` | Delegated access | ✅ Revocable |
| `PlayProof` | Hot Potato | `drop` | Transaction-scoped | ✅ Correct pattern |
| `House` | Shared | `key` | Shared via `share_object` | ✅ Proper validation |
| `HouseAdminCap` | Owned | `key, store` | Admin-owned | ✅ Single owner |
| `HouseTransactionCap` | Hot Potato | None | Transaction-scoped | ✅ Correct pattern |
| `Participation` | Owned | `key, store` | User-owned | ✅ House-validated |
| `Registry` | Shared | `key` | Protocol singleton | ✅ Version controlled |
| `OpenPlayAdminCap` | Owned | `key, store` | Protocol admin | ⚠️ Centralization |
| `Referral` | Shared | `key` | Shared via `share_object` | ✅ Proper design |
| `ReferralCap` | Owned | `key, store` | Referral owner | ✅ Proper ownership |
| `Vault` | Wrapped | `store` | Inside House | ✅ Protected |
| `State` | Wrapped | `store` | Inside House | ✅ Protected |
| `GameStatistics` | Shared | `key` | Shared via `share_object` | ✅ Proper validation |

**Note on Tables:** Sui's `Table` data structure stores entries as separate on-chain objects. This means the parent object (House, State, GameStatistics) does not grow unboundedly - only the number of child objects increases. This is a correct and scalable design pattern.

### 4.2 Capability Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        PROTOCOL INIT                             │
├─────────────────────────────────────────────────────────────────┤
│  Registry::init() ──► OpenPlayAdminCap ──► tx.sender()          │
│                   ──► Registry (shared)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     HOUSE CREATION                               │
├─────────────────────────────────────────────────────────────────┤
│  openplay_admin_new_house() ──► House + HouseAdminCap           │
│  (requires OpenPlayAdminCap)                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   BALANCE MANAGER CREATION                       │
├─────────────────────────────────────────────────────────────────┤
│  balance_manager::new() ──► BalanceManager + BalanceManagerCap  │
│  mint_play_cap() ──► PlayCap (delegated access)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TRANSACTION PROCESSING                         │
├─────────────────────────────────────────────────────────────────┤
│  borrow_tx_cap() ──► HouseTransactionCap (hot potato)           │
│  generate_proof_*() ──► PlayProof (hot potato)                  │
│  tx_admin_process_transactions_v2() consumes both               │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Version Control & Emergency Pause Mechanism

The protocol implements a version-based pause mechanism through the Registry:

**When version is DISABLED:**

| Operation | Status | Reason |
|-----------|--------|--------|
| `register_house` | ❌ Blocked | Calls `assert_version()` |
| `tx_admin_process_transactions_v2` | ❌ Blocked | Calls `protocol_fee_factor()` which requires version |
| `tx_admin_process_transactions_v2_no_bm` | ❌ Blocked | Same as above |
| `stake` | ✅ Works | No version check needed |
| `unstake_v2` | ✅ Works | No version check needed |
| `claim_all` | ✅ Works | No version check needed |
| `update_participation` | ✅ Works | No version check needed |

**This is intentional and correct behavior:** Users can always withdraw their funds even when gameplay is paused. This prevents funds from being locked in an emergency.

### 4.4 Unstaking Behavior

**When house is ACTIVE:**
- Unstake requests go to `pending_unstake`
- Funds become claimable after epoch ends
- User still participates in profits/losses for the current epoch

**When house is INACTIVE:**
- Unstake is **immediate** to `claimable_balance`
- User can call `claim_all` right away
- No waiting required

This is verified in `participation.move:201-208`:
```move
if (is_active) {
    self.pending_unstake = self.pending_unstake + remaining_amount;
} else {
    self.stake = self.stake - remaining_amount;
    self.claimable_balance = self.claimable_balance + remaining_amount;
};
```

---

## 5. Privileged Roles & Centralization Analysis

### 5.1 Privileged Roles Matrix

| Role | Capability | Upgrade Code? | Move User Funds? | Pause Gameplay? | Pause Withdrawals? |
|------|------------|---------------|------------------|-----------------|-------------------|
| **OpenPlay Admin** | `OpenPlayAdminCap` | Via version control | Indirect (fees) | Yes | **No** |
| **House Admin** | `HouseAdminCap` | No | No | No | No |
| **Game Owner** | `HouseTransactionCap` | No | No | No | No |
| **Referral Owner** | `ReferralCap` | No | No | No | No |
| **Balance Manager Owner** | `BalanceManagerCap` | No | Own funds only | No | No |

### 5.2 Centralization Risk Assessment

| Risk | Severity | Description |
|------|----------|-------------|
| Protocol Fee Control | Low | `OpenPlayAdminCap` can set protocol fees |
| Version Disable | Low | `OpenPlayAdminCap` can pause gameplay (but NOT withdrawals) |
| House Creation Gate | Low | Only OpenPlay admin can create houses |
| Game Fee Control | Low | `HouseAdminCap` can set arbitrary game fees per game |

**Key Security Property:** The OpenPlay admin **cannot** prevent users from withdrawing their funds. Even with version disabled, `unstake_v2` and `claim_all` continue to work.

---

## 6. Security Findings

### [L-01] Low: Referral Fee Included in TransactionsProcessedEvent is Always Zero

**Severity:** Low  
**Category:** Events  
**Location:** `house.move:386-391, 467-472`

**Description:**

The `TransactionsProcessedEvent` always reports `referral_fee: 0` regardless of the actual referral fee charged:

```move
emit(TransactionsProcessedEvent {
    // ...
    fees: Fees {
        protocol_fee: protocol_fee,
        game_fee: game_fee,
        referral_fee: 0,  // Bug: Always 0, should be `referral_fee`
    },
})
```

**Impact:**

- Off-chain systems cannot accurately track referral fees from events
- Incorrect fee reporting for analytics and accounting

**Recommendation:**

Change `referral_fee: 0` to `referral_fee: referral_fee` in both occurrences (lines 389 and 470).

**Status:** Open

---

### [L-02] Low: PlayCap Revocation Does Not Destroy the PlayCap Object

**Severity:** Low  
**Category:** Object Lifecycle  
**Location:** `balance_manager.move:172-182`

**Description:**

When a `PlayCap` is revoked, only the ID is removed from the allow list. The `PlayCap` object itself is not destroyed:

```move
public fun revoke_play_cap(self: &mut BalanceManager, cap: &BalanceManagerCap, player_cap_id: &ID) {
    self.validate_owner(cap);
    assert!(self.tx_allow_listed.contains(player_cap_id), EPlayCapNotInList);
    self.tx_allow_listed.remove(player_cap_id);
    // PlayCap object still exists but is now useless
    emit(PlayCapRevokedEvent { ... });
}
```

**Impact:**

- Revoked `PlayCap` objects continue to exist but serve no purpose
- Storage is not reclaimed
- Users may be confused about whether their PlayCap is valid

**Recommendation:**

Add a `destroy_play_cap` function that takes ownership of the PlayCap and destroys it:

```move
public fun destroy_play_cap(
    self: &mut BalanceManager,
    cap: &BalanceManagerCap,
    play_cap: PlayCap,
) {
    self.validate_owner(cap);
    let id = &play_cap.id.to_inner();
    if (self.tx_allow_listed.contains(id)) {
        self.tx_allow_listed.remove(id);
    };
    let PlayCap { id, balance_manager_id: _ } = play_cap;
    object::delete(id);
}
```

**Status:** Open

---

### [L-03] Low: Missing Event for Claim Operations

**Severity:** Low  
**Category:** Events  
**Location:** `participation.move:299-304`

**Description:**

The `claim_all` function does not emit an event when funds are claimed:

```move
public(package) fun claim_all(self: &mut Participation, ctx: &TxContext): u64 {
    assert!(self.last_updated_epoch == ctx.epoch(), EEpochMismatch);
    let claimable = self.claimable_balance;
    self.claimable_balance = 0;
    claimable
    // No event emitted
}
```

**Impact:**

- Off-chain indexers may have difficulty tracking claims
- Audit trails may be incomplete

**Recommendation:**

Add a `ClaimProcessedEvent`:

```move
public struct ClaimProcessedEvent has copy, drop {
    participation_id: ID,
    amount: u64,
}

// In claim_all:
emit(ClaimProcessedEvent {
    participation_id: self.id(),
    amount: claimable,
});
```

**Status:** Open

---

### [I-01] Informational: All Test Functions Properly Gated

**Severity:** Informational  
**Category:** Testing  
**Location:** Multiple files

**Description:**

All test helper functions in the codebase are properly protected with `#[test_only]` attributes:

| File | Test Functions | Status |
|------|----------------|--------|
| `balance_manager.move` | `generate_proof_for_testing` | ✅ Gated |
| `house.move` | `admin_cap_for_testing`, `tx_cap_for_testing`, `new_for_testing`, `add_referral_fees_for_testing`, `add_game_fees_for_testing`, `referral_for_testing` | ✅ All Gated |
| `registry.move` | `registry_for_testing`, `cap_for_testing` | ✅ Gated |
| `game_stats.move` | `stats_for_testing` | ✅ Gated |
| `vault.move` | All 7 `*_for_testing` functions | ✅ All Gated |

**Impact:**

No impact - this is correct behavior.

**Status:** Verified Correct

---

### [I-02] Informational: No On-Chain Randomness Usage in Core Protocol

**Severity:** Informational  
**Category:** GambleFi  
**Location:** Protocol-wide

**Description:**

The OpenPlay Core protocol does not directly use randomness. It provides infrastructure for games but delegates randomness handling to individual game implementations.

**Impact:**

Games integrating with OpenPlay must implement their own secure randomness using `sui::random` (VRF).

**Recommendation:**

Document clearly in developer documentation that games MUST use `sui::random` for any randomness requirements.

**Status:** Acknowledged

---

### [I-03] Informational: Epoch-Based Settlement Design

**Severity:** Informational  
**Category:** Economics  
**Location:** `house.move`, `participation.move`, `house_state.move`

**Description:**

The protocol uses Sui epochs (approximately 24 hours) for profit/loss settlement:

1. Stakes become active in the epoch after staking (when house is already active)
2. Unstakes from active stake are processed at end of current epoch
3. Profits/losses are realized at end of epoch

**Note:** If the house is **not active**, stakes are added directly to `stake` (not `pending_stake`) and unstakes are **immediate** to `claimable_balance`.

**Status:** Documented (Working as Intended)

---

### [I-04] Informational: VecMap Usage for Fee Storage

**Severity:** Informational  
**Category:** Data Structures  
**Location:** `vault.move`, `house.move`

**Description:**

The protocol uses `VecMap` for storing game fees and referral fees with O(n) lookup complexity. For typical use cases (< 100 games/referrals), this is acceptable.

**Status:** Acknowledged

---

### [I-05] Informational: Integer Overflow Protection

**Severity:** Informational  
**Category:** Mathematics  
**Location:** `house_state.move`, `game_stats.move`

**Description:**

The protocol correctly uses `u128` for cumulative statistics that could grow large:

```move
all_time_bet_amount: u128,
all_time_win_amount: u128,
all_time_profits: u128,
all_time_losses: u128,
```

Individual transaction amounts use `u64`, which is sufficient for SUI (max ~10^19 MIST).

**Status:** Verified Correct

---

## 7. Rounding Analysis Deep Dive

### 7.1 UQ32_32 Fixed-Point Arithmetic

The protocol uses Sui's `uq32_32` module for fixed-point arithmetic:
- 32 bits integer part
- 32 bits fractional part
- `int_mul` performs truncation (rounds towards zero)

### 7.2 Rounding Behavior Analysis

#### Fee Calculations

```move
fun calculate_fee(transactions: &vector<Transaction>, house_fee_factor: UQ32_32): u64 {
    let mut total_fee = 0;
    transactions.do_ref!(|tx| {
        if (tx.is_debit()) {
            let fee_amount = int_mul(tx.amount(), house_fee_factor);
            total_fee = total_fee + fee_amount
        }
    });
    total_fee
}
```

| Direction | Beneficiary | Analysis |
|-----------|-------------|----------|
| Truncation | **User** | Fee is slightly less than exact, users pay less |

**Issue:** Rounding favors users, not the protocol.

**Magnitude:** Maximum 1 MIST per transaction.

**Recommendation:** For strict protocol-favoring rounding, consider using ceiling division for fees:
```move
// Ceiling: (a * b + denominator - 1) / denominator
```

However, given the magnitude (1 MIST per transaction ≈ $0.000000001), this is negligible in practice.

---

#### Profit Distribution (calculate_ggr_share)

```move
let participation_ratio = from_quotient(account_stake, epoch_volume.active_stake_amount);
let profits = int_mul(end_of_day.day_profits, participation_ratio);
```

| Direction | Beneficiary | Analysis |
|-----------|-------------|----------|
| Truncation | **Protocol** | User receives slightly less profit |

**Result:** Dust accumulates in the house over time. ✅ Favors protocol.

---

#### Loss Distribution (calculate_ggr_share)

```move
let participation_ratio = from_quotient(account_stake, epoch_volume.active_stake_amount);
let losses = int_mul(end_of_day.day_losses, participation_ratio);
```

| Direction | Beneficiary | Analysis |
|-----------|-------------|----------|
| Truncation | **User** | User loses slightly less than proportional share |

**Issue:** Sum of user losses may be less than total house losses.

**Example:**
- Total house loss: 100 MIST
- 3 users with equal stake
- Each user loss: `int_mul(100, 0.333...)` = 33 MIST
- Sum distributed: 99 MIST
- House shows 100 MIST loss, users only absorbed 99 MIST

**Cumulative Impact:**
- Per epoch, per user: ~1 MIST maximum discrepancy
- With 1000 users over 10000 epochs: ~10 million MIST = 0.01 SUI

**Risk Assessment:** 

This discrepancy is **bounded** and **negligible** in practice:
1. The house's `reserve_balance` reflects actual assets
2. Each participation's `stake` reflects their view
3. Discrepancy grows very slowly (< 1 SUI per million user-epochs)
4. The `precision_error_allowance` of 2 MIST handles per-transaction edge cases

---

#### Actualize Amount (for pending_unstake)

```move
let actual_unstake_amount = actualize_amount(
    self.pending_unstake,
    profits,
    losses,
    prev_active_stake,
);
```

For **profits**: `new_amount = int_mul(amount, 1 + profit_ratio)` → User gets slightly less (favors protocol) ✅

For **losses**: `new_amount = int_mul(amount, 1 - loss_ratio)` → User loses slightly less (favors user) ⚠️

---

### 7.3 Rounding Summary

| Operation | Who Benefits | Magnitude | Risk |
|-----------|--------------|-----------|------|
| Fee calculation | User | 1 MIST/tx | Negligible |
| Profit distribution | Protocol | 1 MIST/user/epoch | None |
| Loss distribution | User | 1 MIST/user/epoch | Negligible |
| Unstake actualization (profit) | Protocol | 1 MIST/unstake | None |
| Unstake actualization (loss) | User | 1 MIST/unstake | Negligible |

### 7.4 Recommendation

The current rounding behavior is **acceptable** for production use. However, if strict protocol-favoring rounding is desired:

1. **For fee calculations:** Use ceiling division
2. **For loss distribution:** Use ceiling division (so users absorb the full loss)

```move
// Helper for ceiling division with UQ32_32
// Adds 1 MIST if there's any remainder
fun int_mul_ceil(val: u64, multiplier: UQ32_32): u64 {
    let result = int_mul(val, multiplier);
    // Check if there was truncation by reverse calculation
    // If so, add 1
    result + 1 // Simplified - actual implementation needs remainder check
}
```

**Trade-off:** Adding ceiling operations increases gas costs and code complexity for negligible financial benefit.

---

## 8. Checklist Compliance

### 8.1 SMS-2025 General Move & Sui Logic Vectors

| Check | Status | Notes |
|-------|--------|-------|
| **A. Coin Smasher Fallacy** | ✅ PASS | Protocol uses `Balance<SUI>` internally and validates coin values |
| **B. Function Visibility** | ✅ PASS | Sensitive functions properly use `public(package)` or are private |
| **C. Type Confusion** | ✅ PASS | All system types (`Clock`, `TxContext`) are from standard modules |
| **D. Transfer-to-Object Trap** | ✅ PASS | No transfers to object IDs |
| **E. Phantom Type Misuse** | ✅ PASS | No phantom types used incorrectly |
| **F. Capability Leakage** | ✅ PASS | Caps are not stored in shared objects or returned publicly |
| **G. Storage Growth DoS** | ✅ PASS | Tables store entries as separate objects |

### 8.2 GambleFi Specific Checks

| Check | Status | Notes |
|-------|--------|-------|
| **A. Randomness Predictability** | ✅ N/A | Core protocol doesn't use randomness |
| **B. Randomness Scaling Bias** | ✅ N/A | Core protocol doesn't use randomness |
| **C. Shared Object Sequencing** | ✅ PASS | Protocol design handles concurrent access |
| **D. Replay/Double-Claim** | ✅ PASS | Hot potato patterns prevent replay |

### 8.3 Pre-Flight Checklist

| Check | Status | Notes |
|-------|--------|-------|
| **Upgrade Policy** | ✅ INFO | Package upgradeable, version control exists |
| **Events** | ⚠️ LOW | Most events present, some missing (L-01, L-03) |
| **Slippage Parameters** | ✅ N/A | Not applicable to this protocol |
| **DoS via Unbounded Loops** | ✅ PASS | No unbounded loops over dynamic data |
| **Centralization Review** | ✅ PASS | Admin cannot lock user funds |
| **Withdrawals Always Work** | ✅ PASS | Even with version disabled |

### 8.4 Test Function Gating

| Check | Status | Notes |
|-------|--------|-------|
| All `*_for_testing` functions | ✅ PASS | All properly gated with `#[test_only]` |
| Test modules | ✅ PASS | All in `tests/` directory with `#[test_only]` |

---

## 9. Recommendations

### 9.1 High Priority

1. **Fix referral fee in events** (L-01)
   - Change `referral_fee: 0` to `referral_fee: referral_fee` in `TransactionsProcessedEvent`

### 9.2 Medium Priority

2. **Implement PlayCap destruction** (L-02)
   - Add `destroy_play_cap` function for clean object lifecycle

3. **Add claim event** (L-03)
   - Emit event when funds are claimed from participation

### 9.3 Optional Improvements

4. **Consider ceiling division for fees and losses**
   - Would make rounding strictly favor the protocol
   - Trade-off: increased complexity for negligible benefit

5. **Add developer documentation**
   - Document randomness requirements for game integrations
   - Document epoch-based settlement behavior
   - Document immediate unstaking when house is inactive

---

## 10. Conclusion

The OpenPlay Core protocol demonstrates **excellent security architecture** with proper use of Sui Move patterns:

**Strengths:**
- ✅ Proper capability-based access control
- ✅ Hot potato patterns for transaction authorization
- ✅ Correct object ownership model
- ✅ Comprehensive test coverage (81 tests, all passing)
- ✅ Version control with safe emergency pause (gameplay stops, withdrawals continue)
- ✅ No direct randomness vulnerabilities (delegated to games)
- ✅ Proper separation of concerns
- ✅ All test functions properly gated with `#[test_only]`
- ✅ Tables store entries as separate objects (no unbounded growth)
- ✅ Immediate unstaking when house is inactive

**Minor Issues:**
- ⚠️ Referral fee always 0 in events (bug)
- ⚠️ PlayCap not destroyed on revoke
- ⚠️ Missing claim event
- ⚠️ Rounding slightly favors users in some cases (negligible)

**Overall Assessment:**

The protocol is **production-ready** with only minor issues to address. No critical, high, or medium severity vulnerabilities were found. The codebase follows Move best practices and demonstrates careful consideration of Sui's object model.

---

## 11. Disclaimer

This audit report is provided "as is" and makes no warranties regarding the security of the smart contract code. This audit validates code logic and security best practices at the time of review.

**This audit does not guarantee:**
- Protection against economic attacks or market manipulation
- Security of private key management
- Correctness of off-chain infrastructure
- Future security as dependencies are updated

**The audit scope was limited to:**
- Static code analysis
- Architecture review
- Known vulnerability pattern matching
- Best practice compliance

The findings in this report are based on the code at commit `1e76099c30891013d9b51890ec20665576630265`. Any changes to the codebase after this commit are not covered by this audit.

---

**Report Generated:** December 3, 2025  
**Methodology:** SMS-2025 (Sui & Move Smart Contract Security Standard)  
**Auditor:** Security Review

---

## Appendix A: File-by-File Analysis Summary

| File | Risk Level | Key Findings |
|------|------------|--------------|
| `balance_manager.move` | Low | L-02: PlayCap not destroyed on revoke |
| `calculations.move` | None | Clean implementation |
| `core_constants.move` | None | Constants only |
| `game_stats.move` | None | Clean implementation |
| `house.move` | Low | L-01: Referral fee always 0 in events |
| `parameter_store.move` | None | Simple key-value store |
| `participation.move` | Low | L-03: Missing claim event |
| `referral.move` | None | Clean implementation |
| `registry.move` | None | Correct version control |
| `account.move` | None | Clean implementation |
| `house_state.move` | None | Rounding analyzed, acceptable |
| `transaction.move` | None | Clean implementation |
| `vault.move` | None | Clean implementation |

## Appendix B: Test Coverage Assessment

The protocol includes comprehensive tests covering:
- ✅ Complete stake/unstake flows
- ✅ Profit/loss sharing scenarios
- ✅ Multi-epoch operations
- ✅ Capability validation failures
- ✅ Version control behavior
- ✅ Fee collection and claiming
- ✅ Private house functionality
- ✅ Immediate unstaking when inactive

**Test Result:** 81 tests, all passing
