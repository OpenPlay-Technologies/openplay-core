/// Module representing a transaction, the building block for all money transfers.
module openplay_core::transaction;

use openplay_core::core_constants::{tx_type_bet, tx_type_win};
use std::string::String;

// === Errors ===
const EUnknownTxType: u64 = 1;

// === Structs ===
/// Represents a single transaction in the OpenPlay system.
/// Can be either a bet (debit) or win (credit) transaction.
public struct Transaction has copy, drop, store {
    transaction_type: String,
    amount: u64,
}

// === Public-View Functions ===
/// Returns the amount of the transaction.
public fun amount(self: &Transaction): u64 {
    self.amount
}

/// Returns true if the transaction type is a credit.
/// Returns false if the transaction type is a debit.
public fun is_credit(self: &Transaction): bool {
    if (self.transaction_type == tx_type_win()) {
        return true
    };
    if (self.transaction_type == tx_type_bet()) {
        return false
    };
    abort EUnknownTxType
}

/// Returns false if the transaction type is a credit.
/// Returns true if the transaction type is a debit.
public fun is_debit(self: &Transaction): bool {
    !is_credit(self)
}

// === Public-Mutative Functions ===
/// Creates a win (credit) transaction with the specified amount.
public fun win(amount: u64): Transaction {
    Transaction {
        transaction_type: tx_type_win(),
        amount,
    }
}

/// Creates a bet (debit) transaction with the specified amount.
public fun bet(amount: u64): Transaction {
    Transaction {
        transaction_type: tx_type_bet(),
        amount: amount,
    }
}
