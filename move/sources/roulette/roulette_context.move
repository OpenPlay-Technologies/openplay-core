module openplay::roulette_context;

use std::string::String;
use openplay::roulette_const::{ color_red, straight_up_bet, split_bet,
    street_bet, corner_bet, column_bet, dozen_bet, five_number_bet, half_bet,
    even_odd_bet, color_bet, line_bet, state_new, state_initialized, state_settled, wheel_type_american,
    straight_up_payout_factor, split_payout_factor, street_payout_factor, corner_payout_factor,
    column_payout_factor, dozen_payout_factor, five_number_payout_factor, half_payout_factor,
    color_payout_factor, even_odd_payout_factor, line_payout_factor, get_number_slots
};


// === Errors ===
const EInvalidPrediction: u64 = 1;
const EInvalidResult: u64 = 2;
const EInvalidStateTransition: u64 = 3;

// === Structs ===
public struct RouletteContext has store {
    stakes: vector<u64>,
    predictions: vector<Prediction>,
    result: Outcome,
    state: String,
}

public struct Prediction has copy, store, drop {
    numbers: vector<u8>,
    bet_type: String,
}

public struct Outcome has store, drop, copy {
    number: u8,
    color: String,
}


public fun empty(): RouletteContext {
    RouletteContext {
        stakes: vector::empty<u64>(),
        predictions: vector::empty<Prediction>(),
        result: Outcome {
            number: 0,
            color: color_red(),
        },
        state: state_new(),
    }
}

// === Public-View Functions ===
public fun result(self: &RouletteContext): Outcome {
    self.result
}


public fun get_outcome_number(self: &RouletteContext) : u8 {
    self.result.number
}

public fun get_state(self: &RouletteContext) : String {
    self.state
}


public(package) fun create_prediction(bet_type: String, numbers: vector<u8>) : Prediction {
    Prediction {
        numbers,
        bet_type,
    }
}


public(package) fun create_predictions(bet_types : vector<String>, included_numbers : vector<vector<u8>>) : vector<Prediction> {
    let mut i = 0;
    let len = bet_types.length();
    let mut result : vector<Prediction> = vector::empty();
    loop {
        if (i == len) {
            break
        };
        let bet_type = bet_types[i];
        let numbers = included_numbers[i];
        vector::push_back(&mut result, create_prediction(bet_type, numbers));
        i = i + 1;
    };
    result
}

public(package) fun create_outcome(number: u8, color: String) : Outcome {
    Outcome {
        number,
        color,
    }
}


fun is_win(self: &RouletteContext, i : u8): bool {
    // check if the player won
    let prediction = &self.predictions[i as u64];
    prediction.numbers.contains(&self.get_outcome_number())
}


// === Public-Mutative Functions ===
public fun bet(self: &mut RouletteContext, stakes: vector<u64>, predictions: vector<Prediction>, wheel_type: String) {
    validate_predictions(predictions, wheel_type);
    self.assert_valid_state_transition(state_initialized());
    self.stakes = stakes;
    self.predictions = predictions;
    self.state = state_initialized();
}

public fun settle(self: &mut RouletteContext, result: Outcome, wheel_type: String) {
    assert_valid_result(&result, wheel_type);
    self.assert_valid_state_transition(state_settled());
    self.result = result;
    self.state = state_settled();
}

public fun get_payout(self: &RouletteContext) : u64 {
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
            total_payout = total_payout + self.stakes[i as u64] * (get_payout_factor(prediction.bet_type) as u64)
        };

        i = (i + 1);
    };

    total_payout
}


public fun get_payout_factor(bet_type: String) : u8 {
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


public fun is_valid_stakes(stakes: vector<u64>, max_stake: u64) : bool {
    // validate the stakes
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

public fun is_valid_stake(stake: u64, max_stake: u64) : bool {
    // validate the stake
    stake <= max_stake
}

public fun is_valid_predictions(predictions: vector<Prediction>, wheel_type: String) : bool {
    // validate the predictions
    let mut i = 0;
    let len = predictions.length();
    loop {
        if (i == len) {
            break
        };
        let prediction = predictions[i];
        if (!is_valid_prediction(prediction, wheel_type)) {
            return false
        };
        i = i + 1;
    };
    true
}

public fun is_valid_prediction(prediction: Prediction, wheel_type: String) : bool {
    // validate the prediction
    if (prediction.bet_type == straight_up_bet()) {
        (prediction.numbers).length() == 1
    } else if (prediction.bet_type == split_bet()) {
        (prediction.numbers).length() == 2
    } else if (prediction.bet_type == street_bet()) {
        (prediction.numbers).length() == 3
    } else if (prediction.bet_type == corner_bet()) {
        (prediction.numbers).length() == 4
    } else if (prediction.bet_type == line_bet()) {
        (prediction.numbers).length() == 6
    } else if (prediction.bet_type == column_bet()) {
        (prediction.numbers).length() == 12
    } else if (prediction.bet_type == dozen_bet()) {
        (prediction.numbers).length() == 12
    } else if (prediction.bet_type == five_number_bet()) {
        (prediction.numbers).length() == 5 && wheel_type == wheel_type_american()
    } else if (prediction.bet_type == half_bet()) {
        (prediction.numbers).length() == 18
    } else if (prediction.bet_type == color_bet()) {
        (prediction.numbers).length() == 0
    } else if (prediction.bet_type == even_odd_bet()) {
        (prediction.numbers).length() == 0
    } else {
        false
    }
}


fun validate_predictions(predictions: vector<Prediction>, wheel_type: String) {
    // validate the predictions
    assert!(is_valid_predictions(predictions, wheel_type), EInvalidPrediction);
}

fun assert_valid_result(result: &Outcome, wheel_type: String) {
    // validate the result

    let maxNumber = get_number_slots(wheel_type) - 1; // subtract one because slots start at 0

    assert!((result.number) >= 0 && (result.number) <= maxNumber, EInvalidResult);
}

fun assert_valid_state_transition(self: &RouletteContext, new_status: String) {
    // validate the state transition
    let current_status = self.state;
    if (current_status == state_new()) {
        assert!(new_status == state_initialized(), EInvalidStateTransition);
    } else if (current_status == state_initialized()) {
        assert!(new_status == state_settled(), EInvalidStateTransition);
    } else if (current_status == state_settled()) {
        assert!(false, EInvalidStateTransition);
    }
}


