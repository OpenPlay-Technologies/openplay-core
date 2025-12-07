/// The state module represents the current global state of a game. It maintains all accounts and history.
/// It needs to process all gamerounds to keep the state up to date.
/// It serves a similar function as the State in deepbookv3.
module openplay_core::house_state;

use openplay_core::account::{Self, Account};
use openplay_core::calculations::{actualize_amount, mul_ceil, mul_ceil_bps, mul_floor};
use openplay_core::participation::Participation;
use openplay_core::transaction::{Transaction, is_credit};
use sui::event::emit;
use sui::table::{Self, Table};

// === Structs ===
/// Maintains the global state of a House, tracking accounts, stake, volumes, and history.
/// Processes transactions, manages stake activation/deactivation, and calculates profit/loss sharing.
public struct State has store {
    accounts: Table<ID, Account>,
    epoch: u64, // The current epoch of the state
    is_active: bool, // Boolean that indicates whether a cycle is currently active
    inactive_stake: u64, // Stake that is available to be activated in the next cycle
    active_stake: u64, // Stake that is currently active, this can never change throughout a cycle
    pending_unstake: u64, // The stake from epoch i that will be disactived in epoch i+1
    // Keep track of volumes
    current_volumes: Volumes,
    // All time statistics
    all_time_bet_amount: u128,
    all_time_win_amount: u128,
    all_time_profits: u128,
    all_time_losses: u128,
    // History for cycles, eof, and volumes
    active_history: Table<u64, bool>,
    historic_volumes: Table<u64, Volumes>,
    eod_history: Table<u64, EndOfDay>,
}

/// Volume statistics for a specific epoch, tracking stake and transaction amounts.
public struct Volumes has copy, drop, store {
    active_stake_amount: u64,
    total_bet_amount: u64,
    total_win_amount: u64,
}

/// End-of-day summary containing profits and losses for a specific epoch.
public struct EndOfDay has copy, drop, store {
    day_profits: u64,
    day_losses: u64,
}

/// Event emitted when a House is activated (has sufficient stake).
public struct HouseActivatedEvent has copy, drop {
    active_stake: u64,
}

/// Event emitted when end-of-day processing completes for a State.
public struct StateEndOfDayProcessedEvent has copy, drop {
    epoch: u64,
    profits: u64,
    losses: u64,
    total_bets: u64,
    total_wins: u64,
    active_stake: u64,
}

// === Errors ===
const EUnknownTransaction: u64 = 1;
const EEpochMismatch: u64 = 2;
const ECannotUnstakeMoreThanStaked: u64 = 3;
const EEndOfDayNotAvailable: u64 = 4;
const EEpochHasNotFinishedYet: u64 = 5;
const EVolumeNotAvailable: u64 = 6;
const EInvalidProfitsOrLosses: u64 = 7;
const EHouseIsNotActive: u64 = 8;
const EHouseIsAlreadyActive: u64 = 9;
const EActualizedUnstakeExceedsStake: u64 = 10;

// == Public-View Functions ==
/// Returns whether the House is currently active.
public fun is_active(self: &State): bool {
    self.is_active
}

/// Returns the current epoch of the State.
public fun epoch(self: &State): u64 {
    self.epoch
}

/// Returns the currently active stake amount.
public fun active_stake(self: &State): u64 {
    self.active_stake
}

/// Returns the inactive stake amount (available for activation).
public fun inactive_stake(self: &State): u64 {
    self.inactive_stake
}

/// Returns the pending unstake amount (will be deactivated next epoch).
public fun pending_unstake(self: &State): u64 {
    self.pending_unstake
}

/// Returns the volume statistics for a specific historic epoch.
/// Aborts if the epoch is not found.
public fun volume_for_epoch(self: &State, epoch: u64): Volumes {
    assert!(self.historic_volumes.contains(epoch), EVolumeNotAvailable);
    self.historic_volumes[epoch]
}

/// Returns the all-time total bet amount.
public fun all_time_bet_amount(self: &State): u128 {
    self.all_time_bet_amount
}

/// Returns the all-time total win amount.
public fun all_time_win_amount(self: &State): u128 {
    self.all_time_win_amount
}

/// Returns the all-time total profits.
public fun all_time_profits(self: &State): u128 {
    self.all_time_profits
}

/// Returns the all-time total losses.
public fun all_time_losses(self: &State): u128 {
    self.all_time_losses
}

/// Returns the active stake amount from volumes.
public fun active_stake_amount(volume: &Volumes): u64 {
    volume.active_stake_amount
}

/// Returns the total bet amount from volumes.
public fun total_bet_amount(volume: &Volumes): u64 {
    volume.total_bet_amount
}

