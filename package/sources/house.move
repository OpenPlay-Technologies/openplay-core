/// House is responsible for processing and settling transactions between the vault and balance manager.
/// It is responsible for keeping the right amount of fees for stakers, game owners, and house admin (performance fee).
module openplay_core::house;

use openplay_core::balance_manager::{Self, BalanceManager, PlayCap};
use openplay_core::calculations::mul_ceil_bps;
use openplay_core::core_constants::max_bps;
use openplay_core::game_stats::GameStatistics;
use openplay_core::house_state::{Self, State};
use openplay_core::participation::{Self, Participation};
use openplay_core::registry::{Registry, OpenPlayAdminCap};
use openplay_core::transaction::Transaction;
use openplay_core::vault::{Self, Vault};
use sui::coin::Coin;
use sui::event::emit;
use sui::sui::SUI;
use sui::transfer::share_object;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// === Errors ===
const EInsufficientFunds: u64 = 1;
const EInvalidTxCap: u64 = 2;
const EInvalidParticipation: u64 = 3;
const EHouseNotActive: u64 = 4;
const EHouseIsPrivate: u64 = 6;
const EMaxTxCapsReached: u64 = 7;
const EInvalidAdminCap: u64 = 9;
const EInvalidFeeConfiguration: u64 = 10;
const EUnauthorizedGameId: u64 = 11;
const ETxCapNotAllowed: u64 = 12;
const EInvalidGameStats: u64 = 13;

// === Constants ===
const MAX_TX_CAPS: u64 = 1000;

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
    house_fee_bps: u64, // Performance fee taken from profits (in basis points)
    games_fee_bps: VecMap<ID, u64>,
    tx_allow_listed: VecSet<ID>,
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
public struct HouseTransactionCap {
    house_id: ID,
    game_id: ID,
}

/// Fee breakdown structure containing protocol and game fees.
public struct Fees has copy, drop {
    protocol_fee: u64,
    game_fee: u64,
}

/// Event emitted when a new House is created.
public struct HouseCreatedEvent has copy, drop {
    house_id: ID,
    admin_cap_id: ID,
}

/// Event emitted when a game's fee is updated.
public struct GameFeeUpdatedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
    game_fee_bps: u64,
}

/// Event emitted when transactions are processed by a game.
public struct TransactionsProcessedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
    balance_manager_id: ID,
    transactions: vector<Transaction>,
    fees: Fees,
}

/// Event emitted when a game is authorized to execute transactions.
public struct GameTransactionsAllowedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
}

/// Event emitted when a game's transaction authorization is revoked.
public struct GameTransactionsRevokedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
}

/// Event emitted when protocol fees are claimed by the OpenPlay admin.
public struct ProtocolFeesClaimedEvent has copy, drop {
    house_id: ID,
    amount: u64,
}

/// Event emitted when game fees are claimed by a game owner.
public struct GameFeesClaimedEvent has copy, drop {
    house_id: ID,
    game_id: ID,
    amount: u64,
}

/// Event emitted when house fees (performance fees) are claimed by the house admin.
public struct HouseFeesClaimedEvent has copy, drop {
    house_id: ID,
    amount: u64,
}

// === Public-View Functions ===
/// Returns the ID of the House.
public fun id(self: &House): ID {
    self.id.to_inner()
}

/// Returns whether the House is private (admin-only staking).
public fun private(self: &House): bool {
    self.private
}

/// Returns the current play balance available for game payouts.
/// Automatically processes end-of-day if needed.
public fun play_balance(self: &mut House, ctx: &mut TxContext): u64 {
    self.process_end_of_day(ctx);
    self.vault.play_balance()
}

/// Returns the reserve balance (staked funds not yet in play).
/// Automatically processes end-of-day if needed.
public fun reserve_balance(self: &mut House, ctx: &mut TxContext): u64 {
    self.process_end_of_day(ctx);
    self.vault.reserve_balance()
}

/// Returns the game fee in basis points for a specific game.
/// Returns 0 if the game has no configured fee.
public fun game_fee_bps(self: &House, game_id: &ID): u64 {
    self.games_fee_bps.try_get(game_id).get_with_default(0)
}

/// Returns the house fee in basis points.
public fun house_fee_bps(self: &House): u64 {
    self.house_fee_bps
}

