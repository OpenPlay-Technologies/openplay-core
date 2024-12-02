/*
Balance manager is an owned object that keeps the balances for the different assets.
It needs to be passed along mutably when playing a game.
The balance_manager module works in a similar fashion as the one in deepbookv3, with the exception that the object is not shared and
it is currently not supported to distribute a capability to play on behalf of a user.
*/
module openplay::balance_manager;

// === Imports ===

// === Structs ===
public struct BalanceManager has key {
    id: UID,
}