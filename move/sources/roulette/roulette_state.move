module openplay::roulette_state;

use openplay::roulette_const::{state_settled, max_recent_outcomes};
use openplay::roulette_context::{RouletteContext};


public struct RouletteState has store {
    outcome_count : vector<u8>, // vector with as index the outcome number and as value the count. 37 is 00.
    recent_outcomes : vector<u8>,
}

public fun empty(): RouletteState {

    let outcome_count = initialize_array_with_zeros();

    RouletteState {
        outcome_count,
        recent_outcomes: vector::empty(),
    }
}

public fun process_context(self: &mut RouletteState, ctx: &RouletteContext) {
    let outcome_number = ctx.get_outcome_number();

    // State only needs to be updated on a settle
    if (ctx.get_state() != state_settled()) {
        return
    };

    // Recent outcomes
    self.recent_outcomes.push_back(outcome_number);
    if (self.recent_outcomes.length() > max_recent_outcomes()) {
        self.recent_outcomes.remove(0);
    };

    // Counters
    let count_ref = vector::borrow_mut(&mut self.outcome_count, outcome_number as u64);
    *count_ref = *count_ref + 1;
}


public fun initialize_array_with_zeros(): vector<u8> {
    let mut v = vector::empty<u8>();
    let length = 38;

    // Push 0 into the vector 37 times
    let mut i = 0;
    while (i < length) {
        vector::push_back(&mut v, 0);
        i = i + 1;
    };

    v
}


