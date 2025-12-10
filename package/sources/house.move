/// House is responsible for processing and settling transactions between the vault and balance manager.
/// Manages fee distribution using a GGR-based model where all fees (protocol, house, collector) are calculated
/// from Gross Gaming Revenue (bet_amount - win_amount) at epoch end.
module openplay_core::house;

use openplay_core::balance_manager::{Self, BalanceManager, PlayCap};
use openplay_core::calculations::mul_floor;
use openplay_core::core_constants::{
    max_bps,
    max_house_and_collector_fees_bps,
    max_protocol_fee_bps
};
use openplay_core::fee_collector::{Self, FeeCollector, FeeCollectorCap};
use openplay_core::game_stats::GameStatistics;
use openplay_core::house_state::{Self, State, collector_id, fee_amount};
use openplay_core::participation::{Self, Participation};
use openplay_core::registry::{Registry, OpenPlayAdminCap};
use openplay_core::transaction::Transaction;
use openplay_core::vault::{Self, Vault};
use sui::coin::Coin;
use sui::event::emit;
use sui::sui::SUI;
use sui::transfer::share_object;
use sui::vec_map::{Self, VecMap};

// === Errors ===
const EInsufficientFunds: u64 = 1;
const EInvalidTxCap: u64 = 2;
const EInvalidParticipation: u64 = 3;
const EHouseIsPrivate: u64 = 6;
const EInvalidAdminCap: u64 = 9;
const EInvalidFeeConfiguration: u64 = 10;
const EUnauthorizedGameId: u64 = 11;
const EInvalidGameStats: u64 = 13;
const EMaxGamesReached: u64 = 14;
const EGameDoesNotExist: u64 = 16;
const EInvalidFeeCollector: u64 = 17;
const EProtocolFeeTooHigh: u64 = 18; // Protocol fee cannot exceed 20%
const EHouseAndCollectorFeesTooHigh: u64 = 19; // House fee + collector fee cannot exceed 50%
const ENotEnoughShares: u64 = 20; // Not enough shares to sell
const EInvalidAmount: u64 = 21; // Invalid amount (e.g., deposit with zero shares)

// === Constants ===
const MAX_GAMES: u64 = 500;

// === Structs ===
/// One-time witness type for the House module.
public struct HOUSE has drop {}

/// Main House object that processes and settles transactions between the vault and balance managers.
/// Manages fee distribution, staking participation, and game authorization.
public struct House has key {
    id: UID,
    admin_cap_id: ID,
    private: bool, // Staking becomes an admin-only function
    min_activation_balance: u64,
    house_fee_bps: u64, // Performance fee taken from GGR (in basis points)
    fee_collector_share_bps: u64, // Fee collector share of GGR (in basis points)
    game_fee_collectors: VecMap<ID, ID>, // game_id -> fee_collector_id (also serves as allow list)
    // Internal props
    vault: Vault,
    state: State,
}

/// Capability object that grants administrative access to a House.
/// Allows configuration changes like fee settings and game authorization.
public struct HouseAdminCap has key, store {
    id: UID,
    house_id: ID,
}

/// Capability object that authorizes a specific game to execute transactions on a House.
/// Created by borrowing from the House's transaction allow list.
/// Includes the fee collector ID for GGR attribution.
public struct HouseTransactionCap {
    house_id: ID,
    game_id: ID,
    fee_collector_id: ID, // Fee collector for GGR attribution
}

// === Events ===
/// Event emitted when a new House is created.
public struct HouseCreatedEvent has copy, drop {
    house_id: ID,
    admin_cap_id: ID,
    private: bool, // Whether the house is private (admin-only staking)
    min_activation_balance: u64, // Minimum activation balance
    house_fee_bps: u64, // House performance fee in basis points
    fee_collector_share_bps: u64, // Fee collector share in basis points
}

/// Event emitted when transactions are processed by a game.
public struct TransactionsProcessedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
    balance_manager_id: ID,
    fee_collector_id: ID, // Fee collector for GGR attribution
    epoch: u64, // Epoch when transactions were processed
    transactions: vector<Transaction>,
}

/// Event emitted when a game is authorized to execute transactions.
public struct GameTransactionsAllowedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
    fee_collector_id: ID, // Fee collector assigned to this game
}

/// Event emitted when protocol fees are claimed by the OpenPlay admin.
public struct ProtocolFeesClaimedEvent has copy, drop {
    house_id: ID,
    amount: u64,
    epoch: u64, // Epoch when fees were claimed
}

