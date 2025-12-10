/// The state module represents the current global state of a game. It maintains all accounts and history.
/// It needs to process all gamerounds to keep the state up to date.
/// It serves a similar function as the State in deepbookv3.
module openplay_core::house_state;

use openplay_core::account::{Self, Account};
use openplay_core::calculations::mul_ceil_bps;
use openplay_core::transaction::{Transaction, is_credit};
use sui::event::emit;
use sui::table::{Self, Table};
use sui::vec_map::{Self, VecMap};

// === Structs ===
/// Maintains the global state of a House, tracking accounts, volumes, and history.
/// Processes transactions and calculates profit/loss sharing using the share-based model.
public struct State has store {
    house_id: ID,
    accounts: Table<ID, Account>,
    epoch: u64, // The current epoch of the state
    // Keep track of volumes
    current_volumes: Volumes,
    // All time statistics
    all_time_bet_amount: u128,
    all_time_win_amount: u128,
    all_time_profits: u128,
    all_time_losses: u128,
    // History for eof and volumes
    historic_volumes: Table<u64, Volumes>,
    // Share model
    total_shares: u64,
    // Fees for current epoch (fixed at epoch start)
    current_epoch_protocol_fee_bps: u64,
    current_epoch_house_fee_bps: u64,
    current_epoch_fee_collector_share_bps: u64,
    // Fee collector tracking - current epoch
    current_collector_ggr: VecMap<ID, CollectorGGR>,
    // Fee collector tracking - historical (epoch -> collector_id -> GGR)
    historic_collector_ggr: Table<u64, VecMap<ID, CollectorGGR>>,
}

/// Volume statistics for a specific epoch, tracking stake and transaction amounts.
public struct Volumes has copy, drop, store {
    total_bet_amount: u64,
    total_win_amount: u64,
}

/// Tracks GGR for a fee collector within the current epoch.
public struct CollectorGGR has copy, drop, store {
    bet_amount: u128,
    win_amount: u128,
}

/// Creates an empty CollectorGGR with zero values.
public fun empty_collector_ggr(): CollectorGGR {
    CollectorGGR {
        bet_amount: 0,
        win_amount: 0,
    }
}

/// Returns the bet amount from a CollectorGGR.
public fun bet_amount(ggr: &CollectorGGR): u128 {
    ggr.bet_amount
}

/// Returns the win amount from a CollectorGGR.
public fun win_amount(ggr: &CollectorGGR): u128 {
    ggr.win_amount
}

/// Helper struct for returning collector fee information.
public struct CollectorFee has copy, drop {
    collector_id: ID,
    fee_amount: u64,
}

/// Returns the collector ID from a CollectorFee.
public fun collector_id(fee: &CollectorFee): ID {
    fee.collector_id
}

/// Returns the fee amount from a CollectorFee.
public fun fee_amount(fee: &CollectorFee): u64 {
    fee.fee_amount
}

// === Events ===
/// Event emitted when end-of-day processing completes for a State.
public struct StateEndOfDayProcessedEvent has copy, drop {
    house_id: ID,
    epoch: u64,
    profits: u64,
    losses: u64,
    total_bets: u64,
    total_wins: u64,
}

// === Errors ===
const EUnknownTransaction: u64 = 1;
const EEpochMismatch: u64 = 2;
const ECannotUnstakeMoreThanStaked: u64 = 3;
const EEpochHasNotFinishedYet: u64 = 5;
const EVolumeNotAvailable: u64 = 6;

