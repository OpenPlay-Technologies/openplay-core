/// The state module represents the current global state of a game. It maintains all accounts and history.
/// It needs to process all gamerounds to keep the state up to date.
/// It serves a similar function as the State in deepbookv3.
module openplay::state;

use openplay::account::{Self, Account};
use openplay::history::History;
use openplay::transaction::{Transaction, is_credit};
use sui::table::Table;

// === Structs ===
public struct State has store {
    accounts: Table<ID, Account>,
    history: History,
}

// === Constant ===
const OWNER_FEE_BPS: u64 = 50; // in bps , taken on bets
const PROTOCOL_FEE_BPS: u64 = 50; // in bps , taken on bets

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
    ctx: &TxContext,
): (u64, u64, u64, u64) {
    // Make sure the account is up to date
    self.update_account(balance_manager_id, ctx);

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
public(package) fun process_stake(
    self: &mut State,
    balance_manager_id: ID,
    amount: u64,
    ctx: &TxContext,
): (u64, u64) {
    // Make sure the account is up to date
    self.update_account(balance_manager_id, ctx);

    // Add the stake to the account pending balance
    self.accounts[balance_manager_id].add_stake(amount);

    // Add the stake to the pending stake of this epoch
    // It will become active in the next epoch
    self.history.add_pending_stake(amount);

    // Return the settled and owed balance to be processed by the vault in the next step
    self.accounts[balance_manager_id].settle()
}

public(package) fun process_unstake(
    self: &mut State,
    balance_manager_id: ID,
    ctx: &TxContext,
): (u64, u64) {
    // Make sure the account is up to date
    self.update_account(balance_manager_id, ctx);

    // Remove stake from the account
    let (unstake_immediately, pending_unstake) = self.accounts[balance_manager_id].unstake();

    // Add the amount to the pending unstake in this epoch
    // It will be unlocked next epoch (plus or minus the winnings/losses that it accrued)
    self.history.add_pending_unstake(pending_unstake);

    // Remove the amount that can be unstaked immediately
    self.history.unstake_immediately(unstake_immediately);

    // Return the settled and owed balance to be processed by the vault in the next step
    self.accounts[balance_manager_id].settle()
}

/// Advances the epoch: updates the history and saves the end of day of the house.
public(package) fun process_end_of_day(
    self: &mut State,
    epoch: u64,
    profits: u64,
    losses: u64,
    end_balance: u64,
    ctx: &TxContext,
) {
    self.history.process_end_of_day(epoch, profits, losses, end_balance, ctx);
}

// == Private Functions ==
/// Advances the account state to the latest epoch, if this is not the case.
/// Inactive stake will be activated, while profits / losses will be added to the active stake.
fun update_account(self: &mut State, balance_manager_id: ID, ctx: &TxContext) {
    if (!self.accounts.contains(balance_manager_id)) {
        self.accounts.add(balance_manager_id, account::empty(ctx));
    };

    let account = &mut self.accounts[balance_manager_id];
    let (mut epoch_change, mut prev_epoch, mut active_stake) = account.update(ctx);

    // process the account's ggr share for all epochs between the last activate epoch and the current one
    while (epoch_change) {
        let (epoch_profits, epoch_losses) = self
            .history
            .calculate_ggr_share(prev_epoch, active_stake);
        account.process_ggr_share(epoch_profits, epoch_losses);

        (epoch_change, prev_epoch, active_stake) = account.update(ctx);
    }
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
        total_fee = total_fee + (tx.amount() / 10000 * PROTOCOL_FEE_BPS)
    });
    total_fee
}

/// Calculates the total fee for the owner based on the transactions
fun total_owner_fee(transactions: &vector<Transaction>): u64 {
    let mut total_fee = 0;
    transactions.do_ref!(|tx| {
        total_fee = total_fee + (tx.amount() / 10000 * OWNER_FEE_BPS)
    });
    total_fee
}
