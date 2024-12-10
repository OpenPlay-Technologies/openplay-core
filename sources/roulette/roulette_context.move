module openplay::roulette_context;

// === Imports ===
use std::string::String;
use openplay::roulette_prediction::{RoulettePrediction, validate_predictions};
use openplay::roulette_outcome;
use openplay::roulette_outcome::{RouletteOutcome, assert_valid_result};
use openplay::roulette_const::{straight_up_bet, split_bet,
    street_bet, corner_bet, column_bet, dozen_bet, five_number_bet, half_bet,
    even_odd_bet, color_bet, line_bet, state_new, state_initialized, state_settled,
    straight_up_payout_factor, split_payout_factor, street_payout_factor, corner_payout_factor,
    column_payout_factor, dozen_payout_factor, five_number_payout_factor, half_payout_factor,
    color_payout_factor, even_odd_payout_factor, line_payout_factor
};


// === Errors ===
const EInvalidPrediction: u64 = 1;
const EInvalidStateTransition: u64 = 2;

// === Structs ===
public struct RouletteContext has store {
    stakes: vector<u64>,
    predictions: vector<RoulettePrediction>,
    result: RouletteOutcome,
    state: String,
}

// === Public-View Functions ===
public fun result(self: &RouletteContext): RouletteOutcome {
    self.result
}

public fun get_outcome_number(self: &RouletteContext) : u8 {
    self.result.get_number()
}

public fun get_state(self: &RouletteContext) : String {
    self.state
}

// === Public-Mutative Functions ===
public fun empty(): RouletteContext {
    RouletteContext {
        stakes: vector::empty<u64>(),
        predictions: vector::empty<RoulettePrediction>(),
        result: roulette_outcome::empty(),
        state: state_new(),
    }
}

// === Public-Package Functions ===
public(package) fun bet(self: &mut RouletteContext, stakes: vector<u64>, predictions: vector<RoulettePrediction>, wheel_type: String) {
    validate_predictions(predictions, wheel_type);
    self.assert_valid_state_transition(state_initialized());
    self.stakes = stakes;
    self.predictions = predictions;
    self.state = state_initialized();
}

public(package) fun settle(self: &mut RouletteContext, result: RouletteOutcome, wheel_type: String) {
    assert_valid_result(&result, wheel_type);
    self.assert_valid_state_transition(state_settled());
    self.result = result;
    self.state = state_settled();
}

public(package) fun get_payout(self: &RouletteContext) : u64 {
    // get the payout
    let num_predictions = (self.predictions).length();
    let mut i : u8 = 0;
    let mut total_payout = 0;
    loop {
        if (i as u64 == num_predictions) {
            break
        };
        let prediction = &self.predictions[i as u64];

        if (self.is_win(i)) {
            total_payout = total_payout + self.stakes[i as u64] * (get_payout_factor(prediction.get_bet_type()) as u64)
        };

        i = (i + 1);
    };

    total_payout
}


public(package) fun is_valid_stakes(stakes: vector<u64>, max_stake: u64) : bool {
    let mut i = 0;
    let len = stakes.length();
    loop {
        if (i == len) {
            break
        };
        let stake = stakes[i];
        if (!is_valid_stake(stake, max_stake)) {
            return false
        };
        i = i + 1;
    };
    true
}

// === Private Functions ===
fun is_valid_stake(stake: u64, max_stake: u64) : bool {
    stake <= max_stake
}

fun assert_valid_state_transition(self: &RouletteContext, new_status: String) {
    let current_status = self.state;
    if (current_status == state_new()) {
        assert!(new_status == state_initialized(), EInvalidStateTransition);
    } else if (current_status == state_initialized()) {
        assert!(new_status == state_settled(), EInvalidStateTransition);
    } else if (current_status == state_settled()) {
        assert!(false, EInvalidStateTransition);
    }
}

fun get_payout_factor(bet_type: String) : u8 {
    if (bet_type == straight_up_bet()) {
        straight_up_payout_factor()
    }
    else if (bet_type == split_bet()) {
        split_payout_factor()
    }
    else if (bet_type == street_bet()) {
        street_payout_factor()
    }
    else if (bet_type == corner_bet()) {
        corner_payout_factor()
    }
    else if (bet_type == column_bet()) {
        column_payout_factor()
    }
    else if (bet_type == dozen_bet()) {
        dozen_payout_factor()
    }
    else if (bet_type == line_bet()) {
        line_payout_factor()
    }
    else if (bet_type == five_number_bet()) {
        five_number_payout_factor()
    }
    else if (bet_type == half_bet()) {
        half_payout_factor()
    }
    else if (bet_type == color_bet()) {
        color_payout_factor()
    }
    else if (bet_type == even_odd_bet()) {
        even_odd_payout_factor()
    }
    else {
        abort EInvalidPrediction
    }
}

fun is_win(self: &RouletteContext, i : u8): bool {
    // check if the player won
    let prediction = &self.predictions[i as u64];
    prediction.get_numbers().contains(&self.get_outcome_number())
}

