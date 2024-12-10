module openplay::roulette_prediction;
use std::string::String;
use openplay::roulette_const::{straight_up_bet, split_bet,
    street_bet, corner_bet, column_bet, dozen_bet, five_number_bet, half_bet,
    even_odd_bet, color_bet, line_bet, wheel_type_american
};

// === Errors ===
const EInvalidPrediction: u64 = 1;

// === Constants ===
public struct RoulettePrediction has copy, store, drop {
    numbers: vector<u8>,
    bet_type: String,
}


// === Public-View Functions ===
public fun get_numbers(self: &RoulettePrediction) : vector<u8> {
    self.numbers
}

public fun get_bet_type(self: &RoulettePrediction) : String {
    self.bet_type
}


/// === Public-Package Functions ===
public(package) fun new(bet_type: String, numbers: vector<u8>) : RoulettePrediction {
    RoulettePrediction {
        numbers,
        bet_type,
    }
}

public(package) fun create_predictions(bet_types : vector<String>, included_numbers : vector<vector<u8>>) : vector<RoulettePrediction> {
    let mut i = 0;
    let len = bet_types.length();
    let mut result : vector<RoulettePrediction> = vector::empty();
    loop {
        if (i == len) {
            break
        };
        let bet_type = bet_types[i];
        let numbers = included_numbers[i];
        vector::push_back(&mut result, new(bet_type, numbers));
        i = i + 1;
    };
    result
}

public(package) fun is_valid_predictions(predictions: vector<RoulettePrediction>, wheel_type: String) : bool {
    let mut i = 0;
    let len = predictions.length();
    loop {
        if (i == len) {
            break
        };
        let prediction = predictions[i];
        if (!prediction.is_valid_prediction(wheel_type)) {
            return false
        };
        i = i + 1;
    };
    true
}

public(package) fun validate_predictions(predictions: vector<RoulettePrediction>, wheel_type: String) {
    assert!(is_valid_predictions(predictions, wheel_type), EInvalidPrediction);
}


/// === Private Functions ===


fun is_valid_prediction(self: &RoulettePrediction, wheel_type: String) : bool {
    if (self.bet_type == straight_up_bet()) {
        (self.numbers).length() == 1
    } else if (self.bet_type == split_bet()) {
        (self.numbers).length() == 2
    } else if (self.bet_type == street_bet()) {
        (self.numbers).length() == 3
    } else if (self.bet_type == corner_bet()) {
        (self.numbers).length() == 4
    } else if (self.bet_type == line_bet()) {
        (self.numbers).length() == 6
    } else if (self.bet_type == column_bet()) {
        (self.numbers).length() == 12
    } else if (self.bet_type == dozen_bet()) {
        (self.numbers).length() == 12
    } else if (self.bet_type == five_number_bet()) {
        (self.numbers).length() == 5 && wheel_type == wheel_type_american()
    } else if (self.bet_type == half_bet()) {
        (self.numbers).length() == 18
    } else if (self.bet_type == color_bet()) {
        (self.numbers).length() == 0
    } else if (self.bet_type == even_odd_bet()) {
        (self.numbers).length() == 0
    } else {
        false
    }
}