/// Returns the House ID associated with an admin cap.
public fun admin_cap_house_id(cap: &HouseAdminCap): ID {
    cap.house_id
}

/// Returns the House ID associated with a transaction cap.
public fun transaction_cap_house_id(cap: &HouseTransactionCap): ID {
    cap.house_id
}

/// Returns whether the House is currently active (has sufficient stake and is operational).
/// Automatically processes end-of-day if needed.
public fun is_active(self: &mut House, ctx: &TxContext): bool {
    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);
    self.state.is_active()
}

// === Public-Mutative Functions ===
/// Shares the House object and registers it with the Registry.
/// This makes the House publicly accessible for transactions.
public fun share(registry: &mut Registry, house: House) {
    registry.register_house(house.id());
    share_object(house);
}

/// Ensures that the vault can cover `max_payout` with the play balance
public fun ensure_sufficient_funds(self: &mut House, amount: u64, ctx: &TxContext) {
    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    assert!(self.state.is_active(), EHouseNotActive);
    assert!(self.vault.play_balance() >= amount, EInsufficientFunds)
}

/// Public function to create a new participation. This is only possible if the house is public.
public fun new_participation(self: &House, ctx: &mut TxContext): Participation {
    self.assert_not_private();
    participation::empty(self.id.to_inner(), ctx)
}

/// Stake money in the protocol to participate in the house winnings.
/// The stake is first added to the account's inactive stake, and is only activated in the next epoch.
public fun stake(
    self: &mut House,
    participation: &mut Participation,
    stake: Coin<SUI>,
    ctx: &mut TxContext,
) {
    self.assert_valid_participation(participation);

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Process the stake in the state
    self.state.process_stake(stake.value(), ctx);

    // Add funds to the participation
    participation.add_stake(stake.value(), self.state.is_active(), ctx);

    // Move funds to the vault
    self.vault.deposit(stake.into_balance());

    // Try to activate the house
    self.activate_if_possible(ctx);
}

/// Refreshes the participation to process any unprocessed profits or losses.
/// Updates a participation to the current epoch, processing all missed epochs.
/// This is the default behavior and processes all epochs in a single call.
public fun update_participation(
    self: &mut House,
    participation: &mut Participation,
    ctx: &mut TxContext,
) {
    self.assert_valid_participation(participation);

    // Make sure the end of day is processed
    self.process_end_of_day(ctx);

    // Refresh the participation (processes all epochs by default)
    self.state.refresh(participation, ctx);
}

/// Updates a participation with a limit on the number of epochs processed per call.
/// Returns `true` if all epochs were processed, `false` if more epochs remain.
/// Useful for catching up participations that haven't been updated for many epochs.
///
/// # Parameters
/// - `max_epochs`: Maximum number of epochs to process in this call. Use a reasonable value (e.g., 100)
///                 to prevent gas limit issues when catching up after many epochs.
public fun update_participation_with_limit(
    self: &mut House,
    participation: &mut Participation,
    max_epochs: u64,
    ctx: &mut TxContext,
): bool {
    self.assert_valid_participation(participation);

    // Make sure the end of day is processed
    self.process_end_of_day(ctx);

    // Refresh the participation with epoch limit
    self.state.refresh_with_limit(participation, max_epochs, ctx)
}

/// Withdraws the stake from the current game. This only goes into effect in the next epoch.
public fun unstake_v2(
    self: &mut House,
    participation: &mut Participation,
    amount: u64,
    ctx: &mut TxContext,
) {
    self.assert_valid_participation(participation);

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Unstake the funds in the participation
    let (remaining_amount, pending_stake_removed) = participation.unstake_v2(
        amount,
        self.state.is_active(),
        ctx,
    );

    // Process the unstake in the history
    self.state.process_unstake(remaining_amount, pending_stake_removed, ctx);
}

/// Claims all claimable balance from a participation.
/// Returns the claimable amount as a Coin<SUI>.
public fun claim_all(
    self: &mut House,
    participation: &mut Participation,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.assert_valid_participation(participation);

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Take the claimable balance from participation
    let claimable = participation.claim_all(ctx);

    // Withdraw from vault
    self.vault.withdraw(claimable).into_coin(ctx)
}

