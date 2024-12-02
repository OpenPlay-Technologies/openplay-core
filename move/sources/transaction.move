/*
Module representing a transaction, the building block for all money transfers.
*/
module openplay::transaction;

// === Structs ===
public enum TransactionType {
    Bet { amount: u64 },
    Win { amount: u64 }
}