/// Returns the total win amount from volumes.
public fun total_win_amount(volume: &Volumes): u64 {
    volume.total_win_amount
}

/// Returns the current epoch's volume statistics.
public fun current_volumes(self: &State): Volumes {
    self.current_volumes
}

/// Returns the end-of-day summary for a specific epoch.
/// Aborts if the epoch is not found.
public fun end_of_day_for_epoch(self: &State, epoch: u64): EndOfDay {
    assert!(self.eod_history.contains(epoch), EEndOfDayNotAvailable);
    self.eod_history[epoch]
}

/// Returns the day profits from an end-of-day summary.
public fun day_profits(eod: &EndOfDay): u64 {
    eod.day_profits
}

/// Returns the day losses from an end-of-day summary.
public fun day_losses(eod: &EndOfDay): u64 {
    eod.day_losses
}

// == Public-Package Functions ==
/// Process the transactions in the given state by updating the history and account.
/// Returns a tuple (credit_balance, debit_balance, game_fee, protocol_fee).
/// The first two values are the to_credit and to_debit balance by the balance manager.
/// The last two values are the fees taken by the game owner and protocol.
/// These are calculated by the state because they might depend on state values (such as volumes).
/// The Vault uses these values to perform any necessary transfers.
public(package) fun process_transactions(
    self: &mut State,
    transactions: &vector<Transaction>,
    balance_manager_id: ID,
    game_fee_bps: u64,
    protocol_fee_bps: u64,
    ctx: &TxContext,
): (u64, u64, u64, u64) {
    self.assert_active();
    self.assert_epoch_up_to_date(ctx);
    self.update_account(balance_manager_id);

    // Process transactions on the account
    self.process_transactions_for_account(balance_manager_id, transactions);

    // Process transactions for the history
    self.process_volumes(transactions);

    // Calculate fees (round UP to favor protocol)
    let game_fee = calculate_fee(transactions, game_fee_bps);
    let protocol_fee = calculate_fee(transactions, protocol_fee_bps);

    // Settle account balance
    let (credit_balance, debit_balance) = self.accounts[balance_manager_id].settle();

    (credit_balance, debit_balance, game_fee, protocol_fee)
}

/// Processes a stake transaction in the game.
public(package) fun process_stake(self: &mut State, amount: u64, ctx: &TxContext) {
    self.assert_epoch_up_to_date(ctx);
    // Add the stake to the pending stake of this epoch
    // It will become active in the next epoch
    self.add_stake(amount);
}

/// Processes an unstake.
/// Takes two arguments:
/// `other_stake_removed` is the stake that was removed, this can be inactive or active stake depending on the house state.
/// `pending_stake_removed` is pending stake that was removed. This is the stake that was supposed to become active in the next epoch, but cancelled now.
/// If the house is active, then the removed stake need to be queued through the `pending_unstake` balance. This will go in effect next epoch.
/// If the house is inactive, then the removed stake can be deducted from the `inactive_stake` balance immediately.
public(package) fun process_unstake(
    self: &mut State,
    other_stake_removed: u64,
    pending_stake_removed: u64,
    ctx: &TxContext,
) {
    self.assert_epoch_up_to_date(ctx);
    // Can only remove stake if the state is up to date
    assert!(ctx.epoch() == self.epoch, EEpochMismatch);

    if (self.is_active) {
        self.add_pending_unstake(other_stake_removed);
    } else {
        self.remove_inactive_stake(other_stake_removed);
    };
    self.remove_inactive_stake(pending_stake_removed);
}

