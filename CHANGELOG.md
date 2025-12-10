# Changelog

All notable changes to this project will be documented in this file.

## [v3.1] - In Progress

### Added

#### Slippage Protection for Share Operations
- **New Feature:** Added slippage protection to `buy_shares()` and `sell_shares()` functions
  - `buy_shares()` now takes a `min_shares_out: u64` parameter - aborts with `ESlippageExceeded` if shares received would be less than the minimum
  - `sell_shares()` now takes a `min_sui_out: u64` parameter - aborts with `ESlippageExceeded` if SUI received would be less than the minimum
  - Protects users from unfavorable NAV changes between transaction submission and execution
  - Set parameter to 0 to disable slippage protection (not recommended for large transactions)
- **New Error Code:**
  - `ESlippageExceeded: u64 = 22` - slippage protection triggered when received amount is below minimum

### Major Architectural Changes

#### Share-Based Participation Model
- **BREAKING CHANGE:** Complete redesign from stake-based to share-based participation model
- Houses are now always active (no activation/deactivation cycles)
- Users buy and sell shares instead of staking/unstaking
- Shares are 1:1 with MIST (1 share = 1 MIST at initial NAV)
- NAV (Net Asset Value) per share calculated as: `effective_value / total_shares`
- Initial NAV is 1 MIST per share when no shares exist
- Proceeds from selling shares are immediately available (no pending unstake)
- Removed complex stake management: `stake`, `pending_stake`, `pending_unstake`, `claimable_balance`

#### Fee Collector System
- **New Module:** `fee_collector.move` - complete new module for game creator fee collection
- Multiple games can be assigned to the same fee collector
- Fee collectors receive a share of GGR (Gross Gaming Revenue) calculated at epoch end
- Fees are calculated from GGR (bet - win) rather than per-transaction
- Fee collector share is configurable per house and captured at epoch start
- Fee collectors can claim accumulated fees using their `FeeCollectorCap`

#### Simplified Vault Architecture
- **BREAKING CHANGE:** Removed play/reserve balance separation
- Single `house_balance` replaces `play_balance` and `reserve_balance`
- House is always active, so no need to fund/clear play balance
- Removed epoch tracking from vault (moved to state)
- Removed `process_end_of_day()` from vault (moved to house/state)

### Added

#### Fee Collector (`fee_collector.move`) - NEW MODULE
- **New Structs:**
  - `FeeCollector` - shared object representing a fee collector instance
  - `FeeCollectorCap` - owned capability required to claim fees
- **New Functions:**
  - `new(house_id: ID, ctx: &mut TxContext): (FeeCollector, FeeCollectorCap)` - creates a new fee collector
  - `id(&FeeCollector): ID` - returns fee collector ID
  - `house_id(&FeeCollector): ID` - returns associated house ID
  - `cap_fee_collector_id(&FeeCollectorCap): ID` - returns fee collector ID from cap
  - `assert_valid_cap(&FeeCollector, &FeeCollectorCap)` - validates cap ownership
  - `share(FeeCollector)` - shares the FeeCollector object, making it publicly accessible
- **New Events:**
  - `FeeCollectorCreatedEvent` - emitted when a fee collector is created

#### House (`house.move`)
- **New Struct Fields:**
  - `fee_collector_share_bps: u64` - fee collector share of GGR (in basis points)
  - `game_fee_collectors: VecMap<ID, ID>` - maps game_id to fee_collector_id (replaces `tx_allow_listed` and `games_fee_bps`)
- **New Constants:**
  - `INITIAL_NAV: u64 = 1_000_000_000` - initial NAV per share (1 MIST = 1 share)
  - `max_house_and_collector_fees_bps(): u64` - maximum combined house + collector fees (50% to ensure 30% for stakers)
