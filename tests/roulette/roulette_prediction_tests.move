#[test_only]
module openplay::roulette_prediction_tests;


use openplay::roulette_const::{straight_up_bet, wheel_type_american, split_bet, street_bet, corner_bet, five_number_bet,
    wheel_type_european, line_bet, color_bet, even_odd_bet, column_bet, dozen_bet, half_bet
};
use openplay::roulette_prediction::{EInvalidPrediction, create_prediction};


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_straight_up_bet_empty_prediction() {

    let prediction_value : vector<u8> = vector::empty();
    let _ = create_prediction(10, straight_up_bet(),prediction_value, wheel_type_american());
    abort 0
}


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_straight_up_bet_invalid_number() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 38);
    let _ = create_prediction(10, straight_up_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_straight_up_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, straight_up_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_straight_up() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    let prediction = create_prediction(10, straight_up_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 1);
    assert!(prediction.get_bet_type() == straight_up_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_split_bet_invalid_number() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 38);
    vector::push_back(&mut prediction_value, 5);
    let _ = create_prediction(10, split_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_split_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    let _ = create_prediction(10, split_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_split() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let prediction = create_prediction(10, split_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 2);
    assert!(prediction.get_bet_type() == split_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_street_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 12);
    let _ = create_prediction(10, street_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_street_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, street_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_street() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, street_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 3);
    assert!(prediction.get_bet_type() == street_bet());
}


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_corner_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 22);
    let _ = create_prediction(10, corner_bet(), prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_corner_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, corner_bet(), prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_corner() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, corner_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 4);
    assert!(prediction.get_bet_type() == corner_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_five_number_european() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let _ = create_prediction(10, five_number_bet(), prediction_value, wheel_type_european());
    abort 0
}

#[test]
public fun valid_prediction_five_number() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, five_number_bet(), prediction_value, wheel_type_american());
    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 5);
    assert!(prediction.get_bet_type() == five_number_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_line_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 11);
    let _ = create_prediction(10, line_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_line_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, line_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_line() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, line_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 6);
    assert!(prediction.get_bet_type() == line_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_column_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 3);
    let _ = create_prediction(10, column_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_column_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, column_bet(),prediction_value, wheel_type_american());
    abort 0
}


#[test]
public fun valid_prediction_column() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, column_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 12);
    assert!(prediction.get_bet_type() == column_bet());
}


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_dozen_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 3);
    let _ = create_prediction(10, dozen_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_dozen_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, dozen_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_dozen() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, dozen_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 12);
    assert!(prediction.get_bet_type() == dozen_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_even_odd_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 3);
    let _ = create_prediction(10, even_odd_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_even_odd_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, even_odd_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_even_odd() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, even_odd_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    let even_number = prediction_numbers[0];
    assert!(prediction_numbers.length() == 18);
    assert!(even_number == 2);

    assert!(prediction.get_bet_type() == even_odd_bet());
}


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_red_black_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 3);
    let _ = create_prediction(10, color_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_prediction_red_black_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, color_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_prediction_red_black() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0); // 1 is red
    let prediction = create_prediction(10, color_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    let red_number = prediction_numbers[0];
    assert!(prediction_numbers.length() == 18);
    assert!(red_number == 1); // 1 is the first defined number in the red array

    assert!(prediction.get_bet_type() == color_bet());
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_half_bet_invalid_index() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 2);
    let _ = create_prediction(10, half_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_half_bet_invalid_length() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 5);
    vector::push_back(&mut prediction_value, 6);
    let _ = create_prediction(10, half_bet(),prediction_value, wheel_type_american());
    abort 0
}

#[test]
public fun valid_half_bet() {

    let mut prediction_value : vector<u8> = vector::empty();
    vector::push_back(&mut prediction_value, 0);
    let prediction = create_prediction(10, half_bet(), prediction_value, wheel_type_american());

    let prediction_numbers = prediction.get_prediction_numbers();
    assert!(prediction_numbers.length() == 18);
    assert!(prediction.get_bet_type() == half_bet());
}