# Changelog

All notable changes to this project will be documented in this file.

## [v2.1] - In Progress

### Added

#### Balance Manager (`balance_manager.move`)
- **New Events:**
  - `PlayCapDestroyedEvent` - emitted when a PlayCap is destroyed
  - `BalanceManagerDestroyedEvent` - emitted when a BalanceManager is destroyed
  - `PlayCapAllowListPrunedEvent` - emitted when all PlayCaps are pruned from the allow list
- **New Functions:**
  - `allow_list_length(&BalanceManager): u64` - returns the number of PlayCaps in the allow list
  - `prune_allow_list(&mut BalanceManager, &BalanceManagerCap)` - removes all PlayCap IDs from the allow list (owner only)
  - `destroy_play_cap(PlayCap)` - destroys a PlayCap (works even if BalanceManager no longer exists)
  - `destroy_play_cap_and_revoke(PlayCap, &mut BalanceManager)` - destroys a PlayCap and removes it from allow list

#### Calculations (`calculations.move`)
- **Complete rewrite of calculation system** - replaced UQ32_32 fixed-point arithmetic with integer-based calculations
- **New Public Functions:**
  - `mul_floor(val: u64, numerator: u64, denominator: u64): u64` - multiplies by ratio, rounding DOWN (for protocol payouts)
  - `mul_ceil(val: u64, numerator: u64, denominator: u64): u64` - multiplies by ratio, rounding UP (for user fees/losses)
  - `mul_floor_bps(val: u64, bps: u64): u64` - convenience function for basis points, rounds DOWN
  - `mul_ceil_bps(val: u64, bps: u64): u64` - convenience function for basis points, rounds UP
- **New Error Codes:**
  - `EOverflow: u64 = 2` - when calculation result would overflow u64
  - `EDivisionByZero: u64 = 3` - when denominator is zero

#### House (`house.move`)
- **New Struct Field:**
  - `house_fee_bps: u64` - performance fee taken from profits (in basis points)
- **New Constants:**
  - `MAX_GAMES: u64 = 500` - maximum number of games that can have fees configured
- **New Error Codes:**
  - `EMaxGamesReached: u64 = 14` - when trying to add more than MAX_GAMES
  - `EGameFeeNotFound: u64 = 15` - when trying to remove a game fee that doesn't exist
- **New Functions:**
  - `update_participation_with_limit(&mut House, &mut Participation, max_epochs: u64, &mut TxContext): bool` - updates participation with epoch limit to prevent DoS
  - `admin_claim_house_fees(&mut House, &HouseAdminCap, &mut TxContext): Coin<SUI>` - claims collected house performance fees
  - `admin_remove_game_fee(&mut House, &HouseAdminCap, &ID)` - removes fee configuration for a game
- **New Events:**
  - `HouseFeesClaimedEvent` - emitted when house fees are claimed
  - `StakeAddedEvent` - emitted when stake is added to a participation
  - `StakeRemovedEvent` - emitted when stake is removed from a participation
  - `SettlementEvent` - emitted when balances are settled between vault and balance manager
  - `GameFeeRemovedEvent` - emitted when a game's fee is removed
- **New Getter Functions:**
  - `game_fee_bps(&House, &ID): u64` - returns game fee in basis points (replaces `game_fee_factor`)
  - `house_fee_bps(&House): u64` - returns house fee in basis points

#### Participation (`participation.move`)
- **New Event:**
  - `ClaimProcessedEvent` - emitted when funds are claimed from a participation
- **New Error Code:**
  - `EActualizedUnstakeExceedsStake: u64 = 8` - when actualized unstake amount exceeds remaining stake (mathematically impossible but enforced)

#### Registry (`registry.move`)
- **New Events:**
  - `ProtocolFeeUpdatedEvent` - emitted when protocol fee is updated
  - `VersionAllowedEvent` - emitted when a package version is allowed
  - `VersionDisallowedEvent` - emitted when a package version is disallowed
  - `GameStatsInitializedEvent` - emitted when GameStatistics are initialized
  - `HouseRegisteredEvent` - emitted when a House is registered