- **New Error Codes:**
  - `ENotEnoughShares: u64 = 20` - not enough shares to sell
  - `EInvalidAmount: u64 = 21` - invalid amount (e.g., deposit with zero shares)
  - `EInvalidFeeCollector: u64 = 22` - fee collector doesn't belong to house
  - `EHouseAndCollectorFeesTooHigh: u64 = 23` - combined fees exceed maximum
  - `EProtocolFeeTooHigh: u64 = 24` - protocol fee exceeds maximum
  - `EGameDoesNotExist: u64 = 25` - game not found when revoking
- **New Functions:**
  - `nav(&House, &Participation): u64` - calculates the current value of a participation's shares
  - `effective_house_balance(&House): u64` - returns house balance minus pending fees
  - `total_shares(&House): u64` - returns total shares in circulation
  - `house_balance(&House): u64` - returns the house balance
  - `game_fee_collector(&House, game_id: &ID): ID` - returns fee collector ID for a game
  - `refresh_state(&mut House, &Registry, ctx: &mut TxContext)` - processes end of day to refresh state
  - `buy_shares(&mut House, &Registry, &mut Participation, deposit: Coin<SUI>, min_shares_out: u64, ctx: &mut TxContext): u64` - buys shares with deposited funds, with slippage protection
  - `sell_shares(&mut House, &Registry, &mut Participation, shares_to_sell: u64, min_sui_out: u64, ctx: &mut TxContext): Coin<SUI>` - sells shares and withdraws proceeds, with slippage protection
  - `admin_create_fee_collector(&House, &HouseAdminCap, ctx: &mut TxContext): (FeeCollector, FeeCollectorCap)` - creates a fee collector
  - `admin_add_tx_allowed_with_collector(&mut House, &HouseAdminCap, game_id: ID, &FeeCollector)` - whitelists game and assigns fee collector
  - `claim_collector_fees(&mut House, &Registry, &FeeCollector, &FeeCollectorCap, ctx: &mut TxContext): Coin<SUI>` - claims fees for a fee collector
  - `admin_update_fees(&mut House, &HouseAdminCap, house_fee_bps: u64, fee_collector_share_bps: u64)` - updates both house and collector fees
- **New Events:**
  - `SharesPurchasedEvent` - emitted when shares are purchased (includes NAV, shares, total_shares, epoch, player)
  - `SharesSoldEvent` - emitted when shares are sold (includes NAV, shares, total_shares, epoch, player)
  - `SettlementEvent` - emitted when balances are settled between vault and balance manager (includes game_id, fee_collector_id, amount_in, amount_out, epoch)
  - `CollectorFeesClaimedEvent` - emitted when collector fees are claimed (includes fee_collector_id, amount, epoch)
  - `HouseFeesUpdatedEvent` - emitted when house/collector fees are updated (includes old/new values)
  - `HouseFeeProcessedEvent` - emitted when house fees are processed at epoch end (includes amount, epoch)
  - `ProtocolFeesProcessedEvent` - emitted when protocol fees are processed at epoch end (includes amount, epoch)
- **Modified Events:**
  - `GameTransactionsAllowedEvent` - now includes `fee_collector_id`
  - `GameTransactionsDisallowedEvent` - renamed from `GameTransactionsRevokedEvent`, includes `fee_collector_id`
  - `TransactionsProcessedEvent` - now includes `fee_collector_id` and `epoch`, removed `fees` struct
  - `ProtocolFeesClaimedEvent` - now includes `epoch`
  - `HouseFeesClaimedEvent` - now includes `epoch`
  - `HouseCreatedEvent` - now includes `private`, `house_fee_bps`, `fee_collector_share_bps`
- **New Getter Functions:**
  - `fee_collector_share_bps(&House): u64` - returns fee collector share in basis points

#### Participation (`participation.move`)
- **New Struct Field:**
  - `shares: u64` - number of shares owned (replaces all stake-related fields)
- **New Functions:**
  - `shares(&Participation): u64` - returns number of shares owned
  - `add_shares(&mut Participation, shares: u64)` - adds shares to participation
  - `remove_shares(&mut Participation, shares: u64)` - removes shares from participation