/// Advances the epoch: updates the history and saves the end of day of the house.
/// Fails if the epoch that is trying to be processed is not the last known one.
/// Also fails if the epoch is in the future or not finished yet.
/// Returns the stake amount for the new epoch.
public(package) fun process_end_of_day(
    self: &mut State,
    epoch: u64,
    profits: u64,
    losses: u64,
    ctx: &TxContext,
) {
    // We can only process an epoch after it has been finished
    assert!(ctx.epoch() > self.epoch, EEpochHasNotFinishedYet);

    // We can only process the epoch that we are currently on
    // This means that the vault and state epochs need to be kept in sync
    assert!(self.epoch == epoch, EEpochMismatch);

    // Make sure the chain is correct, and only profits OR losses are reported
    assert!(losses == 0 || profits == 0, EInvalidProfitsOrLosses);

    // The new staked amount is
    // 1) the previous stake amount
    // 2) plus profits or minus losses
    // 3) minus the pending unstake (actualized)
    // 4) plus the pending stake
    let prev_active_stake_amount = self.current_volumes.active_stake_amount;
    let mut new_active_stake_amount = prev_active_stake_amount;

    if (profits > 0) {
        new_active_stake_amount = new_active_stake_amount + profits
    } else if (losses > 0) {
        assert!(new_active_stake_amount >= losses, EInvalidProfitsOrLosses);
        new_active_stake_amount = new_active_stake_amount - losses;
    };

    // The pending unstake need to be actualized to get the actual unstake amount
    // The reason for this is:
    // - If you unstake you still need to bear the losses or receive the winnings from that epoch
    // => If you receive winnings, then the actual unstake amount is greater than the pending unstake amount
    // => If you bear losses, then the actual unstake amount is smaller than the pending unstake amount
    if (self.pending_unstake > 0) {
        // Calculate the actual unstake amount
        // Round UP for losses (user gets less, protocol keeps more)
        // Round DOWN for profits (user gets less, protocol pays less)
        let round_up = losses > 0;
        let actual_unstake_amount = actualize_amount(
            self.pending_unstake,
            profits,
            losses,
            prev_active_stake_amount,
            round_up,
        );

        // Assert that actualized unstake amount does not exceed remaining stake.
        // This is mathematically guaranteed by our rounding strategy (same proof as in participation.move).
        // If this assertion fails, it indicates a bug in rounding logic or constraint enforcement.
        assert!(actual_unstake_amount <= new_active_stake_amount, EActualizedUnstakeExceedsStake);

        // Deduct the actualized unstake amount from remaining stake
        new_active_stake_amount = new_active_stake_amount - actual_unstake_amount;
    };

    // Update the current active stake by the new amount
    self.active_stake = new_active_stake_amount;
    self.pending_unstake = 0;

    // Desactivate the state
    let was_active = self.is_active;
    self.desactivate();

    // Reset the volumes
    let prev_volume = self.current_volumes;
    self.current_volumes = new_volumes();

    // Save the history eod, volume, active
    self.historic_volumes.add(epoch, prev_volume);
    self.active_history.add(epoch, was_active);
    let eod = EndOfDay {
        day_profits: profits,
        day_losses: losses,
    };
    self.eod_history.add(epoch, eod);

    // Update the all time statistics
    self.all_time_losses = self.all_time_losses + (losses as u128);
    self.all_time_profits = self.all_time_profits + (profits as u128);

    // Update the epoch
    self.epoch = ctx.epoch();

    // Emit event
    emit(StateEndOfDayProcessedEvent {
        epoch: epoch,
        profits: profits,
        losses: losses,
        total_bets: prev_volume.total_bet_amount,
        total_wins: prev_volume.total_win_amount,
        active_stake: prev_volume.active_stake_amount,
    })
}

/// Creates a new State with all values initialized to zero and epoch set to current epoch.
public(package) fun new(ctx: &mut TxContext): State {
    State {
        accounts: table::new(ctx),
        epoch: ctx.epoch(),
        is_active: false,
        inactive_stake: 0,
        active_stake: 0,
        pending_unstake: 0,
        // Keep track of volumes
        current_volumes: new_volumes(),
        // All time statistics
        all_time_bet_amount: 0,
        all_time_win_amount: 0,
        all_time_profits: 0,
        all_time_losses: 0,
        // History for cycles, eof, and volumes
        active_history: table::new(ctx),
        historic_volumes: table::new(ctx),
        eod_history: table::new(ctx),
    }
}

/// This function can be used to settle any remaining balances on the account.
/// This can be used to claim profits or to claim unstaked amount that can available.
/// Returns a tuple (credit_balance, debit_balance).
/// The Vault uses thes values to perform any necessary transfers in the balance manager.
///
/// By default, processes all epochs. Use `refresh_with_limit` to limit epochs processed per call.
public(package) fun refresh(self: &State, participation: &mut Participation, ctx: &TxContext) {
    self.update_participation(participation, std::u64::max_value!(), ctx); // u64::MAX
}

/// Same as `refresh` but allows limiting the number of epochs processed per call.
/// Returns `true` if all epochs were processed, `false` if more epochs remain.
/// Useful for catching up participations that haven't been updated for many epochs.
public(package) fun refresh_with_limit(
    self: &State,
    participation: &mut Participation,
    max_epochs: u64,
    ctx: &TxContext,
): bool {
    self.update_participation(participation, max_epochs, ctx)
}

