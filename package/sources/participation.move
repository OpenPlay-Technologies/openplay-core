/// The participation module maintains all the house participation state.
/// Resonsible for managing staking, unstaking, and profit/loss sharing.
module openplay_core::participation;

use openplay_core::calculations::actualize_amount;
use openplay_core::core_constants::precision_error_allowance;
use sui::event::emit;

// == Errors ==
const EInvalidGgrShare: u64 = 1;
// const ECancellationWasRequested: u64 = 2;
const EEpochMismatch: u64 = 3;
const EEpochHasNotFinishedYet: u64 = 4;
const EInvalidProfitsOrLosses: u64 = 5;
const ENotEmpty: u64 = 6;
const ENotEnoughToUnstake: u64 = 7;

// === Structs ===
/// Represents a user's participation in a House, tracking stake, profits, and losses.
/// Manages stake activation/deactivation across epochs and claimable balances.
public struct Participation has key, store {
    id: UID,
    house_id: ID,
    last_updated_epoch: u64,
    stake: u64, // Stake that is currently counting towards profits/loss sharing
    pending_stake: u64, // Pending stake is stake that needs to wait until the end of the epoch to become active
    claimable_balance: u64,
    pending_unstake: u64, // Pending unstake is stake that is currently active and will be moved to the claimable balance at the end of the epoch
}

/// Event emitted when a new Participation is created.
public struct ParticipationCreatedEvent has copy, drop {
    participation_id: ID,
}

/// Event emitted when a Participation is removed (destroyed).
public struct ParticipationRemovedEvent has copy, drop {
    participation_id: ID,
}

/// Event emitted when stake is added to a Participation.
public struct StakeAddedEvent has copy, drop {
    participation_id: ID,
    amount: u64,
    pending: bool,
}

/// Event emitted when stake is removed from a Participation.
public struct StakeRemovedEvent has copy, drop {
    participation_id: ID,
    amount: u64,
    pending_stake_removed: u64,
}

/// Event emitted when end-of-day processing completes for a Participation.
public struct ParticipationEndOfDayProcessedEvent has copy, drop {
    participation_id: ID,
    profits: u64,
    losses: u64,
}

// === Public-View Functions ===
public fun stake(self: &Participation): u64 {
    self.stake
}

public fun pending_stake(self: &Participation): u64 {
    self.pending_stake
}

public fun claimable_balance(self: &Participation): u64 {
    self.claimable_balance
}

public fun house_id(self: &Participation): ID {
    self.house_id
}

public fun last_updated_epoch(self: &Participation): u64 {
    self.last_updated_epoch
}

public fun pending_unstake(self: &Participation): u64 {
    self.pending_unstake
}

public fun id(self: &Participation): ID {
    self.id.to_inner()
}

// === Public-Mutative Functions ===
public fun destroy_empty(self: Participation, ctx: &mut TxContext) {
    assert!(self.last_updated_epoch == ctx.epoch(), EEpochMismatch);
    assert!(self.stake == 0, ENotEmpty);
    assert!(self.claimable_balance == 0, ENotEmpty);

    let Participation {
        id,
        house_id: _,
        last_updated_epoch: _,
        stake: _,
        pending_stake: _,
        claimable_balance: _,
        pending_unstake: _,
    } = self;

    // Event
    emit(ParticipationRemovedEvent {
        participation_id: id.to_inner(),
    });

    object::delete(id);
}

// === Public-Package Functions ===
/// Create a new house participation object. The stake is added to the `inactive_stake` and is activated in the next epoch.
public(package) fun empty(house_id: ID, ctx: &mut TxContext): Participation {
    let participation = Participation {
        id: object::new(ctx),
        house_id,
        last_updated_epoch: ctx.epoch(),
        stake: 0,
        pending_stake: 0,
        claimable_balance: 0,
        pending_unstake: 0,
    };

    // Event
    emit(ParticipationCreatedEvent {
        participation_id: participation.id(),
    });

    participation
}

/// Adds stake to the participation.
/// If the house is active, then it will be added to the `pending_stake` which wil be activated in the next epoch.
/// If the house is not active, then it will be added to `stake`.
public(package) fun add_stake(
    self: &mut Participation,
    amount: u64,
    is_active: bool,
    ctx: &TxContext,
) {
    assert!(self.last_updated_epoch == ctx.epoch(), EEpochMismatch);

    if (is_active) {
        self.pending_stake = self.pending_stake + amount;
    } else {
        self.stake = self.stake + amount;
    };

    // Event
    emit(StakeAddedEvent {
        participation_id: self.id(),
        amount: amount,
        pending: is_active,
    });
}

