/// Registry holds all created games.
module openplay::registry; // TODO: implementation

// === Imports ===
//use sui::bag::{Bag};

// === Structs ===
public struct Registry has key {
    id: UID,
    // fee_rescipient: address,
    // games: Bag
}