/// Event emitted when protocol fees are processed at end of day.
public struct ProtocolFeesProcessedEvent has copy, drop {
    house_id: ID,
    amount: u64,
    epoch: u64, // Epoch for which fees were processed
}

/// Event emitted when house fees (performance fees) are claimed by the house admin.
public struct HouseFeesClaimedEvent has copy, drop {
    house_id: ID,
    amount: u64,
    epoch: u64, // Epoch when fees were claimed
}

/// Event emitted when house fees and collector share are updated.
public struct HouseFeesUpdatedEvent has copy, drop {
    house_id: ID,
    old_house_fee_bps: u64, // Previous house fee in basis points
    new_house_fee_bps: u64, // New house fee in basis points
    old_fee_collector_share_bps: u64, // Previous collector share in basis points
    new_fee_collector_share_bps: u64, // New collector share in basis points
}

/// Event emitted when shares are purchased.
public struct SharesPurchasedEvent has copy, drop {
    house_id: ID,
    participation_id: ID,
    player: address, // Address of the player purchasing shares
    shares: u64, // Shares purchased in this transaction
    amount: u64, // Amount deposited (MIST)
    effective_house_balance: u64, // Effective house balance at time of purchase
    total_shares: u64, // Total shares in circulation after purchase
    epoch: u64, // Epoch when shares were purchased
}

/// Event emitted when shares are sold.
public struct SharesSoldEvent has copy, drop {
    house_id: ID,
    participation_id: ID,
    player: address, // Address of the player selling shares
    shares: u64, // Shares sold in this transaction
    payout: u64, // Amount received (MIST)
    effective_house_balance: u64, // Effective house balance at time of sale
    total_shares: u64, // Total shares in circulation after sale
    epoch: u64, // Epoch when shares were sold
}

/// Event emitted when balances are settled between the vault and a balance manager.
public struct SettlementEvent has copy, drop {
    house_id: ID,
    game_id: ID, // Game that triggered the settlement
    balance_manager_id: ID,
    fee_collector_id: ID, // Fee collector for GGR attribution
    amount_in: u64, // Amount debited from balance manager
    amount_out: u64, // Amount credited to balance manager
    epoch: u64, // Epoch when settlement occurred
}

/// Event emitted when the performance fee of the house is processed.
public struct HouseFeeProcessedEvent has copy, drop {
    house_id: ID,
    amount: u64,
    epoch: u64, // Epoch for which fees were processed
}

/// Event emitted when collector fees are claimed.
public struct CollectorFeesClaimedEvent has copy, drop {
    house_id: ID,
    fee_collector_id: ID,
    amount: u64,
    epoch: u64, // Epoch when fees were claimed
}

/// Event emitted when a game is removed from the allow list (game authorization revoked).
public struct GameTransactionsDisallowedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
    fee_collector_id: ID, // Fee collector that was previously assigned
}

// === View Functions ===
/// Returns the ID of the House.
public fun id(self: &House): ID {
    self.id.to_inner()
}

/// Returns whether the House is private (admin-only staking).
public fun private(self: &House): bool {
    self.private
}

/// Returns the fee collector ID for a specific game.
/// Aborts if the game doesn't have a fee collector assigned.
public fun game_fee_collector(self: &House, game_id: &ID): ID {
    assert!(self.game_fee_collectors.contains(game_id), EGameDoesNotExist);
    *self.game_fee_collectors.get(game_id)
}

/// Returns the house fee in basis points.
public fun house_fee_bps(self: &House): u64 {
    self.house_fee_bps
}

/// Returns the house balance (all funds available for the house).
public fun house_balance(self: &House): u64 {
    self.vault.house_balance()
}

/// Returns the total number of shares in circulation.
/// This is a read-only operation that doesn't require end-of-day processing.
public fun total_shares(self: &House): u64 {
    self.state.total_shares()
}

/// Returns the effective house balance (house_balance - pending_fees).
/// This represents the actual value available to shareholders after accounting for pending fees.
/// This is a read-only operation that doesn't require end-of-day processing.
public fun effective_house_balance(self: &House): u64 {
    let vault_value = self.vault.house_balance();
    let total_pending_fees = self.state.calculate_total_pending_fees();
    
    if (vault_value > total_pending_fees) {
        vault_value - total_pending_fees
    } else {
        0
    }
}

/// Calculates the current value of a participation's shares.
/// Uses mul_floor for accurate calculation that handles rounding properly.
/// This is a read-only operation that doesn't require end-of-day processing.
/// Returns the value in MIST that the participation's shares are worth.
public fun nav(self: &House, participation: &Participation): u64 {
    self.assert_valid_participation(participation);
    
    let participation_shares = participation::shares(participation);
    let total_shares = self.state.total_shares();
    
    if (total_shares == 0 || participation_shares == 0) {
        return 0
    };
    
    let effective_value = self.effective_house_balance();
    
    // Use mul_floor to preserve precision: (participation_shares * effective_value) / total_shares
    // Round DOWN to favor protocol (user gets slightly less)
    mul_floor(participation_shares, effective_value, total_shares)
}