// === View Functions ===
/// Returns the current epoch of the State.
public fun epoch(self: &State): u64 {
    self.epoch
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

/// Returns total shares in circulation.
public fun total_shares(self: &State): u64 {
    self.total_shares
}

/// Returns the current epoch's protocol fee bps.
public fun current_epoch_protocol_fee_bps(self: &State): u64 {
    self.current_epoch_protocol_fee_bps
}

/// Returns the current epoch's house fee bps.
public fun current_epoch_house_fee_bps(self: &State): u64 {
    self.current_epoch_house_fee_bps
}

/// Returns the current epoch's fee collector share bps.
public fun current_epoch_fee_collector_share_bps(self: &State): u64 {
    self.current_epoch_fee_collector_share_bps
}

/// Returns the current epoch's collector GGR for a specific collector.
/// Returns a CollectorGGR with zero values if collector is not found or has no activity.
public fun current_collector_ggr(self: &State, collector_id: ID): CollectorGGR {
    if (vec_map::contains(&self.current_collector_ggr, &collector_id)) {
        *vec_map::get(&self.current_collector_ggr, &collector_id)
    } else {
        empty_collector_ggr()
    }
}

/// Returns the collector GGR for a specific collector in a specific epoch.
/// Returns a CollectorGGR with zero values if epoch or collector is not found.
public fun historic_collector_ggr(self: &State, epoch: u64, collector_id: ID): CollectorGGR {
    if (!self.historic_collector_ggr.contains(epoch)) {
        return empty_collector_ggr()
    };
    let epoch_ggr = &self.historic_collector_ggr[epoch];
    if (vec_map::contains(epoch_ggr, &collector_id)) {
        *vec_map::get(epoch_ggr, &collector_id)
    } else {
        empty_collector_ggr()
    }
}

// === Package Functions ===
/// Process the transactions in the given state by updating the history and account.
/// Returns a tuple (credit_balance, debit_balance).
/// These values are the to_credit and to_debit balance by the balance manager.
/// Fees are GGR-based and calculated at epoch end, not during transaction processing.
/// The House orchestrates the flow between State and Vault.
public(package) fun process_transactions(
    self: &mut State,
    transactions: &vector<Transaction>,
    balance_manager_id: ID,
    fee_collector_id: ID,
    ctx: &TxContext,
): (u64, u64) {
    self.assert_epoch_up_to_date(ctx);
    self.update_account(balance_manager_id);

    // Process transactions on the account
    self.process_transactions_for_account(balance_manager_id, transactions);

    // Process transactions for the history (includes fee collector GGR tracking)
    // Fees are now GGR-based and calculated at epoch end, not during transaction processing
    self.process_volumes(transactions, fee_collector_id);

    // Settle account balance
    let (credit_balance, debit_balance) = self.accounts[balance_manager_id].settle();

    (credit_balance, debit_balance)
}

/// Mints new shares. Called when user buys in.
public(package) fun mint_shares(self: &mut State, shares: u64) {
    self.total_shares = self.total_shares + shares;
}

/// Burns shares. Called when user sells.
public(package) fun burn_shares(self: &mut State, shares: u64) {
    assert!(self.total_shares >= shares, ECannotUnstakeMoreThanStaked);
    self.total_shares = self.total_shares - shares;
}

/// Calculates total pending collector fees for NAV calculation.
/// This is the sum of all pending fees across all collectors for the current epoch.
/// Uses the epoch-specific fee_collector_share_bps from state.
public(package) fun calculate_pending_collector_fees(self: &State): u64 {
    let mut total_pending = 0u64;

    // Iterate through all collectors using index-based access (O(1) per entry)
    // to avoid O(N²) complexity from keys() + get()
    let len = vec_map::length(&self.current_collector_ggr);
    let mut i = 0;

    while (i < len) {
        let (_, ggr) = vec_map::get_entry_by_idx(&self.current_collector_ggr, i);

        // Calculate GGR: bet_amount - win_amount
        let ggr_amount = if (ggr.bet_amount > ggr.win_amount) {
            (ggr.bet_amount - ggr.win_amount) as u64
        } else {
            0u64
        };

        // Calculate fee: GGR * fee_collector_share_bps / 10000
        // Round UP to favor protocol
        let fee = mul_ceil_bps(ggr_amount, self.current_epoch_fee_collector_share_bps);
        total_pending = total_pending + fee;

        i = i + 1;
    };

    total_pending
}

/// Calculates pending house performance fees based on GGR during the current epoch.
/// House fees are calculated on GGR: (bet_amount - win_amount) * house_fee_bps.
/// Returns 0 if there's no GGR or if house_fee_bps is 0.
/// Uses the epoch-specific house_fee_bps from state.
public(package) fun calculate_pending_house_fees(self: &State): u64 {
    if (self.current_epoch_house_fee_bps == 0) {
        return 0
    };

    // Calculate GGR: bet_amount - win_amount
    let ggr = if (self.current_volumes.total_bet_amount > self.current_volumes.total_win_amount) {
        self.current_volumes.total_bet_amount - self.current_volumes.total_win_amount
    } else {
        0
    };

    if (ggr == 0) {
        return 0
    };

    // Calculate fee: GGR * house_fee_bps / 10000
    // Round UP to favor protocol
    mul_ceil_bps(ggr, self.current_epoch_house_fee_bps)
}

/// Calculates pending protocol fees based on GGR during the current epoch.
/// Uses the protocol fee stored in state for the current epoch.
/// Returns 0 if there's no GGR or if protocol_fee_bps is 0.
public(package) fun calculate_pending_protocol_fees(self: &State): u64 {
    if (self.current_epoch_protocol_fee_bps == 0) {
        return 0
    };

    // Calculate GGR: bet_amount - win_amount
    let ggr = if (self.current_volumes.total_bet_amount > self.current_volumes.total_win_amount) {
        self.current_volumes.total_bet_amount - self.current_volumes.total_win_amount
    } else {
        0
    };

    if (ggr == 0) {
        return 0
    };

    // Calculate fee: GGR * protocol_fee_bps / 10000
    // Round UP to favor protocol
    mul_ceil_bps(ggr, self.current_epoch_protocol_fee_bps)
}

/// Calculates total pending fees (protocol + house + collector) for NAV calculation.
/// This is more efficient than calculating each fee separately.
/// Returns the total amount of pending fees that reduce NAV during the epoch.
/// Uses the epoch-specific fees from state.
public(package) fun calculate_total_pending_fees(self: &State): u64 {
    // Calculate GGR: bet_amount - win_amount
    let ggr = if (self.current_volumes.total_bet_amount > self.current_volumes.total_win_amount) {
        self.current_volumes.total_bet_amount - self.current_volumes.total_win_amount
    } else {
        0
    };

    if (ggr == 0) {
        return 0
    };

    // Calculate total fee bps: protocol + house + collector
    let total_fee_bps =
        self.current_epoch_protocol_fee_bps + self.current_epoch_house_fee_bps + self.current_epoch_fee_collector_share_bps;

    // Calculate total fee: GGR * total_fee_bps / 10000
    // Round UP to favor protocol
    mul_ceil_bps(ggr, total_fee_bps)
}

/// Processes end of day for collectors - returns fees per collector.
/// Saves current GGR to history and resets for new epoch.
/// Returns vector of CollectorFee structs.
/// Uses the epoch-specific fee_collector_share_bps from state.
public(package) fun process_collector_end_of_day(
    self: &mut State,
    epoch: u64,
    _ctx: &mut TxContext,
): vector<CollectorFee> {
    let mut fees = vector::empty<CollectorFee>();

    // Save current GGR to history before processing
    // Create a copy of current_collector_ggr for history
    let mut historic_ggr = vec_map::empty<ID, CollectorGGR>();
    let len = vec_map::length(&self.current_collector_ggr);
    let mut i = 0;

    // First pass: copy to history and calculate fees using index-based access (O(1) per entry)
    // to avoid O(N²) complexity from keys() + get()
    while (i < len) {
        let (collector_id, ggr) = vec_map::get_entry_by_idx(&self.current_collector_ggr, i);

        // Copy GGR to history
        vec_map::insert(&mut historic_ggr, *collector_id, *ggr);

        // Calculate GGR: bet_amount - win_amount
        let ggr_amount = if (ggr.bet_amount > ggr.win_amount) {
            (ggr.bet_amount - ggr.win_amount) as u64
        } else {
            0u64
        };

        // Calculate fee: GGR * fee_collector_share_bps / 10000
        // Round UP to favor protocol
        let fee = mul_ceil_bps(ggr_amount, self.current_epoch_fee_collector_share_bps);

        if (fee > 0) {
            vector::push_back(
                &mut fees,
                CollectorFee {
                    collector_id: *collector_id,
                    fee_amount: fee,
                },
            );
        };

        i = i + 1;
    };

    // Second pass: reset GGR for new epoch using index-based mutable access (O(1) per entry)
    i = 0;
    while (i < len) {
        let (_, ggr_mut) = vec_map::get_entry_by_idx_mut(&mut self.current_collector_ggr, i);
        ggr_mut.bet_amount = 0;
        ggr_mut.win_amount = 0;
        i = i + 1;
    };

    // Save to history if there was any collector activity
    if (vec_map::length(&historic_ggr) > 0) {
        self.historic_collector_ggr.add(epoch, historic_ggr);
    };

    fees
}

/// Advances the epoch: updates the history and saves the end of day of the house.
/// Fails if the epoch that is trying to be processed is not the last known one.
/// Also fails if the epoch is in the future or not finished yet.
/// Calculates profits from volumes (bet - win) and all fees from GGR.
/// Captures the new epoch's fees (house_fee_bps, fee_collector_share_bps, protocol_fee_bps) at epoch start.
/// Returns (collector_fees, house_fee, protocol_fee) that need to be processed by the vault.
public(package) fun process_end_of_day(
    self: &mut State,
    epoch: u64,
    house_fee_bps: u64,
    fee_collector_share_bps: u64,
    protocol_fee_bps: u64,
    ctx: &mut TxContext,
): (vector<CollectorFee>, u64, u64) {
    // We can only process an epoch after it has been finished
    assert!(ctx.epoch() > self.epoch, EEpochHasNotFinishedYet);

    // We can only process the epoch that we are currently on
    assert!(self.epoch == epoch, EEpochMismatch);

    // Process collector fees and save GGR to history before saving other history
    // This happens when GGR is moved to history
    // Use current epoch's fee_collector_share_bps for calculations
    let collector_fees = process_collector_end_of_day(
        self,
        epoch,
        ctx,
    );

    // Reset the volumes (save before resetting)
    let prev_volume = self.current_volumes;
    self.current_volumes = new_volumes();

    // Calculate GGR (bet - win) from the epoch we're processing
    // This represents the profits for the epoch
    let ggr = if (prev_volume.total_bet_amount > prev_volume.total_win_amount) {
        prev_volume.total_bet_amount - prev_volume.total_win_amount
    } else {
        0
    };

    // Calculate profits and losses from GGR
    let profits = ggr;
    let losses = if (prev_volume.total_win_amount > prev_volume.total_bet_amount) {
        prev_volume.total_win_amount - prev_volume.total_bet_amount
    } else {
        0
    };

    // Calculate all fees based on GGR (all fees are GGR-based)
    // Use current epoch's fees for calculations
    let house_fee = if (self.current_epoch_house_fee_bps > 0 && ggr > 0) {
        mul_ceil_bps(ggr, self.current_epoch_house_fee_bps)
    } else {
        0
    };

    let protocol_fee = if (self.current_epoch_protocol_fee_bps > 0 && ggr > 0) {
        mul_ceil_bps(ggr, self.current_epoch_protocol_fee_bps)
    } else {
        0
    };

    // Save the history eod and volume
    self.historic_volumes.add(epoch, prev_volume);

    // Update the all time statistics
    self.all_time_losses = self.all_time_losses + (losses as u128);
    self.all_time_profits = self.all_time_profits + (profits as u128);

    // Update the epoch and store fees for the new epoch (captured at epoch start)
    self.epoch = ctx.epoch();
    self.current_epoch_protocol_fee_bps = protocol_fee_bps;
    self.current_epoch_house_fee_bps = house_fee_bps;
    self.current_epoch_fee_collector_share_bps = fee_collector_share_bps;

    // Emit event
    emit(StateEndOfDayProcessedEvent {
        house_id: self.house_id,
        epoch: epoch,
        profits: profits,
        losses: losses,
        total_bets: prev_volume.total_bet_amount,
        total_wins: prev_volume.total_win_amount,
    });

    (collector_fees, house_fee, protocol_fee)
}

/// Creates a new State with all values initialized to zero and epoch set to current epoch.
/// The fees are captured at creation time for the first epoch.
public(package) fun new(
    house_id: ID,
    protocol_fee_bps: u64,
    house_fee_bps: u64,
    fee_collector_share_bps: u64,
    ctx: &mut TxContext,
): State {
    State {
        house_id,
        accounts: table::new(ctx),
        epoch: ctx.epoch(),
        // Keep track of volumes
        current_volumes: new_volumes(),
        // All time statistics
        all_time_bet_amount: 0,
        all_time_win_amount: 0,
        all_time_profits: 0,
        all_time_losses: 0,
        // History for eof and volumes
        historic_volumes: table::new(ctx),
        // Share model
        total_shares: 0,
        // Fee collector tracking - current epoch
        current_collector_ggr: vec_map::empty(),
        // Fee collector tracking - historical
        historic_collector_ggr: table::new(ctx),
        // Fees for current epoch (captured at epoch start)
        current_epoch_protocol_fee_bps: protocol_fee_bps,
        current_epoch_house_fee_bps: house_fee_bps,
        current_epoch_fee_collector_share_bps: fee_collector_share_bps,
    }
}

// === Private Functions ===

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
/// Also tracks GGR for the fee collector.
fun process_volumes(self: &mut State, transactions: &vector<Transaction>, fee_collector_id: ID) {
    transactions.do_ref!<Transaction, ()>(|tx| {
        let amount = tx.amount();
        if (tx.is_credit()) {
            self.process_win(amount, fee_collector_id);
        } else if (tx.is_debit()) {
            self.process_bet(amount, fee_collector_id);
        } else {
            // should never happen!
            abort EUnknownTransaction
        }
    });
}

/// Processes a bet transaction by updating volume statistics and fee collector GGR.
fun process_bet(self: &mut State, amount: u64, fee_collector_id: ID) {
    self.current_volumes.total_bet_amount = self.current_volumes.total_bet_amount + amount;
    self.all_time_bet_amount = self.all_time_bet_amount + (amount as u128);

    // Update fee collector GGR (auto-register if needed)
    self.update_collector_ggr_bet(fee_collector_id, amount);
}

/// Processes a win transaction by updating volume statistics and fee collector GGR.
fun process_win(self: &mut State, amount: u64, fee_collector_id: ID) {
    self.current_volumes.total_win_amount = self.current_volumes.total_win_amount + amount;
    self.all_time_win_amount = self.all_time_win_amount + (amount as u128);

    // Update fee collector GGR (auto-register if needed)
    self.update_collector_ggr_win(fee_collector_id, amount);
}

/// Updates bet amount for a fee collector. Auto-registers if not already present.
fun update_collector_ggr_bet(self: &mut State, fee_collector_id: ID, bet_amount: u64) {
    // Ensure collector is registered
    if (!vec_map::contains(&self.current_collector_ggr, &fee_collector_id)) {
        vec_map::insert(&mut self.current_collector_ggr, fee_collector_id, empty_collector_ggr());
    };

    let ggr = vec_map::get_mut(&mut self.current_collector_ggr, &fee_collector_id);
    ggr.bet_amount = ggr.bet_amount + (bet_amount as u128);
}

/// Updates win amount for a fee collector. Auto-registers if not already present.
fun update_collector_ggr_win(self: &mut State, fee_collector_id: ID, win_amount: u64) {
    // Ensure collector is registered
    if (!vec_map::contains(&self.current_collector_ggr, &fee_collector_id)) {
        vec_map::insert(&mut self.current_collector_ggr, fee_collector_id, empty_collector_ggr());
    };

    let ggr = vec_map::get_mut(&mut self.current_collector_ggr, &fee_collector_id);
    ggr.win_amount = ggr.win_amount + (win_amount as u128);
}

/// Creates a new Volumes struct with all values initialized to zero.
fun new_volumes(): Volumes {
    Volumes {
        total_bet_amount: 0,
        total_win_amount: 0,
    }
}

/// Asserts that the State's epoch matches the current transaction epoch.
/// Aborts if epochs don't match.
fun assert_epoch_up_to_date(self: &State, ctx: &TxContext) {
    assert!(self.epoch == ctx.epoch(), EEpochMismatch);
}
