module openplay::roulette_state;
use sui::borrow;
use openplay::roulette_const::State;
use openplay::roulette_context::{RouletteContext};
use sui::table::Table;


public struct RouletteState has store {
    outcome_count : Table<u8,u64>,
    recent_outcomes : vector<u8>,
}

public fun empty(): RouletteState {
    RouletteState {
        outcome_count: table::new(),
        recent_outcomes: vector::empty(),
    }
}

public fun process_context(self: &mut RouletteState, ctx: &RouletteContext) {
    let outcome_number = ctx.get_outcome_number();

    // State only needs to be updated on a settle
    if (ctx.state() != State::SETTLED) {
        return;
    };

    // Recent outcomes
    self.recent_outcomes.push_back(outcome_number);
    if (self.recent_outcomes.length() > max_recent_outcomes()) {
        self.recent_outcomes.remove(0);
    };

    // Counters
    let count = self.outcome_count.get_or_default(outcome_number, 0);
    self.outcome_count.insert(outcome_number, count + 1);
}


