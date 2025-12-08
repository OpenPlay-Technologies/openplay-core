/// The vault holds all of the assets of a house. At the end of all
/// transaction processing, the vault is used to settle the balances for the account.
/// The vault is also responsible for collecting fees (protocol, game, and house performance fees)
module openplay_core::vault;

use openplay_core::balance_manager::{BalanceManager, PlayProof};
use sui::balance::{Self, Balance};
use sui::event::emit;
use sui::sui::SUI;
use sui::vec_map::{Self, VecMap};

// === Errors ===
const EInsufficientFunds: u64 = 1;
const EGameDoesNotExist: u64 = 4;

// === Structs ===
/// Stores all assets for a House, including play balance, reserve balance, and collected fees.
/// Manages the separation between funds available for game payouts and staked reserves.
public struct Vault has store {
    house_id: ID,
    epoch: u64,
    collected_protocol_fees: Balance<SUI>,
    collected_game_fees: VecMap<ID, Balance<SUI>>,
    collected_house_fees: Balance<SUI>,
    play_balance: Balance<SUI>,
    reserve_balance: Balance<SUI>,
}

/// Event emitted when the play balance is funded from reserves.
public struct PlayBalanceFundedEvent has copy, drop {
    house_id: ID,
    amount: u64,
}

/// Event emitted when the play balance is cleared back to reserves at end of epoch.
public struct PlayBalanceClearedEvent has copy, drop {
    house_id: ID,
    amount: u64,
}

// === Public-View Functions ---
/// Returns the current play balance available for game payouts.
public fun play_balance(self: &Vault): u64 {
    self.play_balance.value()
}

/// Returns the reserve balance (staked funds not yet in play).
public fun reserve_balance(self: &Vault): u64 {
    self.reserve_balance.value()
}

/// Returns the collected game fees for a specific game ID.
/// Aborts if the game doesn't exist.
public fun collected_game_fees(self: &Vault, game_id: ID): u64 {
    assert!(self.collected_game_fees.contains(&game_id), EGameDoesNotExist);
    self.collected_game_fees[&game_id].value()
}

/// Returns the total collected protocol fees.
public fun collected_protocol_fees(self: &Vault): u64 {
    self.collected_protocol_fees.value()
}

/// Returns the current epoch of the Vault.
public fun epoch(self: &Vault): u64 {
    self.epoch
}

// === Public-Package Functions ===

/// Creates an empty vault, with all balances initialized to zero and the epoch set to the current epoch.
public(package) fun empty(house_id: ID, ctx: &TxContext): Vault {
    Vault {
        house_id,
        epoch: ctx.epoch(),
        collected_protocol_fees: balance::zero(),
        collected_game_fees: vec_map::empty(),
        collected_house_fees: balance::zero(),
        play_balance: balance::zero(),
        reserve_balance: balance::zero(),
    }
}

/// If there is an epoch switch, the end of day is processed. The playable balance is joined back into the reserves, and the last
/// playable balance, which we call the end of day balance, is returned. Current vault epoch is updated.
/// returns (epoch_switched, prev_epoch, end_of_day_balance, was_active)
/// - `epoch_switched` is true if there was a new epoch, and the end of day was processed.
/// - `prev_epoch` will be 0 if there was no epoch switch, and the old epoch number otherwise.
/// - `end_of_day_balance` will be 0 if there was no epoch swith, and the last `play_balance` otherwise.
public(package) fun process_end_of_day(self: &mut Vault, ctx: &TxContext): (bool, u64, u64) {
    if (self.epoch == ctx.epoch()) return (false, 0, 0);
    let prev_epoch = self.epoch;
    let end_of_day_balance = self.play_balance.value();

    // Move the house funds back to the reserve
    let leftover_balance = self.play_balance.withdraw_all();
    let amount_cleared = leftover_balance.value();
    self.reserve_balance.join(leftover_balance);
    self.epoch = ctx.epoch();

    // Event
    emit(PlayBalanceClearedEvent {
        house_id: self.house_id,
        amount: amount_cleared,
    });

    return (true, prev_epoch, end_of_day_balance)
}

