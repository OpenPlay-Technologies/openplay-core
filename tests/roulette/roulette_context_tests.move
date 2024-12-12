#[test_only]
module openplay::roulette_context_tests;
use openplay::roulette_prediction::{RoulettePrediction, new};
use openplay::roulette_outcome::{new as roulette_outcome_new};
use openplay::roulette_context::{empty, EInvalidStateTransition};
use openplay::roulette_const::{wheel_type_american, state_initialized, straight_up_bet, state_new, state_settled};
use sui::test_utils::destroy;

#[test]
public fun ok_flow() {
    let mut context = empty();
    assert!(context.get_state() == state_new());


    let mut stakes: vector<u64> = vector::empty();
    vector::push_back(&mut stakes, 10);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    let mut pred_number : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number, 1);

    let pred = new(straight_up_bet(), pred_number);
    vector::push_back(&mut predictions, pred);


    context.bet(stakes, predictions, wheel_type_american());


    assert!(context.get_state() == state_initialized());
    assert!(context.get_predictions().length() == 1);
    assert!(context.get_stakes().length() == 1);

    let outcome = roulette_outcome_new(1);
    context.settle(outcome, wheel_type_american());
    assert!(context.get_outcome_number() == 1);
    assert!(context.get_state() == state_settled());
    assert!(context.get_payout() == 360);

    destroy(context);
}



#[test, expected_failure(abort_code = EInvalidStateTransition)]
public fun invalid_transition_bet_twice() {
    let mut context = empty();
    let mut stakes: vector<u64> = vector::empty();
    vector::push_back(&mut stakes, 10);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    let mut pred_number : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number, 1);

    let pred = new(straight_up_bet(), pred_number);
    vector::push_back(&mut predictions, pred);

    context.bet(stakes, predictions, wheel_type_american());
    context.bet(stakes, predictions, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidStateTransition)]
public fun invalid_transition_settle_twice() {
    let mut context = empty();
    let mut stakes: vector<u64> = vector::empty();
    vector::push_back(&mut stakes, 10);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    let mut pred_number : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number, 1);

    let pred = new(straight_up_bet(), pred_number);
    vector::push_back(&mut predictions, pred);

    let outcome = roulette_outcome_new(1);
    context.bet(stakes, predictions, wheel_type_american());
    context.settle(outcome, wheel_type_american());
    context.settle(outcome, wheel_type_american());
    abort 0
}


#[test, expected_failure(abort_code = EInvalidStateTransition)]
public fun invalid_transition_settle_first() {
    let mut context = empty();
    let outcome = roulette_outcome_new(1);
    context.settle(outcome, wheel_type_american());
    abort 0
}

#[test, expected_failure(abort_code = EInvalidStateTransition)]
public fun invalid_transition_bet_after_settle() {
    let mut context = empty();
    let mut stakes: vector<u64> = vector::empty();
    vector::push_back(&mut stakes, 10);

    let mut predictions : vector<RoulettePrediction> = vector::empty();
    let mut pred_number : vector<u8> = vector::empty();
    vector::push_back(&mut pred_number, 1);

    let pred = new(straight_up_bet(), pred_number);
    vector::push_back(&mut predictions, pred);

    let outcome = roulette_outcome_new(1);
    context.bet(stakes, predictions, wheel_type_american());
    context.settle(outcome, wheel_type_american());
    context.bet(stakes, predictions, wheel_type_american());
    abort 0
}

