/// The state module represents the current global state of a game. It maintains all accounts and history.
/// It needs to process all gamerounds to keep the state up to date.
/// It serves a similar function as the State in deepbookv3.
module openplay::state;

use openplay::account::{Self, Account};
use openplay::constants::{owner_fee, protocol_fee};
use openplay::history::{Self, History};
use openplay::participation::Participation;
use openplay::transaction::{Transaction, is_credit};
use std::uq32_32::int_mul;
use sui::table::{Self, Table};

// === Structs ===
public struct State has store {
    accounts: Table<ID, Account>,
    history: History,
}

// === Errors ===
const EUnknownTransaction: u64 = 1;

// == Public-Package Functions ==
/// Process the transactions in the given state by updating the history and account.
/// Returns a tuple (credit_balance, debit_balance, owner_fee, protocol_fee).
/// The first two values are the to_credit and to_debit balance by the balance manager.
/// The last two values are the fees taken by the owner and protocol.
/// These are calculated by the state because they might depend on state values (such as volumes).
/// The Vault uses these values to perform any necessary transfers.
public(package) fun process_transactions(
    self: &mut State,
    transactions: &vector<Transaction>,
    balance_manager_id: ID,
): (u64, u64, u64, u64) {
    self.update_account(balance_manager_id);

    // Process transactions on the account
    self.process_transactions_for_account(balance_manager_id, transactions);

    // Calculate fees
    let owner_fee = total_owner_fee(transactions);
    let protocol_fee = total_protocol_fee(transactions);

    // Settle account balance
    let (credit_balance, debit_balance) = self.accounts[balance_manager_id].settle();

    (credit_balance, debit_balance, owner_fee, protocol_fee)
}

/// Processes a stake transaction in the game.
/// Returns a tuple (credit_balance, debit_balance).
/// The Vault uses thes values to perform any necessary transfers in the balance manager.
public(package) fun process_stake(self: &mut State, amount: u64) {
    // Add the stake to the pending stake of this epoch
    // It will become active in the next epoch
    self.history.add_pending_stake(amount);
}

public(package) fun process_unstake(
    self: &mut State,
    unstake_immediately: u64,
    pending_unstake: u64,
) {
    // Add the amount to the pending unstake in this epoch
    // It will be unlocked next epoch (plus or minus the winnings/losses that it accrued)
    self.history.add_pending_unstake(pending_unstake);

    // Remove the amount that can be unstaked immediately
    self.history.unstake_immediately(unstake_immediately);
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
): u64 {
    self.history.process_end_of_day(epoch, profits, losses, ctx);
    self.history.current_stake()
}

public(package) fun new(ctx: &mut TxContext): State {
    State {
        accounts: table::new(ctx),
        history: history::empty(ctx),
    }
}

/// This function can be used to settle any remaining balances on the account.
/// This can be used to claim profits or to claim unstaked amount that can available.
/// Returns a tuple (credit_balance, debit_balance).
/// The Vault uses thes values to perform any necessary transfers in the balance manager.
public(package) fun refresh(self: &State, participation: &mut Participation, ctx: &TxContext) {
    self.update_participation(participation, ctx);
}

// == Private Functions ==
/// Advances the account state to the latest epoch, if this is not the case.
/// Inactive stake will be activated, while profits / losses will be added to the active stake.
fun update_participation(self: &State, participation: &mut Participation, ctx: &TxContext) {
    let (mut current_participation_epoch, mut active_stake) = participation.current_state();

    // process the account's ggr share for all epochs between the last activate epoch and the current one
    while (current_participation_epoch < ctx.epoch()) {
        let (epoch_profits, epoch_losses) = self
            .history
            .calculate_ggr_share(current_participation_epoch, active_stake);

        participation.process_end_of_day(
            current_participation_epoch,
            epoch_profits,
            epoch_losses,
            ctx,
        );

        (current_participation_epoch, active_stake) = participation.current_state();
    }
}

/// Advances the account state to the latest epoch, if this is not the case.
/// Inactive stake will be activated, while profits / losses will be added to the active stake.
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
    transactions.do_ref!<Transaction>(|tx| {
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

/// Calculates the total fee for the protocol based on the transactions
fun total_protocol_fee(transactions: &vector<Transaction>): u64 {
    let mut total_fee = 0;
    transactions.do_ref!(|tx| {
        if (tx.is_debit()) {
            let fee_amount = int_mul(tx.amount(), protocol_fee());
            total_fee = total_fee + fee_amount;
        }
    });
    total_fee
}

/// Calculates the total fee for the owner based on the transactions
fun total_owner_fee(transactions: &vector<Transaction>): u64 {
    let mut total_fee = 0;
    transactions.do_ref!(|tx| {
        if (tx.is_debit()) {
            let fee_amount = int_mul(tx.amount(), owner_fee());
            total_fee = total_fee + fee_amount
        }
    });
    total_fee
}
