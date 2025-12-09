/// The vault holds all of the assets of a house. At the end of all
/// transaction processing, the vault is used to settle the balances for the account.
/// The vault is responsible for collecting fees (protocol, collector, and house performance fees)
/// which are calculated from GGR at epoch end.
module openplay_core::vault;

use openplay_core::balance_manager::{BalanceManager, PlayProof};
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use sui::vec_map::{Self, VecMap};

// === Errors ===
const EInsufficientFunds: u64 = 1;

// === Structs ===
/// Stores all assets for a House, including house balance and collected fees.
/// In the share-based model, the house is always active, so there's a single house balance.
public struct Vault has store {
    house_id: ID,
    collected_protocol_fees: Balance<SUI>,
    collected_house_fees: Balance<SUI>,
    collected_collector_fees: VecMap<ID, Balance<SUI>>, // fee_collector_id -> balance
    house_balance: Balance<SUI>, // Single balance for all house funds (replaces play_balance + reserve_balance)
}

// === View Functions ===
/// Returns the house balance (all funds available for the house).
public fun house_balance(self: &Vault): u64 {
    self.house_balance.value()
}

/// Returns the total collected protocol fees.
public fun collected_protocol_fees(self: &Vault): u64 {
    self.collected_protocol_fees.value()
}

/// Returns the collected collector fees for a specific fee collector ID.
/// Returns 0 if the collector doesn't exist.
public fun collected_collector_fees(self: &Vault, fee_collector_id: ID): u64 {
    if (self.collected_collector_fees.contains(&fee_collector_id)) {
        self.collected_collector_fees[&fee_collector_id].value()
    } else {
        0
    }
}

// === Package Functions ===

/// Creates an empty vault, with all balances initialized to zero.
public(package) fun empty(house_id: ID): Vault {
    Vault {
        house_id,
        collected_protocol_fees: balance::zero(),
        collected_house_fees: balance::zero(),
        collected_collector_fees: vec_map::empty(),
        house_balance: balance::zero(),
    }
}

/// Deposits funds into the house balance.
public(package) fun deposit(self: &mut Vault, stake: Balance<SUI>) {
    self.house_balance.join(stake);
}

/// Withdraws the specified amount from the house balance.
public(package) fun withdraw(self: &mut Vault, amount: u64): Balance<SUI> {
    self.house_balance.split(amount)
}

public(package) fun withdraw_protocol_fees(self: &mut Vault): Balance<SUI> {
    self.collected_protocol_fees.withdraw_all()
}

/// Withdraws all collected house fees from the vault.
public(package) fun withdraw_house_fees(self: &mut Vault): Balance<SUI> {
    self.collected_house_fees.withdraw_all()
}

/// Processes and collects house fees (performance fee) from profits.
/// This should be called during end-of-day processing when there are profits.
/// House fees are deducted from the house balance.
public(package) fun process_house_fee(self: &mut Vault, house_fee: u64) {
    if (house_fee > 0) {
        assert!(self.house_balance.value() >= house_fee, EInsufficientFunds);
        // House fees are collected from the house balance
        let balance = self.house_balance.split(house_fee);
        self.collected_house_fees.join(balance);
    };
}

/// Processes and collects collector fees from the house balance.
/// This should be called during end-of-day processing when collector fees are calculated.
/// Collector fees are deducted from the house balance.
public(package) fun process_collector_fee(self: &mut Vault, fee_collector_id: ID, amount: u64) {
    if (amount > 0) {
        assert!(self.house_balance.value() >= amount, EInsufficientFunds);
        // Collector fees are collected from the house balance
        self.ensure_collector_fee_balance(fee_collector_id);
        let balance = self.house_balance.split(amount);
        let collector_balance = &mut self.collected_collector_fees[&fee_collector_id];
        collector_balance.join(balance);
    };
}

/// Withdraws all collected collector fees for a specific fee collector.
/// Returns a zero balance if the collector doesn't exist or has no fees.
public(package) fun withdraw_collector_fees(self: &mut Vault, fee_collector_id: ID): Balance<SUI> {
    if (self.collected_collector_fees.contains(&fee_collector_id)) {
        let balance = &mut self.collected_collector_fees[&fee_collector_id];
        balance.withdraw_all()
    } else {
        balance::zero()
    }
}

/// Settles the balances between the `vault` and `balance_manager`.
/// For `amount_in`, balances are withdrawn from the `balance_manager` and joined with the `house_balance`.
/// For `amount_out`, balances are split from the `house_balance` and deposited into `balance_manager`.
/// Fails if the balance_manager funds are lower than the amount_in for safety reasons.
public(package) fun settle_balance_manager(
    self: &mut Vault,
    amount_out: u64,
    amount_in: u64,
    balance_manager: &mut BalanceManager,
    play_proof: &PlayProof,
) {
    // No matter what, the balance manager should have sufficient funds to cover the debits
    balance_manager.ensure_sufficient_funds(amount_in);
    if (amount_out > amount_in) {
        // Vault needs to pay the difference to the balance_manager
        let needed = amount_out - amount_in;
        assert!(self.house_balance.value() >= needed, EInsufficientFunds);
        let balance = self.house_balance.split(needed);
        balance_manager.deposit_with_proof(play_proof, balance);
    } else if (amount_in > amount_out) {
        // Balance manager needs to pay the difference to the vault
        let balance;
        balance = balance_manager.withdraw_with_proof(play_proof, amount_in - amount_out);
        self.house_balance.join(balance);
    };
}

/// Processes and collects a protocol fee from the house balance.
/// Aborts if there are insufficient funds.
public(package) fun process_protocol_fee(self: &mut Vault, protocol_fee: u64) {
    assert!(self.house_balance.value() >= protocol_fee, EInsufficientFunds);
    if (protocol_fee > 0) {
        let balance = self.house_balance.split(protocol_fee);
        self.collected_protocol_fees.join(balance);
    };
}

// === Private Functions ===
/// Ensures a collector fee balance exists for the given fee collector ID.
/// Creates a zero balance if it doesn't exist.
fun ensure_collector_fee_balance(self: &mut Vault, fee_collector_id: ID) {
    if (!self.collected_collector_fees.contains(&fee_collector_id)) {
        self.collected_collector_fees.insert(fee_collector_id, balance::zero());
    };
}

// === Test Functions ===
#[test_only]
public fun fund_house_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.house_balance.join(balance);
}

#[test_only]
public fun burn_house_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = self.house_balance.split(amount);
    balance.into_coin(ctx).burn_for_testing();
}

#[test_only]
public fun fund_protocol_fees_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.collected_protocol_fees.join(balance);
}