- **New Events:**
  - `ParticipationCreatedEvent` - now includes `house_id` and `player`
  - `ParticipationRemovedEvent` - now includes `house_id` and `player`
- **New Error Codes:**
  - `ENotEnoughShares: u64 = 7` - not enough shares to remove

#### House State (`state/house_state.move`)
- **New Struct Fields:**
  - `house_id: ID` - reference to parent house
  - `total_shares: u64` - total shares in circulation
  - `current_collector_ggr: VecMap<ID, CollectorGGR>` - tracks GGR per fee collector for current epoch
  - `historic_collector_ggr: Table<u64, VecMap<ID, CollectorGGR>>` - historical GGR per fee collector per epoch
  - `current_epoch_protocol_fee_bps: u64` - protocol fee captured at epoch start
  - `current_epoch_house_fee_bps: u64` - house fee captured at epoch start
  - `current_epoch_fee_collector_share_bps: u64` - collector share captured at epoch start
- **New Structs:**
  - `CollectorGGR` - tracks bet and win amounts for a fee collector
  - `CollectorFee` - helper struct for returning collector fee information
- **New Functions:**
  - `total_shares(&State): u64` - returns total shares in circulation
  - `current_epoch_protocol_fee_bps(&State): u64` - returns protocol fee captured at epoch start
  - `current_epoch_house_fee_bps(&State): u64` - returns house fee captured at epoch start
  - `current_epoch_fee_collector_share_bps(&State): u64` - returns collector share captured at epoch start
  - `current_collector_ggr(&State, collector_id: ID): CollectorGGR` - returns current epoch GGR for a collector
  - `historic_collector_ggr(&State, epoch: u64, collector_id: ID): CollectorGGR` - returns historic GGR for a collector
  - `mint_shares(&mut State, shares: u64)` - mints new shares
  - `burn_shares(&mut State, shares: u64)` - burns shares
  - `calculate_pending_collector_fees(&State): u64` - calculates pending collector fees for NAV calculation
  - `calculate_pending_house_fees(&State): u64` - calculates pending house fees for NAV calculation
  - `calculate_pending_protocol_fees(&State): u64` - calculates pending protocol fees for NAV calculation
  - `calculate_total_pending_fees(&State): u64` - calculates total pending fees for NAV calculation
  - `process_collector_end_of_day(&mut State, epoch: u64, ctx: &mut TxContext): vector<CollectorFee>` - processes collector fees at epoch end
- **New Helper Functions:**
  - `empty_collector_ggr(): CollectorGGR` - creates empty collector GGR
  - `bet_amount(&CollectorGGR): u128` - returns bet amount
  - `win_amount(&CollectorGGR): u128` - returns win amount
  - `collector_id(&CollectorFee): ID` - returns collector ID
  - `fee_amount(&CollectorFee): u64` - returns fee amount
- **Modified Events:**
  - `StateEndOfDayProcessedEvent` - now includes `house_id`, removed `active_stake`

#### Vault (`vault.move`)
- **New Struct Fields:**
  - `house_id: ID` - reference to parent house
  - `collected_collector_fees: VecMap<ID, Balance<SUI>>` - collected fees per fee collector
  - `house_balance: Balance<SUI>` - single balance for all house funds (replaces play_balance + reserve_balance)