/// Returns the House ID associated with an admin cap.
public fun admin_cap_house_id(cap: &HouseAdminCap): ID {
    cap.house_id
}

/// Returns the House ID associated with a transaction cap.
public fun transaction_cap_house_id(cap: &HouseTransactionCap): ID {
    cap.house_id
}

// === Public Functions ===
/// Shares the House object and registers it with the Registry.
/// This makes the House publicly accessible for transactions.
public fun share(registry: &mut Registry, house: House, ctx: &TxContext) {
    registry.register_house(house.id(), ctx);
    share_object(house);
}

/// Ensures that the vault can cover `max_payout` with the house balance.
/// In the share-based model, this checks the single house balance.
public fun ensure_sufficient_funds(self: &mut House, amount: u64) {
    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    assert!(self.vault.house_balance() >= amount, EInsufficientFunds)
}

/// Public function to create a new participation. This is only possible if the house is public.
public fun new_participation(self: &House, ctx: &mut TxContext): Participation {
    self.assert_not_private();
    participation::empty(self.id.to_inner(), ctx)
}

/// Buys shares in the house by depositing funds.
/// Calculates the number of shares to mint based on current NAV.
/// Shares are 1:1 with MIST, so shares = deposit_amount / nav_per_share.
/// Requires end-of-day processing to ensure NAV is up-to-date.
public fun buy_shares(
    self: &mut House,
    registry: &Registry,
    participation: &mut Participation,
    deposit: Coin<SUI>,
    ctx: &mut TxContext,
): u64 {
    self.assert_valid_participation(participation);

    // Process end of day to ensure NAV is up-to-date
    self.process_end_of_day(registry, ctx);

    let deposit_amount = deposit.value();
    assert!(deposit_amount > 0, EInvalidAmount);

    let current_epoch = ctx.epoch();
    let player = ctx.sender();

    // Calculate shares to mint using mul_floor to handle rounding properly
    // shares = deposit_amount / nav_per_share = (deposit_amount * total_shares) / effective_value
    // Round DOWN to favor protocol (user gets slightly fewer shares)
    let total_shares = self.state.total_shares();
    let effective_value = self.effective_house_balance();
    let shares_to_mint = if (total_shares == 0) {
        // If no shares exist yet, use 1:1 ratio (NAV = 1)
        deposit_amount
    } else {
        assert!(effective_value > 0, EInvalidAmount);
        // Use mul_floor to preserve precision: (deposit_amount * total_shares) / effective_value
        mul_floor(deposit_amount, total_shares, effective_value)
    };

    // Ensure we mint at least some shares
    assert!(shares_to_mint > 0, EInvalidAmount);

    // Update participation
    participation::add_shares(participation, shares_to_mint);

    // Update global state
    self.state.mint_shares(shares_to_mint);

    // Get total shares after minting
    let total_shares = self.state.total_shares();

    // Deposit funds to vault
    self.vault.deposit(deposit.into_balance());

    // Event
    emit(SharesPurchasedEvent {
        house_id: self.id(),
        participation_id: participation.id(),
        player,
        shares: shares_to_mint,
        amount: deposit_amount,
        effective_house_balance: effective_value,
        total_shares: total_shares,
        epoch: current_epoch,
    });

    shares_to_mint
}