/// Borrows a transaction cap for a game that is authorized in the allow list.
/// Aborts if the game is not authorized.
public fun borrow_tx_cap(self: &House, game_id: &mut UID): HouseTransactionCap {
    assert!(self.tx_allow_listed.contains(game_id.as_inner()), EUnauthorizedGameId);
    HouseTransactionCap {
        house_id: self.id(),
        game_id: game_id.to_inner(),
    }
}

// === Tx-Admin Functions ===
/// Processes transactions for a game using a balance manager.
/// Handles fee calculation, balance settlement, and statistics updates.
/// Requires a valid transaction cap and play cap.
public fun tx_admin_process_transactions_v2(
    self: &mut House,
    registry: &Registry,
    game_stats: &mut GameStatistics,
    cap: HouseTransactionCap,
    balance_manager: &mut BalanceManager,
    transactions: &vector<Transaction>,
    play_cap: &PlayCap,
    ctx: &TxContext,
) {
    // Check the stats
    let game_id = cap.game_id;
    assert!(game_id == game_stats.game_id(), EInvalidGameStats);

    let game_id = cap.game_id;
    self.assert_valid_tx_cap(cap);

    // Generate proof
    let play_proof = balance_manager.generate_proof_as_player(play_cap, ctx);

    let game_fee_bps = self.game_fee_bps(&game_id);
    let protocol_fee_bps = registry.protocol_fee_bps();

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    let (credit_balance, debit_balance, game_fee, protocol_fee) = self
        .state
        .process_transactions(
            transactions,
            balance_manager.id(),
            game_fee_bps,
            protocol_fee_bps,
            ctx,
        );

    // Settle the balances in vault
    self.vault.settle_balance_manager(credit_balance, debit_balance, balance_manager, &play_proof);

    // Process fees
    self.vault.process_game_fee(game_id, game_fee);
    self.vault.process_protocol_fee(protocol_fee);

    // Update stats
    game_stats.process_transactions(transactions, ctx);

    // Event
    emit(TransactionsProcessedEvent {
        house_id: self.id(),
        game_id: game_id,
        balance_manager_id: balance_manager.id(),
        transactions: *transactions,
        fees: Fees {
            protocol_fee: protocol_fee,
            game_fee: game_fee,
        },
    })
}

/// Processes transactions for a game without requiring a pre-existing balance manager.
/// Creates a temporary balance manager, processes transactions, and returns remaining funds.
/// Useful for games that don't maintain persistent balance managers.
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
    self.assert_valid_tx_cap(cap);

    // Create a temporary balance manager and fund it
    let (mut balance_manager, bm_cap) = balance_manager::new(ctx);
    balance_manager.deposit(&bm_cap, funds, ctx);

    // Generate proof
    let play_proof = balance_manager.generate_proof_as_owner(&bm_cap, ctx);

    let game_fee_bps = self.game_fee_bps(&game_id);
    let protocol_fee_bps = registry.protocol_fee_bps();

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    let (credit_balance, debit_balance, game_fee, protocol_fee) = self
        .state
        .process_transactions(
            transactions,
            balance_manager.id(),
            game_fee_bps,
            protocol_fee_bps,
            ctx,
        );

    // Settle the balances in vault
    self
        .vault
        .settle_balance_manager(credit_balance, debit_balance, &mut balance_manager, &play_proof);

    // Process fees
    self.vault.process_game_fee(game_id, game_fee);
    self.vault.process_protocol_fee(protocol_fee);

    // Update stats
    game_stats.process_transactions(transactions, ctx);

    // Event
    emit(TransactionsProcessedEvent {
        house_id: self.id(),
        game_id: game_id,
        balance_manager_id: balance_manager.id(),
        transactions: *transactions,
        fees: Fees {
            protocol_fee: protocol_fee,
            game_fee: game_fee,
        },
    });

    // Withdraw remaining coins and destroy bm
    let remainder = balance_manager.withdraw_all(&bm_cap, ctx);
    balance_manager.destroy_empty(bm_cap);

    remainder
}

// === Tx-Admin Functions ===
/// Claims all the game fees for a specific game. Can only be called by the game owner using a transaction cap.
public fun tx_admin_claim_game_fees(
    self: &mut House,
    cap: HouseTransactionCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    // Check the tx cap
    let game_id = cap.game_id;
    self.assert_valid_tx_cap(cap);

    let fee_coin = self.vault.withdraw_game_fees(game_id).into_coin(ctx);

    // Event
    emit(GameFeesClaimedEvent {
        house_id: self.id(),
        game_id: game_id,
        amount: fee_coin.value(),
    });

    fee_coin
}

