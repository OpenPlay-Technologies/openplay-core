#[test_only]
module openplay::coin_flip_tests;

use openplay::balance_manager;
use openplay::coin_flip::{Self, new_interact};
use openplay::coin_flip_const::{
    place_bet_action,
    tail_result,
    settled_status,
    head_result,
    house_bias_result
};
use openplay::test_utils::create_and_fix_random;
use openplay::transaction::{bet, win};
use sui::random::Random;
use sui::test_scenario::{begin, return_shared};
use sui::test_utils::destroy;

#[test]
public fun success_win_flow() {
    // We create and fix random
    // The result will be TAIL
    create_and_fix_random(x"0F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");

    let addr = @0xa;
    let mut scenario = begin(addr);
    let mut coin_flip = coin_flip::new(1000, 0, 20_000, scenario.ctx());
    let balance_manager = balance_manager::new(scenario.ctx());
    let rand = scenario.take_shared<Random>();

    // Place a bet on tail for 100 MIST
    let mut interact = new_interact(place_bet_action(), balance_manager.id(), tail_result(), 100);
    coin_flip.interact(&mut interact, &rand, scenario.ctx());

    // Validate context
    let context = coin_flip.get_context(balance_manager.id());
    assert!(context.result() == tail_result());
    assert!(context.prediction() == tail_result());
    assert!(context.status() == settled_status());
    assert!(context.player_won() == true);

    // Validate transactions
    assert!(interact.transactions() == vector[bet(100), win(200)]);

    destroy(coin_flip);
    destroy(balance_manager);
    return_shared(rand);
    scenario.end();
}

#[test]
public fun success_lose_flow() {
    // We create and fix random
    // The result will be TAIL
    create_and_fix_random(x"0F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");

    let addr = @0xa;
    let mut scenario = begin(addr);
    let mut coin_flip = coin_flip::new(1000, 0, 20_000, scenario.ctx());
    let balance_manager = balance_manager::new(scenario.ctx());
    let rand = scenario.take_shared<Random>();

    // Place a bet on head for 100 MIST
    let mut interact = new_interact(place_bet_action(), balance_manager.id(), head_result(), 100);
    coin_flip.interact(&mut interact, &rand, scenario.ctx());

    // Validate context
    let context = coin_flip.get_context(balance_manager.id());
    assert!(context.result() == tail_result());
    assert!(context.prediction() == head_result());
    assert!(context.status() == settled_status());
    assert!(context.player_won() == false);

    // Validate transactions
    assert!(interact.transactions() == vector[bet(100), win(0)]);

    destroy(coin_flip);
    destroy(balance_manager);
    return_shared(rand);
    scenario.end();
}

#[test]
public fun success_house_bias_flow() {
    // We create and fix random
    // The result will be TAIL
    create_and_fix_random(x"0F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");

    let addr = @0xa;
    let mut scenario = begin(addr);
    let mut coin_flip = coin_flip::new(1000, 9_999, 20_000, scenario.ctx());
    let balance_manager = balance_manager::new(scenario.ctx());
    let rand = scenario.take_shared<Random>();

    // Place a bet on head for 100 MIST
    let mut interact = new_interact(place_bet_action(), balance_manager.id(), head_result(), 100);
    coin_flip.interact(&mut interact, &rand, scenario.ctx());

    // Validate context
    let context = coin_flip.get_context(balance_manager.id());
    assert!(context.result() == house_bias_result());
    assert!(context.prediction() == head_result());
    assert!(context.status() == settled_status());
    assert!(context.player_won() == false);

    // Validate transactions
    assert!(interact.transactions() == vector[bet(100), win(0)]);

    destroy(coin_flip);
    destroy(balance_manager);
    return_shared(rand);
    scenario.end();
}