/// Sells shares and withdraws the proceeds.
/// Calculates payout based on current NAV.
/// Shares are 1:1 with MIST, so payout = shares_to_sell * nav_per_share.
/// Requires end-of-day processing to ensure NAV is up-to-date.
/// House performance fees are handled at epoch end (GGR-based), not on individual sales.
public fun sell_shares(
    self: &mut House,
    registry: &Registry,
    participation: &mut Participation,
    shares_to_sell: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.assert_valid_participation(participation);

    // Process end of day to ensure NAV is up-to-date
    self.process_end_of_day(registry, ctx);

    // Verify participation has enough shares
    assert!(participation::shares(participation) >= shares_to_sell, ENotEnoughShares);

    let current_epoch = ctx.epoch();
    let player = ctx.sender();

    // Calculate payout using mul_floor to handle rounding properly
    // payout = shares_to_sell * nav_per_share = (shares_to_sell * effective_value) / total_shares
    // Round DOWN to favor protocol (user gets slightly less)
    let total_shares = self.state.total_shares();
    assert!(total_shares > 0, EInvalidAmount);
    let vault_value = self.vault.house_balance();
    let total_pending_fees = self.state.calculate_total_pending_fees();
    let effective_value = if (vault_value > total_pending_fees) {
        vault_value - total_pending_fees
    } else {
        0
    };
    // Use mul_floor to preserve precision: (shares_to_sell * effective_value) / total_shares
    let payout = mul_floor(shares_to_sell, effective_value, total_shares);

    // Remove shares from participation
    participation::remove_shares(participation, shares_to_sell);

    // Update global state
    self.state.burn_shares(shares_to_sell);

    // Get total shares after burning
    let total_shares = self.state.total_shares();

    // Withdraw from vault
    let payout_coin = self.vault.withdraw(payout).into_coin(ctx);

    // Event
    emit(SharesSoldEvent {
        house_id: self.id(),
        participation_id: participation.id(),
        player,
        shares: shares_to_sell,
        payout: payout,
        effective_house_balance: effective_value,
        total_shares: total_shares,
        epoch: current_epoch,
    });

    payout_coin
}

/// Borrows a transaction cap for a game that is authorized (has a fee collector assigned).
/// Aborts if the game is not authorized.
public fun borrow_tx_cap(self: &House, game_id: &mut UID): HouseTransactionCap {
    let game_id_inner = game_id.to_inner();
    assert!(self.game_fee_collectors.contains(&game_id_inner), EUnauthorizedGameId);

    let fee_collector_id = *self.game_fee_collectors.get(&game_id_inner);

    HouseTransactionCap {
        house_id: self.id(),
        game_id: game_id_inner,
        fee_collector_id,
    }
}

/// Refreshes the state of the house by processing the end of day.
public fun refresh_state(self: &mut House, registry: &Registry, ctx: &mut TxContext) {
    self.process_end_of_day(registry, ctx);
}

// === Admin Functions ===
/// Processes transactions for a game using a balance manager.
/// Handles balance settlement and statistics updates.
/// Requires a valid transaction cap and play cap.
///
/// # Fee Model
/// With GGR-based commissions, fees are no longer processed during gameplay. All fees
/// (house, collector, and protocol) are calculated from GGR at epoch end. This simplifies
/// transaction processing and ensures fees are based on actual house performance.
///
/// # Version Check
/// **IMPORTANT**: This function calls `registry.check_version()` which performs a registry
/// version check. If the current package version is disabled in the registry, this function
/// will abort, effectively pausing gameplay. This is intentional - version checks allow the
/// protocol to pause gameplay for security or upgrade purposes. However, note that fund
/// operations (stake/unstake/claim) do NOT perform version checks, ensuring user funds can
/// never be paused.
public fun tx_admin_process_transactions_v2(
    self: &mut House,
    registry: &Registry,
    game_stats: &mut GameStatistics,
    cap: HouseTransactionCap,
    balance_manager: &mut BalanceManager,
    transactions: &vector<Transaction>,
    play_cap: &PlayCap,
    ctx: &mut TxContext,
) {
    // Check the stats
    let game_id = cap.game_id;
    assert!(game_id == game_stats.game_id(), EInvalidGameStats);

    // Extract values before validating (assert_valid_tx_cap takes ownership)
    let fee_collector_id = cap.fee_collector_id;
    self.assert_valid_tx_cap(cap);

    // Version check: Ensure gameplay is not paused
    // This will abort if the current package version is disabled in the registry
    registry.check_version();

    // Generate proof
    let play_proof = balance_manager.generate_proof_as_player(play_cap, ctx);

    // Process end of day to ensure state is up-to-date
    self.process_end_of_day(registry, ctx);

    // Process transactions (GGR tracking happens automatically via process_volumes)
    // Fees are now GGR-based and handled at epoch end, not during transaction processing
    let (credit_balance, debit_balance) = self
        .state
        .process_transactions(
            transactions,
            balance_manager.id(),
            fee_collector_id,
            ctx,
        );

    // Settle the balances in vault
    self.vault.settle_balance_manager(credit_balance, debit_balance, balance_manager, &play_proof);

    let current_epoch = ctx.epoch();

    // Event
    emit(SettlementEvent {
        house_id: self.id(),
        game_id: game_id,
        balance_manager_id: balance_manager.id(),
        fee_collector_id: fee_collector_id,
        amount_in: debit_balance,
        amount_out: credit_balance,
        epoch: current_epoch,
    });

    // Update stats
    game_stats.process_transactions(transactions, ctx);

    // Event
    emit(TransactionsProcessedEvent {
        house_id: self.id(),
        game_id: game_id,
        balance_manager_id: balance_manager.id(),
        fee_collector_id: fee_collector_id,
        epoch: current_epoch,
        transactions: *transactions,
    })
}