- **New Error Code:**
  - `EInvalidFeeConfiguration: u64 = 6` - when fee configuration is invalid (e.g., >= 100%)
- **Changed Default:**
  - Protocol fee default changed from `0` to `10` (0.1%) in registry initialization

#### Transaction (`transaction.move`)
- **New Constants:**
  - `MIN_TRANSACTION_AMOUNT: u64 = 100_000` (0.0001 SUI in MIST)
- **New Error Code:**
  - `EAmountTooLow: u64 = 2` - when transaction amount is below minimum
- **New Functions:**
  - `min_transaction_amount(): u64` - returns the minimum transaction amount
  - `win_checked(amount: u64): Transaction` - creates win transaction with amount validation
  - `bet_checked(amount: u64): Transaction` - creates bet transaction with amount validation
- **Breaking Change:**
  - `win()` and `bet()` functions are now `#[test_only]` - production code must use `win_checked()` and `bet_checked()`

#### Vault (`vault.move`)
- **New Struct Field:**
  - `collected_house_fees: Balance<SUI>` - balance for collected house performance fees
- **New Functions:**
  - `withdraw_house_fees(&mut Vault): Balance<SUI>` - withdraws all collected house fees
  - `process_house_fee(&mut Vault, house_fee: u64)` - processes and collects house fees from reserve balance

### Changed

#### Balance Manager (`balance_manager.move`)
- **Modified Function:**
  - `destroy_empty()` - now emits `BalanceManagerDestroyedEvent` when BalanceManager is destroyed

#### Calculations (`calculations.move`)
- **BREAKING CHANGE - Function Signature:**
  - `actualize_amount()` signature changed:
    - **Old:** `actualize_amount(amount: u64, profits: u64, losses: u64, base: u64): u64`
    - **New:** `actualize_amount(amount: u64, profits: u64, losses: u64, base: u64, round_up: bool): u64`
  - Added `round_up` parameter to control rounding direction (UP for losses, DOWN for profits)
- **Implementation Changes:**
  - Removed UQ32_32 fixed-point arithmetic, replaced with integer-based calculations using u128 for overflow safety
  - Removed precision error allowance - now uses strict assertions
  - Loss handling: removed edge case handling for precision errors, now strictly enforces `losses <= base`
  - All rounding now explicitly favors the protocol (UP for fees/losses, DOWN for payouts)

#### Core Constants (`core_constants.move`)
- **Removed:**
  - `PRECISION_ERROR_ALLOWANCE` constant
  - `precision_error_allowance()` function

#### House (`house.move`)
- **BREAKING CHANGE - Struct Field:**
  - Removed: `referral_fee_bps: u64` field from `House` struct
  - Added: `house_fee_bps: u64` field to `House` struct
- **BREAKING CHANGE - Struct:**
  - `Fees` struct changed:
    - **Removed:** `referral_fee: u64` field
    - **Remaining:** `protocol_fee: u64`, `game_fee: u64`
- **BREAKING CHANGE - Function Signatures:**
  - `game_fee_factor(&House, &ID): UQ32_32` → `game_fee_bps(&House, &ID): u64`
  - Removed: `referral_fee_factor(&House): UQ32_32`
  - `openplay_admin_new_house()` signature changed:
    - **Removed:** `referral_fee_bps: u64` parameter
    - **Added:** `house_fee_bps: u64` parameter
  - `tx_admin_process_transactions_v2()` signature changed:
    - **Removed:** `referral_id: Option<ID>` parameter
  - `tx_admin_process_transactions_v2_no_bm()` signature changed:
    - **Removed:** `referral_id: Option<ID>` parameter
