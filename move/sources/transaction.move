/*
Module representing a transaction, the building block for all money transfers.
*/
module openplay::transaction;

// === Structs ===
public enum TransactionType {
    Bet,
    Win
}

public struct Transaction {
    transaction_type: TransactionType,
    amount: u64
}

// === Public-Package Functions ===
public(package) fun win(amount: u64): Transaction {
    Transaction {
        transaction_type: TransactionType::Win,
        amount
    }
}

public(package) fun bet(amount: u64): Transaction {
    Transaction {
        transaction_type: TransactionType::Bet,
        amount: amount
    }
}