/// Processes transactions for a game without requiring a pre-existing balance manager.
/// Creates a temporary balance manager, processes transactions, and returns remaining funds.
/// Useful for games that don't maintain persistent balance managers.
///
/// # Fee Model
/// With GGR-based commissions, fees are no longer processed during gameplay. All fees
/// (house, collector, and protocol) are calculated from GGR at epoch end. This simplifies
/// transaction processing and ensures fees are based on actual house performance.
///
/// # Version Check
/// **IMPORTANT**: This function calls `registry.check_version()` which performs a registry
/// version check. If the current package version is disabled in the registry, this function
/// will abort, effectively pausing gameplay. This is intentional - version checks allow the
/// protocol to pause gameplay for security or upgrade purposes. However, note that fund
/// operations (stake/unstake/claim) do NOT perform version checks, ensuring user funds can
/// never be paused.
public fun tx_admin_process_transactions_v2_no_bm(
    self: &mut House,
    registry: &Registry,
    game_stats: &mut GameStatistics,
    cap: HouseTransactionCap,
    transactions: &vector<Transaction>,
    funds: Coin<SUI>,
    ctx: &mut TxContext,
): Coin<SUI> {
    let game_id = cap.game_id;
    assert!(game_id == game_stats.game_id(), EInvalidGameStats);

    // Check the tx cap
    // Extract values before validating (assert_valid_tx_cap takes ownership)
    let fee_collector_id = cap.fee_collector_id;
    self.assert_valid_tx_cap(cap);

    // Version check: Ensure gameplay is not paused
    // This will abort if the current package version is disabled in the registry
    registry.check_version();

    // Create a temporary balance manager and fund it
    let (mut balance_manager, bm_cap) = balance_manager::new(ctx);
    balance_manager.deposit(&bm_cap, funds, ctx);

    // Generate proof
    let play_proof = balance_manager.generate_proof_as_owner(&bm_cap, ctx);

    // Process end of day to ensure state is up-to-date
    self.process_end_of_day(registry, ctx);

    // Process transactions (GGR tracking happens automatically via process_volumes)
    // Fees are now GGR-based and handled at epoch end, not during transaction processing
    let (credit_balance, debit_balance) = self
        .state
        .process_transactions(
            transactions,
            balance_manager.id(),
            fee_collector_id,
            ctx,
        );

    // Settle the balances in vault
    self
        .vault
        .settle_balance_manager(credit_balance, debit_balance, &mut balance_manager, &play_proof);

    let current_epoch = ctx.epoch();

    // Event
    emit(SettlementEvent {
        house_id: self.id(),
        game_id: game_id,
        balance_manager_id: balance_manager.id(),
        fee_collector_id: fee_collector_id,
        amount_in: debit_balance,
        amount_out: credit_balance,
        epoch: current_epoch,
    });

    // Update stats
    game_stats.process_transactions(transactions, ctx);

    // Event
    emit(TransactionsProcessedEvent {
        house_id: self.id(),
        game_id: game_id,
        balance_manager_id: balance_manager.id(),
        fee_collector_id: fee_collector_id,
        epoch: current_epoch,
        transactions: *transactions,
    });

    // Withdraw remaining coins and destroy bm
    let remainder = balance_manager.withdraw_all(&bm_cap, ctx);
    balance_manager.destroy_empty(bm_cap, ctx);

    remainder
}

// === Admin Functions ===
/// Claims all the house fees (performance fees) collected from profits.
/// Can only be called by the house admin.
public fun admin_claim_house_fees(
    self: &mut House,
    registry: &Registry,
    admin_cap: &HouseAdminCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.assert_valid_admin_cap(admin_cap);

    // Process any pending end-of-day first to ensure all fees are available
    self.process_end_of_day(registry, ctx);

    let fee_coin = self.vault.withdraw_house_fees().into_coin(ctx);
    let current_epoch = ctx.epoch();

    // Event
    emit(HouseFeesClaimedEvent {
        house_id: self.id(),
        amount: fee_coin.value(),
        epoch: current_epoch,
    });

    fee_coin
}

// === Admin Functions ===
/// Creates a new fee collector for this house.
/// Returns the shared FeeCollector and owned FeeCollectorCap.
public fun admin_create_fee_collector(
    self: &House,
    admin_cap: &HouseAdminCap,
    ctx: &mut TxContext,
): (FeeCollector, FeeCollectorCap) {
    self.assert_valid_admin_cap(admin_cap);
    fee_collector::new(self.id(), ctx)
}

