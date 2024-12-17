module openplay::roulette_outcome_tests;

use openplay::roulette_const;
use openplay::roulette_outcome::{new, EInvalidResult, assert_valid_result};

#[test, expected_failure(abort_code = EInvalidResult)]
public fun invalid_outcome() {
    let outcome = new(37);
    outcome.assert_valid_result(roulette_const::wheel_type_european());
    abort 0
}


#[test]
public fun valid_outcome() {
    let outcome = new(0);
    outcome.assert_valid_result(roulette_const::wheel_type_european());
}


#[test]
public fun valid_outcome_american() {
    let outcome = new(37);
    outcome.assert_valid_result(roulette_const::wheel_type_american());
}

#[test, expected_failure(abort_code = EInvalidResult)]
public fun invalid_outcome_2() {
    let outcome = new(38);
    outcome.assert_valid_result(roulette_const::wheel_type_american());
    abort 0
}


#[test]
public fun new_outcome() {
    let outcome = new(0);
    assert!(outcome.get_number() == 0);
}
