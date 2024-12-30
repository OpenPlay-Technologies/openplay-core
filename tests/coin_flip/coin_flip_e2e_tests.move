#[test_only]
module openplay::coin_flip_e2e_tests;

use openplay::balance_manager;
use openplay::coin_flip_const::{place_bet_action, head_result, tail_result};
use openplay::constants::{owner_fee, protocol_fee};
use openplay::game;
use openplay::registry::registry_for_testing;
use openplay::test_utils::{
    create_and_fix_random,
    fund_game_for_playing,
    assert_eq_within_precision_allowance
};
use openplay::transaction::{bet, win};
use std::uq32_32::int_mul;
use sui::coin::mint_for_testing;
use sui::random::Random;
use sui::sui::SUI;
use sui::test_scenario::{begin, return_shared};
use sui::test_utils::destroy;
use std::string::utf8;

#[test]
public fun success_flow_win() {
    // We create and fix random
    // The result will be HEAD
    create_and_fix_random(x"0F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");

    // Create and fund the coin flip game
    let addr = @0xa;
    let mut scenario = begin(addr);
    let mut registry = registry_for_testing(scenario.ctx());
    let rand = scenario.take_shared<Random>();
    let mut coin_flip_game = game::new_coin_flip(
        &mut registry,
        utf8(b""),
        utf8(b""),
        utf8(b""),
        100_000,
        10_000,
        0,
        20_000,
        scenario.ctx(),
    );

    // Fund the game
    let mut stake_balance_manager = fund_game_for_playing(
        &mut coin_flip_game,
        200_000,
        scenario.ctx(),
    );
    scenario.next_epoch(addr);

    // Create a balance manager with 10_000 stake
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let deposit_balance = mint_for_testing<SUI>(10_000, scenario.ctx()).into_balance();
    balance_manager.deposit_int(deposit_balance);

    // Place 1_000 bet on head
    let interact = coin_flip_game.interact_coin_flip(
        &mut balance_manager,
        place_bet_action(),
        1_000,
        head_result(),
        &rand,
        scenario.ctx(),
    );

    assert!(balance_manager.balance() == 11_000);
    assert!(interact.transactions() == vector[bet(1_000), win(2_000)]);

    // Check the stake balance manager
    scenario.next_epoch(addr);
    let expected_fee = int_mul(1_000, protocol_fee()) + int_mul(1_000, owner_fee());
    assert_eq_within_precision_allowance(
        coin_flip_game.active_stake(&mut stake_balance_manager, scenario.ctx()),
        199_000 - expected_fee,
    );

    destroy(coin_flip_game);
    destroy(balance_manager);
    destroy(stake_balance_manager);
    destroy(registry);
    return_shared(rand);
    scenario.end();
}

#[test]
public fun success_flow_lose() {
    // We create and fix random
    // The result will be HEAD
    create_and_fix_random(x"0F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F");

    // Create and fund the coin flip game
    let addr = @0xa;
    let mut scenario = begin(addr);
    let mut registry = registry_for_testing(scenario.ctx());
    let rand = scenario.take_shared<Random>();
    let mut coin_flip_game = game::new_coin_flip(
        &mut registry,
                utf8(b""),
        utf8(b""),
        utf8(b""),
        100_000,
        10_000,
        0,
        20_000,
        scenario.ctx(),
    );

    // Fund the game
    let mut stake_balance_manager = fund_game_for_playing(
        &mut coin_flip_game,
        200_000,
        scenario.ctx(),
    );
    scenario.next_epoch(addr);

    // Create a balance manager with 10_000 stake
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let deposit_balance = mint_for_testing<SUI>(10_000, scenario.ctx()).into_balance();
    balance_manager.deposit_int(deposit_balance);

    // Place 1_000 bet on tail
    let interact = coin_flip_game.interact_coin_flip(
        &mut balance_manager,
        place_bet_action(),
        1_000,
        tail_result(),
        &rand,
        scenario.ctx(),
    );

    assert!(balance_manager.balance() == 9_000);
    assert!(interact.transactions() == vector[bet(1_000), win(0)]);

    // Check the stake balance manager
    scenario.next_epoch(addr);
    let expected_fee = int_mul(1_000, protocol_fee()) + int_mul(1_000, owner_fee());
    assert_eq_within_precision_allowance(
        coin_flip_game.active_stake(&mut stake_balance_manager, scenario.ctx()),
        201_000 - expected_fee,
    );

    destroy(coin_flip_game);
    destroy(balance_manager);
    destroy(stake_balance_manager);
    destroy(registry);
    return_shared(rand);
    scenario.end();
}