/// Whitelists a game AND assigns it to a fee collector.
/// The fee collector must belong to this house.
public fun admin_add_tx_allowed_with_collector(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    game_id: ID,
    fee_collector: &FeeCollector,
) {
    self.assert_valid_admin_cap(admin_cap);
    assert!(fee_collector.house_id() == self.id(), EInvalidFeeCollector);

    // Check if adding a new game would exceed the maximum
    let is_update = self.game_fee_collectors.contains(&game_id);
    if (!is_update) {
        assert!(self.game_fee_collectors.length() < MAX_GAMES, EMaxGamesReached);
    };

    // Assign fee collector (this also whitelists the game)
    // Remove existing entry if updating, then insert new value
    if (is_update) {
        self.game_fee_collectors.remove(&game_id);
    };
    self.game_fee_collectors.insert(game_id, fee_collector.id());

    // Event
    emit(GameTransactionsAllowedEvent {
        house_id: self.id(),
        game_id: game_id,
        fee_collector_id: fee_collector.id(),
    });
}

/// Revokes game transaction authorization by removing the game from the allow list.
/// The game must be currently authorized (have a fee collector assigned).
public fun admin_revoke_tx_allowed(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    game_id: ID,
) {
    self.assert_valid_admin_cap(admin_cap);
    assert!(self.game_fee_collectors.contains(&game_id), EGameDoesNotExist);

    // Get fee collector ID before removing (for event)
    let fee_collector_id = *self.game_fee_collectors.get(&game_id);

    // Remove game from allow list
    self.game_fee_collectors.remove(&game_id);

    // Event
    emit(GameTransactionsDisallowedEvent {
        house_id: self.id(),
        game_id: game_id,
        fee_collector_id: fee_collector_id,
    });
}

/// Claims fees for a fee collector. Requires the cap.
/// Processes any pending end-of-day first to ensure all fees are available.
public fun claim_collector_fees(
    self: &mut House,
    registry: &Registry,
    fee_collector: &FeeCollector,
    cap: &FeeCollectorCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    // Validate fee collector belongs to this house
    assert!(fee_collector.house_id() == self.id(), EInvalidFeeCollector);

    // Validate cap ownership
    fee_collector::assert_valid_cap(fee_collector, cap);

    // Process any pending end-of-day first to ensure all fees are available
    self.process_end_of_day(registry, ctx);

    // Withdraw from vault
    let fee_balance = self.vault.withdraw_collector_fees(fee_collector.id());
    let amount = fee_balance.value();
    let current_epoch = ctx.epoch();

    // Emit house-level event
    emit(CollectorFeesClaimedEvent {
        house_id: self.id(),
        fee_collector_id: fee_collector.id(),
        amount: amount,
        epoch: current_epoch,
    });

    fee_balance.into_coin(ctx)
}

/// Updates both house fee and fee collector share.
/// The sum of both fees cannot exceed the maximum (50%) to ensure at least 30% for stakers.
public fun admin_update_fees(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    house_fee_bps: u64,
    fee_collector_share_bps: u64,
) {
    self.assert_valid_admin_cap(admin_cap);
    assert!(house_fee_bps < max_bps(), EInvalidFeeConfiguration);
    assert!(fee_collector_share_bps < max_bps(), EInvalidFeeConfiguration);
    // House fee + collector fee cannot exceed maximum to ensure at least 30% for stakers
    assert!(
        house_fee_bps + fee_collector_share_bps <= max_house_and_collector_fees_bps(),
        EHouseAndCollectorFeesTooHigh,
    );

    let old_house_fee_bps = self.house_fee_bps;
    let old_fee_collector_share_bps = self.fee_collector_share_bps;
    self.house_fee_bps = house_fee_bps;
    self.fee_collector_share_bps = fee_collector_share_bps;

    // Event
    emit(HouseFeesUpdatedEvent {
        house_id: self.id(),
        old_house_fee_bps,
        new_house_fee_bps: house_fee_bps,
        old_fee_collector_share_bps,
        new_fee_collector_share_bps: fee_collector_share_bps,
    });
}

// === Admin Functions ===
/// Privileged instruction for creating a new participation. Should be used when the house is `private`.
public fun admin_new_participation(
    self: &House,
    cap: &HouseAdminCap,
    ctx: &mut TxContext,
): Participation {
    // Check the admin cap
    self.assert_valid_admin_cap(cap);

    participation::empty(self.id.to_inner(), ctx)
}

