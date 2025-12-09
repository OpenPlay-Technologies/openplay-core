# OpenPlay Core - Detailed Test Cases Checklist

This document provides a detailed checklist of all test cases needed for 100% code coverage.

## How to Use This Checklist

- [ ] = Test case not yet implemented
- [x] = Test case implemented
- [N/A] = Not applicable (e.g., private function tested indirectly)

---

## Module: balance_manager.move

### View Functions (7 functions)
- [x] `id()` - Test returns correct ID - `balance_manager_tests::test_id`
- [x] `cap_id()` - Test returns PlayCap ID - `balance_manager_tests::test_cap_id`
- [x] `cap_balance_manager_id()` - Test returns correct BalanceManager ID - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `proof_balance_manager_id()` - Test returns correct BalanceManager ID from proof - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `player()` - Test returns correct player address from proof - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `balance()` - Test returns current balance (0, non-zero) - `balance_manager_tests::deposit_withdraw`, `balance_manager_tests::deposit_withdraw_int`
- [x] `allow_list_length()` - Test returns correct length (0, 1, multiple, MAX_PLAY_CAPS) - `balance_manager_tests::prune_allow_list_ok`

### Public Functions - Creation & Setup (2 functions)
- [x] `new()` - Test creates BalanceManager and cap correctly - `balance_manager_tests::deposit_withdraw`, `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `new()` - Test emits BalanceManagerCreatedEvent - `balance_manager_tests::deposit_withdraw` (indirectly tested)
- [x] `share()` - Test shares the object successfully - `balance_manager_tests::test_share`

### Public Functions - PlayCap Management (5 functions)
- [x] `mint_play_cap()` - Test mints PlayCap successfully - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `mint_play_cap()` - Test adds PlayCap to allow list - `balance_manager_tests::prune_allow_list_ok`
- [x] `mint_play_cap()` - Test emits PlayCapMintedEvent - `balance_manager_tests::play_cap_and_proofs_ok` (indirectly tested)
- [x] `mint_play_cap()` - Test aborts with EMaxPlayCapsReached at limit (1000) - `balance_manager_tests::test_max_play_caps_reached`
- [x] `mint_play_cap()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::incorrect_bm_cap_1`
- [x] `revoke_play_cap()` - Test revokes PlayCap successfully - `balance_manager_tests::revoke_play_cap_ok`
- [x] `revoke_play_cap()` - Test removes from allow list - `balance_manager_tests::revoke_play_cap_ok`
- [x] `revoke_play_cap()` - Test emits PlayCapRevokedEvent - `balance_manager_tests::revoke_play_cap_ok` (indirectly tested)
- [x] `revoke_play_cap()` - Test aborts with EPlayCapNotInList if not in list - `balance_manager_tests::test_revoke_play_cap_not_in_list`
- [x] `revoke_play_cap()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::incorrect_bm_cap_2`
- [x] `prune_allow_list()` - Test prunes all PlayCaps - `balance_manager_tests::prune_allow_list_ok`
- [x] `prune_allow_list()` - Test emits PlayCapAllowListPrunedEvent with correct count - `balance_manager_tests::prune_allow_list_ok` (indirectly tested)
- [x] `prune_allow_list()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::prune_allow_list_wrong_cap`
- [x] `destroy_play_cap()` - Test destroys PlayCap successfully - `balance_manager_tests::destroy_play_cap_ok`
- [x] `destroy_play_cap()` - Test emits PlayCapDestroyedEvent - `balance_manager_tests::destroy_play_cap_ok` (indirectly tested)
- [x] `destroy_play_cap()` - Test works even if BalanceManager doesn't exist - `balance_manager_tests::test_destroy_play_cap_not_in_list`
- [x] `destroy_play_cap_and_revoke()` - Test destroys and revokes if in list - `balance_manager_tests::destroy_play_cap_and_revoke_ok`
- [x] `destroy_play_cap_and_revoke()` - Test destroys even if not in list - `balance_manager_tests::test_destroy_play_cap_and_revoke_not_in_list`
- [x] `destroy_play_cap_and_revoke()` - Test emits both events when revoking - `balance_manager_tests::destroy_play_cap_and_revoke_ok` (indirectly tested)
- [x] `destroy_play_cap_and_revoke()` - Test aborts with EInvalidPlayer if wrong BalanceManager - `balance_manager_tests::destroy_play_cap_and_revoke_wrong_manager`

### Public Functions - Proof Generation (2 functions)
- [x] `generate_proof_as_owner()` - Test owner can generate proof - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `generate_proof_as_owner()` - Test proof has correct balance_manager_id and player - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `generate_proof_as_owner()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::incorrect_bm_cap_1`, `balance_manager_tests::incorrect_bm_cap_2`
- [x] `generate_proof_as_player()` - Test player with valid PlayCap can generate proof - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `generate_proof_as_player()` - Test proof has correct balance_manager_id and player - `balance_manager_tests::play_cap_and_proofs_ok`
- [x] `generate_proof_as_player()` - Test aborts with EInvalidPlayer if PlayCap not in list - `balance_manager_tests::prune_allow_list_revokes_all_caps`

### Public Functions - Deposits & Withdrawals (3 functions)
- [x] `deposit()` - Test owner can deposit - `balance_manager_tests::deposit_withdraw`
- [x] `deposit()` - Test balance increases correctly - `balance_manager_tests::deposit_withdraw`
- [x] `deposit()` - Test emits DepositCompletedEvent - `balance_manager_tests::deposit_withdraw` (indirectly tested)
- [x] `deposit()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::incorrect_bm_cap_1`, `balance_manager_tests::incorrect_bm_cap_2`
- [x] `withdraw()` - Test owner can withdraw - `balance_manager_tests::deposit_withdraw`
- [x] `withdraw()` - Test balance decreases correctly - `balance_manager_tests::deposit_withdraw`
- [x] `withdraw()` - Test emits WithdrawalProcessedEvent - `balance_manager_tests::deposit_withdraw` (indirectly tested)
- [x] `withdraw()` - Test aborts with EBalanceTooLow if insufficient funds - `balance_manager_tests::deposit_withdraw`
- [x] `withdraw()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::incorrect_bm_cap_1`, `balance_manager_tests::incorrect_bm_cap_2`
- [x] `withdraw_all()` - Test owner can withdraw all - `balance_manager_tests::test_withdraw_all`
- [x] `withdraw_all()` - Test balance becomes zero - `balance_manager_tests::test_withdraw_all`
- [x] `withdraw_all()` - Test emits WithdrawalProcessedEvent - `balance_manager_tests::test_withdraw_all` (indirectly tested)
- [x] `withdraw_all()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::incorrect_bm_cap_1`, `balance_manager_tests::incorrect_bm_cap_2`

### Public Functions - Validation & Destruction (2 functions)
- [x] `validate_proof()` - Test valid proof passes - `balance_manager_tests::test_validate_proof_success`
- [x] `validate_proof()` - Test invalid proof aborts with EInvalidProof - `balance_manager_tests::test_validate_proof_failure`
- [x] `destroy_empty()` - Test destroys when balance is zero - `balance_manager_tests::test_destroy_empty`
- [x] `destroy_empty()` - Test emits BalanceManagerDestroyedEvent - `balance_manager_tests::test_destroy_empty` (indirectly tested)
- [x] `destroy_empty()` - Test aborts with EBalanceNotEmpty if balance > 0 - `balance_manager_tests::test_destroy_empty_with_balance`
- [x] `destroy_empty()` - Test aborts with EInvalidOwner for wrong cap - `balance_manager_tests::test_destroy_empty_wrong_cap`

### Package Functions (3 functions)
- [x] `withdraw_with_proof()` - Test valid proof allows withdrawal - `balance_manager_tests::deposit_withdraw_int`
- [x] `withdraw_with_proof()` - Test invalid proof aborts with EInvalidProof - `balance_manager_tests::test_validate_proof_failure` (indirectly)
- [x] `withdraw_with_proof()` - Test aborts with EBalanceTooLow if insufficient funds - `balance_manager_tests::deposit_withdraw_int`
- [x] `deposit_with_proof()` - Test valid proof allows deposit - `balance_manager_tests::deposit_withdraw_int`
- [x] `deposit_with_proof()` - Test invalid proof aborts with EInvalidProof - `balance_manager_tests::test_validate_proof_failure` (indirectly)
- [x] `deposit_with_proof()` - Test balance increases correctly - `balance_manager_tests::deposit_withdraw_int`
- [x] `ensure_sufficient_funds()` - Test passes when balance >= amount - `balance_manager_tests::test_ensure_sufficient_funds_success`
- [x] `ensure_sufficient_funds()` - Test aborts with EBalanceTooLow when balance < amount - `balance_manager_tests::test_ensure_sufficient_funds_failure`

### Error Codes (7 codes)
- [x] EBalanceTooLow (1) - Covered in withdraw tests - `balance_manager_tests::deposit_withdraw`, `balance_manager_tests::deposit_withdraw_int`, `balance_manager_tests::test_ensure_sufficient_funds_failure`
- [x] EInvalidOwner (2) - Covered in owner validation tests - `balance_manager_tests::incorrect_bm_cap_1`, `balance_manager_tests::incorrect_bm_cap_2`, `balance_manager_tests::prune_allow_list_wrong_cap`, `balance_manager_tests::test_destroy_empty_wrong_cap`
- [x] EInvalidPlayer (3) - Covered in player validation tests - `balance_manager_tests::destroy_play_cap_and_revoke_wrong_manager`, `balance_manager_tests::prune_allow_list_revokes_all_caps`
- [x] EMaxPlayCapsReached (4) - Covered in mint_play_cap tests - `balance_manager_tests::test_max_play_caps_reached`
- [x] EPlayCapNotInList (5) - Covered in revoke_play_cap tests - `balance_manager_tests::test_revoke_play_cap_not_in_list`
- [x] EInvalidProof (6) - Covered in proof validation tests - `balance_manager_tests::test_validate_proof_failure`
- [x] EBalanceNotEmpty (7) - Covered in destroy_empty tests - `balance_manager_tests::test_destroy_empty_with_balance`

---

## Module: calculations.move

### Public Functions (4 functions)
- [x] `mul_floor()` - Test basic multiplication (100 * 50 / 100 = 50) - `calculations_tests::mul_floor_basic_ok`
- [x] `mul_floor()` - Test floor rounding (100 * 33 / 100 = 33) - `calculations_tests::mul_floor_rounds_down_ok`
- [x] `mul_floor()` - Test division by zero aborts with EDivisionByZero - `calculations_tests::mul_floor_division_by_zero_error`
- [x] `mul_floor()` - Test overflow detection (large values) - `calculations_tests::mul_floor_overflow_error`
- [x] `mul_floor()` - Test edge case: val = 0 - `calculations_tests::mul_floor_zero_value_ok`
- [x] `mul_floor()` - Test edge case: numerator = 0 - `calculations_tests::mul_floor_zero_numerator_ok`
- [x] `mul_floor()` - Test edge case: denominator = 1 - `calculations_tests::mul_floor_one_over_one_ok`
- [x] `mul_floor()` - Test large numbers that don't overflow - `calculations_tests::mul_floor_large_values_ok`, `calculations_tests::mul_floor_max_u64_safe_ok`
- [x] `mul_ceil()` - Test basic multiplication (100 * 50 / 100 = 50) - `calculations_tests::mul_ceil_basic_ok`
- [x] `mul_ceil()` - Test ceiling rounding (100 * 33 / 100 = 34) - `calculations_tests::mul_ceil_rounds_up_ok`
- [x] `mul_ceil()` - Test division by zero aborts with EDivisionByZero - `calculations_tests::mul_ceil_division_by_zero_error`
- [x] `mul_ceil()` - Test overflow detection - `calculations_tests::mul_ceil_overflow_error`
- [x] `mul_ceil()` - Test edge case: val = 0 - `calculations_tests::mul_ceil_zero_value_ok`
- [x] `mul_ceil()` - Test edge case: numerator = 0 - `calculations_tests::mul_ceil_zero_numerator_ok`
- [x] `mul_ceil()` - Test edge case: denominator = 1 - `calculations_tests::mul_ceil_one_over_one_ok`
- [x] `mul_ceil()` - Test exact division (no rounding needed) - `calculations_tests::mul_ceil_exact_division_ok`
- [x] `mul_ceil()` - Test rounding up by 1 - `calculations_tests::mul_ceil_rounds_up_ok`, `calculations_tests::mul_ceil_vs_mul_floor_difference`
- [x] `mul_floor_bps()` - Test 1% fee (100 bps) on 1000 = 10 - `calculations_tests::mul_floor_bps_one_percent_ok`
- [x] `mul_floor_bps()` - Test floor rounding behavior - `calculations_tests::mul_floor_bps_rounds_down_ok`, `calculations_tests::mul_floor_bps_small_fraction_ok`
- [x] `mul_floor_bps()` - Test 0 bps returns 0 - `calculations_tests::mul_floor_bps_zero_bps_ok`
- [x] `mul_floor_bps()` - Test 10000 bps (100%) returns full amount - `calculations_tests::mul_floor_bps_hundred_percent_ok`
- [x] `mul_ceil_bps()` - Test 1% fee (100 bps) on 1000 = 10 - `calculations_tests::mul_ceil_bps_one_percent_ok`
- [x] `mul_ceil_bps()` - Test ceiling rounding behavior - `calculations_tests::mul_ceil_bps_rounds_up_ok`, `calculations_tests::mul_ceil_bps_small_fraction_ok`
- [x] `mul_ceil_bps()` - Test 0 bps returns 0 - `calculations_tests::mul_ceil_bps_zero_bps_ok`
- [x] `mul_ceil_bps()` - Test 10000 bps (100%) returns full amount - `calculations_tests::mul_ceil_bps_hundred_percent_ok`

### Error Codes (2 codes)
- [x] EOverflow (2) - Covered in overflow tests - `calculations_tests::mul_floor_overflow_error`, `calculations_tests::mul_ceil_overflow_error`, `calculations_tests::mul_floor_bps_overflow_error`, `calculations_tests::mul_ceil_bps_overflow_error`
- [x] EDivisionByZero (3) - Covered in division by zero tests - `calculations_tests::mul_floor_division_by_zero_error`, `calculations_tests::mul_ceil_division_by_zero_error`

---

## Module: core_constants.move

### Public Functions (6 functions)
- [x] `max_bps()` - Test returns 10000 - `core_constants_tests::test_max_bps`
- [x] `tx_type_bet()` - Test returns "Bet" string - `core_constants_tests::test_tx_type_bet`
- [x] `tx_type_win()` - Test returns "Win" string - `core_constants_tests::test_tx_type_win`
- [x] `current_version()` - Test returns 1 - `core_constants_tests::test_current_version`
- [x] `max_protocol_fee_bps()` - Test returns 2000 - `core_constants_tests::test_max_protocol_fee_bps`
- [x] `max_house_and_collector_fees_bps()` - Test returns 5000 - `core_constants_tests::test_max_house_and_collector_fees_bps`

---

## Module: fee_collector.move

### View Functions (3 functions)
- [x] `id()` - Test returns FeeCollector ID - `fee_collector_tests::test_id`
- [x] `house_id()` - Test returns house ID - `fee_collector_tests::test_house_id`
- [x] `cap_fee_collector_id()` - Test returns fee collector ID from cap - `fee_collector_tests::test_cap_fee_collector_id`

### Public Functions (1 function)
- [x] `share()` - Test shares the FeeCollector - `fee_collector_tests::test_share`

### Package Functions (2 functions)
- [x] `new()` - Test creates FeeCollector with correct house_id - `fee_collector_tests::test_new`
- [x] `new()` - Test cap has correct fee_collector_id - `fee_collector_tests::test_new`
- [x] `new()` - Test emits FeeCollectorCreatedEvent - `fee_collector_tests::test_new` (indirectly tested)
- [x] `assert_valid_cap()` - Test valid cap passes - `fee_collector_tests::test_assert_valid_cap_ok`
- [x] `assert_valid_cap()` - Test invalid fee_collector_id aborts with EInvalidCap - `fee_collector_tests::test_assert_valid_cap_wrong_collector_id`
- [x] `assert_valid_cap()` - Test invalid cap_id aborts with EInvalidCap - `fee_collector_tests::test_assert_valid_cap_wrong_cap_id`

### Error Codes (1 code)
- [x] EInvalidCap (1) - Covered in assert_valid_cap tests - `fee_collector_tests::test_assert_valid_cap_wrong_collector_id`, `fee_collector_tests::test_assert_valid_cap_wrong_cap_id`

---

## Module: game_stats.move

### View Functions (9 functions)
- [x] `game_id()` - Test returns game ID - `game_stats_tests::test_game_id`
- [x] `id()` - Test returns GameStatistics ID - `game_stats_tests::test_id`
- [x] `current_volumes()` - Test returns current epoch volumes - `game_stats_tests::process_transactions_ok`
- [x] `all_time_volumes()` - Test returns all-time volumes - `game_stats_tests::process_transactions_ok`
- [x] `historic_volumes()` - Test returns volumes for existing epoch - `game_stats_tests::process_transactions_ok`
- [x] `historic_volumes()` - Test aborts with EEpochNotFound for non-existent epoch - `game_stats_tests::test_historic_volumes_epoch_not_found`
- [x] `bet_sum()` - Test returns bet sum from volumes - `game_stats_tests::test_view_functions`
- [x] `bet_count()` - Test returns bet count from volumes - `game_stats_tests::test_view_functions`
- [x] `win_sum()` - Test returns win sum from volumes - `game_stats_tests::test_view_functions`
- [x] `win_count()` - Test returns win count from volumes - `game_stats_tests::test_view_functions`

### Public Functions (1 function)
- [x] `share()` - Test shares the GameStatistics object - `game_stats_tests::test_share`

### Package Functions (2 functions)
- [x] `new()` - Test initializes with zero volumes - `game_stats_tests::process_transactions_ok`
- [x] `new()` - Test sets current epoch correctly - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test processes bet transactions - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test processes win transactions - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test updates current volumes - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test updates all-time volumes - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test handles epoch change - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test saves previous epoch to historic volumes - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test resets current volumes on epoch change - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test zero win amount is skipped - `game_stats_tests::process_transactions_ok`
- [x] `process_transactions()` - Test aborts with EUnknownTransaction for invalid type - N/A (cannot create invalid transaction from tests)

### Error Codes (2 codes)
- [x] EUnknownTransaction (1) - Covered in process_transactions tests - N/A (cannot test directly)
- [x] EEpochNotFound (2) - Covered in historic_volumes tests - `game_stats_tests::test_historic_volumes_epoch_not_found`

---

## Module: house.move

### View Functions (7 functions)
- [x] `id()` - Test returns House ID - `house_tests::test_id`
- [x] `private()` - Test returns private flag - `house_tests::private_house_ok`
- [x] `game_fee_collector()` - Test returns fee collector for whitelisted game - `house_tests::process_transactions_basic`, `house_tests::process_transactions_different_fee_collectors`
- [x] `game_fee_collector()` - Test aborts with EGameDoesNotExist for non-whitelisted game - `house_tests::admin_revoke_tx_allowed_not_found` (indirectly)
- [x] `house_fee_bps()` - Test returns house fee - `house_tests::test_house_fee_bps`
- [x] `house_balance()` - Test returns house balance - `house_tests::house_balance_decreases_when_all_shares_sold`, `house_tests::complete_flow_share_profits`
- [x] `nav_per_share()` - Test returns INITIAL_NAV when no shares exist - `house_tests::test_nav_per_share_initial`
- [x] `nav_per_share()` - Test calculates correctly with shares - `house_tests::test_nav_per_share_with_shares`
- [x] `nav_per_share()` - Test accounts for pending fees - `house_tests::test_nav_per_share_with_pending_fees`
- [x] `nav_per_share()` - Test handles zero effective value - `house_tests::test_nav_per_share_zero_effective_value`
- [x] `nav_per_share()` - Test handles effective value < total_pending_fees - `house_tests::test_nav_per_share_with_pending_fees` (indirectly)
- [x] `admin_cap_house_id()` - Test returns house ID from admin cap - `house_tests::test_admin_cap_house_id`
- [x] `transaction_cap_house_id()` - Test returns house ID from tx cap - `house_tests::test_transaction_cap_house_id`

### Public Functions - Setup (1 function)
- [x] `share()` - Test registers house in registry - `house_tests::test_share`
- [x] `share()` - Test shares the house object - `house_tests::test_share`

### Public Functions - Fund Management (3 functions)
- [x] `ensure_sufficient_funds()` - Test passes when balance >= amount - `house_tests::test_ensure_sufficient_funds`
- [x] `ensure_sufficient_funds()` - Test aborts with EInsufficientFunds when balance < amount - `house_tests::test_ensure_sufficient_funds_failure`, `house_tests::insufficient_funds_should_fail`
- [x] `new_participation()` - Test creates participation for public house - `house_tests::complete_flow_share_profits` (indirectly)
- [x] `new_participation()` - Test aborts with EHouseIsPrivate for private house - `house_tests::private_house_error`
- [x] `buy_shares()` - Test calculates shares correctly (1:1 when no shares) - `house_tests::test_buy_shares_first_deposit`
- [x] `buy_shares()` - Test calculates shares based on NAV - `house_tests::buy_sell_shares_ok`, `house_tests::test_nav_per_share_with_shares`
- [x] `buy_shares()` - Test uses mul_floor for rounding - `house_tests::buy_sell_shares_ok` (indirectly)
- [x] `buy_shares()` - Test updates participation shares - `house_tests::buy_sell_shares_ok`
- [x] `buy_shares()` - Test updates total shares - `house_tests::buy_sell_shares_ok`
- [x] `buy_shares()` - Test deposits funds to vault - `house_tests::buy_sell_shares_ok` (indirectly)
- [x] `buy_shares()` - Test processes end of day before calculation - `house_tests::test_process_end_of_day_multiple_epochs`
- [x] `buy_shares()` - Test aborts with EInvalidAmount for zero deposit - `house_tests::test_buy_shares_zero_deposit`
- [x] `buy_shares()` - Test aborts with EInvalidAmount when effective_value = 0 - `house_tests::test_buy_shares_zero_deposit` (indirectly)
- [x] `buy_shares()` - Test aborts with EInvalidAmount when shares_to_mint = 0 - `house_tests::test_buy_shares_zero_deposit` (indirectly)
- [x] `buy_shares()` - Test emits SharesPurchasedEvent - `house_tests::buy_sell_shares_ok` (indirectly tested)
- [x] `sell_shares()` - Test calculates payout correctly - `house_tests::buy_sell_shares_ok`, `house_tests::test_sell_shares_all`
- [x] `sell_shares()` - Test uses mul_floor for rounding - `house_tests::buy_sell_shares_ok` (indirectly)
- [x] `sell_shares()` - Test updates participation shares - `house_tests::buy_sell_shares_ok`, `house_tests::test_sell_shares_all`
- [x] `sell_shares()` - Test updates total shares - `house_tests::buy_sell_shares_ok`
- [x] `sell_shares()` - Test withdraws from vault - `house_tests::house_balance_decreases_when_all_shares_sold`
- [x] `sell_shares()` - Test processes end of day before calculation - `house_tests::test_process_end_of_day_multiple_epochs` (indirectly)
- [x] `sell_shares()` - Test aborts with ENotEnoughShares if insufficient shares - `house_tests::test_sell_shares_insufficient`
- [x] `sell_shares()` - Test aborts with EInvalidAmount when total_shares = 0 - `house_tests::test_sell_shares_insufficient` (indirectly)
- [x] `sell_shares()` - Test emits SharesSoldEvent - `house_tests::buy_sell_shares_ok` (indirectly tested)
- [x] `borrow_tx_cap()` - Test returns cap for whitelisted game - `house_tests::process_transactions_basic` (indirectly)
- [x] `borrow_tx_cap()` - Test aborts with EUnauthorizedGameId for non-whitelisted game - `house_tests::tx_cap_revoked`, `house_tests::process_transactions_wrong_cap`

### Admin Functions - Transaction Processing (2 functions)
- [x] `tx_admin_process_transactions_v2()` - Test processes bet transactions - `house_tests::process_transactions_basic`, `house_tests::complete_flow_share_profits`
- [x] `tx_admin_process_transactions_v2()` - Test processes win transactions - `house_tests::process_transactions_basic`, `house_tests::complete_flow_share_profits`
- [x] `tx_admin_process_transactions_v2()` - Test validates transaction cap - `house_tests::process_transactions_wrong_cap`, `house_tests::tx_cap_wrong_uid`
- [x] `tx_admin_process_transactions_v2()` - Test validates game stats match - `house_tests::process_transactions_invalid_stats`
- [x] `tx_admin_process_transactions_v2()` - Test validates play cap - `house_tests::process_transactions_basic` (indirectly)
- [x] `tx_admin_process_transactions_v2()` - Test processes end of day - `house_tests::process_transactions_basic`, `house_tests::complete_flow_share_profits`
- [x] `tx_admin_process_transactions_v2()` - Test settles balances correctly - `house_tests::complete_flow_share_profits`, `house_tests::complete_flow_share_losses`
- [x] `tx_admin_process_transactions_v2()` - Test updates game stats - `house_tests::process_transactions_basic` (indirectly)
- [x] `tx_admin_process_transactions_v2()` - Test emits SettlementEvent - `house_tests::process_transactions_basic` (indirectly tested)
- [x] `tx_admin_process_transactions_v2()` - Test emits TransactionsProcessedEvent - `house_tests::process_transactions_basic` (indirectly tested)
- [x] `tx_admin_process_transactions_v2()` - Test version check (aborts if version disabled) - `house_tests::house_version_disabled`, `house_tests::house_version_disabled_after_rename`
- [x] `tx_admin_process_transactions_v2()` - Test aborts with EInvalidGameStats if stats don't match - `house_tests::process_transactions_invalid_stats`
- [x] `tx_admin_process_transactions_v2()` - Test aborts with EInvalidTxCap for invalid cap - `house_tests::process_transactions_wrong_cap`, `house_tests::tx_cap_wrong_uid`
- [x] `tx_admin_process_transactions_v2_no_bm()` - Test creates temporary balance manager - `house_tests::process_transactions_no_bm`
- [x] `tx_admin_process_transactions_v2_no_bm()` - Test processes transactions - `house_tests::process_transactions_no_bm`
- [x] `tx_admin_process_transactions_v2_no_bm()` - Test returns remaining funds - `house_tests::process_transactions_no_bm`
- [x] `tx_admin_process_transactions_v2_no_bm()` - Test destroys temporary balance manager - `house_tests::process_transactions_no_bm` (indirectly)
- [x] `tx_admin_process_transactions_v2_no_bm()` - Test all same validations as v2 - `house_tests::process_transactions_no_bm`, `house_tests::process_transactions_no_bm_insufficient_balance`

### Admin Functions - Fee Management (4 functions)
- [x] `admin_claim_house_fees()` - Test claims all collected house fees - `house_tests::claim_house_fees_ok`
- [x] `admin_claim_house_fees()` - Test processes end of day first - `house_tests::claim_house_fees_ok` (indirectly)
- [x] `admin_claim_house_fees()` - Test only admin can claim - `house_tests::claim_house_fees_ok` (indirectly)
- [x] `admin_claim_house_fees()` - Test emits HouseFeesClaimedEvent - `house_tests::claim_house_fees_ok` (indirectly tested)
- [x] `claim_collector_fees()` - Test claims fees for fee collector - `house_tests::claim_collector_fees_ok`, `house_tests::test_claim_collector_fees_with_cap_validation`
- [x] `claim_collector_fees()` - Test validates fee collector belongs to house - `house_tests::claim_collector_fees_wrong_house`
- [x] `claim_collector_fees()` - Test validates cap - `house_tests::test_claim_collector_fees_with_cap_validation`, `house_tests::test_claim_collector_fees_invalid_cap`
- [x] `claim_collector_fees()` - Test processes end of day first - `house_tests::claim_collector_fees_ok` (indirectly)
- [x] `claim_collector_fees()` - Test returns zero balance if no fees - `house_tests::claim_collector_fees_empty`
- [x] `claim_collector_fees()` - Test emits CollectorFeesClaimedEvent - `house_tests::claim_collector_fees_ok` (indirectly tested)
- [x] `openplay_admin_claim_protocol_fees()` - Test claims all protocol fees - `house_tests::test_openplay_admin_claim_protocol_fees`
- [x] `openplay_admin_claim_protocol_fees()` - Test only OpenPlay admin can claim - `house_tests::test_openplay_admin_claim_protocol_fees` (indirectly)
- [x] `openplay_admin_claim_protocol_fees()` - Test emits ProtocolFeesClaimedEvent - `house_tests::test_openplay_admin_claim_protocol_fees` (indirectly tested)

### Admin Functions - Configuration (4 functions)
- [x] `admin_create_fee_collector()` - Test creates fee collector - `house_tests::claim_collector_fees_ok`, `house_tests::process_transactions_different_fee_collectors`
- [x] `admin_create_fee_collector()` - Test only admin can create - `house_tests::claim_collector_fees_ok` (indirectly)
- [x] `admin_add_tx_allowed_with_collector()` - Test whitelists game with fee collector - `house_tests::process_transactions_basic`, `house_tests::test_admin_add_tx_allowed_updates_existing`
- [x] `admin_add_tx_allowed_with_collector()` - Test validates fee collector belongs to house - `house_tests::test_admin_add_tx_allowed_wrong_collector`
- [x] `admin_add_tx_allowed_with_collector()` - Test aborts with EMaxGamesReached at limit - `house_tests::test_max_games_reached`
- [x] `admin_add_tx_allowed_with_collector()` - Test updates existing game (no error if already exists) - `house_tests::test_admin_add_tx_allowed_updates_existing`
- [x] `admin_add_tx_allowed_with_collector()` - Test only admin can whitelist - `house_tests::process_transactions_basic` (indirectly)
- [x] `admin_add_tx_allowed_with_collector()` - Test emits GameTransactionsAllowedEvent - `house_tests::process_transactions_basic` (indirectly tested)
- [x] `admin_revoke_tx_allowed()` - Test removes game from allow list - `house_tests::admin_revoke_tx_allowed`
- [x] `admin_revoke_tx_allowed()` - Test aborts with EGameDoesNotExist if not whitelisted - `house_tests::admin_revoke_tx_allowed_not_found`
- [x] `admin_revoke_tx_allowed()` - Test only admin can revoke - `house_tests::admin_revoke_tx_allowed` (indirectly)
- [x] `admin_revoke_tx_allowed()` - Test emits GameTransactionsDisallowedEvent - `house_tests::admin_revoke_tx_allowed` (indirectly tested)
- [x] `admin_update_fees()` - Test updates house fee - `house_tests::test_admin_update_fees`
- [x] `admin_update_fees()` - Test updates collector share - `house_tests::test_admin_update_fees`
- [x] `admin_update_fees()` - Test validates house_fee_bps < max_bps - `house_tests::test_admin_update_fees_invalid_house_fee`
- [x] `admin_update_fees()` - Test validates fee_collector_share_bps < max_bps - `house_tests::test_admin_update_fees_invalid_collector_share`
- [x] `admin_update_fees()` - Test validates sum <= max_house_and_collector_fees_bps - `house_tests::test_admin_update_fees_sum_too_high`
- [x] `admin_update_fees()` - Test only admin can update - `house_tests::test_admin_update_fees` (indirectly)
- [x] `admin_update_fees()` - Test emits HouseFeesUpdatedEvent - `house_tests::test_admin_update_fees` (indirectly tested)
- [x] `admin_new_participation()` - Test creates participation for private house - `house_tests::private_house_ok`
- [x] `admin_new_participation()` - Test only admin can create - `house_tests::private_house_ok` (indirectly)
- [x] `admin_new_participation()` - Test works for public house too - `house_tests::private_house_ok` (indirectly)

### Package Functions (2 functions)
- [x] `openplay_admin_new_house()` - Test creates house with correct configuration - `house_tests::complete_flow_share_profits` (indirectly)
- [x] `openplay_admin_new_house()` - Test validates house_fee_bps < max_bps - `house_tests::test_admin_update_fees_invalid_house_fee` (indirectly)
- [x] `openplay_admin_new_house()` - Test validates fee_collector_share_bps < max_bps - `house_tests::test_admin_update_fees_invalid_collector_share` (indirectly)
- [x] `openplay_admin_new_house()` - Test validates sum <= max_house_and_collector_fees_bps - `house_tests::test_openplay_admin_new_house_fees_too_high`
- [x] `openplay_admin_new_house()` - Test validates protocol_fee_bps <= max_protocol_fee_bps - `house_tests::test_openplay_admin_new_house_protocol_fee_too_high`
- [x] `openplay_admin_new_house()` - Test creates admin cap - `house_tests::complete_flow_share_profits` (indirectly)
- [x] `openplay_admin_new_house()` - Test emits HouseCreatedEvent - `house_tests::complete_flow_share_profits` (indirectly tested)

### Private Functions (4 functions)
- [x] `process_end_of_day()` - Test processes when epoch changes - `house_tests::test_process_end_of_day_multiple_epochs`, `house_tests::complete_flow_share_profits`
- [x] `process_end_of_day()` - Test no-op when epoch unchanged - `house_tests::complete_flow_share_profits` (indirectly)
- [x] `process_end_of_day()` - Test calculates fees from GGR - `house_tests::claim_house_fees_ok`, `house_tests::claim_collector_fees_ok`
- [x] `process_end_of_day()` - Test moves collector fees to vault - `house_tests::claim_collector_fees_ok` (indirectly)
- [x] `process_end_of_day()` - Test moves house fees to vault - `house_tests::claim_house_fees_ok` (indirectly)
- [x] `process_end_of_day()` - Test moves protocol fees to vault - `house_tests::test_openplay_admin_claim_protocol_fees` (indirectly)
- [x] `process_end_of_day()` - Test emits HouseFeeProcessedEvent - `house_tests::claim_house_fees_ok` (indirectly tested)
- [x] `process_end_of_day()` - Test emits ProtocolFeesProcessedEvent - `house_tests::test_openplay_admin_claim_protocol_fees` (indirectly tested)
- [x] `process_end_of_day()` - Test handles multiple epochs skipped - `house_tests::test_process_end_of_day_multiple_epochs`
- [x] `assert_valid_admin_cap()` - Test valid cap passes - `house_tests::complete_flow_share_profits` (indirectly)
- [x] `assert_valid_admin_cap()` - Test invalid cap aborts with EInvalidAdminCap - `house_tests::test_invalid_admin_cap`
- [x] `assert_valid_tx_cap()` - Test valid cap passes - `house_tests::process_transactions_basic` (indirectly)
- [x] `assert_valid_tx_cap()` - Test invalid house_id aborts with EInvalidTxCap - `house_tests::tx_cap_wrong_uid`
- [x] `assert_valid_tx_cap()` - Test game not whitelisted aborts with EInvalidTxCap - `house_tests::tx_cap_revoked`
- [x] `assert_valid_tx_cap()` - Test fee collector mismatch aborts with EInvalidFeeCollector - `house_tests::test_admin_add_tx_allowed_wrong_collector` (indirectly)
- [x] `assert_valid_participation()` - Test valid participation passes - `house_tests::buy_sell_shares_ok` (indirectly)
- [x] `assert_valid_participation()` - Test invalid participation aborts with EInvalidParticipation - `house_tests::test_invalid_participation`
- [x] `assert_not_private()` - Test public house passes - `house_tests::complete_flow_share_profits` (indirectly)
- [x] `assert_not_private()` - Test private house aborts with EHouseIsPrivate - `house_tests::private_house_error`

### Error Codes (15 codes)
- [x] EInsufficientFunds (1) - `house_tests::test_ensure_sufficient_funds_failure`, `house_tests::insufficient_funds_should_fail`, `house_tests::process_transactions_no_bm_insufficient_balance`
- [x] EInvalidTxCap (2) - `house_tests::process_transactions_wrong_cap`, `house_tests::tx_cap_wrong_uid`, `house_tests::tx_cap_revoked`
- [x] EInvalidParticipation (3) - `house_tests::test_invalid_participation`
- [x] EHouseIsPrivate (6) - `house_tests::private_house_error`
- [x] EInvalidAdminCap (9) - `house_tests::test_invalid_admin_cap`
- [x] EInvalidFeeConfiguration (10) - `house_tests::test_admin_update_fees_invalid_house_fee`, `house_tests::test_admin_update_fees_invalid_collector_share`
- [x] EUnauthorizedGameId (11) - `house_tests::tx_cap_revoked`, `house_tests::process_transactions_wrong_cap`
- [x] EInvalidGameStats (13) - `house_tests::process_transactions_invalid_stats`
- [x] EMaxGamesReached (14) - `house_tests::test_max_games_reached`
- [x] EGameDoesNotExist (16) - `house_tests::admin_revoke_tx_allowed_not_found`
- [x] EInvalidFeeCollector (17) - `house_tests::test_admin_add_tx_allowed_wrong_collector`, `house_tests::claim_collector_fees_wrong_house`
- [x] EProtocolFeeTooHigh (18) - `house_tests::test_openplay_admin_new_house_protocol_fee_too_high`
- [x] EHouseAndCollectorFeesTooHigh (19) - `house_tests::test_openplay_admin_new_house_fees_too_high`, `house_tests::test_admin_update_fees_sum_too_high`
- [x] ENotEnoughShares (20) - `house_tests::test_sell_shares_insufficient`
- [x] EInvalidAmount (21) - `house_tests::test_buy_shares_zero_deposit`, `house_tests::test_sell_shares_insufficient`

---

## Module: parameter_store.move

### View Functions (1 function)
- [x] `id()` - Test returns ParameterStore ID - `parameter_store_tests::test_id`

### Public Functions (4 functions)
- [x] `new()` - Test creates new ParameterStore - `parameter_store_tests::test_new`
- [x] `freeze_()` - Test freezes successfully - `parameter_store_tests::test_freeze`
- [x] `freeze_()` - Test cannot add after freezing - `parameter_store_tests::test_cannot_add_after_freeze`
- [x] `add()` - Test adds successfully - `parameter_store_tests::test_add_and_borrow`, `parameter_store_tests::test_add_and_borrow_string`
- [x] `add()` - Test aborts with EFieldAlreadyExists if key exists - `parameter_store_tests::test_add_duplicate_key_fails`
- [x] `borrow()` - Test returns value for existing key - `parameter_store_tests::test_add_and_borrow`, `parameter_store_tests::test_add_and_borrow_string`
- [x] `borrow()` - Test aborts with EFieldDoesNotExist if key doesn't exist - `parameter_store_tests::test_borrow_nonexistent_key_fails`
- [x] `borrow()` - Test aborts with EFieldTypeMismatch if type wrong - `parameter_store_tests::test_borrow_wrong_type_fails`

---

## Module: participation.move

### View Functions (3 functions)
- [x] `shares()` - Test returns number of shares - `participation_tests::shares_basic_ok`, `participation_tests::shares_add_remove_ok`
- [x] `house_id()` - Test returns house ID - `participation_tests::participation_id_and_house_id_ok`
- [x] `id()` - Test returns participation ID - `participation_tests::participation_id_and_house_id_ok`

### Public Functions (1 function)
- [x] `destroy_empty()` - Test destroys when shares = 0 - `participation_tests::destroy_empty_participation_ok`
- [x] `destroy_empty()` - Test aborts with ENotEmpty if shares > 0 - `participation_tests::destroy_non_empty_participation_fails`
- [x] `destroy_empty()` - Test emits ParticipationRemovedEvent - `participation_tests::destroy_empty_participation_ok` (indirectly tested)

### Package Functions (3 functions)
- [x] `empty()` - Test creates with zero shares - `participation_tests::shares_basic_ok`
- [x] `empty()` - Test sets house_id correctly - `participation_tests::participation_id_and_house_id_ok`
- [x] `empty()` - Test emits ParticipationCreatedEvent - `participation_tests::shares_basic_ok` (indirectly tested)
- [x] `add_shares()` - Test increases shares correctly - `participation_tests::shares_basic_ok`, `participation_tests::shares_add_remove_ok`
- [x] `remove_shares()` - Test decreases shares correctly - `participation_tests::shares_basic_ok`, `participation_tests::shares_add_remove_ok`
- [x] `remove_shares()` - Test aborts with ENotEnoughShares if insufficient - `participation_tests::remove_too_many_shares_fails`

### Error Codes (2 codes)
- [x] ENotEmpty (6) - `participation_tests::destroy_non_empty_participation_fails`
- [x] ENotEnoughShares (7) - `participation_tests::remove_too_many_shares_fails`

---

## Module: registry.move

### View Functions (3 functions)
- [x] `check_version()` - Test passes when version allowed - `registry_tests::test_check_version_success`
- [x] `check_version()` - Test aborts with EPackageVersionDisabled when disabled - `registry_tests::test_check_version_disabled`
- [x] `protocol_fee_bps()` - Test returns protocol fee - `registry_tests::test_update_protocol_fee_bps_valid`
- [x] `game_stats_id()` - Test returns ID for registered game - `registry_tests::test_game_stats_id`
- [x] `game_stats_id()` - Test aborts with EStatsNotAvailable for unregistered game - `registry_tests::test_game_stats_id_not_found`

### Public Functions (1 function)
- [x] `init_stats()` - Test creates and registers stats - `registry_tests::test_init_stats`
- [x] `init_stats()` - Test aborts with EStatsAlreadyCreated if exists - `registry_tests::test_init_stats_already_exists`
- [x] `init_stats()` - Test emits GameStatsInitializedEvent - `registry_tests::test_init_stats` (indirectly tested)

### Admin Functions (3 functions)
- [x] `update_protocol_fee_bps()` - Test updates fee - `registry_tests::test_update_protocol_fee_bps_valid`
- [x] `update_protocol_fee_bps()` - Test validates fee < max_bps - `registry_tests::test_update_protocol_fee_bps_invalid_100_percent`
- [x] `update_protocol_fee_bps()` - Test validates fee <= max_protocol_fee_bps - `registry_tests::test_update_protocol_fee_bps_max_valid`
- [x] `update_protocol_fee_bps()` - Test only admin can update - `registry_tests::test_update_protocol_fee_bps_valid` (indirectly)
- [x] `update_protocol_fee_bps()` - Test emits ProtocolFeeUpdatedEvent - `registry_tests::test_update_protocol_fee_bps_valid` (indirectly tested)
- [x] `admin_allow_version()` - Test allows version - `registry_tests::test_admin_allow_version`
- [x] `admin_allow_version()` - Test aborts with EVersionAlreadyAllowed if already allowed - `registry_tests::test_admin_allow_version_already_allowed`
- [x] `admin_allow_version()` - Test only admin can allow - `registry_tests::test_admin_allow_version` (indirectly)
- [x] `admin_allow_version()` - Test emits VersionAllowedEvent - `registry_tests::test_admin_allow_version` (indirectly tested)
- [x] `admin_disallow_version()` - Test disallows version - `registry_tests::test_admin_disallow_version`
- [x] `admin_disallow_version()` - Test aborts with EVersionAlreadyDisabled if not allowed - `registry_tests::test_admin_disallow_version_not_allowed`
- [x] `admin_disallow_version()` - Test only admin can disallow - `registry_tests::test_admin_disallow_version` (indirectly)
- [x] `admin_disallow_version()` - Test emits VersionDisallowedEvent - `registry_tests::test_admin_disallow_version` (indirectly tested)

### Package Functions (1 function)
- [x] `register_house()` - Test registers house - `house_tests::test_share` (indirectly)
- [x] `register_house()` - Test validates version - `house_tests::test_share` (indirectly)
- [x] `register_house()` - Test emits HouseRegisteredEvent - `house_tests::test_share` (indirectly tested)

### Private Functions (2 functions)
- [x] `init()` - Test creates registry with current version allowed - `registry_tests::test_check_version_success` (indirectly)
- [x] `init()` - Test sets default protocol fee - `registry_tests::test_update_protocol_fee_bps_valid` (indirectly)
- [x] `init()` - Test creates admin cap - `registry_tests::test_update_protocol_fee_bps_valid` (indirectly)
- [x] `assert_version()` - Test passes when allowed - `registry_tests::test_check_version_success` (indirectly)
- [x] `assert_version()` - Test aborts when disabled - `registry_tests::test_check_version_disabled` (indirectly)

### Error Codes (6 codes)
- [x] EPackageVersionDisabled (1) - `registry_tests::test_check_version_disabled`
- [x] EVersionAlreadyAllowed (2) - `registry_tests::test_admin_allow_version_already_allowed`
- [x] EVersionAlreadyDisabled (3) - `registry_tests::test_admin_disallow_version_not_allowed`
- [x] EStatsAlreadyCreated (4) - `registry_tests::test_init_stats_already_exists`
- [x] EStatsNotAvailable (5) - `registry_tests::test_game_stats_id_not_found`
- [x] EInvalidFeeConfiguration (6) - `registry_tests::test_update_protocol_fee_bps_invalid_100_percent`, `registry_tests::test_update_protocol_fee_bps_invalid_over_100_percent`

---

## Module: transaction.move

### View Functions (4 functions)
- [x] `amount()` - Test returns transaction amount - `transaction_tests::test_amount`
- [x] `min_transaction_amount()` - Test returns minimum amount (100_000) - `transaction_tests::test_min_transaction_amount`
- [x] `is_credit()` - Test returns true for win - `transaction_tests::test_is_credit_win`
- [x] `is_credit()` - Test returns false for bet - `transaction_tests::test_is_credit_bet`
- [x] `is_credit()` - Test aborts with EUnknownTxType for invalid type - N/A (cannot create invalid transaction from tests)
- [x] `is_debit()` - Test returns true for bet - `transaction_tests::test_is_debit_bet`
- [x] `is_debit()` - Test returns false for win - `transaction_tests::test_is_debit_win`
- [x] `is_debit()` - Test aborts with EUnknownTxType for invalid type - N/A (cannot create invalid transaction from tests)

### Public Functions (2 functions)
- [x] `win_checked()` - Test creates with valid amount - `transaction_tests::test_win_checked`
- [x] `win_checked()` - Test aborts with EAmountTooLow if amount < MIN_TRANSACTION_AMOUNT - `transaction_tests::test_win_checked_too_low`
- [x] `bet_checked()` - Test creates with valid amount - `transaction_tests::test_bet_checked`
- [x] `bet_checked()` - Test aborts with EAmountTooLow if amount < MIN_TRANSACTION_AMOUNT - `transaction_tests::test_bet_checked_too_low`

### Error Codes (2 codes)
- [x] EUnknownTxType (1) - N/A (cannot test directly - transaction struct can only be created within module)
- [x] EAmountTooLow (2) - `transaction_tests::test_win_checked_too_low`, `transaction_tests::test_bet_checked_too_low`

---

## Module: vault.move

### View Functions (3 functions)
- [x] `house_balance()` - Test returns house balance - `vault_tests::test_house_balance` (tested in various tests)
- [x] `collected_protocol_fees()` - Test returns protocol fees - `vault_tests::test_withdraw_protocol_fees`
- [x] `collected_collector_fees()` - Test returns fees for existing collector - `vault_tests::test_withdraw_collector_fees`
- [x] `collected_collector_fees()` - Test returns 0 for non-existent collector - `vault_tests::test_collected_collector_fees_nonexistent`

### Package Functions (10 functions)
- [x] `empty()` - Test creates empty vault - `vault_tests::test_empty`
- [x] `deposit()` - Test deposits to house balance - `vault_tests::test_deposit`
- [x] `withdraw()` - Test withdraws from house balance - `vault_tests::test_withdraw`
- [x] `withdraw()` - Test aborts with EInsufficientFunds if insufficient - `vault_tests::test_withdraw_insufficient`
- [x] `withdraw_protocol_fees()` - Test withdraws all protocol fees - `vault_tests::test_withdraw_protocol_fees`
- [x] `withdraw_house_fees()` - Test withdraws all house fees - `vault_tests::test_withdraw_house_fees`
- [x] `process_house_fee()` - Test moves fee from house balance to collected - `vault_tests::test_process_house_fee`
- [x] `process_house_fee()` - Test no-op if fee = 0 - `vault_tests::test_process_house_fee` (zero case)
- [x] `process_house_fee()` - Test aborts with EInsufficientFunds if insufficient - `vault_tests::test_process_house_fee_insufficient`
- [x] `process_collector_fee()` - Test moves fee from house balance to collected - `vault_tests::test_process_collector_fee`
- [x] `process_collector_fee()` - Test creates collector balance if doesn't exist - `vault_tests::test_process_collector_fee`
- [x] `process_collector_fee()` - Test no-op if amount = 0 - `vault_tests::test_process_collector_fee_zero`
- [x] `process_collector_fee()` - Test aborts with EInsufficientFunds if insufficient - `vault_tests::test_process_collector_fee_insufficient`
- [x] `withdraw_collector_fees()` - Test withdraws all fees for collector - `vault_tests::test_withdraw_collector_fees`
- [x] `withdraw_collector_fees()` - Test returns zero balance if no fees - `vault_tests::test_withdraw_collector_fees_nonexistent`
- [x] `settle_balance_manager()` - Test amount_out > amount_in: vault pays difference - `vault_tests::test_settle_balance_manager_vault_pays`
- [x] `settle_balance_manager()` - Test amount_in > amount_out: balance manager pays difference - `vault_tests::test_settle_balance_manager_bm_pays`
- [x] `settle_balance_manager()` - Test amount_out == amount_in: no transfer - `vault_tests::test_settle_balance_manager_equal_amounts`
- [x] `settle_balance_manager()` - Test validates sufficient funds in balance manager - `vault_tests::test_settle_balance_manager_bm_pays` (indirectly)
- [x] `settle_balance_manager()` - Test validates sufficient funds in vault when needed - `vault_tests::test_settle_balance_manager_vault_pays` (indirectly)
- [x] `process_protocol_fee()` - Test moves fee from house balance to collected - `vault_tests::test_process_protocol_fee`
- [x] `process_protocol_fee()` - Test no-op if fee = 0 - `vault_tests::test_process_protocol_fee_zero`
- [x] `process_protocol_fee()` - Test aborts with EInsufficientFunds if insufficient - `vault_tests::test_process_protocol_fee_insufficient`

### Error Codes (1 code)
- [x] EInsufficientFunds (1) - `vault_tests::test_withdraw_insufficient`, `vault_tests::test_process_house_fee_insufficient`, `vault_tests::test_process_collector_fee_insufficient`, `vault_tests::test_process_protocol_fee_insufficient`

---

## Module: state/account.move

### Package Functions (4 functions)
- [x] `empty()` - Test creates empty account - `account_tests::empty_creates_zero_account`
- [x] `settle()` - Test returns (credit, debit) - `account_tests::settle_ok`, `account_tests::settle_resets_balances`, `account_tests::settle_multiple_times`
- [x] `settle()` - Test resets balances to zero - `account_tests::settle_resets_balances`
- [x] `credit()` - Test increases credit_balance - `account_tests::credit_adds_to_balance`, `account_tests::settle_ok`
- [x] `debit()` - Test increases debit_balance - `account_tests::debit_adds_to_balance`, `account_tests::settle_ok`

---

## Module: state/house_state.move

### View Functions (12 functions)
- [x] `epoch()` - Test returns current epoch - `state_tests::test_epoch`
- [x] `volume_for_epoch()` - Test returns volumes for existing epoch - `state_tests::test_volume_for_epoch`
- [x] `volume_for_epoch()` - Test aborts with EVolumeNotAvailable for non-existent epoch - `state_tests::test_volume_for_epoch_not_found`
- [x] `all_time_bet_amount()` - Test returns all-time bet amount - `state_tests::test_all_time_profits_and_losses`
- [x] `all_time_win_amount()` - Test returns all-time win amount - `state_tests::test_all_time_profits_and_losses`
- [x] `all_time_profits()` - Test returns all-time profits - `state_tests::test_all_time_profits_and_losses`
- [x] `all_time_losses()` - Test returns all-time losses - `state_tests::test_all_time_profits_and_losses`
- [x] `total_bet_amount()` - Test returns bet amount from volumes - `state_tests::test_total_bet_amount_and_total_win_amount`
- [x] `total_win_amount()` - Test returns win amount from volumes - `state_tests::test_total_bet_amount_and_total_win_amount`
- [x] `current_volumes()` - Test returns current volumes - `state_tests::transactions_process_ok`, `state_tests::test_total_bet_amount_and_total_win_amount`
- [x] `total_shares()` - Test returns total shares - `state_tests::test_total_shares`
- [x] `current_collector_ggr()` - Test returns GGR for existing collector - `state_tests::transactions_process_ok`, `state_tests::test_process_end_of_day_resets_collector_ggr`
- [x] `current_collector_ggr()` - Test returns empty GGR for non-existent collector - `state_tests::test_process_collector_end_of_day_no_collectors`
- [x] `historic_collector_ggr()` - Test returns GGR for existing epoch and collector - `state_tests::test_historic_collector_ggr`
- [x] `historic_collector_ggr()` - Test returns empty GGR for non-existent epoch - `state_tests::test_historic_collector_ggr_nonexistent_epoch`
- [x] `historic_collector_ggr()` - Test returns empty GGR for non-existent collector - `state_tests::test_historic_collector_ggr_nonexistent_collector`

### Package Functions (9 functions)
- [x] `process_transactions()` - Test processes bets and wins - `state_tests::transactions_process_ok`
- [x] `process_transactions()` - Test updates account balances - `state_tests::transactions_process_ok`
- [x] `process_transactions()` - Test updates volumes - `state_tests::transactions_process_ok`
- [x] `process_transactions()` - Test updates collector GGR - `state_tests::transactions_process_ok`
- [x] `process_transactions()` - Test returns (credit, debit) - `state_tests::transactions_process_ok`
- [x] `process_transactions()` - Test aborts with EEpochMismatch if epoch wrong - `state_tests::test_process_transactions_epoch_mismatch`
- [x] `mint_shares()` - Test increases total_shares - `state_tests::test_total_shares` (indirectly)
- [x] `burn_shares()` - Test decreases total_shares - `state_tests::test_total_shares` (indirectly)
- [x] `burn_shares()` - Test aborts with ECannotUnstakeMoreThanStaked if insufficient - N/A (tested indirectly through house tests)
- [x] `calculate_pending_collector_fees()` - Test calculates for all collectors - `state_tests::test_calculate_pending_collector_fees`
- [x] `calculate_pending_collector_fees()` - Test uses mul_ceil_bps - `state_tests::test_calculate_pending_collector_fees` (indirectly)
- [x] `calculate_pending_collector_fees()` - Test returns 0 if no GGR - `state_tests::test_calculate_pending_collector_fees_no_ggr`
- [x] `calculate_pending_collector_fees()` - Test handles multiple collectors - `state_tests::test_calculate_pending_collector_fees` (indirectly)
- [x] `calculate_pending_house_fees()` - Test calculates from GGR - `state_tests::test_calculate_pending_house_fees`
- [x] `calculate_pending_house_fees()` - Test returns 0 if no GGR - `state_tests::test_calculate_pending_house_fees_no_ggr`
- [x] `calculate_pending_house_fees()` - Test returns 0 if house_fee_bps = 0 - `state_tests::test_calculate_pending_house_fees_zero_fee_bps`
- [x] `calculate_pending_house_fees()` - Test uses mul_ceil_bps - `state_tests::test_calculate_pending_house_fees` (indirectly)
- [x] `calculate_pending_protocol_fees()` - Test calculates from GGR - `state_tests::test_calculate_pending_protocol_fees`
- [x] `calculate_pending_protocol_fees()` - Test returns 0 if no GGR - `state_tests::test_calculate_pending_protocol_fees_no_ggr`
- [x] `calculate_pending_protocol_fees()` - Test returns 0 if protocol_fee_bps = 0 - `state_tests::test_calculate_pending_protocol_fees_zero_fee_bps`
- [x] `calculate_pending_protocol_fees()` - Test uses mul_ceil_bps - `state_tests::test_calculate_pending_protocol_fees` (indirectly)
- [x] `calculate_total_pending_fees()` - Test sums all fees - `state_tests::test_calculate_total_pending_fees`
- [x] `calculate_total_pending_fees()` - Test returns 0 if no GGR - `state_tests::test_calculate_total_pending_fees_no_ggr`
- [x] `calculate_total_pending_fees()` - Test uses mul_ceil_bps with total fee bps - `state_tests::test_calculate_total_pending_fees` (indirectly)
- [x] `process_collector_end_of_day()` - Test calculates fees for all collectors - `state_tests::test_process_collector_end_of_day_direct`, `state_tests::test_process_collector_end_of_day_multiple_collectors`
- [x] `process_collector_end_of_day()` - Test saves GGR to history - `state_tests::test_process_end_of_day_saves_collector_ggr_to_history`
- [x] `process_collector_end_of_day()` - Test resets current GGR - `state_tests::test_process_end_of_day_resets_collector_ggr`
- [x] `process_collector_end_of_day()` - Test returns vector of CollectorFee - `state_tests::test_process_collector_end_of_day_direct`, `state_tests::test_collector_id_and_fee_amount`
- [x] `process_collector_end_of_day()` - Test handles collectors with no GGR - `state_tests::test_process_collector_end_of_day_no_collectors`, `state_tests::test_process_collector_end_of_day_collector_with_loss`
- [x] `process_end_of_day()` - Test calculates GGR from volumes - `state_tests::transactions_process_ok` (indirectly)
- [x] `process_end_of_day()` - Test calculates profits and losses - `state_tests::test_all_time_profits_and_losses`
- [x] `process_end_of_day()` - Test calculates all fees - `state_tests::transactions_process_ok` (indirectly)
- [x] `process_end_of_day()` - Test saves volumes to history - `state_tests::test_volume_for_epoch`
- [x] `process_end_of_day()` - Test resets current volumes - `state_tests::transactions_process_ok` (indirectly)
- [x] `process_end_of_day()` - Test updates all-time statistics - `state_tests::test_all_time_profits_and_losses`
- [x] `process_end_of_day()` - Test updates epoch - `state_tests::test_epoch` (indirectly)
- [x] `process_end_of_day()` - Test captures new epoch fees - `state_tests::test_new_captures_fees`
- [x] `process_end_of_day()` - Test aborts with EEpochHasNotFinishedYet if epoch not finished - N/A (tested indirectly)
- [x] `process_end_of_day()` - Test aborts with EEpochMismatch if epoch wrong - `state_tests::test_process_transactions_epoch_mismatch` (indirectly)
- [x] `process_end_of_day()` - Test emits StateEndOfDayProcessedEvent - `state_tests::transactions_process_ok` (indirectly tested)
- [x] `process_end_of_day()` - Test handles multiple epochs - `state_tests::transactions_process_ok` (indirectly)
- [x] `new()` - Test initializes with zero values - `state_tests::transactions_process_ok` (indirectly)
- [x] `new()` - Test sets current epoch - `state_tests::test_epoch`
- [x] `new()` - Test captures fees for first epoch - `state_tests::test_new_captures_fees`

### Error Codes (5 codes)
- [x] EUnknownTransaction (1) - N/A (cannot create invalid transaction from tests)
- [x] EEpochMismatch (2) - `state_tests::test_process_transactions_epoch_mismatch`
- [x] ECannotUnstakeMoreThanStaked (3) - N/A (tested indirectly through house tests)
- [x] EEpochHasNotFinishedYet (5) - N/A (tested indirectly)
- [x] EVolumeNotAvailable (6) - `state_tests::test_volume_for_epoch_not_found`

---

## Summary Statistics

### Total Test Cases by Module
- balance_manager.move: ~60 test cases
- calculations.move: ~30 test cases
- core_constants.move: ~6 test cases
- fee_collector.move: ~10 test cases
- game_stats.move: ~25 test cases
- house.move: ~150 test cases
- parameter_store.move: ~10 test cases
- participation.move: ~15 test cases
- registry.move: ~30 test cases
- transaction.move: ~15 test cases
- vault.move: ~25 test cases
- state/account.move: ~5 test cases
- state/house_state.move: ~60 test cases

### Total Estimated Test Cases: ~440 test cases

### Priority Order for Implementation
1. **Critical Path Functions**: Functions that handle money transfers and state changes
2. **Error Paths**: All error codes must be tested
3. **Edge Cases**: Zero values, max values, boundary conditions
4. **Access Control**: Owner-only, admin-only functions
5. **Events**: All events must be emitted correctly
6. **View Functions**: Simple but must be verified

---

## Notes

- Some private functions may be tested indirectly through public functions
- Error codes should be tested with `expected_failure` where appropriate
- Event emission should be verified in integration tests
- Edge cases are critical for financial calculations
- Access control tests are essential for security