- **New Functions:**
  - `house_balance(&Vault): u64` - returns house balance
  - `collected_collector_fees(&Vault, fee_collector_id: ID): u64` - returns collected fees for a collector (0 if doesn't exist)
  - `process_collector_fee(&mut Vault, fee_collector_id: ID, amount: u64)` - processes and collects collector fees
  - `withdraw_collector_fees(&mut Vault, fee_collector_id: ID): Balance<SUI>` - withdraws all collected collector fees
  - `ensure_collector_fee_balance(&mut Vault, fee_collector_id: ID)` - ensures collector fee balance exists

#### Core Constants (`core_constants.move`)
- **New Functions:**
  - `max_house_and_collector_fees_bps(): u64` - maximum combined house + collector fees (5000 = 50%)
  - `max_protocol_fee_bps(): u64` - maximum protocol fee (2000 = 20%)

#### Balance Manager (`balance_manager.move`)
- **New Events:**
  - `PlayCapDestroyedEvent` - emitted when a PlayCap is destroyed (includes `destroyer: address`)
  - `BalanceManagerDestroyedEvent` - emitted when a BalanceManager is destroyed (includes `destroyer: address`)
  - `PlayCapAllowListPrunedEvent` - emitted when all PlayCaps are pruned from the allow list (includes `pruner: address`)
- **New Functions:**
  - `allow_list_length(&BalanceManager): u64` - returns the number of PlayCaps in the allow list
  - `prune_allow_list(&mut BalanceManager, &BalanceManagerCap, ctx: &TxContext)` - removes all PlayCap IDs from the allow list (owner only)
  - `destroy_play_cap(PlayCap, ctx: &TxContext)` - destroys a PlayCap (works even if BalanceManager no longer exists)
  - `destroy_play_cap_and_revoke(PlayCap, &mut BalanceManager, ctx: &TxContext)` - destroys a PlayCap and removes it from allow list
- **Event Changes:**
  - All events now include address fields for tracking who performed the action:
    - `BalanceManagerCreatedEvent` - added `creator: address`
    - `DepositCompletedEvent` - added `depositor: address`
    - `WithdrawalProcessedEvent` - added `withdrawer: address`
    - `PlayCapMintedEvent` - added `minter: address`
    - `PlayCapRevokedEvent` - added `revoker: address`
- **Function Signature Changes:**
  - `revoke_play_cap()` - added `ctx: &TxContext` parameter
  - `destroy_empty()` - added `ctx: &TxContext` parameter
- **Minor Changes:**
  - Section comments updated: `Public-View Functions` → `View Functions`, `Public-Mutative Functions` → `Public Functions`
  - Added `// === Events ===` section comment

#### Registry (`registry.move`)
- **New Functions:**
  - `check_version()` - public function to verify package version is allowed (can block gameplay if version disabled)
- **New Events:**
  - `ProtocolFeeUpdatedEvent` - emitted when protocol fee is updated (includes `admin: address`)
  - `VersionAllowedEvent` - emitted when a package version is allowed (includes `admin: address`)
  - `VersionDisallowedEvent` - emitted when a package version is disallowed (includes `admin: address`)
  - `GameStatsInitializedEvent` - emitted when GameStatistics are initialized (includes `initializer: address`)
  - `HouseRegisteredEvent` - emitted when a House is registered (includes `registrar: address`)
- **New Error Codes:**
  - `EInvalidFeeConfiguration: u64 = 6` - when fee configuration is invalid (e.g., >= 100%)
- **Function Signature Changes:**
  - `register_house()` - added `ctx: &TxContext` parameter
  - `update_protocol_fee_bps()` - added `ctx: &TxContext` parameter, now validates fee < 100% and <= max_protocol_fee_bps
  - `admin_allow_version()` - added `ctx: &TxContext` parameter
  - `admin_disallow_version()` - added `ctx: &TxContext` parameter
- **Implementation Changes:**
  - `protocol_fee_bps()` no longer performs version check - use `check_version()` separately for gameplay operations
  - Added extensive documentation about version control strategy

#### Transaction (`transaction.move`)
- **New Constants:**
  - `MIN_TRANSACTION_AMOUNT: u64 = 100_000` (0.0001 SUI in MIST)
- **New Error Codes:**
  - `EAmountTooLow: u64 = 2` - when transaction amount is below minimum
- **New Functions:**
  - `min_transaction_amount(): u64` - returns the minimum transaction amount
  - `win_checked(amount: u64): Transaction` - creates win transaction with amount validation
  - `bet_checked(amount: u64): Transaction` - creates bet transaction with amount validation
- **Breaking Changes:**
  - `win()` and `bet()` functions are now `#[test_only]` - production code must use `win_checked()` and `bet_checked()`
- **Minor Changes:**
  - Section comments updated: `Public-View Functions` → `View Functions`, `Public-Mutative Functions` → `Public Functions`, added `Test Functions` section

#### Account (`state/account.move`)
- **New View Functions:**
  - `lifetime_total_bets(&Account): u64` - returns lifetime total bets
  - `lifetime_total_wins(&Account): u64` - returns lifetime total wins
  - `debit_balance(&Account): u64` - returns current debit balance
  - `credit_balance(&Account): u64` - returns current credit balance
- **Minor Changes:**
  - Section comments updated for consistency
  - Documentation improvements

### Changed

#### House (`house.move`)
- **BREAKING CHANGE - Struct Fields:**
  - Removed: `min_activation_balance: u64` - no longer needed (house always active)
  - Removed: `games_fee_bps: VecMap<ID, u64>` - per-game fee configuration
  - Removed: `tx_allow_listed: VecSet<ID>` - game allow list
  - Added: `game_fee_collectors: VecMap<ID, ID>` - maps game_id to fee_collector_id (combines allow list and fee assignment)
  - Added: `fee_collector_share_bps: u64` - fee collector share of GGR
- **BREAKING CHANGE - Function Signatures:**
  - `openplay_admin_new_house()` signature changed:
    - **Added:** `registry: &Registry` parameter (for protocol fee validation)
    - **Added:** `fee_collector_share_bps: u64` parameter
    - Vault initialization: `vault::empty(house_id, ctx)` → `vault::empty(house_id)` (removed ctx)
    - State initialization: `house_state::new(house_id, ctx)` → `house_state::new(house_id, protocol_fee_bps, house_fee_bps, fee_collector_share_bps, ctx)`
  - `admin_add_tx_allowed()` → `admin_add_tx_allowed_with_collector()` - now requires fee collector
  - `admin_revoke_tx_allowed()` signature changed:
    - Parameter: `game_id: &ID` → `game_id: ID` (takes ownership)
    - Event: `GameTransactionsRevokedEvent` → `GameTransactionsDisallowedEvent`
  - `admin_set_game_fee()` - REMOVED (replaced by fee collector system)
  - `admin_remove_game_fee()` - REMOVED (replaced by `admin_revoke_tx_allowed()`)
  - `admin_claim_house_fees()` → `openplay_admin_claim_protocol_fees()` - now claims protocol fees (house fees handled differently)
  - `claim_collector_fees()` - NEW function for claiming collector fees
  - `admin_claim_house_fees()` - added `registry: &Registry` parameter
  - `process_end_of_day()` signature changed:
    - **Added:** `registry: &Registry` parameter
    - **Changed:** `ctx: &TxContext` → `ctx: &mut TxContext`
    - Now gets protocol fee from registry and processes collector fees
- **BREAKING CHANGE - Removed Structs:**
  - `Fees` struct - REMOVED (fees are now GGR-based and handled at epoch end)
- **BREAKING CHANGE - Transaction Cap:**
  - `HouseTransactionCap` struct changed:
    - **Added:** `fee_collector_id: ID` field
  - `assert_valid_tx_cap()` now validates fee_collector_id matches game assignment
- **BREAKING CHANGE - Removed Functions:**
  - `stake()` - REMOVED (replaced by `buy_shares()`)
  - `unstake_v2()` - REMOVED (replaced by `sell_shares()`)
  - `claim_all()` - REMOVED (shares are sold directly, no claim needed)
  - `refresh()` - REMOVED (no longer needed in share model)
  - `refresh_with_limit()` - REMOVED (no longer needed in share model)
  - `update_participation()` - REMOVED (no longer needed in share model)
  - `update_participation_with_limit()` - REMOVED (no longer needed in share model)
  - `activate_if_possible()` - REMOVED (house always active)
  - `is_active()` - REMOVED (house always active)
  - `play_balance()` - REMOVED (replaced by `house_balance()`)
  - `reserve_balance()` - REMOVED (replaced by `house_balance()`)
  - `game_fee_bps()` - REMOVED (replaced by fee collector system)
  - `admin_set_game_fee()` - REMOVED (replaced by fee collector system)
  - `admin_remove_game_fee()` - REMOVED (replaced by `admin_revoke_tx_allowed()`)
  - `tx_admin_claim_game_fees()` - REMOVED (replaced by `claim_collector_fees()`)
- **Implementation Changes:**
  - `process_end_of_day()` - completely rewritten:
    - Now calculates fees from GGR (bet - win) at epoch end
    - Processes collector fees per fee collector based on their GGR
    - Moves fees to vault (collector fees, house fees, protocol fees)
    - No longer calculates profits/losses from balance differences
  - Fee calculation moved from per-transaction to epoch-end GGR-based
  - House is always active (no activation/deactivation logic)
  - Transaction processing now tracks fee collector GGR

#### Participation (`participation.move`)
- **BREAKING CHANGE - Complete Rewrite:**
  - Removed all stake-related fields: `stake`, `pending_stake`, `pending_unstake`, `claimable_balance`, `last_updated_epoch`
  - Now only tracks `shares: u64`
  - Reduced from ~370 lines to ~106 lines (simplified by ~70%)
- **BREAKING CHANGE - Removed Functions:**
  - `stake()` - REMOVED
  - `pending_stake()` - REMOVED
  - `claimable_balance()` - REMOVED
  - `pending_unstake()` - REMOVED
  - `last_updated_epoch()` - REMOVED
  - `add_stake()` - REMOVED (replaced by `add_shares()`)
  - `unstake_v2()` - REMOVED (replaced by `remove_shares()`)
  - `claim_all()` - REMOVED (shares sold directly)
  - `process_end_of_day()` - REMOVED (no longer needed in share model)
  - `current_state()` - REMOVED (no longer needed)
- **Removed Events:**
  - `ParticipationEndOfDayProcessedEvent` - REMOVED
  - `ClaimProcessedEvent` - REMOVED
- **Removed Error Codes:**
  - `EInvalidGgrShare` - REMOVED
  - `EEpochMismatch` - REMOVED
  - `EEpochHasNotFinishedYet` - REMOVED
  - `EInvalidProfitsOrLosses` - REMOVED
  - `ENotEnoughToUnstake` - REMOVED
  - `EActualizedUnstakeExceedsStake` - REMOVED

#### House State (`state/house_state.move`)
- **BREAKING CHANGE - Struct Fields:**
  - Removed: `is_active: bool` - house always active
  - Removed: `inactive_stake: u64` - no stake model
  - Removed: `active_stake: u64` - no stake model
  - Removed: `pending_unstake: u64` - no stake model
  - Removed: `active_history: Table<u64, bool>` - no activation tracking
  - Removed: `eod_history: Table<u64, EndOfDay>` - no end-of-day profit/loss tracking
  - Added: `total_shares: u64` - total shares in circulation
  - Added: `current_collector_ggr: VecMap<ID, CollectorGGR>` - fee collector GGR tracking
  - Added: `historic_collector_ggr: Table<u64, VecMap<ID, CollectorGGR>>` - historical GGR
  - Added: `current_epoch_protocol_fee_bps: u64` - protocol fee at epoch start
  - Added: `current_epoch_house_fee_bps: u64` - house fee at epoch start
  - Added: `current_epoch_fee_collector_share_bps: u64` - collector share at epoch start
- **BREAKING CHANGE - Struct Changes:**
  - `Volumes` struct changed:
    - Removed: `active_stake_amount: u64` field
- **BREAKING CHANGE - Function Signatures:**
  - `new()` signature changed:
    - **Added:** `house_id: ID`, `protocol_fee_bps: u64`, `house_fee_bps: u64`, `fee_collector_share_bps: u64` parameters
    - Removed all stake-related initialization
  - `process_transactions()` signature changed:
    - **Added:** `fee_collector_id: ID` parameter (for GGR tracking)
    - Now tracks GGR per fee collector
  - `process_end_of_day()` signature changed:
    - **Added:** `prev_epoch: u64`, `fee_collector_share_bps: u64`, `house_fee_bps: u64`, `protocol_fee_bps: u64` parameters
    - **Changed:** Return type from `()` to `(vector<CollectorFee>, u64, u64)` - returns collector fees, house fee, protocol fee
    - Now calculates fees from GGR instead of profits/losses
  - `process_volumes()` signature changed:
    - **Added:** `fee_collector_id: ID` parameter
- **BREAKING CHANGE - Removed Functions:**
  - `refresh()` - REMOVED (no participation updates needed)
  - `refresh_with_limit()` - REMOVED
  - `update_participation()` - REMOVED (no participation updates)
  - `maybe_activate()` - REMOVED (always active)
  - `activate()` - REMOVED (always active)
  - `desactivate()` - REMOVED (always active)
  - `epoch_active()` - REMOVED (always active)
  - `active_stake_at_epoch()` - REMOVED (no stake model)
  - `calculate_ggr_share()` - REMOVED (no GGR sharing in share model)
  - `add_stake()` - REMOVED
  - `remove_inactive_stake()` - REMOVED
  - `add_pending_unstake()` - REMOVED
  - `assert_active()` - REMOVED
- **Implementation Changes:**
  - `process_bet()` and `process_win()` now track GGR per fee collector
  - `process_end_of_day()` completely rewritten:
    - Calculates GGR per fee collector (bet - win)
    - Calculates collector fees from GGR
    - Calculates house fee from total GGR
    - Calculates protocol fee from total GGR
    - Captures fees at epoch start for next epoch
    - No longer processes profits/losses for participations
  - Removed all stake activation/deactivation logic
  - Removed all participation update logic
- **Removed Events:**
  - `HouseActivatedEvent` - REMOVED (house always active)
- **Removed Structs:**
  - `EndOfDay` - REMOVED (no longer tracking daily profits/losses for stake model)

#### Vault (`vault.move`)
- **BREAKING CHANGE - Struct Fields:**
  - Removed: `epoch: u64` - epoch tracking moved to state
  - Removed: `play_balance: Balance<SUI>` - replaced by `house_balance`
  - Removed: `reserve_balance: Balance<SUI>` - replaced by `house_balance`
  - Removed: `collected_game_fees: VecMap<ID, Balance<SUI>>` - replaced by `collected_collector_fees`
  - Added: `house_balance: Balance<SUI>` - single balance for all house funds
  - Added: `collected_collector_fees: VecMap<ID, Balance<SUI>>` - collector fees (keyed by fee_collector_id)
- **BREAKING CHANGE - Function Signatures:**
  - `empty()` signature changed:
    - **Added:** `house_id: ID` parameter
    - **Removed:** `ctx: &TxContext` parameter
    - Removed epoch initialization
  - `deposit()` - now deposits to `house_balance` instead of `reserve_balance`
  - `withdraw()` - now withdraws from `house_balance` instead of `reserve_balance`
  - `settle_balance_manager()` - now uses `house_balance` instead of `play_balance`
  - `process_protocol_fee()` - now uses `house_balance` instead of `play_balance`
  - `process_house_fee()` - now uses `house_balance` instead of `reserve_balance`
- **BREAKING CHANGE - Removed Functions:**
  - `process_end_of_day()` - REMOVED (moved to house/state)
  - `fund_play_balance()` - REMOVED (house always active)
  - `play_balance()` - REMOVED
  - `reserve_balance()` - REMOVED
  - `epoch()` - REMOVED
  - `collected_game_fees()` - REMOVED (replaced by `collected_collector_fees()`)
  - `withdraw_game_fees()` - REMOVED (replaced by `withdraw_collector_fees()`)
  - `process_game_fee()` - REMOVED (replaced by `process_collector_fee()`)
  - `ensure_game_fee_balance()` - REMOVED (replaced by `ensure_collector_fee_balance()`)
- **Removed Events:**
  - `PlayBalanceFundedEvent` - REMOVED
  - `PlayBalanceClearedEvent` - REMOVED
- **Removed Error Codes:**
  - `EGameDoesNotExist` - REMOVED (replaced by collector system)
- **Implementation Changes:**
  - All balance operations now use single `house_balance`
  - No epoch tracking or end-of-day processing
  - Collector fees tracked by fee_collector_id instead of game_id

#### Parameter Store (`parameter_store.move`)
- **Minor Changes:**
  - Section comments updated for consistency
  - Documentation improvements

### Functional Changes

#### Fee Calculation Model
- **BREAKING CHANGE:** Fees are now calculated from GGR (Gross Gaming Revenue = bet - win) at epoch end, not per transaction
- Collector fees are calculated per fee collector based on their GGR share
- All fees (collector, house, protocol) are calculated from total GGR and deducted from house balance
- Fees are captured at epoch start and used for the entire epoch (prevents mid-epoch fee changes affecting calculations)

#### Participation Model
- **BREAKING CHANGE:** Changed from stake-based to share-based model
- Users buy shares with funds (shares minted based on current NAV)
- Users sell shares to withdraw funds (proceeds = shares * NAV)
- No more staking/unstaking with epoch delays
- No more claimable balances - proceeds from selling shares are immediately available
- No more participation updates/refreshes needed

#### House Activation
- **BREAKING CHANGE:** Houses are now always active
- Removed activation/deactivation cycles
- Removed minimum activation balance requirement for gameplay
- Removed play/reserve balance separation
- Single house balance used for all operations

#### Game Whitelisting
- **BREAKING CHANGE:** Game whitelisting now requires assigning a fee collector
- `admin_add_tx_allowed_with_collector()` combines whitelisting and fee collector assignment
- Transaction caps now include `fee_collector_id` and validate it matches game assignment
- Removed per-game fee configuration (replaced by fee collector share)

#### Transaction Processing
- Transactions now track GGR per fee collector
- Fee collector GGR is accumulated during the epoch
- At epoch end, fees are calculated from GGR and distributed to collectors

### Removed

#### Stake-Based Participation System
- **Removed from Participation:**
  - All stake-related fields and functions
  - Epoch-based profit/loss sharing
  - Claimable balance system
  - Pending stake/unstake queues
- **Removed from House State:**
  - Activation/deactivation logic
  - Stake tracking (active/inactive/pending)
  - Participation update/refresh functions
  - GGR share calculations for participations
- **Removed from House:**
  - `stake()`, `unstake_v2()`, `claim_all()` functions
  - `refresh()`, `refresh_with_limit()`, `update_participation_with_limit()` functions
  - `activate_if_possible()` function
  - Activation-related events

#### Per-Game Fee System
- **Removed from House:**
  - `games_fee_bps: VecMap<ID, u64>` field
  - `admin_set_game_fee()` function
  - `admin_remove_game_fee()` function
  - `game_fee_bps()` getter function
- **Removed from Vault:**
  - `collected_game_fees: VecMap<ID, Balance<SUI>>` field
  - All game fee functions

#### Play/Reserve Balance System
- **Removed from Vault:**
  - `play_balance` and `reserve_balance` fields
  - `process_end_of_day()` function
  - `fund_play_balance()` function
  - All play/reserve balance operations

#### Calculations (`calculations.move`)
- **Removed Functions:**
  - `actualize_amount()` - REMOVED (no longer needed in share model; was used for stake profit/loss actualization)
- **Removed Error Codes:**
  - `ELossTooHigh` - REMOVED (no longer applicable)

---

## [v2.1] - Completed

### Added

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

#### Vault (`vault.move`)
- **New Struct Field:**
  - `collected_house_fees: Balance<SUI>` - balance for collected house performance fees
- **New Functions:**
  - `withdraw_house_fees(&mut Vault): Balance<SUI>` - withdraws all collected house fees
  - `process_house_fee(&mut Vault, house_fee: u64)` - processes and collects house fees from reserve balance

### Changed

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