// === Package Functions ===
/// Creates a new House with the specified configuration.
/// Returns (house, admin_cap) where admin_cap grants administrative access.
/// Validates protocol fee from registry to ensure it doesn't exceed maximum.
public fun openplay_admin_new_house(
    _openplay_admin_cap: &OpenPlayAdminCap,
    registry: &Registry,
    private: bool,
    min_activation_balance: u64,
    house_fee_bps: u64,
    fee_collector_share_bps: u64,
    ctx: &mut TxContext,
): (House, HouseAdminCap) {
    assert!(house_fee_bps < max_bps(), EInvalidFeeConfiguration);
    assert!(fee_collector_share_bps < max_bps(), EInvalidFeeConfiguration);
    // House fee + collector fee cannot exceed maximum to ensure at least 30% for stakers
    assert!(
        house_fee_bps + fee_collector_share_bps <= max_house_and_collector_fees_bps(),
        EHouseAndCollectorFeesTooHigh,
    );

    // Validate protocol fee from registry
    let protocol_fee_bps = registry.protocol_fee_bps();
    assert!(protocol_fee_bps <= max_protocol_fee_bps(), EProtocolFeeTooHigh);
    let admin_cap_id = object::new(ctx);
    let house_id_obj = object::new(ctx);
    let house_id = house_id_obj.to_inner();
    let house = House {
        id: house_id_obj,
        admin_cap_id: admin_cap_id.to_inner(),
        private,
        vault: vault::empty(house_id),
        state: house_state::new(
            house_id,
            protocol_fee_bps,
            house_fee_bps,
            fee_collector_share_bps,
            ctx,
        ),
        min_activation_balance,
        house_fee_bps,
        fee_collector_share_bps,
        game_fee_collectors: vec_map::empty(),
    };
    let admin_cap = HouseAdminCap {
        id: admin_cap_id,
        house_id: house.id(),
    };

    emit(HouseCreatedEvent {
        house_id: house.id(),
        admin_cap_id: admin_cap.id.to_inner(),
        private,
        min_activation_balance,
        house_fee_bps,
        fee_collector_share_bps,
    });

    (house, admin_cap)
}

/// Claims all the protocol fees for this house. Can only be called by the openplay admin.
public fun openplay_admin_claim_protocol_fees(
    self: &mut House,
    _admin_cap: &OpenPlayAdminCap,
    registry: &Registry,
    ctx: &mut TxContext,
): Coin<SUI> {
    // Ensure end of day is processed before claiming fees
    self.process_end_of_day(registry, ctx);
    let fee_coin = self.vault.withdraw_protocol_fees().into_coin(ctx);
    let current_epoch = ctx.epoch();

    // Event
    emit(ProtocolFeesClaimedEvent {
        house_id: self.id(),
        amount: fee_coin.value(),
        epoch: current_epoch,
    });

    fee_coin
}

// === Private Functions ===
/// Processes end-of-day when a new epoch is detected.
/// Calculates profits/losses from state volumes (bet - win), calculates all fees from GGR,
/// and moves fees to vault. Profits are calculated from the state volumes, not balance differences.
/// Registry is required to get the protocol fee for the current epoch.
/// Note: there can be a number of epochs in between without any activity.
fun process_end_of_day(self: &mut House, registry: &Registry, ctx: &mut TxContext) {
    // Check if epoch changed in state
    let current_epoch = ctx.epoch();
    let state_epoch = self.state.epoch();

    if (current_epoch > state_epoch) {
        let prev_epoch = state_epoch;

        // Get protocol fee from registry
        let protocol_fee_bps = registry.protocol_fee_bps();

        // Process end of day in state - calculates profits from volumes and all fees from GGR
        // Returns (collector_fees, house_fee, protocol_fee) that need to be moved to vault
        let (collector_fees, house_fee, protocol_fee) = self
            .state
            .process_end_of_day(
                prev_epoch,
                self.house_fee_bps,
                self.fee_collector_share_bps,
                protocol_fee_bps,
                ctx,
            );

        // Physically move collector fees to vault
        let fees_len = vector::length(&collector_fees);
        let mut i = 0;
        while (i < fees_len) {
            let fee = vector::borrow(&collector_fees, i);
            self
                .vault
                .process_collector_fee(
                    collector_id(fee),
                    fee_amount(fee),
                );
            i = i + 1;
        };

        // Physically move house fees to vault
        if (house_fee > 0) {
            self.vault.process_house_fee(house_fee);
            emit(HouseFeeProcessedEvent {
                house_id: self.id(),
                amount: house_fee,
                epoch: prev_epoch,
            });
        };

        // Physically move protocol fees to vault
        if (protocol_fee > 0) {
            self.vault.process_protocol_fee(protocol_fee);
            emit(ProtocolFeesProcessedEvent {
                house_id: self.id(),
                amount: protocol_fee,
                epoch: prev_epoch,
            });
        };
    }
}

