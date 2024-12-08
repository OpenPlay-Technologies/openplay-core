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
    stake: u64,
    prediction: Prediction,
    result: Outcome,
    state: String,
}

public struct Prediction has copy, store, drop {
    numbers: vector<u8>,
    color: String,
    bet_type: String,
}

public struct Outcome has store, drop, copy {
    number: u8,
    color: String,
}


public fun empty(): RouletteContext {
    RouletteContext {
        stake: 0,
        prediction: Prediction {
            numbers: vector::empty(),
            color: color_red(),
            bet_type: straight_up_bet(),
        },
        result: Outcome {
            number: 0,
            color: color_red(),
        },
        state: state_new(),
    }
}

// === Public-View Functions ===
public fun stake(self: &RouletteContext): u64 {
    self.stake
}

public fun prediction(self: &RouletteContext): Prediction {
    self.prediction
}

public fun result(self: &RouletteContext): Outcome {
    self.result
}


public fun get_outcome_number(self: &RouletteContext) : u8 {
    self.result.number
}

public fun get_state(self: &RouletteContext) : String {
    self.state
}

public fun get_outcome_color(self: &RouletteContext) : String {
    self.result.color
}


public(package) fun create_prediction(bet_type: String, numbers: vector<u8>, color: String) : Prediction {
    Prediction {
        numbers,
        color,
        bet_type,
    }
}

public(package) fun create_outcome(number: u8, color: String) : Outcome {
    Outcome {
        number,
        color,
    }
}


fun is_win(self: &RouletteContext): bool {
    // check if the player won
    if (self.prediction.bet_type == straight_up_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == split_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == street_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == corner_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == column_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == dozen_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == five_number_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == half_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else if (self.prediction.bet_type == column_bet()) {
        self.prediction.color == self.get_outcome_color()
    } else if (self.prediction.bet_type == even_odd_bet()) {
        self.prediction.numbers.contains(&self.get_outcome_number())
    } else {
        abort EInvalidPrediction
    }
}


// === Public-Mutative Functions ===
public fun bet(self: &mut RouletteContext, stake: u64, prediction: Prediction, wheel_type: String) {
    validate_prediction(prediction, wheel_type);
    assert_valid_state_transition(self, state_initialized());
    self.stake = stake;
    self.prediction = prediction;
    self.state = state_initialized();
}

public fun settle(self: &mut RouletteContext, result: Outcome, wheel_type: String) {
    assert_valid_result(&result, wheel_type);
    assert_valid_state_transition(self, state_settled());
    self.result = result;
    self.state = state_settled();
}

public fun get_payout(self: &RouletteContext) : u64 {
    // get the payout
    if (self.is_win()) {
        self.stake * (get_payout_factor(self.prediction.bet_type) as u64)
    } else {
        0
    }
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


fun validate_prediction(prediction: Prediction, wheel_type: String) {
    // validate the prediction
    assert!(is_valid_prediction(prediction, wheel_type), EInvalidPrediction);
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


