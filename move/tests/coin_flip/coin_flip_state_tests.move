#[test_only]
module openplay::coin_flip_state_tests;

use openplay::coin_flip_const::{head_result, tail_result, house_bias_result, max_recent_throws};
use openplay::coin_flip_context;
use openplay::coin_flip_state;
use sui::test_utils::destroy;

#[test]
public fun counter_ok() {
    // Create empty state
    let mut state = coin_flip_state::empty();
    let (nb_of_heads, nb_of_tails, nb_of_house_bias) = state.counters();
    assert!(nb_of_heads == 0);
    assert!(nb_of_tails == 0);
    assert!(nb_of_house_bias == 0);

    // Process some contexts
    let mut unfinished_context = coin_flip_context::empty();
    unfinished_context.bet(10, head_result());

    let mut head_context = coin_flip_context::empty();
    head_context.bet(10, head_result());
    head_context.settle(head_result());

    let mut tail_context = coin_flip_context::empty();
    tail_context.bet(10, head_result());
    tail_context.settle(tail_result());

    let mut house_context = coin_flip_context::empty();
    house_context.bet(10, head_result());
    house_context.settle(house_bias_result());

    // Process them by state and check the counters
    state.process_context(&unfinished_context);
    state.process_context(&head_context);
    let (nb_of_heads, nb_of_tails, nb_of_house_bias) = state.counters();
    assert!(nb_of_heads == 1);
    assert!(nb_of_tails == 0);
    assert!(nb_of_house_bias == 0);

    state.process_context(&tail_context);
    let (nb_of_heads, nb_of_tails, nb_of_house_bias) = state.counters();
    assert!(nb_of_heads == 1);
    assert!(nb_of_tails == 1);
    assert!(nb_of_house_bias == 0);

    state.process_context(&house_context);
    let (nb_of_heads, nb_of_tails, nb_of_house_bias) = state.counters();
    assert!(nb_of_heads == 1);
    assert!(nb_of_tails == 1);
    assert!(nb_of_house_bias == 1);

    destroy(state);
    destroy(head_context);
    destroy(tail_context);
    destroy(house_context);
    destroy(unfinished_context);
}

#[test]
public fun recent_throws_ok() {
    // Create empty state
    let mut state = coin_flip_state::empty();
    let recent_throws = state.recent_throws();
    assert!(recent_throws.length() == 0);

    // Process some contexts
    let mut unfinished_context = coin_flip_context::empty();
    unfinished_context.bet(10, head_result());

    let mut head_context = coin_flip_context::empty();
    head_context.bet(10, head_result());
    head_context.settle(head_result());

    let mut tail_context = coin_flip_context::empty();
    tail_context.bet(10, head_result());
    tail_context.settle(tail_result());

    let mut house_context = coin_flip_context::empty();
    house_context.bet(10, head_result());
    house_context.settle(house_bias_result());

    // Process them by state and check the counters
    state.process_context(&head_context);
    let recent_throws = state.recent_throws();
    assert!(recent_throws == vector[head_result()]);

    state.process_context(&tail_context);
    let recent_throws = state.recent_throws();
    assert!(recent_throws == vector[head_result(), tail_result()]);

    state.process_context(&house_context);
    let recent_throws = state.recent_throws();
    assert!(recent_throws == vector[head_result(), tail_result(), house_bias_result()]);

    // Now check the max size of it
    let mut i = max_recent_throws();
    while (i > 0) {
        state.process_context(&tail_context);
        i = i - 1
    };
    let recent_throws = state.recent_throws();
    assert!(recent_throws.length() == max_recent_throws());
    assert!(recent_throws.all!(|x| x == tail_result()));

    destroy(state);
    destroy(head_context);
    destroy(tail_context);
    destroy(house_context);
    destroy(unfinished_context);
}
