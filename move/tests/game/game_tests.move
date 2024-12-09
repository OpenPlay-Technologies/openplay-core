module openplay::game_tests;

use sui::test_scenario::{begin};
use openplay::game::{empty_game_for_testing};
use openplay::balance_manager::{Self};
use sui::coin::{mint_for_testing};
use sui::sui::SUI;
use sui::test_utils::destroy;
use openplay::transaction::{bet, win};
use openplay::constants::{owner_fee, protocol_fee};
use std::uq32_32::int_mul;

#[test]
public fun complete_flow_ok(){
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    // Stake 100_000
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 100_000, scenario.ctx());
    assert!(balance_manager.balance() == 400_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(game.active_stake(&balance_manager, scenario.ctx()) == 100_000);

    // Process some transactions
    game.process_transactions_for_testing(50_000, &vector[bet(10_000), win(20_000)], &mut balance_manager, scenario.ctx());
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 410_000);
    assert!(game.play_balance(scenario.ctx()) == 90_000 - expected_fee);
    assert!(game.active_stake(&balance_manager, scenario.ctx()) == 100_000); // Active stake remains the same, losses are only deducted later on

    // End the epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Out of funds
    assert!(game.active_stake(&balance_manager, scenario.ctx()) == 100_000 - 10_000 - expected_fee); // Losses are deducted now

    // Stake another 20_000
    game.stake(&mut balance_manager, 20_000, scenario.ctx());
    assert!(balance_manager.balance() == 390_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is not started

    // Now unstake everything
    game.unstake(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 410_000); // Only the 20_000 that was pending is immediately released

    // Advance epoch
    scenario.next_epoch(addr);
    game.settle(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 410_000 + (100_000 - 10_000 - expected_fee)); // Now the rest is related, namely 100_000 minus losses

    destroy(game);
    destroy(balance_manager);
    scenario.end();
}