/// Function that activates the house if 1) it is not active yet and 2) there is enough pending stake.
/// Returns true if the state was activated, false if nothing changed.
public(package) fun maybe_activate(
    self: &mut State,
    min_activation_balance: u64,
    ctx: &TxContext,
): bool {
    // Can only activate if up to date
    self.assert_epoch_up_to_date(ctx);

    // No need to do anything if the house is already active
    if (self.is_active()) {
        return false
    };

    // Check if there is enough pending stake to activate
    if (self.inactive_stake >= min_activation_balance) {
        self.activate();
        return true
    };

    false
}

/// Returns `true` if the provided epoch was active, and `false` if the epoch was inactive.
/// Crashes if the provided epoch number is unseen.
public(package) fun epoch_active(self: &State, epoch: u64): bool {
    // Check if the epoch is in the future
    assert!(epoch <= self.epoch, EEpochMismatch);

    // Check if it is the current epoch
    if (self.epoch == epoch) {
        return self.is_active()
    };
    // Return false if the epoch was not in the history
    if (!self.active_history.contains(epoch)) {
        return false
    };

    self.active_history[epoch]
}

/// Returns the active stake amount for a specific epoch.
/// Returns 0 if the epoch is not in history or is in the future.
public(package) fun active_stake_at_epoch(self: &State, epoch: u64): u64 {
    // Check if the epoch is in the future
    assert!(epoch <= self.epoch, EEpochMismatch);

    // Check if it is the current epoch
    if (self.epoch == epoch) {
        return self.active_stake
    };
    // Return 0 if the epoch was not in the history
    if (!self.active_history.contains(epoch)) {
        return 0
    };

    self.volume_for_epoch(epoch).active_stake_amount()
}

/// Calculates the gross gaming revenue (GGR) share for an account's stake in a specific epoch.
/// Returns (profits, losses) where profits and losses are the account's proportional share.
/// Returns (0, 0) if epoch data is unavailable, no stake, or house was inactive.
public(package) fun calculate_ggr_share(self: &State, epoch: u64, account_stake: u64): (u64, u64) {
    // If the epoch data is unavailable, there is no ggr_share
    if (
        !self.historic_volumes.contains(epoch) || !self.eod_history.contains(epoch) || !self.active_history.contains(epoch)
    ) {
        return (0, 0)
    };
    let epoch_volume = &self.historic_volumes[epoch];
    let end_of_day = &self.eod_history[epoch];
    let was_active = self.active_history[epoch];

    // If there was no stake, or no active cycle, there is no ggr_share
    if (epoch_volume.active_stake_amount == 0 || !was_active) {
        return (0, 0)
    };

    if (end_of_day.day_losses > 0) {
        // Round UP losses (users owe more) - favors protocol
        let losses = mul_ceil(
            end_of_day.day_losses,
            account_stake,
            epoch_volume.active_stake_amount,
        );
        return (0, losses)
    };
    if (end_of_day.day_profits > 0) {
        // Round DOWN profits (protocol pays less) - favors protocol
        let profits = mul_floor(
            end_of_day.day_profits,
            account_stake,
            epoch_volume.active_stake_amount,
        );
        return (profits, 0)
    };
    return (0, 0)
}

// == Private Functions ==
/// Advances the participation state to the latest epoch by processing missed epochs.
/// Calculates and applies profit/loss shares for each epoch between last_updated_epoch and current epoch.
///
/// # Parameters
/// - `max_epochs`: Maximum number of epochs to process in this call. Use `u64::MAX` to process all epochs (default behavior).
///                  This prevents DoS attacks when a participation hasn't been updated for many epochs.
///
/// # Returns
/// Returns `true` if all epochs were processed, `false` if more epochs remain to be processed.
fun update_participation(
    self: &State,
    participation: &mut Participation,
    max_epochs: u64,
    ctx: &TxContext,
): bool {
    let (
        mut current_participation_epoch,
        mut stake,
        mut _pending_stake,
        mut _pending_unstake,
    ) = participation.current_state();

    let target_epoch = ctx.epoch();
    let mut epochs_processed = 0;

    // process the account's ggr share for epochs between the last activate epoch and the current one
    // but limit the number of epochs processed to prevent DoS
    while (current_participation_epoch < target_epoch && epochs_processed < max_epochs) {
        let (epoch_profits, epoch_losses) = self.calculate_ggr_share(
            current_participation_epoch,
            stake,
        );

        participation.process_end_of_day(
            current_participation_epoch,
            epoch_profits,
            epoch_losses,
            ctx,
        );

        (current_participation_epoch, stake, _pending_stake, _pending_unstake) =
            participation.current_state();

        epochs_processed = epochs_processed + 1;
    };

    // Return true if we've caught up to the current epoch, false if more epochs remain
    current_participation_epoch >= target_epoch
}

