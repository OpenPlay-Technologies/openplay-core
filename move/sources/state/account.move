/// The account module maintains all the account data for each user.
/// Keeps things like loyalty rank and gameplay statistics.
/// Each balance manager has 1 account.
/// The account serves a similar role as the account in deepbookv3.
module openplay::account;

// == Errors ==
const EInvalidGgrShare: u64 = 1;
const ECancellationWasRequested: u64 = 2;
const EEpochMismatch: u64 = 3;
const EEpochHasNotFinishedYet: u64 = 4;

// === Structs ===
public struct Account has store {
    epoch: u64,
    lifetime_total_bets: u64,
    lifetime_total_wins: u64,
    debit_balance: u64,
    credit_balance: u64,
    active_stake: u64,
    inactive_stake: u64,
    unstake_requested: bool,
    // ... Other things like loyalty rank, responsible gaming limits etc.
}

// === Public-View Functions ===
public fun active_stake(self: &Account): u64 {
    self.active_stake
}

// === Public-Package Functions ===
public(package) fun empty(ctx: &TxContext): Account {
    Account {
        epoch: ctx.epoch(),
        lifetime_total_bets: 0,
        lifetime_total_wins: 0,
        debit_balance: 0,
        credit_balance: 0,
        active_stake: 0,
        inactive_stake: 0,
        unstake_requested: false,
    }
}


public(package) fun current_state(self: &Account): (u64, u64) {
    (self.epoch, self.active_stake)
}

/// Process the end of day.
/// Wins are added to the active stake, while losses are removed from the active stake.
/// Pending stake is activated, and pending unstake is removed.
public(package) fun process_end_of_day(self: &mut Account, epoch: u64, profits: u64, losses: u64,  ctx: &TxContext) {
    assert!(profits == 0 || losses == 0, EInvalidGgrShare);
    assert!(self.epoch == epoch, EEpochMismatch);
    assert!(ctx.epoch() > self.epoch, EEpochHasNotFinishedYet);
    if (profits > 0) {
        self.active_stake = self.active_stake + profits;
    } else if (losses > 0) {
        if (losses > self.active_stake) {
            // This can only happen with small rounding errors
            self.active_stake = 0
        } else {
            self.active_stake = self.active_stake - losses;
        }
    };
    // Unlock the staked amount
    if (self.unstake_requested) {
        self.credit_balance = self.credit_balance + self.active_stake;
        self.active_stake = 0;
    };
    // Activate the stake that was waiting for activation
    self.active_stake = self.active_stake + self.inactive_stake;
    self.inactive_stake = 0;
    self.unstake_requested = false;
    self.epoch = self.epoch + 1;
}

/// Returns a tuple (credit_balance, debit_balance) and resets their values.
/// The Vault uses thes values to perform any necessary transfers in the balance manager.
public(package) fun settle(self: &mut Account): (u64, u64) {
    let old_credit = self.credit_balance;
    let old_debit = self.debit_balance;
    self.reset_balances();
    (old_credit, old_debit)
}

/// Adds stake to the inactive stake balance of the account.
/// This balance will be activated in the next epoch.
/// Fails if an unstake action was already performed this epoch.
public(package) fun add_stake(self: &mut Account, amount: u64) {
    assert!(self.unstake_requested == false, ECancellationWasRequested);
    self.inactive_stake = self.inactive_stake + amount;
    self.debit_balance = self.debit_balance + amount;
}

/// Unstakes the account. This does two things
/// 1) The inactive stake is returned immediately
/// 2) The active stake is requested to be unstaked, and will be returned at the next epoch
/// Fails if an unstake action was already performed this epoch.
/// Returns a tuple (unstake_immediately, pending_unstake)
public(package) fun unstake(self: &mut Account): (u64, u64) {
    assert!(self.unstake_requested == false, ECancellationWasRequested);

    let prev_inactive_stake = self.inactive_stake;

    // Inactive stake
    if (self.inactive_stake > 0) {
        self.credit_balance = self.credit_balance + self.inactive_stake;
        self.inactive_stake = 0;
    };

    // Active stake
    if (self.active_stake > 0) {
        self.unstake_requested = true; // Only set this to true when there is active stake, such that we can still change our mind between staking and unstaking during an epoch.
    };

    return (prev_inactive_stake, self.active_stake)
}

public(package) fun credit(self: &mut Account, amount: u64) {
    self.credit_balance = self.credit_balance + amount;
}

public(package) fun debit(self: &mut Account, amount: u64) {
    self.debit_balance = self.debit_balance + amount
}

// === Private Functions ===
fun reset_balances(self: &mut Account) {
    self.credit_balance = 0;
    self.debit_balance = 0;
}