/// Validates that the admin cap belongs to this House.
/// Aborts if the cap's house_id doesn't match.
fun assert_valid_admin_cap(self: &House, house_cap: &HouseAdminCap) {
    assert!(self.id() == house_cap.house_id, EInvalidAdminCap);
}

/// Validates that the transaction cap is valid for this House and game.
/// Aborts if the game is not in the allow list or the house_id doesn't match.
/// Takes ownership of the cap to prevent reuse.
fun assert_valid_tx_cap(self: &House, tx_cap: HouseTransactionCap) {
    let HouseTransactionCap { house_id, game_id, fee_collector_id } = tx_cap;
    assert!(self.id() == house_id, EInvalidTxCap);
    // Verify game is whitelisted (has fee collector assigned)
    assert!(self.game_fee_collectors.contains(&game_id), EInvalidTxCap);
    // Verify fee collector matches
    assert!(*self.game_fee_collectors.get(&game_id) == fee_collector_id, EInvalidFeeCollector);
}

/// Validates that the participation belongs to this House.
/// Aborts if the participation's house_id doesn't match.
fun assert_valid_participation(self: &House, participation: &Participation) {
    assert!(self.id() == participation.house_id(), EInvalidParticipation);
}

/// Asserts that the House is not private.
/// Aborts if the House is private.
fun assert_not_private(self: &House) {
    assert!(self.private() == false, EHouseIsPrivate);
}

// === Test Functions ===
#[test_only]
public fun admin_cap_for_testing(house: &House, ctx: &mut TxContext): HouseAdminCap {
    HouseAdminCap {
        id: object::new(ctx),
        house_id: house.id(),
    }
}
#[test_only]
public fun tx_cap_for_testing(house: &mut House, game_id: ID): HouseTransactionCap {
    // For testing, assign game_id as its own fee_collector_id if not already assigned
    if (!house.game_fee_collectors.contains(&game_id)) {
        house.game_fee_collectors.insert(game_id, game_id);
    };
    // Get fee collector for this game (or use a default/zero ID for testing)
    let fee_collector_id = if (house.game_fee_collectors.contains(&game_id)) {
        *house.game_fee_collectors.get(&game_id)
    } else {
        // For testing, use game_id as fee_collector_id if not assigned
        game_id
    };
    let cap = HouseTransactionCap {
        house_id: house.id(),
        game_id,
        fee_collector_id,
    };
    cap
}

#[test_only]
public fun new_for_testing(
    private: bool,
    min_activation_balance: u64,
    house_fee_bps: u64,
    fee_collector_share_bps: u64,
    protocol_fee_bps: u64,
    ctx: &mut TxContext,
): (House, HouseAdminCap) {
    assert!(house_fee_bps < max_bps(), EInvalidFeeConfiguration);
    // House fee + collector fee cannot exceed maximum to ensure at least 30% for stakers
    assert!(
        house_fee_bps + fee_collector_share_bps <= max_house_and_collector_fees_bps(),
        EHouseAndCollectorFeesTooHigh,
    );
    let admin_cap_id = object::new(ctx);
    let house_id_obj = object::new(ctx);
    let house_id = house_id_obj.to_inner();
    let house = House {
        id: house_id_obj,
        admin_cap_id: admin_cap_id.to_inner(),
        private,
        vault: vault::empty(house_id),
        state: house_state::new(
            house_id,
            protocol_fee_bps,
            house_fee_bps,
            fee_collector_share_bps,
            ctx,
        ),
        min_activation_balance,
        house_fee_bps,
        fee_collector_share_bps,
        game_fee_collectors: vec_map::empty(),
    };
    let admin_cap = HouseAdminCap {
        id: admin_cap_id,
        house_id: house.id(),
    };

    emit(HouseCreatedEvent {
        house_id: house.id(),
        admin_cap_id: admin_cap.id.to_inner(),
        private,
        min_activation_balance,
        house_fee_bps,
        fee_collector_share_bps,
    });

    (house, admin_cap)
}

#[test_only]
/// Test helper to add collector fees for testing.
/// Note: In production, collector fees are calculated from GGR at epoch end.
public fun add_collector_fees_for_testing(self: &mut House, fee_collector_id: ID, amount: u64) {
    self.vault.process_collector_fee(fee_collector_id, amount);
}
