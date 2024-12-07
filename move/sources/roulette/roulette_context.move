module openplay::roulette_context;

use openplay::roulette_const::{BetType, Color, State, WheelType};


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
    color: Color,
    bet_type: BetType,
}

public struct Outcome {
    number: u8,
    color: Color,
}


public fun empty(): RouletteContext {
    RouletteContext {
        stake: 0,
        prediction: Prediction {
            numbers: vector::empty(),
            color: Color::RED,
            bet_type: BetType::STRAIGHT_UP,
        },
        result: Outcome {
            number: 0,
            color: Color::RED,
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

fun is_win(self: &RouletteContext): bool {
    // check if the player won
    match (self.prediction.bet_type) {
            BetType::STRAIGHT_UP => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::SPLIT => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::STREET => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::CORNER => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::COLUMN => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::DOZEN => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::FIVE_NUMBER => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::HALF => {
            self.prediction.numbers.contains(self.result.number);
        }
            BetType::COLOR => {
            self.prediction.color == self.result.color;
        }
            BetType::EVEN_ODD => {
            self.prediction.numbers.contains(self.result.number);
        }
            _ => {
            false
        }
    }
}


// === Public-Mutative Functions ===
public fun bet(self: &mut RouletteContext, stake: u64, prediction: Prediction, wheel_type: WheelType) {
    validate_prediction(prediction, wheel_type);
    self.stake = stake;
    self.prediction = prediction;
    self.state = State::INITIALIZED;
}

public fun settle(self: &mut RouletteContext, result: Outcome) {
    assert_valid_result(&result);
    self.result = result;
    self.state = State::SETTLED;
}


public fun is_valid_prediction(prediction: Prediction, wheel_type: WheelType) : bool {
    // validate the prediction
    match (prediction.bet_type) {
            BetType::STRAIGHT_UP => {
            (prediction.numbers).len() == 1
        }
            BetType::SPLIT => {
            (prediction.numbers).len() == 2
        }
            BetType::STREET => {
            (prediction.numbers).len() == 3
        }
            BetType::CORNER => {
            (prediction.numbers).len() == 4
        }
            BetType::COLUMN => {
            (prediction.numbers).len() == 12
        }
            BetType::DOZEN => {
            (prediction.numbers).len() == 12
        }
            BetType::FIVE_NUMBER => {
            (prediction.numbers).len() == 5 && wheel_type == WheelType::AMERICAN
        }
            BetType::HALF => {
            (prediction.numbers).len() == 18
        }
            BetType::COLOR => {
            (prediction.numbers).len() == 0
        }
            BetType::EVEN_ODD => {
            (prediction.numbers).len() == 0
        }
            _ => {
            false
        }
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