/// Ensures an account exists for the given balance_manager_id.
/// Creates a new empty account if one doesn't exist.
fun update_account(self: &mut State, balance_manager_id: ID) {
    if (!self.accounts.contains(balance_manager_id)) {
        self.accounts.add(balance_manager_id, account::empty());
    };
}

/// Processes the transactions for an account by increasing the debit or credit balance based on the transaction types.
fun process_transactions_for_account(
    self: &mut State,
    balance_manager_id: ID,
    transactions: &vector<Transaction>,
) {
    transactions.do_ref!<Transaction, ()>(|tx| {
        if (tx.is_credit()) {
            self.accounts[balance_manager_id].credit(tx.amount())
        } else if (tx.is_debit()) {
            self.accounts[balance_manager_id].debit(tx.amount())
        } else {
            // should never happen!
            abort EUnknownTransaction
        }
    });
}

/// Processes the transactions for the history by updating the statistics.
fun process_volumes(self: &mut State, transactions: &vector<Transaction>) {
    transactions.do_ref!<Transaction, ()>(|tx| {
        let amount = tx.amount();
        if (tx.is_credit()) {
            self.process_win(amount);
        } else if (tx.is_debit()) {
            self.process_bet(amount);
        } else {
            // should never happen!
            abort EUnknownTransaction
        }
    });
}

/// Calculates the total fee based on debit transactions and a fee in basis points.
/// Only bet (debit) transactions are subject to fees.
/// Rounds UP to favor the protocol (collects slightly more fees).
fun calculate_fee(transactions: &vector<Transaction>, fee_bps: u64): u64 {
    let mut total_fee = 0;
    transactions.do_ref!(|tx| {
        if (tx.is_debit()) {
            // Round UP to favor protocol
            let fee_amount = mul_ceil_bps(tx.amount(), fee_bps);
            total_fee = total_fee + fee_amount
        }
    });
    total_fee
}

/// Activates the House state by moving inactive stake to active stake.
/// Aborts if the state is already active.
fun activate(self: &mut State) {
    // Can only activate if not activated yet
    assert!(self.is_active == false, EHouseIsAlreadyActive);

    // Activate the state by setting is_active to `true` and moving the stake from inactive_to_active
    self.is_active = true;
    self.active_stake = self.inactive_stake;
    self.inactive_stake = 0;
    self.current_volumes.active_stake_amount = self.active_stake;

    // Event
    emit(HouseActivatedEvent {
        active_stake: self.active_stake,
    })
}

/// Processes a bet transaction by updating volume statistics.
fun process_bet(self: &mut State, amount: u64) {
    self.current_volumes.total_bet_amount = self.current_volumes.total_bet_amount + amount;
    self.all_time_bet_amount = self.all_time_bet_amount + (amount as u128);
}

/// Processes a win transaction by updating volume statistics.
fun process_win(self: &mut State, amount: u64) {
    self.current_volumes.total_win_amount = self.current_volumes.total_win_amount + amount;
    self.all_time_win_amount = self.all_time_win_amount + (amount as u128);
}

/// Removes stake from the inactive stake balance.
/// Aborts if attempting to remove more than available.
fun remove_inactive_stake(self: &mut State, amount: u64) {
    assert!(self.inactive_stake >= amount, ECannotUnstakeMoreThanStaked);
    self.inactive_stake = self.inactive_stake - amount;
}

/// Adds amount to the pending unstake balance (will be deactivated next epoch).
fun add_pending_unstake(self: &mut State, amount: u64) {
    self.pending_unstake = self.pending_unstake + amount;
}

/// Adds stake to the inactive stake balance.
fun add_stake(self: &mut State, amount: u64) {
    self.inactive_stake = self.inactive_stake + amount;
}

/// Deactivates the state by moving active stake back to inactive and setting is_active to false.
/// Called at end of epoch to reset for the next cycle.
fun desactivate(self: &mut State) {
    self.inactive_stake = self.inactive_stake + self.active_stake;
    self.active_stake = 0;
    self.is_active = false;
}

/// Creates a new Volumes struct with all values initialized to zero.
fun new_volumes(): Volumes {
    Volumes {
        active_stake_amount: 0,
        total_bet_amount: 0,
        total_win_amount: 0,
    }
}

/// Asserts that the House is currently active.
/// Aborts if the House is not active.
fun assert_active(self: &State) {
    assert!(self.is_active == true, EHouseIsNotActive);
}

/// Asserts that the State's epoch matches the current transaction epoch.
/// Aborts if epochs don't match.
fun assert_epoch_up_to_date(self: &State, ctx: &TxContext) {
    assert!(self.epoch == ctx.epoch(), EEpochMismatch);
}