/// Funds the `play_balance` to the target_balance.
/// Fails if the reserve does not have enough funds
public(package) fun fund_play_balance(self: &mut Vault, target_balance: u64) {
    assert!(self.reserve_balance.value() >= target_balance, EInsufficientFunds);
    let fresh_play_balance = self.reserve_balance.split(target_balance);
    self.play_balance.join(fresh_play_balance);

    // Event
    emit(PlayBalanceFundedEvent {
        house_id: self.house_id,
        amount: target_balance,
    });
}

/// Deposits stake into the reserve balance.
public(package) fun deposit(self: &mut Vault, stake: Balance<SUI>) {
    self.reserve_balance.join(stake);
}

/// Withdraws the specified amount from the reserve balance.
public(package) fun withdraw(self: &mut Vault, amount: u64): Balance<SUI> {
    self.reserve_balance.split(amount)
}

public(package) fun withdraw_game_fees(self: &mut Vault, game_id: ID): Balance<SUI> {
    self.ensure_game_fee_balance(game_id);

    let balance = &mut self.collected_game_fees[&game_id];
    balance.withdraw_all()
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
/// House fees are deducted from the reserve balance where profits are stored after end-of-day.
public(package) fun process_house_fee(self: &mut Vault, house_fee: u64) {
    if (house_fee > 0) {
        assert!(self.reserve_balance.value() >= house_fee, EInsufficientFunds);
        // House fees are collected from the reserve balance (where profits are stored)
        let balance = self.reserve_balance.split(house_fee);
        self.collected_house_fees.join(balance);
    };
}

/// Settles the balances between the `vault` and `balance_manager`.
/// For `amount_in`, balances are withdrawn from the `balance_manager` and joined with the `play_balance`.
/// For `amount_out`, balances are split from the `play_balance` and deposited into `balance_manager`.
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
        assert!(self.play_balance.value() >= needed, EInsufficientFunds);
        let balance = self.play_balance.split(needed);
        balance_manager.deposit_with_proof(play_proof, balance);
    } else if (amount_in > amount_out) {
        // Balance manager needs to pay the difference to the vault
        let balance;
        balance = balance_manager.withdraw_with_proof(play_proof, amount_in - amount_out);
        self.play_balance.join(balance);
    };
}

/// Processes and collects a protocol fee from the play balance.
/// Aborts if there are insufficient funds.
public(package) fun process_protocol_fee(self: &mut Vault, protocol_fee: u64) {
    assert!(self.play_balance.value() >= protocol_fee, EInsufficientFunds);
    if (protocol_fee > 0) {
        let balance = self.play_balance.split(protocol_fee);
        self.collected_protocol_fees.join(balance);
    };
}

/// Processes and collects a game fee from the play balance for a specific game.
/// Aborts if there are insufficient funds.
public(package) fun process_game_fee(self: &mut Vault, game_id: ID, game_fee: u64) {
    assert!(self.play_balance.value() >= game_fee, EInsufficientFunds);
    if (game_fee > 0) {
        self.ensure_game_fee_balance(game_id);
        let balance = self.play_balance.split(game_fee);
        let game_balance = &mut self.collected_game_fees[&game_id];
        game_balance.join(balance);
    };
}

// === Private Functions ===
/// Ensures a game fee balance exists for the given game ID.
/// Creates a zero balance if it doesn't exist.
fun ensure_game_fee_balance(self: &mut Vault, game_id: ID) {
    if (!self.collected_game_fees.contains(&game_id)) {
        self.collected_game_fees.insert(game_id, balance::zero());
    };
}

// === Test Functions ===
#[test_only]
public fun fund_play_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.play_balance.join(balance);
}

#[test_only]
public fun burn_play_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = self.play_balance.split(amount);
    balance.into_coin(ctx).burn_for_testing();
}

#[test_only]
public fun fund_reserve_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.reserve_balance.join(balance);
}

#[test_only]
public fun burn_reserve_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = self.reserve_balance.split(amount);
    balance.into_coin(ctx).burn_for_testing();
}

#[test_only]
public fun fund_game_fees_for_testing(
    self: &mut Vault,
    game_id: ID,
    amount: u64,
    ctx: &mut TxContext,
) {
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    let ref_balance = &mut self.collected_game_fees[&game_id];
    ref_balance.join(balance);
}

#[test_only]
public fun fund_protocol_fees_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext) {
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.collected_protocol_fees.join(balance);
}
