/// The vault holds all of the assets of a game. At the end of all
/// transaction processing, the vault is used to settle the balances for the user.
/// The vault is also responsible for taking a fee when processing transactions
module openplay::vault;

use openplay::balance_manager::BalanceManager;
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use openplay::constants::{precision_error_allowance};

// === Errors ===
const EInsufficientFunds: u64 = 1;

// === Structs ===
public struct Vault has store {
    epoch: u64,
    collected_protocol_fees: Balance<SUI>,
    collected_owner_fees: Balance<SUI>,
    play_balance: Balance<SUI>,
    reserve_balance: Balance<SUI>,
    active: bool // A boolean indicating whether the vault has been activated by stake, and the play_balance funded
}

// === Public-View Functions ---
public fun play_balance(self: &Vault): u64 {
    self.play_balance.value()
}

public fun reserve_balance(self: &Vault): u64 {
    self.reserve_balance.value()
}

public fun collected_owner_fees(self: &Vault): u64 {
    self.collected_owner_fees.value()
}

public fun collected_protocol_fees(self: &Vault): u64 {
    self.collected_protocol_fees.value()
}

public fun epoch(self: &Vault): u64 {
    self.epoch
}

// === Public-Package Functions ===

/// Creates an empty vault, with all balances initialized to zero and the epoch set to the current epoch.
public(package) fun empty(ctx: &TxContext): Vault {
    Vault {
        epoch: ctx.epoch(),
        collected_protocol_fees: balance::zero(),
        collected_owner_fees: balance::zero(),
        play_balance: balance::zero(),
        reserve_balance: balance::zero(),
        active: false
    }
}

/// Processes the end of day for the vault, if applicable.
/// returns (epoch_switched, prev_epoch, end_of_day_balance, was_active)
/// - `epoch_switched` is true if there was a new epoch, and the end of day was processed.
/// - `prev_epoch` will be 0 if there was no epoch switch, and the old epoch number otherwise.
/// - `end_of_day_balance` will be 0 if there was no epoch swith, and the last `play_balance` otherwise.
/// - `was_active` will be false if there was no epoch switch, and the vault activation state otherwise. This
/// says if the vault was activated in the previous epoch.
public(package) fun process_end_of_day(
    self: &mut Vault,
    ctx: &TxContext,
): (bool, u64, u64, bool) {
    if (self.epoch == ctx.epoch()) return (false, 0, 0, false);
    let prev_epoch = self.epoch;
    let end_of_day_balance = self.play_balance.value();
    let was_active = self.active;

    // Move the house funds back to the reserve
    let leftover_balance = self.play_balance.withdraw_all();
    self.reserve_balance.join(leftover_balance);
    self.active = false;

    self.epoch = ctx.epoch();
    return (true, prev_epoch, end_of_day_balance, was_active)
}

/// Activates the vault. This will set `active` to true, and fund the `play_balance` to the target_balance.
public(package) fun activate(self: &mut Vault, target_balance: u64) {
    assert!(self.reserve_balance.value() >= target_balance, EInsufficientFunds);
    let fresh_play_balance = self.reserve_balance.split(target_balance);
    self.play_balance.join(fresh_play_balance);
    self.active = true;
}

/// Settles the balances between the `vault` and `balance_manager`.
/// For `amount_in`, balances are withdrawn from the `balance_manager` and joined with the `play_balance` or `reserve_balance`.
/// For `amount_out`, balances are split from the `play_balance` and deposited into `balance_manager` or `reserve_balance`.
/// Gameplay transactions are settled from the `play_balance`, while other transactions are settled from the `reserve_balance`.
public(package) fun settle_balance_manager(
    self: &mut Vault,
    amount_out: u64,
    amount_in: u64,
    balance_manager: &mut BalanceManager,
    game_play: bool
) {
    if (amount_out > amount_in) {
        // Vault needs to pay the difference to the balance_manager
        let balance;
        if (game_play){
            if (self.play_balance.value() >= amount_out - amount_in){
                balance = self.play_balance.split(amount_out - amount_in);
            }
            else if (amount_out - amount_in - self.play_balance.value() <= precision_error_allowance()) {
                // Small precision errors
                balance = self.play_balance.withdraw_all();
            }
            else {
                abort EInsufficientFunds
            }
        }
        else {
            if (self.reserve_balance.value() >= amount_out - amount_in){
                balance = self.reserve_balance.split(amount_out - amount_in);
            }
            else if (amount_out - amount_in - self.reserve_balance.value() <= precision_error_allowance()) {
                // This can only happen with small precision errors
                balance = self.reserve_balance.withdraw_all();
            }
            else {
                abort EInsufficientFunds
            }  
        };
        balance_manager.deposit(balance);
    } else if (amount_in > amount_out) {
        // Balance manager needs to pay the difference to the vault
        let balance;
        balance = balance_manager.withdraw(amount_in - amount_out);
        if (game_play){
            self.play_balance.join(balance);
        }
        else {
            self.reserve_balance.join(balance);
        }
    };
}

/// Process the fees of the game owner and protocol.
public(package) fun process_fees(self: &mut Vault, owner_fee: u64, protocol_fee: u64) {
    assert!(self.play_balance.value() > owner_fee + protocol_fee, EInsufficientFunds);
    if (owner_fee > 0) {
        let balance = self.play_balance.split(owner_fee);
        self.collected_owner_fees.join(balance);
    };
    if (protocol_fee > 0) {
        let balance = self.play_balance.split(protocol_fee);
        self.collected_protocol_fees.join(balance);
    };
}

// === Test Functions ===
#[test_only]
public fun fund_play_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext){
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.play_balance.join(balance);
}

#[test_only]
public fun burn_play_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext){
    let balance = self.play_balance.split(amount);
    balance.into_coin(ctx).burn_for_testing();
}

#[test_only]
public fun fund_reserve_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext){
    let balance = sui::coin::mint_for_testing(amount, ctx).into_balance();
    self.reserve_balance.join(balance);
}

#[test_only]
public fun burn_reserve_balance_for_testing(self: &mut Vault, amount: u64, ctx: &mut TxContext){
    let balance = self.reserve_balance.split(amount);
    balance.into_coin(ctx).burn_for_testing();
}