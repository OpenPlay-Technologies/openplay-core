/// Balance manager is an owned object that keeps the balances for the different assets.
/// It needs to be passed along mutably when playing a game.
/// The balance_manager module works in a similar fashion as the one in deepbookv3, with the exception that the object is not shared and
/// it is currently not supported to distribute a capability to play on behalf of a user.
/// This will likely be added later.
module openplay::balance_manager;

use sui::balance::Balance;
use sui::sui::SUI;

// === Errors ===
const EBalanceTooLow: u64 = 1;

// === Structs ===
public struct BalanceManager has key {
    id: UID,
    balance: Balance<SUI>,
}

// === Public-View Functions ===
/// Returns the id of the balance_manager.
public fun id(balance_manager: &BalanceManager): ID {
    balance_manager.id.to_inner()
}

// === Public-Package Functions ===
/// Withdraws the provided amount from the `balance`. Fails if there are not sufficient funds.
public(package) fun withdraw_int(self: &mut BalanceManager, withdraw_amount: u64): Balance<SUI> {
    assert!(self.balance.value() > withdraw_amount, EBalanceTooLow);
    self.balance.split(withdraw_amount)
}

/// Deposits the provided balance into the `balance`.
public(package) fun deposit_int(self: &mut BalanceManager, to_deposit: Balance<SUI>) {
    self.balance.join(to_deposit);
}
