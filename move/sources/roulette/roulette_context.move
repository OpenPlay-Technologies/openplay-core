module openplay::roulette_context;

use std::string;
use std::string::String;
use sui::balance::split;
use openplay::roulette_const::{State, WheelType, color_red, straight_up_bet, split_bet,
    street_bet, corner_bet, column_bet, dozen_bet, five_number_bet, half_bet,
    even_odd_bet, color_bet, line_bet
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
    state: State,
}

public struct Prediction has copy {
    numbers: vector<u8>,
    color: String,
    bet_type: String,
}

public struct Outcome {
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
        state: State::NEW,
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

fun is_win(self: &RouletteContext): bool {
    // check if the player won
    if (self.prediction.bet_type == straight_up_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == split_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == street_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == corner_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == column_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == dozen_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == five_number_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == half_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else if (self.prediction.bet_type == column_bet()) {
        self.prediction.color == self.result.color
    } else if (self.prediction.bet_type == even_odd_bet()) {
        self.prediction.numbers.contains(self.result.number)
    } else {
        abort EInvalidPrediction
    }
}


// === Public-Mutative Functions ===
public fun bet(self: &mut RouletteContext, stake: u64, prediction: Prediction, wheel_type: WheelType) {
    validate_prediction(prediction, wheel_type);
    self.stake = stake;
    self.prediction = prediction;
    self.state = State::INITIALIZED;
}

public fun settle(self: &mut RouletteContext, result: Outcome, wheel_type: WheelType) {
    assert_valid_result(&result, wheel_type);
    self.result = result;
    self.state = State::SETTLED;
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


public fun is_valid_prediction(prediction: Prediction, wheel_type: WheelType) : bool {
    // validate the prediction
    if (prediction.bet_type == straight_up_bet()) {
        (prediction.numbers).len() == 1
    } else if (prediction.bet_type == split_bet()) {
        (prediction.numbers).len() == 2
    } else if (prediction.bet_type == street_bet()) {
        (prediction.numbers).len() == 3
    } else if (prediction.bet_type == corner_bet()) {
        (prediction.numbers).len() == 4
    } else if (prediction.bet_type == line_bet()) {
        (prediction.numbers).len() == 6
    } else if (prediction.bet_type == column_bet()) {
        (prediction.numbers).len() == 12
    } else if (prediction.bet_type == dozen_bet()) {
        (prediction.numbers).len() == 12
    } else if (prediction.bet_type == five_number_bet()) {
        (prediction.numbers).len() == 5 && wheel_type == WheelType::AMERICAN
    } else if (prediction.bet_type == half_bet()) {
        (prediction.numbers).len() == 18
    } else if (prediction.bet_type == color_bet()) {
        (prediction.numbers).len() == 0
    } else if (prediction.bet_type == even_odd_bet()) {
        (prediction.numbers).len() == 0
    } else {
        false
    }
}


fun validate_prediction(prediction: Prediction, wheel_type: WheelType) {
    // validate the prediction
    assert!(is_valid_prediction(prediction, wheel_type), EInvalidPrediction);
}

fun assert_valid_result(result: &Outcome, wheel_type: WheelType) {
    // validate the result

    let maxNumber = match (wheel_type) {
        WheelType::AMERICAN => 37, // we mock 00 as 37
        WheelType::EUROPEAN => 36,
    };

    assert!((result.number) >= 0 && (result.number) <= maxNumber, EInvalidResult);
}

fun assert_valid_state_transition(self: &RouletteContext, new_status: State) {
    // validate the state transition
    let current_status = self.state;
    match (current_status) {
        State::NEW => {
            assert!(new_status == State::INITIALIZED, EInvalidStateTransition);
        }
        State::INITIALIZED => {
            assert!(new_status == State::SETTLED, EInvalidStateTransition);
        }
        State::SETTLED => {
            assert!(false, EInvalidStateTransition);
        }
    }
}


