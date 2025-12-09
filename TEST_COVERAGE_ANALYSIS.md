# OpenPlay Core - Test Coverage Analysis

This document compares the test plan with existing tests and identifies gaps.

## Summary

- **Total Test Cases Needed**: ~440
- **Currently Tested**: ~180 (estimated)
- **Coverage**: ~41%
- **Remaining**: ~260 test cases

## Module-by-Module Analysis

### balance_manager.move

**Status**: ~60% coverage

**✅ Already Tested:**
- [x] `deposit()` - deposit_withdraw test
- [x] `withdraw()` - deposit_withdraw test  
- [x] `deposit_with_proof()` - deposit_withdraw_int test
- [x] `withdraw_with_proof()` - deposit_withdraw_int test
- [x] `mint_play_cap()` - play_cap_and_proofs_ok, incorrect_bm_cap_1
- [x] `revoke_play_cap()` - revoked_play_cap test
- [x] `prune_allow_list()` - prune_allow_list_ok, prune_allow_list_revokes_all_caps
- [x] `destroy_play_cap()` - destroy_play_cap_ok
- [x] `destroy_play_cap_and_revoke()` - destroy_play_cap_and_revoke_ok, destroy_play_cap_and_revoke_wrong_manager
- [x] `generate_proof_as_owner()` - play_cap_and_proofs_ok, incorrect_bm_cap_2
- [x] `generate_proof_as_player()` - play_cap_and_proofs_ok, incorrect_play_cap, revoked_play_cap
- [x] `balance()` - tested in multiple tests
- [x] `allow_list_length()` - prune_allow_list_ok
- [x] `cap_balance_manager_id()` - play_cap_and_proofs_ok
- [x] `proof_balance_manager_id()` - play_cap_and_proofs_ok
- [x] `player()` - play_cap_and_proofs_ok
- [x] EBalanceTooLow - deposit_withdraw, deposit_withdraw_int
- [x] EInvalidOwner - incorrect_bm_cap_1, incorrect_bm_cap_2, prune_allow_list_wrong_cap
- [x] EInvalidPlayer - incorrect_play_cap, revoked_play_cap, destroy_play_cap_and_revoke_wrong_manager, prune_allow_list_revokes_all_caps

**❌ Missing Tests:**
- [ ] `new()` - Test emits BalanceManagerCreatedEvent
- [ ] `share()` - Test shares the object
- [ ] `mint_play_cap()` - Test emits PlayCapMintedEvent
- [ ] `mint_play_cap()` - Test aborts with EMaxPlayCapsReached at limit (1000)
- [ ] `revoke_play_cap()` - Test emits PlayCapRevokedEvent
- [ ] `revoke_play_cap()` - Test aborts with EPlayCapNotInList if not in list
- [ ] `prune_allow_list()` - Test emits PlayCapAllowListPrunedEvent with correct count
- [ ] `destroy_play_cap()` - Test emits PlayCapDestroyedEvent
- [ ] `destroy_play_cap()` - Test works even if BalanceManager doesn't exist
- [ ] `destroy_play_cap_and_revoke()` - Test emits both events when revoking
- [ ] `deposit()` - Test emits DepositCompletedEvent
- [ ] `withdraw()` - Test emits WithdrawalProcessedEvent
- [ ] `withdraw_all()` - All tests
- [ ] `validate_proof()` - All tests
- [ ] `destroy_empty()` - All tests
- [ ] `id()` - View function test
- [ ] `cap_id()` - View function test
- [ ] EMaxPlayCapsReached
- [ ] EPlayCapNotInList
- [ ] EInvalidProof
- [ ] EBalanceNotEmpty

---

### calculations.move

**Status**: ~95% coverage

**✅ Already Tested:**
- [x] `mul_floor()` - Comprehensive tests (basic, rounding, edge cases, overflow)
- [x] `mul_ceil()` - Comprehensive tests (basic, rounding, edge cases, overflow)
- [x] `mul_floor_bps()` - Comprehensive tests
- [x] `mul_ceil_bps()` - Comprehensive tests
- [x] EDivisionByZero - mul_floor_division_by_zero_error, mul_ceil_division_by_zero_error
- [x] EOverflow - mul_floor_overflow_error, mul_ceil_overflow_error, mul_floor_bps_overflow_error, mul_ceil_bps_overflow_error

**❌ Missing Tests:**
- [ ] Edge case: denominator = 1 (implicitly tested but could be explicit)
- [ ] Some very specific edge cases (but coverage is excellent)

---

### core_constants.move