// === House-Admin Functions ===
/// Claims all the house fees (performance fees) collected from profits.
/// Can only be called by the house admin.
public fun admin_claim_house_fees(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.assert_valid_admin_cap(admin_cap);

    let fee_coin = self.vault.withdraw_house_fees().into_coin(ctx);

    // Event
    emit(HouseFeesClaimedEvent {
        house_id: self.id(),
        amount: fee_coin.value(),
    });

    fee_coin
}

// === House-Admin Functions ===
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

/// Adds a `game_id` to the tx allowed list.
public fun admin_add_tx_allowed(self: &mut House, admin_cap: &HouseAdminCap, game_id: ID) {
    // Check if the admin_cap is valid
    self.assert_valid_admin_cap(admin_cap);

    // Check if the max allow listed is reached
    assert!(self.tx_allow_listed.length() < MAX_TX_CAPS, EMaxTxCapsReached);

    self.tx_allow_listed.insert(game_id);

    // Event
    emit(GameTransactionsAllowedEvent {
        house_id: self.id(),
        game_id: game_id,
    })
}

/// Revokes tx access for the provided `game_id`.
public fun admin_revoke_tx_allowed(self: &mut House, admin_cap: &HouseAdminCap, game_id: &ID) {
    // Check if the admin_cap is valid
    self.assert_valid_admin_cap(admin_cap);

    assert!(self.tx_allow_listed.contains(game_id), ETxCapNotAllowed);
    self.tx_allow_listed.remove(game_id);

    // Event
    emit(GameTransactionsRevokedEvent {
        house_id: self.id(),
        game_id: *game_id,
    })
}

/// Sets the fee for the provided
public fun admin_set_game_fee(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    game_id: ID,
    game_fee_bps: u64,
) {
    // Check if the admin_cap is valid
    self.assert_valid_admin_cap(admin_cap);

    assert!(game_fee_bps < max_bps(), EInvalidFeeConfiguration);

    self.games_fee_bps.insert(game_id, game_fee_bps);

    // Event
    emit(GameFeeUpdatedEvent {
        house_id: self.id(),
        game_id: game_id,
        game_fee_bps: game_fee_bps,
    })
}

// === Openplay admin functions ===
/// Creates a new House with the specified configuration.
/// Returns (house, admin_cap) where admin_cap grants administrative access.
public fun openplay_admin_new_house(
    _openplay_admin_cap: &OpenPlayAdminCap,
    private: bool,
    min_activation_balance: u64,
    house_fee_bps: u64,
    ctx: &mut TxContext,
): (House, HouseAdminCap) {
    assert!(house_fee_bps < max_bps(), EInvalidFeeConfiguration);
    let admin_cap_id = object::new(ctx);
    let house = House {
        id: object::new(ctx),
        admin_cap_id: admin_cap_id.to_inner(),
        private,
        vault: vault::empty(ctx),
        state: house_state::new(ctx),
        min_activation_balance,
        house_fee_bps,
        games_fee_bps: vec_map::empty(),
        tx_allow_listed: vec_set::empty(),
    };
    let admin_cap = HouseAdminCap {
        id: admin_cap_id,
        house_id: house.id(),
    };

    emit(HouseCreatedEvent {
        house_id: house.id(),
        admin_cap_id: admin_cap.id.to_inner(),
    });

    (house, admin_cap)
}

/// Claims all the protocol fees for this house. Can only be called by the openplay admin.
public fun openplay_admin_claim_protocol_fees(
    self: &mut House,
    _admin_cap: &OpenPlayAdminCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    let fee_coin = self.vault.withdraw_protocol_fees().into_coin(ctx);

    // Event
    emit(ProtocolFeesClaimedEvent {
        house_id: self.id(),
        amount: fee_coin.value(),
    });

    fee_coin
}