/// Unstakes the account.
/// If any amount is on the `pending_stake` balance, it will first be removed from there
/// The remaining amount will either
/// - be removed from the stake balance immediately if the house is not active
/// - be queued to be unstaked by adding it to the `pending_unstake` balance
/// Returns (remaining_amount, pending_stake_removed) where
/// - the first amount is either queued for unstake if the house is active, or immediately removed from the stake balance if the house is not active
/// - the second amount is the amount that is immediately removed from the pending_stake balance and added to the claimable balance
public(package) fun unstake_v2(
    self: &mut Participation,
    amount: u64,
    is_active: bool,
    ctx: &TxContext,
): (u64, u64) {
    assert!(self.last_updated_epoch == ctx.epoch(), EEpochMismatch);

    let mut remaining_amount = amount;
    let mut pending_stake_removed = 0;
    // First check the `pending_stake` balance
    if (self.pending_stake >= amount) {
        // We have enough on the pending_stake balance
        self.pending_stake = self.pending_stake - amount;
        pending_stake_removed = amount;
        remaining_amount = 0;
    } else if (self.pending_stake > 0) {
        // We deduct the pending_stake balance completely
        pending_stake_removed = self.pending_stake;
        remaining_amount = remaining_amount - self.pending_stake;
        self.pending_stake = 0;
    };

    // Move this amount already to the claimable balance
    if (pending_stake_removed > 0) {
        self.claimable_balance = self.claimable_balance + pending_stake_removed;
    };

    // Make sure we have enough left to unstake in the active stake portion
    let stake_that_is_not_unstaked_yet = self.stake - self.pending_unstake;
    assert!(stake_that_is_not_unstaked_yet >= remaining_amount, ENotEnoughToUnstake);

    // If the house is active then we add the remaining amount to the `pending_unstake` balance
    if (is_active) {
        self.pending_unstake = self.pending_unstake + remaining_amount;
    } // If the house is inactive we can just deduct it immediately and add it to claimable balance
    else {
        self.stake = self.stake - remaining_amount;
        self.claimable_balance = self.claimable_balance + remaining_amount;
    };

    // Evemt
    emit(StakeRemovedEvent {
        participation_id: self.id(),
        amount: remaining_amount,
        pending_stake_removed,
    });

    (remaining_amount, pending_stake_removed)
}

/// Processes the profits or losses for the provided epoch by adding/substracting them to/from the stake.
/// Additionally, pending stake is activated (added to the stake balance) and pending unstake is released (added to the claimable balance).
/// Only the `last_updated_epoch` can be ended.
/// Fails if profits AND losses both contain a value.
public(package) fun process_end_of_day(
    self: &mut Participation,
    epoch: u64,
    profits: u64,
    losses: u64,
    ctx: &TxContext,
) {
    assert!(profits == 0 || losses == 0, EInvalidGgrShare);
    assert!(self.last_updated_epoch == epoch, EEpochMismatch);
    assert!(ctx.epoch() > self.last_updated_epoch, EEpochHasNotFinishedYet);
    let prev_active_stake = self.stake;
    if (profits > 0) {
        self.stake = self.stake + profits;
    } else if (losses > 0) {
        if (self.stake >= losses) {
            self.stake = self.stake - losses;
        } else if (losses - self.stake <= precision_error_allowance()) {
            // Small rounding errors
            self.stake = 0;
        } else {
            abort EInvalidProfitsOrLosses
        }
    };

    // !! TODO: the pending unstake amount needs to be actualized to get the actual unstake amount
    // e.g. if the stake is 1 SUI and you unstake 1 SUI
    // then profits of 0.1 SUI come in (10% profit share)
    // then the actual unstake amount should be 1 SUI * (1 + 10%) = 1.1 SUI
    // and actually 1.1 SUI will be unstaked
    // This is similar to the profit sharing mechanism that we already have

    // Release the amount that is waiting to be unstaked
    if (self.pending_unstake > 0) {
        // Actualize the amount with the profits/losses
        let actual_unstake_amount = actualize_amount(
            self.pending_unstake,
            profits,
            losses,
            prev_active_stake,
        );

        // Deduct
        if (actual_unstake_amount > self.stake) {
            // edge case
            self.claimable_balance = self.claimable_balance + self.stake;
            self.stake = 0;
        } else {
            self.claimable_balance = self.claimable_balance + actual_unstake_amount;
            self.stake = self.stake - actual_unstake_amount;
        };

        self.pending_unstake = 0;
    };

    // Activate the pending stake that was waiting for activation
    self.stake = self.stake + self.pending_stake;
    self.pending_stake = 0;

    // Finally update the epoch
    self.last_updated_epoch = self.last_updated_epoch + 1;

    // Event
    emit(ParticipationEndOfDayProcessedEvent {
        participation_id: self.id(),
        profits,
        losses,
    });
}

/// Returns the current state of the participation
/// (last_updated_epoch, stake, pending_stake, pending_unstake)
public(package) fun current_state(self: &Participation): (u64, u64, u64, u64) {
    (self.last_updated_epoch, self.stake, self.pending_stake, self.pending_unstake)
}

public(package) fun claim_all(self: &mut Participation, ctx: &TxContext): u64 {
    assert!(self.last_updated_epoch == ctx.epoch(), EEpochMismatch);
    let claimable = self.claimable_balance;
    self.claimable_balance = 0;
    claimable
}
