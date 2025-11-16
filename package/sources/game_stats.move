module openplay_core::game_stats;

use openplay_core::transaction::Transaction;
use sui::table::{Self, Table};

// == Errors ==
const EUnknownTransaction: u64 = 1;
const EEpochNotFound: u64 = 2;

// === Structs ===

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

public struct Volumes has copy, drop, store {
    bet_sum: u128,
    bet_count: u128,
    win_sum: u128,
    win_count: u128,
}

// === Public-View Functions ===
public fun game_id(self: &GameStatistics): ID {
    self.game_id
}

public fun id(self: &GameStatistics): ID {
    self.id.to_inner()
}

public fun current_volumes(self: &GameStatistics): Volumes {
    self.current_volumes
}

public fun all_time_volumes(self: &GameStatistics): Volumes {
    self.all_time_volumes
}

public fun historic_volumes(self: &GameStatistics, epoch: u64): Volumes {
    assert!(self.historic_volumes.contains(epoch), EEpochNotFound);
    self.historic_volumes[epoch]
}

public fun bet_sum(volumes: &Volumes): u128 {
    volumes.bet_sum
}

public fun bet_count(volumes: &Volumes): u128 {
    volumes.bet_count
}

public fun win_sum(volumes: &Volumes): u128 {
    volumes.win_sum
}

public fun win_count(volumes: &Volumes): u128 {
    volumes.win_count
}

// === Public-Mutative Functions ===
public fun share(self: GameStatistics) {
    transfer::share_object(self)
}

// == Public-Package Functions ==

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

fun new_volumes(): Volumes {
    Volumes {
        bet_sum: 0,
        bet_count: 0,
        win_sum: 0,
        win_count: 0,
    }
}

fun process_bet(self: &mut GameStatistics, amount: u64) {
    let casted_amount = amount as u128;

    // Current volumes
    self.current_volumes.bet_count = self.current_volumes.bet_count + 1;
    self.current_volumes.bet_sum = self.current_volumes.bet_sum + casted_amount;
    // All time volumes
    self.all_time_volumes.bet_count = self.all_time_volumes.bet_count + 1;
    self.all_time_volumes.bet_sum = self.all_time_volumes.bet_sum + casted_amount;
}

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