**Status**: 0% coverage (no tests found)

**❌ Missing Tests:**
- [ ] `max_bps()` - Test returns 10000
- [ ] `tx_type_bet()` - Test returns "Bet" string
- [ ] `tx_type_win()` - Test returns "Win" string
- [ ] `current_version()` - Test returns 1
- [ ] `max_protocol_fee_bps()` - Test returns 2000
- [ ] `max_house_and_collector_fees_bps()` - Test returns 5000

---

### fee_collector.move

**Status**: ~30% coverage (tested indirectly through house tests)

**✅ Already Tested (indirectly):**
- [x] `new()` - admin_create_fee_collector tests
- [x] `share()` - Multiple house tests
- [x] `id()` - Used in house tests
- [x] `house_id()` - Used in house tests

**❌ Missing Tests:**
- [ ] `cap_fee_collector_id()` - View function test
- [ ] `assert_valid_cap()` - Test valid cap passes
- [ ] `assert_valid_cap()` - Test invalid fee_collector_id aborts
- [ ] `assert_valid_cap()` - Test invalid cap_id aborts
- [ ] EInvalidCap - Direct test needed

---

### game_stats.move

**Status**: ~40% coverage

**✅ Already Tested:**
- [x] `new()` - process_transactions_ok
- [x] `process_transactions()` - process_transactions_ok
- [x] `process_transactions()` - Test zero win amount is skipped
- [x] `current_volumes()` - process_transactions_ok
- [x] `all_time_volumes()` - process_transactions_ok
- [x] `historic_volumes()` - process_transactions_ok (epoch transition)
- [x] `bet_sum()`, `bet_count()`, `win_sum()`, `win_count()` - process_transactions_ok

**❌ Missing Tests:**
- [ ] `game_id()` - View function test
- [ ] `id()` - View function test
- [ ] `historic_volumes()` - Test aborts with EEpochNotFound for non-existent epoch
- [ ] `share()` - Test shares the object
- [ ] `process_transactions()` - Test aborts with EUnknownTransaction for invalid type
- [ ] EUnknownTransaction
- [ ] EEpochNotFound

---

### house.move

**Status**: ~50% coverage

**✅ Already Tested:**
- [x] `buy_shares()` - Multiple tests (complete_flow_*, buy_sell_shares_ok)
- [x] `sell_shares()` - Multiple tests
- [x] `new_participation()` - private_house_error
- [x] `admin_new_participation()` - private_house_ok
- [x] `tx_admin_process_transactions_v2()` - Multiple tests
- [x] `tx_admin_process_transactions_v2_no_bm()` - process_transactions_no_bm, process_transactions_no_bm_insufficient_balance
- [x] `admin_create_fee_collector()` - Multiple tests
- [x] `admin_add_tx_allowed_with_collector()` - Multiple tests
- [x] `admin_revoke_tx_allowed()` - admin_revoke_tx_allowed, admin_revoke_tx_allowed_not_found
- [x] `claim_collector_fees()` - claim_collector_fees_ok, claim_collector_fees_empty, claim_collector_fees_multiple_collectors, claim_collector_fees_wrong_house
- [x] `admin_claim_house_fees()` - claim_house_fees_ok
- [x] `borrow_tx_cap()` - tx_cap_wrong_uid, tx_cap_revoked
- [x] `openplay_admin_new_house()` - private_house_ok
- [x] `house_balance()` - Multiple tests
- [x] `nav_per_share()` - Used in tests (but not explicitly tested)
- [x] `private()` - private_house_ok, private_house_error
- [x] `game_fee_collector()` - process_transactions_different_fee_collectors
- [x] EInsufficientFunds - insufficient_funds_should_fail
- [x] EInvalidTxCap - process_transactions_wrong_cap
- [x] EHouseIsPrivate - private_house_error
- [x] EUnauthorizedGameId - tx_cap_wrong_uid, tx_cap_revoked
- [x] EGameDoesNotExist - admin_revoke_tx_allowed_not_found
- [x] EInvalidFeeCollector - claim_collector_fees_wrong_house
- [x] EInvalidGameStats - process_transactions_invalid_stats
- [x] EPackageVersionDisabled - house_version_disabled, house_version_disabled_after_rename
- [x] EBalanceTooLow - bet_without_funds_win_higher_than_bet, bet_without_funds_win_equals_bet

