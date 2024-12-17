#[test_only]
module openplay::roulette_state_tests;

use openplay::roulette_const::{straight_up_bet, wheel_type_american};
use openplay::roulette_prediction::{RoulettePrediction, create_prediction};
use openplay::roulette_outcome::{new as roulette_outcome_new};
use openplay::roulette_context::{empty};
use openplay::roulette_state;
use sui::test_utils::destroy;

#[test]
public fun initialization_ok() {
    let state = roulette_state::empty();
    let outcome_counts = state.get_outcome_counts();
    assert!(outcome_counts.length() == 38);
    assert!(state.get_recent_outcomes().length() == 0);

    destroy(state);
}


#[test]
public fun process_context_ok() {
    let mut state = roulette_state::empty();

    // context 1
    let mut context = empty();

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    let mut pred_number : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number, 1);

    let pred = create_prediction(10, straight_up_bet(), pred_number, wheel_type_american());
    vector::push_back(&mut predictions, pred);

    let outcome = roulette_outcome_new(1);
    context.bet(predictions, wheel_type_american());
    context.settle(outcome, wheel_type_american());

    // context 2
    let mut context2 = empty();

    let mut predictions2 : vector<RoulettePrediction> = vector::empty();
    let mut pred_number2 : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number2, 1);

    let pred2 = create_prediction(10, straight_up_bet(), pred_number2, wheel_type_american());
    vector::push_back(&mut predictions2, pred2);

    let outcome2 = roulette_outcome_new(37);
    context2.bet(predictions2, wheel_type_american());
    context2.settle(outcome2, wheel_type_american());

    // context 3
    let mut context3 = empty();

    let mut predictions3 : vector<RoulettePrediction> = vector::empty();
    let mut pred_number3 : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number3, 1);

    let pred3 = create_prediction(10, straight_up_bet(), pred_number3, wheel_type_american());
    vector::push_back(&mut predictions3, pred3);

    let outcome3 = roulette_outcome_new(37);
    context3.bet(predictions3, wheel_type_american());
    context3.settle(outcome3, wheel_type_american());

    state.process_context(&context);
    state.process_context(&context2);
    state.process_context(&context3);


    assert!(state.get_outcome_counts()[1] == 1);
    assert!(state.get_recent_outcomes().length() == 3);
    assert!(state.get_outcome_counts()[37] == 2);

    destroy(state);
    destroy(context);
    destroy(context2);
    destroy(context3);
}


