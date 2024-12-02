module openplay::coin_flip;

// === Imports ===
use openplay::coin_flip_context::{Self, CoinFlipContext};
use openplay::transaction::{Transaction};
use sui::table::{Self, Table};
use sui::random::{RandomGenerator};
use std::vector::{Self, vector};

// === Errors ===
const EUnsupportedStake: u64 = 1;

// === Constants ===
const MAX_HOUSE_EDGE: u64 = 100_000;

// === Structs ===
public struct CoinFlip has key, store {
    id: UID,
    max_stake: u64,
    contexts: Table<ID, CoinFlipContext>,
    house_edge: u64 // Percentage bias in favor of the house (0 to MAX_HOUSE_EDGE, where MAX_HOUSE_EDGE = 100%)
}

public enum Interaction has copy, drop {
    PLACE_BET { stake: u64 }
}

// === Public-Package Functions ===
public(package) fun interact(self: &mut CoinFlip, interact: Interaction, balance_manager_id: ID, rand: &mut RandomGenerator){
    let txs = vector::empty<Transaction>();
    let context = self.get_context(balance_manager_id);
    self.validate_interact(interact);

}

public(package) fun new_interact(interact_type: u8, stake: u64): Interaction {
    match (interact_type){
        0 => Interaction::PLACE_BET { stake },
        _ => abort 0
    }
}


// === Private Functions ===
fun interact_int(self: &mut CoinFlip, context: &mut CoinFlipContext, interact: Interaction, balance_manager_id: ID, 
transactions: &mut vector<Transaction>, rand: &mut RandomGenerator) {
    match (interact){
        Interaction::PLACE_BET { stake } => {
            
        }
    }
}

fun validate_interact(self: &CoinFlip, interaction: Interaction) {
    match (interaction){
        Interaction::PLACE_BET { stake } => {
            assert!(stake < self.max_stake, EUnsupportedStake);
        }
    }
}

fun get_context(self: &mut CoinFlip, balance_manager_id: ID): &mut CoinFlipContext {
    if (!self.contexts.contains(balance_manager_id)){
        self.contexts.add(balance_manager_id, coin_flip_context::empty());
    };
    self.contexts.borrow_mut(balance_manager_id)
}

fun flip_coin(self: &CoinFlip, context: &mut CoinFlipContext, rand: &mut RandomGenerator){
    let x = rand.generate_u64_in_range(0, MAX_HOUSE_EDGE);
    if (x <= self.house_edge){
        context.house_wins_by_bias();
    }
}