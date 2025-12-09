# OpenPlay Core - Comprehensive Test Plan for 100% Coverage

This document outlines all test cases needed to achieve 100% test coverage for the OpenPlay Core smart contract suite.

## Table of Contents
1. [balance_manager.move](#balance_manager)
2. [calculations.move](#calculations)
3. [core_constants.move](#core_constants)
4. [fee_collector.move](#fee_collector)
5. [game_stats.move](#game_stats)
6. [house.move](#house)
7. [parameter_store.move](#parameter_store)
8. [participation.move](#participation)
9. [registry.move](#registry)
10. [transaction.move](#transaction)
11. [vault.move](#vault)
12. [state/account.move](#account)
13. [state/house_state.move](#house_state)

---

## balance_manager.move

### View Functions
- [x] `id()` - Returns balance manager ID
- [x] `cap_id()` - Returns PlayCap ID
- [x] `cap_balance_manager_id()` - Returns BalanceManager ID from PlayCap
- [x] `proof_balance_manager_id()` - Returns BalanceManager ID from PlayProof
- [x] `player()` - Returns player address from PlayProof
- [x] `balance()` - Returns current balance
- [x] `allow_list_length()` - Returns number of PlayCaps in allow list

### Public Functions
- [x] `new()` - Creates new BalanceManager and BalanceManagerCap
  - Test: Creation emits BalanceManagerCreatedEvent
  - Test: Cap has correct balance_manager_id
- [x] `share()` - Shares the BalanceManager object
- [x] `mint_play_cap()` - Mints a new PlayCap
  - Test: Successfully mints PlayCap when under MAX_PLAY_CAPS
  - Test: Aborts with EMaxPlayCapsReached when at limit
  - Test: Only owner can mint
  - Test: Emits PlayCapMintedEvent
  - Test: PlayCap is added to allow list
- [x] `revoke_play_cap()` - Revokes a PlayCap
  - Test: Successfully revokes existing PlayCap
  - Test: Aborts with EPlayCapNotInList if not in list
  - Test: Only owner can revoke
  - Test: Emits PlayCapRevokedEvent
- [x] `prune_allow_list()` - Removes all PlayCaps from allow list
  - Test: Successfully prunes all PlayCaps
  - Test: Only owner can prune
  - Test: Emits PlayCapAllowListPrunedEvent with correct count
- [x] `destroy_play_cap()` - Destroys a PlayCap
  - Test: Successfully destroys PlayCap
  - Test: Works even if BalanceManager no longer exists
  - Test: Emits PlayCapDestroyedEvent
- [x] `destroy_play_cap_and_revoke()` - Destroys and revokes PlayCap
  - Test: Successfully destroys and revokes if in list
  - Test: Destroys even if not in list
  - Test: Aborts with EInvalidPlayer if wrong BalanceManager
  - Test: Emits both PlayCapRevokedEvent and PlayCapDestroyedEvent
- [x] `generate_proof_as_owner()` - Generates proof as owner
  - Test: Owner can generate proof
  - Test: Aborts with EInvalidOwner if invalid cap
- [x] `generate_proof_as_player()` - Generates proof as player
  - Test: Player with valid PlayCap can generate proof
  - Test: Aborts with EInvalidPlayer if PlayCap not in list
- [x] `deposit()` - Deposits funds (owner only)
  - Test: Owner can deposit
  - Test: Balance increases correctly
  - Test: Emits DepositCompletedEvent
- [x] `withdraw()` - Withdraws funds (owner only)
  - Test: Owner can withdraw
  - Test: Balance decreases correctly
  - Test: Aborts with EBalanceTooLow if insufficient funds
  - Test: Emits WithdrawalProcessedEvent
- [x] `withdraw_all()` - Withdraws all funds (owner only)
  - Test: Owner can withdraw all
  - Test: Balance becomes zero
  - Test: Emits WithdrawalProcessedEvent
- [x] `validate_proof()` - Validates a PlayProof
  - Test: Valid proof passes
  - Test: Invalid proof aborts with EInvalidProof
- [x] `destroy_empty()` - Destroys empty BalanceManager
  - Test: Successfully destroys when balance is zero
  - Test: Aborts with EBalanceNotEmpty if balance > 0
  - Test: Only owner can destroy
  - Test: Emits BalanceManagerDestroyedEvent

### Package Functions
- [x] `withdraw_with_proof()` - Withdraws with proof
  - Test: Valid proof allows withdrawal
  - Test: Invalid proof aborts
  - Test: Aborts with EBalanceTooLow if insufficient funds
- [x] `deposit_with_proof()` - Deposits with proof
  - Test: Valid proof allows deposit
  - Test: Invalid proof aborts
  - Test: Balance increases correctly
- [x] `ensure_sufficient_funds()` - Ensures sufficient funds
  - Test: Passes when balance >= amount
  - Test: Aborts with EBalanceTooLow when balance < amount

### Private Functions
- [x] `validate_owner()` - Validates owner cap
  - Test: Valid cap passes
  - Test: Invalid balance_manager_id aborts with EInvalidOwner
  - Test: Invalid cap_id aborts with EInvalidOwner
- [x] `validate_player()` - Validates player PlayCap
  - Test: Valid PlayCap in list passes
  - Test: PlayCap not in list aborts with EInvalidPlayer
- [x] `validate_balance_empty()` - Validates zero balance
  - Test: Zero balance passes
  - Test: Non-zero balance aborts with EBalanceNotEmpty

### Error Codes
- [x] EBalanceTooLow (1)
- [x] EInvalidOwner (2)
- [x] EInvalidPlayer (3)
- [x] EMaxPlayCapsReached (4)
- [x] EPlayCapNotInList (5)
- [x] EInvalidProof (6)
- [x] EBalanceNotEmpty (7)

---

## calculations.move

### Public Functions
- [x] `mul_floor()` - Multiplies with floor rounding
  - Test: Basic multiplication (100 * 50 / 100 = 50)
  - Test: Floor rounding (100 * 33 / 100 = 33, not 33.33)
  - Test: Division by zero aborts with EDivisionByZero
  - Test: Overflow detection (large values)
  - Test: Edge case: val = 0
  - Test: Edge case: numerator = 0
  - Test: Edge case: denominator = 1
  - Test: Large numbers that don't overflow
  - Test: Numbers that would overflow u64 but fit in u128
- [x] `mul_ceil()` - Multiplies with ceiling rounding
  - Test: Basic multiplication (100 * 50 / 100 = 50)
  - Test: Ceiling rounding (100 * 33 / 100 = 34)
  - Test: Division by zero aborts with EDivisionByZero
  - Test: Overflow detection
  - Test: Edge case: val = 0
  - Test: Edge case: numerator = 0
  - Test: Edge case: denominator = 1
  - Test: Exact division (no rounding needed)
  - Test: Rounding up by 1
- [x] `mul_floor_bps()` - Floor multiplication with basis points
  - Test: 1% fee (100 bps) on 1000 = 10
  - Test: Floor rounding behavior
  - Test: 0 bps returns 0
  - Test: 10000 bps (100%) returns full amount
  - Test: Edge cases
- [x] `mul_ceil_bps()` - Ceiling multiplication with basis points
  - Test: 1% fee (100 bps) on 1000 = 10
  - Test: Ceiling rounding behavior
  - Test: 0 bps returns 0
  - Test: 10000 bps (100%) returns full amount
  - Test: Edge cases

### Error Codes
- [x] EOverflow (2)
- [x] EDivisionByZero (3)

---

## core_constants.move

### Public Functions
- [x] `max_bps()` - Returns 10000
- [x] `tx_type_bet()` - Returns "Bet" string
- [x] `tx_type_win()` - Returns "Win" string
- [x] `current_version()` - Returns CURRENT_VERSION (1)
- [x] `max_protocol_fee_bps()` - Returns 2000 (20%)
- [x] `max_house_and_collector_fees_bps()` - Returns 5000 (50%)

**Note**: These are simple constant functions. Each should have at least one test verifying the return value.

---

## fee_collector.move

### View Functions
- [x] `id()` - Returns FeeCollector ID
- [x] `house_id()` - Returns house ID
- [x] `cap_fee_collector_id()` - Returns fee collector ID from cap

### Public Functions
- [x] `share()` - Shares the FeeCollector

### Package Functions
- [x] `new()` - Creates new FeeCollector and cap
  - Test: Creates with correct house_id
  - Test: Cap has correct fee_collector_id
  - Test: Emits FeeCollectorCreatedEvent
- [x] `assert_valid_cap()` - Validates cap
  - Test: Valid cap passes
  - Test: Invalid fee_collector_id aborts with EInvalidCap
  - Test: Invalid cap_id aborts with EInvalidCap

### Error Codes
- [x] EInvalidCap (1)

---

## game_stats.move

### View Functions
- [x] `game_id()` - Returns game ID
- [x] `id()` - Returns GameStatistics ID
- [x] `current_volumes()` - Returns current epoch volumes
- [x] `all_time_volumes()` - Returns all-time volumes
- [x] `historic_volumes()` - Returns historic volumes for epoch
  - Test: Returns volumes for existing epoch
  - Test: Aborts with EEpochNotFound for non-existent epoch
- [x] `bet_sum()` - Returns bet sum from volumes
- [x] `bet_count()` - Returns bet count from volumes
- [x] `win_sum()` - Returns win sum from volumes
- [x] `win_count()` - Returns win count from volumes

### Public Functions
- [x] `share()` - Shares the GameStatistics object

### Package Functions
- [x] `new()` - Creates new GameStatistics
  - Test: Initializes with zero volumes
  - Test: Sets current epoch correctly
- [x] `process_transactions()` - Processes transactions
  - Test: Processes bet transactions
  - Test: Processes win transactions
  - Test: Updates current volumes
  - Test: Updates all-time volumes
  - Test: Handles epoch change
  - Test: Saves previous epoch to historic volumes
  - Test: Resets current volumes on epoch change
  - Test: Zero win amount is skipped (doesn't count as win)
  - Test: Aborts with EUnknownTransaction for invalid transaction type

### Private Functions
- [x] `update_epoch()` - Updates epoch
  - Test: Updates when epoch changes
  - Test: Saves current volumes to history
  - Test: Resets current volumes
  - Test: No-op when epoch unchanged
- [x] `new_volumes()` - Creates empty volumes
- [x] `process_bet()` - Processes bet
  - Test: Updates bet_count and bet_sum
  - Test: Updates both current and all-time volumes
- [x] `process_win()` - Processes win
  - Test: Updates win_count and win_sum
  - Test: Updates both current and all-time volumes
  - Test: Skips zero amount wins

### Error Codes
- [x] EUnknownTransaction (1)
- [x] EEpochNotFound (2)

---

## house.move

### View Functions
- [x] `id()` - Returns House ID
- [x] `private()` - Returns private flag
- [x] `game_fee_collector()` - Returns fee collector for game
  - Test: Returns fee collector for whitelisted game
  - Test: Aborts with EGameDoesNotExist for non-whitelisted game
- [x] `house_fee_bps()` - Returns house fee
- [x] `house_balance()` - Returns house balance
- [x] `nav_per_share()` - Calculates NAV per share
  - Test: Returns INITIAL_NAV when no shares exist
  - Test: Calculates correctly with shares
  - Test: Accounts for pending fees
  - Test: Handles zero effective value
  - Test: Handles effective value < total_pending_fees
- [x] `admin_cap_house_id()` - Returns house ID from admin cap
- [x] `transaction_cap_house_id()` - Returns house ID from tx cap

### Public Functions
- [x] `share()` - Shares house and registers with registry
  - Test: Registers house in registry
  - Test: Shares the house object
- [x] `ensure_sufficient_funds()` - Ensures sufficient funds
  - Test: Passes when balance >= amount
  - Test: Aborts with EInsufficientFunds when balance < amount
- [x] `new_participation()` - Creates new participation (public)
  - Test: Creates participation for public house
  - Test: Aborts with EHouseIsPrivate for private house
- [x] `buy_shares()` - Buys shares
  - Test: Calculates shares correctly (1:1 when no shares)
  - Test: Calculates shares based on NAV
  - Test: Uses mul_floor for rounding
  - Test: Updates participation shares
  - Test: Updates total shares
  - Test: Deposits funds to vault
  - Test: Processes end of day before calculation
  - Test: Aborts with EInvalidAmount for zero deposit
  - Test: Aborts with EInvalidAmount when effective_value = 0
  - Test: Aborts with EInvalidAmount when shares_to_mint = 0
  - Test: Emits SharesPurchasedEvent
- [x] `sell_shares()` - Sells shares
  - Test: Calculates payout correctly
  - Test: Uses mul_floor for rounding
  - Test: Updates participation shares
  - Test: Updates total shares
  - Test: Withdraws from vault
  - Test: Processes end of day before calculation
  - Test: Aborts with ENotEnoughShares if insufficient shares
  - Test: Aborts with EInvalidAmount when total_shares = 0
  - Test: Emits SharesSoldEvent
- [x] `borrow_tx_cap()` - Borrows transaction cap
  - Test: Returns cap for whitelisted game
  - Test: Aborts with EUnauthorizedGameId for non-whitelisted game

### Admin Functions
- [x] `tx_admin_process_transactions_v2()` - Processes transactions
  - Test: Processes bet transactions
  - Test: Processes win transactions
  - Test: Validates transaction cap
  - Test: Validates game stats match
  - Test: Validates play cap
  - Test: Processes end of day
  - Test: Settles balances correctly
  - Test: Updates game stats
  - Test: Emits SettlementEvent
  - Test: Emits TransactionsProcessedEvent
  - Test: Version check (aborts if version disabled)
  - Test: Aborts with EInvalidGameStats if stats don't match
  - Test: Aborts with EInvalidTxCap for invalid cap
- [x] `tx_admin_process_transactions_v2_no_bm()` - Processes without balance manager
  - Test: Creates temporary balance manager
  - Test: Processes transactions
  - Test: Returns remaining funds
  - Test: Destroys temporary balance manager
  - Test: All same validations as v2
- [x] `admin_claim_house_fees()` - Claims house fees
  - Test: Claims all collected house fees
  - Test: Processes end of day first
  - Test: Only admin can claim
  - Test: Emits HouseFeesClaimedEvent
- [x] `admin_create_fee_collector()` - Creates fee collector
  - Test: Creates fee collector
  - Test: Only admin can create
- [x] `admin_add_tx_allowed_with_collector()` - Whitelists game
  - Test: Whitelists game with fee collector
  - Test: Validates fee collector belongs to house
  - Test: Aborts with EMaxGamesReached at limit
  - Test: Updates existing game (no error if already exists)
  - Test: Only admin can whitelist
  - Test: Emits GameTransactionsAllowedEvent
- [x] `admin_revoke_tx_allowed()` - Revokes game authorization
  - Test: Removes game from allow list
  - Test: Aborts with EGameDoesNotExist if not whitelisted
  - Test: Only admin can revoke
  - Test: Emits GameTransactionsDisallowedEvent
- [x] `claim_collector_fees()` - Claims collector fees
  - Test: Claims fees for fee collector
  - Test: Validates fee collector belongs to house
  - Test: Validates cap
  - Test: Processes end of day first
  - Test: Returns zero balance if no fees
  - Test: Emits CollectorFeesClaimedEvent
- [x] `admin_update_fees()` - Updates fees
  - Test: Updates house fee
  - Test: Updates collector share
  - Test: Validates house_fee_bps < max_bps
  - Test: Validates fee_collector_share_bps < max_bps
  - Test: Validates sum <= max_house_and_collector_fees_bps
  - Test: Only admin can update
  - Test: Emits HouseFeesUpdatedEvent
- [x] `admin_new_participation()` - Creates participation (admin)
  - Test: Creates participation for private house
  - Test: Only admin can create
  - Test: Works for public house too

### Package Functions
- [x] `openplay_admin_new_house()` - Creates new house
  - Test: Creates house with correct configuration
  - Test: Validates house_fee_bps < max_bps
  - Test: Validates fee_collector_share_bps < max_bps
  - Test: Validates sum <= max_house_and_collector_fees_bps
  - Test: Validates protocol_fee_bps <= max_protocol_fee_bps
  - Test: Creates admin cap
  - Test: Emits HouseCreatedEvent
- [x] `openplay_admin_claim_protocol_fees()` - Claims protocol fees
  - Test: Claims all protocol fees
  - Test: Only OpenPlay admin can claim
  - Test: Emits ProtocolFeesClaimedEvent

### Private Functions
- [x] `process_end_of_day()` - Processes end of day
  - Test: Processes when epoch changes
  - Test: No-op when epoch unchanged
  - Test: Calculates fees from GGR
  - Test: Moves collector fees to vault
  - Test: Moves house fees to vault
  - Test: Moves protocol fees to vault
  - Test: Emits HouseFeeProcessedEvent
  - Test: Emits ProtocolFeesProcessedEvent
  - Test: Handles multiple epochs skipped
- [x] `assert_valid_admin_cap()` - Validates admin cap
  - Test: Valid cap passes
  - Test: Invalid cap aborts with EInvalidAdminCap
- [x] `assert_valid_tx_cap()` - Validates transaction cap
  - Test: Valid cap passes
  - Test: Invalid house_id aborts with EInvalidTxCap
  - Test: Game not whitelisted aborts with EInvalidTxCap
  - Test: Fee collector mismatch aborts with EInvalidFeeCollector
- [x] `assert_valid_participation()` - Validates participation
  - Test: Valid participation passes
  - Test: Invalid participation aborts with EInvalidParticipation
- [x] `assert_not_private()` - Asserts house is not private
  - Test: Public house passes
  - Test: Private house aborts with EHouseIsPrivate

### Error Codes
- [x] EInsufficientFunds (1)
- [x] EInvalidTxCap (2)
- [x] EInvalidParticipation (3)
- [x] EHouseIsPrivate (6)
- [x] EInvalidAdminCap (9)
- [x] EInvalidFeeConfiguration (10)
- [x] EUnauthorizedGameId (11)
- [x] EInvalidGameStats (13)
- [x] EMaxGamesReached (14)
- [x] EGameDoesNotExist (16)
- [x] EInvalidFeeCollector (17)
- [x] EProtocolFeeTooHigh (18)
- [x] EHouseAndCollectorFeesTooHigh (19)
- [x] ENotEnoughShares (20)
- [x] EInvalidAmount (21)

---

## parameter_store.move

### View Functions
- [x] `id()` - Returns ParameterStore ID

### Public Functions
- [x] `new()` - Creates new ParameterStore
- [x] `freeze_()` - Freezes ParameterStore
  - Test: Freezes successfully
  - Test: Cannot add after freezing
- [x] `add()` - Adds key-value pair
  - Test: Adds successfully
  - Test: Aborts with EFieldAlreadyExists if key exists
- [x] `borrow()` - Borrows value
  - Test: Returns value for existing key
  - Test: Aborts with EFieldDoesNotExist if key doesn't exist
  - Test: Aborts with EFieldTypeMismatch if type wrong

---

## participation.move

### View Functions
- [x] `shares()` - Returns number of shares
- [x] `house_id()` - Returns house ID
- [x] `id()` - Returns participation ID

### Public Functions
- [x] `destroy_empty()` - Destroys empty participation
  - Test: Destroys when shares = 0
  - Test: Aborts with ENotEmpty if shares > 0
  - Test: Emits ParticipationRemovedEvent

### Package Functions
- [x] `empty()` - Creates empty participation
  - Test: Creates with zero shares
  - Test: Sets house_id correctly
  - Test: Emits ParticipationCreatedEvent
- [x] `add_shares()` - Adds shares
  - Test: Increases shares correctly
- [x] `remove_shares()` - Removes shares
  - Test: Decreases shares correctly
  - Test: Aborts with ENotEnoughShares if insufficient

### Error Codes
- [x] ENotEmpty (6)
- [x] ENotEnoughShares (7)

---

## registry.move

### View Functions
- [x] `check_version()` - Checks version
  - Test: Passes when version allowed
  - Test: Aborts with EPackageVersionDisabled when disabled
- [x] `protocol_fee_bps()` - Returns protocol fee
- [x] `game_stats_id()` - Returns game stats ID
  - Test: Returns ID for registered game
  - Test: Aborts with EStatsNotAvailable for unregistered game

### Public Functions
- [x] `init_stats()` - Initializes game stats
  - Test: Creates and registers stats
  - Test: Aborts with EStatsAlreadyCreated if exists
  - Test: Emits GameStatsInitializedEvent

### Admin Functions
- [x] `update_protocol_fee_bps()` - Updates protocol fee
  - Test: Updates fee
  - Test: Validates fee < max_bps
  - Test: Validates fee <= max_protocol_fee_bps
  - Test: Only admin can update
  - Test: Emits ProtocolFeeUpdatedEvent
- [x] `admin_allow_version()` - Allows version
  - Test: Allows version
  - Test: Aborts with EVersionAlreadyAllowed if already allowed
  - Test: Only admin can allow
  - Test: Emits VersionAllowedEvent
- [x] `admin_disallow_version()` - Disallows version
  - Test: Disallows version
  - Test: Aborts with EVersionAlreadyDisabled if not allowed
  - Test: Only admin can disallow
  - Test: Emits VersionDisallowedEvent

### Package Functions
- [x] `register_house()` - Registers house
  - Test: Registers house
  - Test: Validates version
  - Test: Emits HouseRegisteredEvent

### Private Functions
- [x] `init()` - Initializes registry
  - Test: Creates registry with current version allowed
  - Test: Sets default protocol fee
  - Test: Creates admin cap
- [x] `assert_version()` - Asserts version allowed
  - Test: Passes when allowed
  - Test: Aborts when disabled

### Error Codes
- [x] EPackageVersionDisabled (1)
- [x] EVersionAlreadyAllowed (2)
- [x] EVersionAlreadyDisabled (3)
- [x] EStatsAlreadyCreated (4)
- [x] EStatsNotAvailable (5)
- [x] EInvalidFeeConfiguration (6)

---

## transaction.move

### View Functions
- [x] `amount()` - Returns transaction amount
- [x] `min_transaction_amount()` - Returns minimum amount
- [x] `is_credit()` - Returns true for win transactions
  - Test: Returns true for win
  - Test: Returns false for bet
  - Test: Aborts with EUnknownTxType for invalid type
- [x] `is_debit()` - Returns true for bet transactions
  - Test: Returns true for bet
  - Test: Returns false for win
  - Test: Aborts with EUnknownTxType for invalid type

### Public Functions
- [x] `win_checked()` - Creates win transaction
  - Test: Creates with valid amount
  - Test: Aborts with EAmountTooLow if amount < MIN_TRANSACTION_AMOUNT
- [x] `bet_checked()` - Creates bet transaction
  - Test: Creates with valid amount
  - Test: Aborts with EAmountTooLow if amount < MIN_TRANSACTION_AMOUNT

### Test Functions
- [x] `win()` - Test-only win creation
- [x] `bet()` - Test-only bet creation

### Error Codes
- [x] EUnknownTxType (1)
- [x] EAmountTooLow (2)

---

## vault.move

### View Functions
- [x] `house_balance()` - Returns house balance
- [x] `collected_protocol_fees()` - Returns protocol fees
- [x] `collected_collector_fees()` - Returns collector fees
  - Test: Returns fees for existing collector
  - Test: Returns 0 for non-existent collector

### Package Functions
- [x] `empty()` - Creates empty vault
- [x] `deposit()` - Deposits to house balance
- [x] `withdraw()` - Withdraws from house balance
  - Test: Withdraws successfully
  - Test: Aborts with EInsufficientFunds if insufficient
- [x] `withdraw_protocol_fees()` - Withdraws protocol fees
- [x] `withdraw_house_fees()` - Withdraws house fees
- [x] `process_house_fee()` - Processes house fee
  - Test: Moves fee from house balance to collected
  - Test: No-op if fee = 0
  - Test: Aborts with EInsufficientFunds if insufficient
- [x] `process_collector_fee()` - Processes collector fee
  - Test: Moves fee from house balance to collected
  - Test: Creates collector balance if doesn't exist
  - Test: No-op if amount = 0
  - Test: Aborts with EInsufficientFunds if insufficient
- [x] `withdraw_collector_fees()` - Withdraws collector fees
  - Test: Withdraws all fees for collector
  - Test: Returns zero balance if no fees
- [x] `settle_balance_manager()` - Settles balances
  - Test: amount_out > amount_in: vault pays difference
  - Test: amount_in > amount_out: balance manager pays difference
  - Test: amount_out == amount_in: no transfer
  - Test: Validates sufficient funds in balance manager
  - Test: Validates sufficient funds in vault when needed
- [x] `process_protocol_fee()` - Processes protocol fee
  - Test: Moves fee from house balance to collected
  - Test: No-op if fee = 0
  - Test: Aborts with EInsufficientFunds if insufficient

### Private Functions
- [x] `ensure_collector_fee_balance()` - Ensures collector balance exists
  - Test: Creates balance if doesn't exist
  - Test: No-op if exists

### Error Codes
- [x] EInsufficientFunds (1)

---

## state/account.move

### Package Functions
- [x] `empty()` - Creates empty account
- [x] `settle()` - Settles and resets balances
  - Test: Returns (credit, debit)
  - Test: Resets balances to zero
- [x] `credit()` - Adds credit
  - Test: Increases credit_balance
- [x] `debit()` - Adds debit
  - Test: Increases debit_balance

### Private Functions
- [x] `reset_balances()` - Resets balances
  - Test: Sets both to zero

---

## state/house_state.move

### View Functions
- [x] `epoch()` - Returns current epoch
- [x] `volume_for_epoch()` - Returns volumes for epoch
  - Test: Returns volumes for existing epoch
  - Test: Aborts with EVolumeNotAvailable for non-existent epoch
- [x] `all_time_bet_amount()` - Returns all-time bet amount
- [x] `all_time_win_amount()` - Returns all-time win amount
- [x] `all_time_profits()` - Returns all-time profits
- [x] `all_time_losses()` - Returns all-time losses
- [x] `total_bet_amount()` - Returns bet amount from volumes
- [x] `total_win_amount()` - Returns win amount from volumes
- [x] `current_volumes()` - Returns current volumes
- [x] `total_shares()` - Returns total shares
- [x] `current_collector_ggr()` - Returns collector GGR
  - Test: Returns GGR for existing collector
  - Test: Returns empty GGR for non-existent collector
- [x] `historic_collector_ggr()` - Returns historic collector GGR
  - Test: Returns GGR for existing epoch and collector
  - Test: Returns empty GGR for non-existent epoch
  - Test: Returns empty GGR for non-existent collector

### Package Functions
- [x] `process_transactions()` - Processes transactions
  - Test: Processes bets and wins
  - Test: Updates account balances
  - Test: Updates volumes
  - Test: Updates collector GGR
  - Test: Returns (credit, debit)
  - Test: Aborts with EEpochMismatch if epoch wrong
- [x] `mint_shares()` - Mints shares
  - Test: Increases total_shares
- [x] `burn_shares()` - Burns shares
  - Test: Decreases total_shares
  - Test: Aborts with ECannotUnstakeMoreThanStaked if insufficient
- [x] `calculate_pending_collector_fees()` - Calculates pending collector fees
  - Test: Calculates for all collectors
  - Test: Uses mul_ceil_bps
  - Test: Returns 0 if no GGR
  - Test: Handles multiple collectors
- [x] `calculate_pending_house_fees()` - Calculates pending house fees
  - Test: Calculates from GGR
  - Test: Returns 0 if no GGR
  - Test: Returns 0 if house_fee_bps = 0
  - Test: Uses mul_ceil_bps
- [x] `calculate_pending_protocol_fees()` - Calculates pending protocol fees
  - Test: Calculates from GGR
  - Test: Returns 0 if no GGR
  - Test: Returns 0 if protocol_fee_bps = 0
  - Test: Uses mul_ceil_bps
- [x] `calculate_total_pending_fees()` - Calculates total pending fees
  - Test: Sums all fees
  - Test: Returns 0 if no GGR
  - Test: Uses mul_ceil_bps with total fee bps
- [x] `process_collector_end_of_day()` - Processes collector end of day
  - Test: Calculates fees for all collectors
  - Test: Saves GGR to history
  - Test: Resets current GGR
  - Test: Returns vector of CollectorFee
  - Test: Handles collectors with no GGR
- [x] `process_end_of_day()` - Processes end of day
  - Test: Calculates GGR from volumes
  - Test: Calculates profits and losses
  - Test: Calculates all fees
  - Test: Saves volumes to history
  - Test: Resets current volumes
  - Test: Updates all-time statistics
  - Test: Updates epoch
  - Test: Captures new epoch fees
  - Test: Aborts with EEpochHasNotFinishedYet if epoch not finished
  - Test: Aborts with EEpochMismatch if epoch wrong
  - Test: Emits StateEndOfDayProcessedEvent
  - Test: Handles multiple epochs
- [x] `new()` - Creates new state
  - Test: Initializes with zero values
  - Test: Sets current epoch
  - Test: Captures fees for first epoch

### Private Functions
- [x] `update_account()` - Updates account
  - Test: Creates account if doesn't exist
  - Test: No-op if exists
- [x] `process_transactions_for_account()` - Processes transactions for account
  - Test: Credits wins
  - Test: Debits bets
  - Test: Aborts with EUnknownTransaction for invalid type
- [x] `process_volumes()` - Processes volumes
  - Test: Updates volumes for bets
  - Test: Updates volumes for wins
  - Test: Updates collector GGR
  - Test: Aborts with EUnknownTransaction for invalid type
- [x] `process_bet()` - Processes bet
  - Test: Updates current volumes
  - Test: Updates all-time bet amount
  - Test: Updates collector GGR
- [x] `process_win()` - Processes win
  - Test: Updates current volumes
  - Test: Updates all-time win amount
  - Test: Updates collector GGR
- [x] `update_collector_ggr_bet()` - Updates collector GGR bet
  - Test: Creates collector if doesn't exist
  - Test: Updates bet_amount
- [x] `update_collector_ggr_win()` - Updates collector GGR win
  - Test: Creates collector if doesn't exist
  - Test: Updates win_amount
- [x] `new_volumes()` - Creates empty volumes
- [x] `assert_epoch_up_to_date()` - Asserts epoch matches
  - Test: Passes when epoch matches
  - Test: Aborts with EEpochMismatch when doesn't match

### Error Codes
- [x] EUnknownTransaction (1)
- [x] EEpochMismatch (2)
- [x] ECannotUnstakeMoreThanStaked (3)
- [x] EEpochHasNotFinishedYet (5)
- [x] EVolumeNotAvailable (6)

---

## Test Coverage Summary

### Modules Coverage Status
- ✅ balance_manager.move - Comprehensive tests needed
- ✅ calculations.move - Comprehensive tests needed
- ⚠️ core_constants.move - Simple constant tests needed
- ⚠️ fee_collector.move - Basic tests needed
- ⚠️ game_stats.move - Comprehensive tests needed
- ✅ house.move - Extensive tests needed (largest module)
- ⚠️ parameter_store.move - Basic tests needed
- ✅ participation.move - Basic tests needed
- ✅ registry.move - Comprehensive tests needed
- ✅ transaction.move - Basic tests needed
- ✅ vault.move - Comprehensive tests needed
- ⚠️ state/account.move - Basic tests needed
- ✅ state/house_state.move - Comprehensive tests needed

### Priority Areas
1. **house.move** - Most complex module, needs extensive testing
2. **state/house_state.move** - Complex state management
3. **calculations.move** - Critical for financial correctness
4. **balance_manager.move** - Core security component
5. **vault.move** - Fund management critical

### Test Execution Strategy
1. Run existing tests to establish baseline
2. Add missing test cases systematically
3. Use code coverage tools to verify 100% coverage
4. Focus on edge cases and error paths
5. Test all error codes are reachable
6. Test all events are emitted correctly
7. Test all view functions return correct values

---

## Next Steps

1. Review existing test files to identify gaps
2. Create test cases for each unchecked item above
3. Ensure all error codes are tested
4. Ensure all events are tested
5. Test edge cases (zero values, max values, overflow conditions)
6. Test access control (owner-only, admin-only functions)
7. Run coverage analysis to verify 100% coverage
8. Document any untestable code paths (if any)

