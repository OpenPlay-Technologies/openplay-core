/// This module keeps track of the historic data of a game.
module openplay::history;

use std::uq32_32::{from_quotient, int_mul, add, sub, from_int};
use sui::table::{Self, Table};

// === Errors ===
const EEpochMismatch: u64 = 1;
const ECannotUnstakeMoreThanStaked: u64 = 2;

// === Structs ===
public struct Volumes has store, copy, drop {
    total_bet_amount: u128,
    total_win_amount: u128,
    total_stake_amount: u64,
}

public struct EndOfDay has store, copy, drop {
    house_balance: u64,
    day_profits: u64,
    day_losses: u64,
}

public struct History has store {
    epoch: u64,
    pending_stake: u64, // The stake from epoch i that will be activated in epoch i+1
    pending_unstake: u64, // The stake from epoch i that will be disactived in epoch i+1
    current_volumes: Volumes,
    historic_volumes: Table<u64, Volumes>,
    end_of_day_balances: Table<u64, EndOfDay>,
}

// === Public-Package Functions ===
public(package) fun empty(ctx: &mut TxContext): History {
    let volumes = Volumes {
        total_bet_amount: 0,
        total_win_amount: 0,
        total_stake_amount: 0,
    };
    let mut history = History {
        epoch: ctx.epoch(),
        pending_stake: 0,
        pending_unstake: 0,
        current_volumes: volumes,
        historic_volumes: table::new(ctx),
        end_of_day_balances: table::new(ctx),
    };
    history.historic_volumes.add(ctx.epoch(), volumes);

    history
}

public(package) fun add_pending_stake(self: &mut History, amount: u64) {
    self.pending_stake = self.pending_stake + amount;
}

/// Unstakes `amount` by adding it to the `pending_unstake` balance.
/// This amount will be unstaked in the next epoch.
public(package) fun add_pending_unstake(self: &mut History, amount: u64) {
    self.pending_unstake = self.pending_unstake + amount;
}

/// Unstakes `amount` immediately by deducting it from the pending stake for next epoch.
public(package) fun unstake_immediately(self: &mut History, amount: u64) {
    assert!(self.pending_stake > amount, ECannotUnstakeMoreThanStaked);
    self.pending_stake = self.pending_stake - amount;
}

/// Processes the end of day by
/// 1) Saving the end of day profis, losses, and house balance in the history
/// 2) Calculating the new stake amount for the next epoch
/// 3) Saving the history volumes
/// 4) Updating the current epoch number
public(package) fun process_end_of_day(
    self: &mut History,
    epoch: u64,
    profits: u64,
    losses: u64,
    house_balance: u64,
    ctx: &TxContext,
) {
    // We can only process the epoch that we are currently on
    // This means that the vault and history epochs need to be kept in sync
    assert!(self.epoch == epoch, EEpochMismatch);
    let prev_stake_amount = self.current_volumes.total_stake_amount;

    // Save the end of day balance
    let eod = EndOfDay {
        house_balance: house_balance,
        day_profits: profits,
        day_losses: losses,
    };
    self.end_of_day_balances.add(epoch, eod);

    // The new staked amount is
    // 1) the previous stake amount
    // 2) plus profits or minus losses
    // 3) minus the pending unstake (actualized)
    // 4) plus the pending stake
    let mut new_stake_amount = prev_stake_amount;
    if (profits > 0) {
        new_stake_amount = new_stake_amount + profits
    } else if (losses > 0) {
        if (losses > new_stake_amount) {
            // Can only happen with small rounding errors
            new_stake_amount = 0;
        } else {
            new_stake_amount = new_stake_amount - losses;
        };
    };

    // The pending unstake need to be actualized to get the actual unstake amount
    // The reason for this is:
    // - If you unstake you still need to bear the losses or receive the winnings from that epoch
    // => If you receive winnings, then the actual unstake amount is greater than the pending unstake amount
    // => If you bear losses, then the actual unstake amount is smaller than the pending unstake amount
    if (self.pending_unstake > 0) {
        // Calculate the actual unstake amount
        let actual_unstake_amount;
        if (profits > 0) {
            let return_on_investment = from_quotient(profits, prev_stake_amount);
            let multiplier = add(from_int(1), return_on_investment);
            actual_unstake_amount = int_mul(self.pending_unstake, multiplier)
        } else if (losses > 0) {
            let loss_on_investment = from_quotient(losses, prev_stake_amount);
            let multiplier = sub(from_int(1), loss_on_investment);
            actual_unstake_amount = int_mul(self.pending_unstake, multiplier)
        } else {
            actual_unstake_amount = self.pending_unstake;
        };

        // Deduct it from the new stake amount
        if (actual_unstake_amount > new_stake_amount) {
            new_stake_amount = 0;
        } else {
            new_stake_amount = new_stake_amount - actual_unstake_amount;
        }
    };

    new_stake_amount = new_stake_amount + self.pending_stake; // Pending stake is added last so the new stakers can not make loss in any case before their stake is activated

    // Save the epoch volumes
    self.historic_volumes.add(epoch, self.current_volumes);
    let volumes = Volumes {
        total_bet_amount: 0,
        total_win_amount: 0,
        total_stake_amount: new_stake_amount,
    };
    self.current_volumes = volumes;

    // Update the epoch
    self.epoch = ctx.epoch();
    self.pending_stake = 0;
}

/// Calculates the share of the profits or losses for the provided account in the provided epoch
/// Returns a tuple (profits, losses) where one of them should be 0
public(package) fun calculate_ggr_share(
    self: &History,
    epoch: u64,
    account_stake: u64,
): (u64, u64) {
    // If the epoch data is unavailable, there is no ggr_share
    if (!self.historic_volumes.contains(epoch) || !self.end_of_day_balances.contains(epoch)) {
        return (0, 0)
    };

    let epoch_volume = &self.historic_volumes[epoch];
    let end_of_day = &self.end_of_day_balances[epoch];

    let participation_ratio = from_quotient(account_stake, epoch_volume.total_stake_amount);
    let losses = int_mul(end_of_day.day_losses, participation_ratio);
    let profits = int_mul(end_of_day.day_profits, participation_ratio);
    assert!(losses == 0 || profits == 0); // Just to make sure we keep respect the invariant
    (profits, losses)
}
