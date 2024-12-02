/*
Registry holds all created games.
*/
module openplay::registry;

// === Imports ===
use sui::bag::{Bag};

// === Structs ===
public struct Registry has key {
    id: UID,
    games: Bag
}