**❌ Missing Tests:**
- [ ] `share()` - Test registers house in registry
- [ ] `ensure_sufficient_funds()` - Direct test
- [ ] `admin_update_fees()` - All tests
- [ ] `openplay_admin_claim_protocol_fees()` - All tests
- [ ] `id()` - View function test
- [ ] `house_fee_bps()` - View function test
- [ ] `nav_per_share()` - Explicit edge case tests (zero effective value, etc.)
- [ ] `admin_cap_house_id()` - View function test
- [ ] `transaction_cap_house_id()` - View function test
- [ ] `buy_shares()` - Edge cases (zero deposit, effective_value = 0, shares_to_mint = 0)
- [ ] `sell_shares()` - Edge cases (total_shares = 0)
- [ ] `process_end_of_day()` - Direct tests (no-op, multiple epochs)
- [ ] EInvalidAdminCap
- [ ] EInvalidFeeConfiguration
- [ ] EMaxGamesReached
- [ ] EProtocolFeeTooHigh
- [ ] EHouseAndCollectorFeesTooHigh
- [ ] ENotEnoughShares
- [ ] EInvalidAmount
- [ ] Event emission tests (most events not explicitly verified)

---

### parameter_store.move

**Status**: 0% coverage (no tests found)

**❌ Missing Tests:**
- [ ] All functions need tests

---

### participation.move

**Status**: ~80% coverage

**✅ Already Tested:**
- [x] `empty()` - Multiple tests
- [x] `add_shares()` - shares_basic_ok, shares_add_remove_ok
- [x] `remove_shares()` - shares_basic_ok, shares_add_remove_ok
- [x] `destroy_empty()` - destroy_empty_participation_ok, destroy_non_empty_participation_fails
- [x] `shares()` - Multiple tests
- [x] `house_id()` - participation_id_and_house_id_ok
- [x] `id()` - participation_id_and_house_id_ok
- [x] ENotEmpty - destroy_non_empty_participation_fails
- [x] ENotEnoughShares - remove_too_many_shares_fails

**❌ Missing Tests:**
- [ ] `empty()` - Test emits ParticipationCreatedEvent
- [ ] `destroy_empty()` - Test emits ParticipationRemovedEvent

---

### registry.move

**Status**: ~30% coverage

**✅ Already Tested:**
- [x] `update_protocol_fee_bps()` - test_update_protocol_fee_bps_valid, test_update_protocol_fee_bps_invalid_100_percent, test_update_protocol_fee_bps_invalid_over_100_percent, test_update_protocol_fee_bps_max_valid
- [x] `protocol_fee_bps()` - Used in tests
- [x] EInvalidFeeConfiguration - test_update_protocol_fee_bps_invalid_100_percent, test_update_protocol_fee_bps_invalid_over_100_percent

**❌ Missing Tests:**
- [ ] `check_version()` - Test passes when version allowed
- [ ] `check_version()` - Test aborts with EPackageVersionDisabled when disabled
- [ ] `game_stats_id()` - All tests
- [ ] `init_stats()` - All tests
- [ ] `admin_allow_version()` - All tests
- [ ] `admin_disallow_version()` - All tests
- [ ] `register_house()` - Test (indirectly tested but could be explicit)
- [ ] `init()` - Test (package init, hard to test directly)
- [ ] EPackageVersionDisabled
- [ ] EVersionAlreadyAllowed
- [ ] EVersionAlreadyDisabled
- [ ] EStatsAlreadyCreated
- [ ] EStatsNotAvailable
- [ ] Event emission tests

---

### transaction.move

**Status**: ~90% coverage

**✅ Already Tested:**
- [x] `bet_checked()` - bet_checked_accepts_minimum_amount, bet_checked_accepts_above_minimum, bet_checked_rejects_below_minimum, bet_checked_rejects_zero
- [x] `win_checked()` - win_checked_accepts_minimum_amount, win_checked_accepts_above_minimum, win_checked_rejects_below_minimum, win_checked_rejects_zero
- [x] `bet()` - test_only_bet_bypasses_validation
- [x] `win()` - test_only_win_bypasses_validation
- [x] `amount()` - Multiple tests
- [x] `min_transaction_amount()` - min_transaction_amount_returns_correct_value
- [x] `is_credit()` - Multiple tests
- [x] `is_debit()` - Multiple tests
- [x] EAmountTooLow - bet_checked_rejects_below_minimum, bet_checked_rejects_zero, win_checked_rejects_below_minimum, win_checked_rejects_zero

**❌ Missing Tests:**
- [ ] `is_credit()` - Test aborts with EUnknownTxType for invalid type
- [ ] `is_debit()` - Test aborts with EUnknownTxType for invalid type
- [ ] EUnknownTxType

