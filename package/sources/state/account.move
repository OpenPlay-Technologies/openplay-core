/// The account module maintains account data for each balance manager.
/// Tracks lifetime bet/win statistics and pending balances for settlement.
/// Each balance manager has 1 account.
module openplay_core::account;

// === Imports ===

// === Errors ===

// === Structs ===
/// Tracks account state for a balance manager, including lifetime statistics and pending balances.
/// Used to accumulate transactions before settlement.
public struct Account has store {
    lifetime_total_bets: u64,
    lifetime_total_wins: u64,
    debit_balance: u64,
    credit_balance: u64,
}

// === View Functions ===
/// Returns the lifetime total bets.
public fun lifetime_total_bets(self: &Account): u64 {
    self.lifetime_total_bets
}

/// Returns the lifetime total wins.
public fun lifetime_total_wins(self: &Account): u64 {
    self.lifetime_total_wins
}

/// Returns the current debit balance.
public fun debit_balance(self: &Account): u64 {
    self.debit_balance
}

/// Returns the current credit balance.
public fun credit_balance(self: &Account): u64 {
    self.credit_balance
}

// === Package Functions ===
/// Creates a new empty Account with all values initialized to zero.
public(package) fun empty(): Account {
    Account {
        lifetime_total_bets: 0,
        lifetime_total_wins: 0,
        debit_balance: 0,
        credit_balance: 0,
    }
}

/// Returns a tuple (credit_balance, debit_balance) and resets their values.
/// The Vault uses these values to perform any necessary transfers in the balance manager.
public(package) fun settle(self: &mut Account): (u64, u64) {
    let old_credit = self.credit_balance;
    let old_debit = self.debit_balance;
    self.reset_balances();
    (old_credit, old_debit)
}

/// Adds a credit (win) amount to the account's credit balance.
public(package) fun credit(self: &mut Account, amount: u64) {
    self.credit_balance = self.credit_balance + amount;
}

/// Adds a debit (bet) amount to the account's debit balance.
public(package) fun debit(self: &mut Account, amount: u64) {
    self.debit_balance = self.debit_balance + amount
}

// === Private Functions ===
/// Resets both credit and debit balances to zero.
/// Called after settlement to prepare for the next transaction batch.
fun reset_balances(self: &mut Account) {
    self.credit_balance = 0;
    self.debit_balance = 0;
}