- **BREAKING CHANGE - Return Types:**
  - `house_state::process_transactions()` return type changed:
    - **Old:** `(u64, u64, u64, u64, u64)` - (credit, debit, game_fee, protocol_fee, referral_fee)
    - **New:** `(u64, u64, u64, u64)` - (credit, debit, game_fee, protocol_fee)
- **BREAKING CHANGE - Events:**
  - `TransactionsProcessedEvent` struct changed:
    - **Removed:** `referral_id: Option<ID>` field
  - `ReferralFeesClaimedEvent` removed (replaced by `HouseFeesClaimedEvent`)
- **Removed Functions:**
  - `new_referral()` - removed referral creation functionality
  - `assert_referral_active()` - removed referral validation
- **Implementation Changes:**
  - `process_end_of_day()` - now calculates and deducts house performance fee from profits before distributing to stakers
  - Fee calculation now uses basis points directly instead of UQ32_32 fixed-point factors
  - All fee calculations now round UP to favor the protocol
  - `admin_set_game_fee()` - now enforces MAX_GAMES limit when adding new games
  - Transaction processing functions now use `registry.protocol_fee_bps()` which performs version checks
  - Version control: `stake()`, `unstake_v2()`, and `claim_all()` explicitly do NOT perform version checks (ensures user funds can never be paused)

#### House State (`state/house_state.move`)
- **BREAKING CHANGE - Function Signature:**
  - `process_transactions()` signature changed:
    - **Removed:** `referral_fee_factor: Option<UQ32_32>` parameter
    - **Changed:** `game_fee_factor: UQ32_32` → `game_fee_bps: u64`
    - **Changed:** `protocol_fee_factor: UQ32_32` → `protocol_fee_bps: u64`
  - Return type changed from `(u64, u64, u64, u64, u64)` to `(u64, u64, u64, u64)`
- **Modified Functions:**
  - `refresh()` - now calls `update_participation()` with `u64::MAX` (processes all epochs)
  - `refresh_with_limit()` - new function that limits epochs processed per call
  - `update_participation()` - now takes `max_epochs: u64` parameter and returns `bool` (true if all epochs processed)
  - `calculate_ggr_share()` - now uses `mul_ceil()` for losses and `mul_floor()` for profits (replaces UQ32_32 arithmetic)
  - `calculate_fee()` - now takes `fee_bps: u64` instead of `house_fee_factor: UQ32_32`, uses `mul_ceil_bps()`
  - `process_end_of_day()` - now uses `actualize_amount()` with `round_up` parameter
  - `remove_inactive_stake()` - removed precision error allowance, now uses strict assertion
- **Implementation Changes:**
  - Removed all UQ32_32 fixed-point arithmetic, replaced with integer-based calculations
  - Removed precision error allowance handling throughout
  - All rounding now explicitly favors the protocol
  - Added mathematical proof documentation for `actualized_unstake <= remaining_stake` guarantee

#### Participation (`participation.move`)
- **Removed Events:**
  - `StakeAddedEvent` - moved to `house.move` (now includes `house_id`)
  - `StakeRemovedEvent` - moved to `house.move` (now includes `house_id`)
- **Modified Functions:**
  - `add_stake()` - removed event emission (now emitted in `house.move`)
  - `unstake_v2()` - removed event emission (now emitted in `house.move`)
  - `process_end_of_day()` - major implementation changes:
    - Removed precision error allowance handling
    - Now uses strict assertion: `assert!(self.stake >= losses, EInvalidProfitsOrLosses)`
    - `actualize_amount()` call now includes `round_up` parameter (true for losses, false for profits)
    - Added assertion: `assert!(actual_unstake_amount <= self.stake, EActualizedUnstakeExceedsStake)`
    - Removed edge case handling for `actual_unstake_amount > self.stake`
    - Added extensive mathematical proof documentation
  - `claim_all()` - now emits `ClaimProcessedEvent`

