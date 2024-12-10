module openplay::roulette_prediction_tests;


#[test_only]
use openplay::roulette_const::{straight_up_bet, wheel_type_american, five_number_bet, wheel_type_european, split_bet};
use openplay::roulette_prediction::{RoulettePrediction, EInvalidPrediction, new, validate_predictions, create_predictions};
use std::string::{String,utf8};


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_predictions_invalid_length() {

    let mut invalid_prediction_length : vector<u8> = vector::empty();
    vector::push_back(&mut invalid_prediction_length, 1);
    vector::push_back(&mut invalid_prediction_length, 2);
    let invalid_prediction = new(straight_up_bet(), invalid_prediction_length);

    let mut valid_prediction_length : vector<u8> = vector::empty();
    vector::push_back(&mut valid_prediction_length, 1);
    let valid_prediction = new(straight_up_bet(), valid_prediction_length);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    vector::push_back(&mut predictions, invalid_prediction);
    vector::push_back(&mut predictions, valid_prediction);


    validate_predictions(predictions, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun not_valid_predictions_not_correct_wheel_type() {

    let mut five_number : vector<u8> = vector::empty();
    vector::push_back(&mut five_number, 37);
    vector::push_back(&mut five_number, 0);
    vector::push_back(&mut five_number, 1);
    vector::push_back(&mut five_number, 2);
    vector::push_back(&mut five_number, 3);


    let invalid_wheel_type = new(five_number_bet(), five_number);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    vector::push_back(&mut predictions, invalid_wheel_type);


    validate_predictions(predictions, wheel_type_european());
    abort 0
}


#[test, expected_failure(abort_code = EInvalidPrediction)]
public fun invalid_bet_type() {

    let invalid_bet_type : vector<u8> = vector::empty();


    let invalid_prediction = new(utf8(b"invalid"), invalid_bet_type);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    vector::push_back(&mut predictions, invalid_prediction);


    validate_predictions(predictions, wheel_type_european());
    abort 0
}


#[test]
public fun valid_predictions() {
    let mut five_number : vector<u8> = vector::empty();
    vector::push_back(&mut five_number, 37);
    vector::push_back(&mut five_number, 0);
    vector::push_back(&mut five_number, 1);
    vector::push_back(&mut five_number, 2);
    vector::push_back(&mut five_number, 3);

    let five_number_prediction = new(five_number_bet(), five_number);

    let mut straight_up : vector<u8> = vector::empty();
    vector::push_back(&mut straight_up, 12);
    let straight_up_prediction = new(straight_up_bet(), straight_up);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    vector::push_back(&mut predictions, five_number_prediction);
    vector::push_back(&mut predictions, straight_up_prediction);

    validate_predictions(predictions, wheel_type_american());
}


#[test]
public fun can_create_single_prediction() {
    let mut bet_types: vector<String> = vector::empty();
    vector::push_back(&mut bet_types, straight_up_bet());
    vector::push_back(&mut bet_types, split_bet());

    let mut included_numbers: vector<vector<u8>> = vector::empty();
    let mut straight_up_numbers: vector<u8> = vector::empty();
    vector::push_back(&mut straight_up_numbers, 12);

    let mut split_numbers: vector<u8> = vector::empty();
    vector::push_back(&mut split_numbers, 2);
    vector::push_back(&mut split_numbers, 5);

    vector::push_back(&mut included_numbers, straight_up_numbers);
    vector::push_back(&mut included_numbers, split_numbers);


    let predictions = create_predictions(bet_types, included_numbers);

    assert!(predictions.length() == 2);

    let first_prediction = predictions[0];
    assert!(first_prediction.get_bet_type() == straight_up_bet());
    assert!((first_prediction.get_numbers()).length() == 1);


    let second_prediction = predictions[1];
    assert!(second_prediction.get_bet_type() == split_bet());
    assert!((second_prediction.get_numbers()).length() == 2);
}
