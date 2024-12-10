#[test_only]
module openplay::coin_flip_context_tests;

use openplay::coin_flip_const::{
    head_result,
    tail_result,
    new_status,
    initialized_status,
    settled_status
};
use openplay::coin_flip_context;
use std::string::utf8;
use sui::test_utils::destroy;

#[test, expected_failure(abort_code = coin_flip_context::EInvalidStateTransition)]
public fun invalid_transition_bet_twice() {
    let mut context = coin_flip_context::empty();
    context.bet(10, head_result());
    context.bet(10, head_result());
    abort 0
}

#[test, expected_failure(abort_code = coin_flip_context::EInvalidStateTransition)]
public fun invalid_transition_settle_twice() {
    let mut context = coin_flip_context::empty();
    context.bet(10, head_result());
    context.settle(head_result());
    context.settle(head_result());
    abort 0
}

#[test, expected_failure(abort_code = coin_flip_context::EInvalidStateTransition)]
public fun invalid_transition_settle_first() {
    let mut context = coin_flip_context::empty();
    context.settle(head_result());
    abort 0
}

#[test]
public fun ok_flow() {
    // Create new context
    let mut context = coin_flip_context::empty();
    assert!(context.status() == new_status());

    // Bet
    context.bet(10, head_result());
    assert!(context.status() == initialized_status());
    assert!(context.prediction() == head_result());

    // Settle
    context.settle(tail_result());
    assert!(context.result() == tail_result());
    assert!(context.player_won() == false);
    assert!(context.status() == settled_status());

    destroy(context);
}

#[test, expected_failure(abort_code = coin_flip_context::EUnsupportedPrediction)]
public fun invalid_prediction() {
    let mut context = coin_flip_context::empty();
    context.bet(10, utf8(b"unknown result"));
    abort 0
}

#[test, expected_failure(abort_code = coin_flip_context::EUnsupportedResult)]
public fun invalid_result() {
    let mut context = coin_flip_context::empty();
    context.bet(10, head_result());
    context.settle(utf8(b"unknown result"));
    abort 0
}