---

### vault.move

**Status**: ~60% coverage

**✅ Already Tested:**
- [x] `empty()` - Multiple tests
- [x] `deposit()` - deposit_withdraw_ok
- [x] `withdraw()` - deposit_withdraw_ok
- [x] `settle_balance_manager()` - settle_balance_manager_gameplay_ok, settle_balance_manager_insufficient_funds_bm, settle_balance_manager_insufficient_funds_vault
- [x] `process_collector_fee()` - process_fees_ok, process_collector_fees_fail
- [x] `process_protocol_fee()` - process_fees_ok, process_protocol_fees_fail
- [x] `house_balance()` - Multiple tests
- [x] `collected_protocol_fees()` - process_fees_ok
- [x] `collected_collector_fees()` - process_fees_ok
- [x] EInsufficientFunds - settle_balance_manager_insufficient_funds_vault, process_protocol_fees_fail, process_collector_fees_fail

**❌ Missing Tests:**
- [ ] `withdraw_protocol_fees()` - All tests
- [ ] `withdraw_house_fees()` - All tests
- [ ] `process_house_fee()` - All tests
- [ ] `withdraw_collector_fees()` - All tests
- [ ] `collected_collector_fees()` - Test returns 0 for non-existent collector

---

### state/account.move

**Status**: ~80% coverage

**✅ Already Tested:**
- [x] `empty()` - settle_ok
- [x] `settle()` - settle_ok
- [x] `credit()` - settle_ok
- [x] `debit()` - settle_ok

**❌ Missing Tests:**
- [ ] More edge cases could be added

---

### state/house_state.move

**Status**: ~50% coverage

**✅ Already Tested:**
- [x] `process_transactions()` - transactions_process_ok
- [x] `mint_shares()` - shares_mint_burn_tests
- [x] `burn_shares()` - shares_mint_burn_tests, burn_too_many_shares
- [x] `process_end_of_day()` - process_end_of_day_ok, cannot_process_eod_before_epoch_ended, cannot_process_eod_for_wrong_epoch
- [x] `current_collector_ggr()` - collector_ggr_tracking_ok
- [x] `epoch()` - Used in tests
- [x] `current_volumes()` - transactions_process_ok
- [x] `all_time_bet_amount()` - transactions_process_ok
- [x] `all_time_win_amount()` - transactions_process_ok
- [x] ECannotUnstakeMoreThanStaked - burn_too_many_shares
- [x] EEpochHasNotFinishedYet - cannot_process_eod_before_epoch_ended
- [x] EEpochMismatch - cannot_process_eod_for_wrong_epoch

**❌ Missing Tests:**
- [ ] `volume_for_epoch()` - All tests
- [ ] `all_time_profits()` - View function test
- [ ] `all_time_losses()` - View function test
- [ ] `total_bet_amount()` - View function test
- [ ] `total_win_amount()` - View function test
- [ ] `total_shares()` - View function test
- [ ] `historic_collector_ggr()` - All tests
- [ ] `calculate_pending_collector_fees()` - All tests
- [ ] `calculate_pending_house_fees()` - All tests
- [ ] `calculate_pending_protocol_fees()` - All tests
- [ ] `calculate_total_pending_fees()` - All tests
- [ ] `process_collector_end_of_day()` - All tests
- [ ] `new()` - Test captures fees for first epoch
- [ ] EUnknownTransaction
- [ ] EVolumeNotAvailable
- [ ] Event emission tests

---

## Priority Gaps to Fill

### High Priority (Critical for Security/Correctness)
1. **house.move** - Missing error code tests, edge cases, event emissions
2. **state/house_state.move** - Missing fee calculation tests, view functions
3. **balance_manager.move** - Missing event emissions, edge cases
4. **vault.move** - Missing fee withdrawal tests

### Medium Priority
5. **registry.move** - Missing version control tests
6. **game_stats.move** - Missing error tests
7. **transaction.move** - Missing EUnknownTxType test

### Low Priority (Simple Functions)
8. **core_constants.move** - All tests missing
9. **parameter_store.move** - All tests missing
10. **fee_collector.move** - Missing direct tests

---

## Next Steps

1. Create tests for core_constants.move (quick win)
2. Add event emission verification to existing tests
3. Add missing error code tests
4. Add edge case tests for critical functions
5. Add view function tests
6. Add fee calculation tests in house_state.move
7. Add parameter_store.move tests

---

**Last Updated**: Based on test files review
**Estimated Remaining Work**: ~260 test cases

