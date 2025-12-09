/// Module for tracking game statistics including bet/win volumes per epoch and all-time.
module openplay_core::game_stats;

use openplay_core::transaction::Transaction;
use sui::table::{Self, Table};

// === Errors ===
/// Error code for unknown transaction types.
const EUnknownTransaction: u64 = 1;
/// Error code when requested epoch is not found in historic volumes.
const EEpochNotFound: u64 = 2;

// === Structs ===

/// Shared object that tracks statistics for a specific game.
/// Maintains current epoch volumes, historic volumes per epoch, and all-time totals.
public struct GameStatistics has key {
    id: UID,
    game_id: ID,
    epoch: u64,
    // Per-Epoch Volumes
    current_volumes: Volumes,
    historic_volumes: Table<u64, Volumes>,
    // All time volumes
    all_time_volumes: Volumes,
}

/// Volume statistics tracking bet and win amounts and counts.
public struct Volumes has copy, drop, store {
    bet_sum: u128,
    bet_count: u128,
    win_sum: u128,
    win_count: u128,
}

// === View Functions ===
/// Returns the game ID associated with these statistics.
public fun game_id(self: &GameStatistics): ID {
    self.game_id
}

/// Returns the ID of the GameStatistics object.
public fun id(self: &GameStatistics): ID {
    self.id.to_inner()
}

/// Returns the current epoch's volume statistics.
public fun current_volumes(self: &GameStatistics): Volumes {
    self.current_volumes
}

/// Returns the all-time volume statistics across all epochs.
public fun all_time_volumes(self: &GameStatistics): Volumes {
    self.all_time_volumes
}

/// Returns the volume statistics for a specific historic epoch.
/// Aborts if the epoch is not found.
public fun historic_volumes(self: &GameStatistics, epoch: u64): Volumes {
    assert!(self.historic_volumes.contains(epoch), EEpochNotFound);
    self.historic_volumes[epoch]
}

/// Returns the total bet amount from the volumes.
public fun bet_sum(volumes: &Volumes): u128 {
    volumes.bet_sum
}

/// Returns the total bet count from the volumes.
public fun bet_count(volumes: &Volumes): u128 {
    volumes.bet_count
}

/// Returns the total win amount from the volumes.
public fun win_sum(volumes: &Volumes): u128 {
    volumes.win_sum
}

/// Returns the total win count from the volumes.
public fun win_count(volumes: &Volumes): u128 {
    volumes.win_count
}

// === Public Functions ===
/// Shares the GameStatistics object, making it publicly accessible.
public fun share(self: GameStatistics) {
    transfer::share_object(self)
}

// === Package Functions ===

/// Creates a new GameStatistics object for the given game ID.
/// Initializes with zero volumes and sets the current epoch.
public(package) fun new(game_id: &UID, ctx: &mut TxContext): GameStatistics {
    let stats = GameStatistics {
        id: object::new(ctx),
        game_id: *game_id.as_inner(),
        epoch: ctx.epoch(),
        current_volumes: new_volumes(),
        historic_volumes: table::new(ctx),
        all_time_volumes: new_volumes(),
    };

    stats
}

/// Processes the transactions for the history by updating the statistics.
public(package) fun process_transactions(
    self: &mut GameStatistics,
    transactions: &vector<Transaction>,
    ctx: &TxContext,
) {
    self.update_epoch(ctx);

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

// === Private Functions ===

/// Updates the epoch if a new epoch has started.
/// Saves current volumes to historic volumes and resets current volumes for the new epoch.
fun update_epoch(self: &mut GameStatistics, ctx: &TxContext) {
    // Early return if we are already at the latest epoch
    if (self.epoch == ctx.epoch()) {
        return
    };

    // Save the current volumes in the historic volumes
    let current_volumes = self.current_volumes;
    self.historic_volumes.add(self.epoch, current_volumes);

    // Reset the current volumes and update epoch
    self.current_volumes = new_volumes();
    self.epoch = ctx.epoch();
}

/// Creates a new Volumes struct with all values initialized to zero.
fun new_volumes(): Volumes {
    Volumes {
        bet_sum: 0,
        bet_count: 0,
        win_sum: 0,
        win_count: 0,
    }
}

/// Processes a bet transaction by updating bet statistics.
fun process_bet(self: &mut GameStatistics, amount: u64) {
    let casted_amount = amount as u128;

    // Current volumes
    self.current_volumes.bet_count = self.current_volumes.bet_count + 1;
    self.current_volumes.bet_sum = self.current_volumes.bet_sum + casted_amount;
    // All time volumes
    self.all_time_volumes.bet_count = self.all_time_volumes.bet_count + 1;
    self.all_time_volumes.bet_sum = self.all_time_volumes.bet_sum + casted_amount;
}

/// Processes a win transaction by updating win statistics.
/// Skips processing if the amount is zero.
fun process_win(self: &mut GameStatistics, amount: u64) {
    // Early return if the amount is 0 (doesn't count as a win)
    if (amount == 0) {
        return
    };

    let casted_amount = amount as u128;

    self.current_volumes.win_count = self.current_volumes.win_count + 1;
    self.current_volumes.win_sum = self.current_volumes.win_sum + casted_amount;
    // All time volumes
    self.all_time_volumes.win_count = self.all_time_volumes.win_count + 1;
    self.all_time_volumes.win_sum = self.all_time_volumes.win_sum + casted_amount;
}

// === Test Functions ===
#[test_only]
public fun stats_for_testing(game_id: ID, ctx: &mut TxContext): GameStatistics {
    let stats = GameStatistics {
        id: object::new(ctx),
        game_id,
        epoch: ctx.epoch(),
        current_volumes: new_volumes(),
        historic_volumes: table::new(ctx),
        all_time_volumes: new_volumes(),
    };

    stats
}