#### Registry (`registry.move`)
- **BREAKING CHANGE - Function Signature:**
  - `protocol_fee_factor(): UQ32_32` → `protocol_fee_bps(): u64`
  - Returns basis points directly instead of UQ32_32 fixed-point factor
- **Modified Functions:**
  - `update_protocol_fee_bps()` - now validates fee < 100% (max_bps), emits `ProtocolFeeUpdatedEvent`
  - `admin_allow_version()` - now emits `VersionAllowedEvent`
  - `admin_disallow_version()` - now emits `VersionDisallowedEvent`
  - `init_stats()` - now emits `GameStatsInitializedEvent`
  - `register_house()` - now emits `HouseRegisteredEvent`
- **Implementation Changes:**
  - `protocol_fee_bps()` now performs version check that can block gameplay (but not fund operations)
  - Added extensive documentation about version control strategy

#### Transaction (`transaction.move`)
- **Implementation Changes:**
  - `win()` and `bet()` functions are now `#[test_only]` - production code must use checked versions

#### Vault (`vault.move`)
- **BREAKING CHANGE - Struct Field:**
  - Removed: `collected_referral_fees: VecMap<ID, Balance<SUI>>` field
  - Added: `collected_house_fees: Balance<SUI>` field
- **Removed Functions:**
  - `collected_referral_fees(&Vault, ID): u64`
  - `withdraw_referral_fees(&mut Vault, ID): Balance<SUI>`
  - `process_referral_fee(&mut Vault, ID, u64)`
  - `ensure_referral_fee_balance(&mut Vault, ID)`
  - `fund_referral_fees_for_testing()` (test-only)
- **Modified Functions:**
  - `empty()` - removed referral fees initialization, added house fees initialization
  - `settle_balance_manager()` - removed precision error allowance handling, now uses strict assertion
- **Implementation Changes:**
  - Removed all referral fee processing logic
  - All precision error allowance handling removed, replaced with strict assertions

### Fixed
- **Precision and Rounding:**
  - Replaced UQ32_32 fixed-point arithmetic with integer-based calculations using u128 for overflow safety
  - Removed precision error allowances that could lead to accounting inconsistencies
  - All rounding now explicitly favors the protocol (mathematically guaranteed)
- **Loss Handling:**
  - Strict enforcement that losses cannot exceed stake (removed precision error edge cases)
  - Mathematical proof added for `actualized_unstake <= remaining_stake` guarantee
- **DoS Protection:**
  - Added epoch limit to `update_participation` to prevent DoS attacks when catching up many epochs

### Removed
- **Referral System:**
  - **Removed Module:** `referral.move` - entire module deleted
  - **Removed from House:**
    - `referral_fee_bps: u64` field from `House` struct
    - `referral_fee: u64` field from `Fees` struct
    - `referral_fee_factor()` function
    - `new_referral()` function
    - `assert_referral_active()` function
    - `EReferralNotEnabled` error code
    - `referral_id: Option<ID>` parameter from transaction processing functions
    - `ReferralFeesClaimedEvent` event
  - **Removed from Vault:**
    - `collected_referral_fees: VecMap<ID, Balance<SUI>>` field
    - All referral fee functions (withdraw, process, ensure, collected getter)
  - **Removed from House State:**
    - `referral_fee_factor: Option<UQ32_32>` parameter from `process_transactions()`
  - **Removed from Calculations:**
    - UQ32_32 fixed-point arithmetic (entire system replaced)
  - **Removed from Core Constants:**
    - `PRECISION_ERROR_ALLOWANCE` constant
    - `precision_error_allowance()` function
- **Removed Precision Error Handling:**
  - All precision error allowance logic removed from:
    - `calculations::actualize_amount()`
    - `participation::process_end_of_day()`
    - `house_state::process_end_of_day()`
    - `house_state::remove_inactive_stake()`
    - `vault::settle_balance_manager()`

---

## [v1.1] - Previous Version

Initial stable version of OpenPlay Core protocol.

