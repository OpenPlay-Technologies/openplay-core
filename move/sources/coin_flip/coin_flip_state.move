module openplay::coin_flip_state;

use openplay::coin_flip_const::{
    max_recent_throws,
    head_result,
    tail_result,
    house_bias_result,
    settled_status
};
use openplay::coin_flip_context::CoinFlipContext;
use std::string::String;

// === Structs ===
/// Global state specific to the CoinFlip game
public struct CoinFlipState has store {
    number_of_house_bias: u64,
    number_of_heads: u64,
    number_of_tails: u64,
    recent_throws: vector<String>,
}

// === Public-Mutative Functions
public fun empty(): CoinFlipState {
    CoinFlipState {
        number_of_house_bias: 0,
        number_of_heads: 0,
        number_of_tails: 0,
        recent_throws: vector::empty(),
    }
}

public fun process_context(self: &mut CoinFlipState, ctx: &CoinFlipContext) {
    let outcome = ctx.result();

    // State only needs to be updated on a settle
    if (ctx.status() != settled_status()) return;

    // Recent throws
    self.recent_throws.push_back(outcome);
    if (self.recent_throws.length() > max_recent_throws()) {
        self.recent_throws.remove(0);
    };
    // Counters
    if (outcome == house_bias_result()) {
        self.number_of_house_bias = self.number_of_house_bias + 1
    } else if (outcome == head_result()) {
        self.number_of_heads = self.number_of_heads + 1
    } else if (outcome == tail_result()) {
        self.number_of_tails = self.number_of_tails + 1
    }
}