// == Private Functions ==
/// Processes end-of-day when a new epoch is detected.
/// Calculates profits/losses, deducts house performance fee from profits (if any),
/// updates participation state, and attempts to reactivate the house if possible.
/// The first time this gets called on a new epoch, the end of the day procedure is initiated for the last known epoch.
/// The vault saves the end of day balance for the house and resets to the target balance if there are enough funds available.
/// Note: there can be a number of epochs in between without any activity.
fun process_end_of_day(self: &mut House, ctx: &TxContext) {
    let (epoch_switched, prev_epoch, end_of_day_balance) = self.vault.process_end_of_day(ctx);

    if (epoch_switched) {
        let profits: u64;
        let losses: u64;
        let was_active = self.state.epoch_active(prev_epoch);
        if (was_active) {
            let active_stake_amount = self.state.active_stake_at_epoch(prev_epoch);
            if (end_of_day_balance > active_stake_amount) {
                profits = end_of_day_balance - active_stake_amount;
                losses = 0;
            } else {
                losses = active_stake_amount - end_of_day_balance;
                profits = 0;
            };
        } else {
            // The house was not funded so no profits or losses were made
            profits = 0;
            losses = 0;
        };

        // Calculate and deduct house fee from profits (performance fee)
        // Round UP to favor protocol (collects slightly more fees)
        let house_fee = if (profits > 0) {
            mul_ceil_bps(profits, self.house_fee_bps)
        } else {
            0
        };
        let profits_after_house_fee = if (profits > house_fee) {
            profits - house_fee
        } else {
            0
        };

        // Store house fee in vault
        if (house_fee > 0) {
            self.vault.process_house_fee(house_fee);
        };

        // Process the profits / losses with the state (after house fee deduction)
        self.state.process_end_of_day(prev_epoch, profits_after_house_fee, losses, ctx);

        // Check if the house can be activated again (if there is still sufficient stake available)
        self.activate_if_possible(ctx);
    }
}

/// Validates that the admin cap belongs to this House.
/// Aborts if the cap's house_id doesn't match.
fun assert_valid_admin_cap(self: &House, house_cap: &HouseAdminCap) {
    assert!(self.id() == house_cap.house_id, EInvalidAdminCap);
}

/// Validates that the transaction cap is valid for this House and game.
/// Aborts if the game is not in the allow list or the house_id doesn't match.
fun assert_valid_tx_cap(self: &House, tx_cap: HouseTransactionCap) {
    let HouseTransactionCap { house_id, game_id } = tx_cap;
    assert!(self.tx_allow_listed.contains(&game_id), EInvalidTxCap);
    assert!(self.id() == house_id, EInvalidTxCap);
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

/// Attempts to activate the House if there is sufficient stake.
/// Funds the play balance if activation succeeds.
fun activate_if_possible(self: &mut House, ctx: &TxContext) {
    // Do nothing if the current epoch is already activated
    if (self.state.is_active()) {
        return
    };
    let activated = self.state.maybe_activate(self.min_activation_balance, ctx);
    if (activated) {
        self.vault.fund_play_balance(self.state.active_stake());
    }
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
    if (!house.tx_allow_listed.contains(&game_id)) {
        house.tx_allow_listed.insert(game_id);
    };
    let cap = HouseTransactionCap {
        house_id: house.id(),
        game_id,
    };
    cap
}

#[test_only]
public fun new_for_testing(
    private: bool,
    min_activation_balance: u64,
    house_fee_bps: u64,
    ctx: &mut TxContext,
): (House, HouseAdminCap) {
    assert!(house_fee_bps < max_bps(), EInvalidFeeConfiguration);
    let admin_cap_id = object::new(ctx);
    let house = House {
        id: object::new(ctx),
        admin_cap_id: admin_cap_id.to_inner(),
        private,
        vault: vault::empty(ctx),
        state: house_state::new(ctx),
        min_activation_balance,
        house_fee_bps,
        games_fee_bps: vec_map::empty(),
        tx_allow_listed: vec_set::empty(),
    };
    let admin_cap = HouseAdminCap {
        id: admin_cap_id,
        house_id: house.id(),
    };

    emit(HouseCreatedEvent {
        house_id: house.id(),
        admin_cap_id: admin_cap.id.to_inner(),
    });

    (house, admin_cap)
}

#[test_only]
public fun add_game_fees_for_testing(
    self: &mut House,
    game_id: ID,
    game_fee: u64,
    ctx: &TxContext,
) {
    self.process_end_of_day(ctx);
    self.vault.process_game_fee(game_id, game_fee);
}
