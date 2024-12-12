#[test_only]
module openplay::test_utils;

use openplay::constants::precision_error_allowance;
use openplay::game::Game;
use openplay::balance_manager::{Self, BalanceManager};
use sui::coin::{mint_for_testing};
use sui::sui::SUI;
use sui::random::{Random, create_for_testing};
use sui::test_scenario::{begin, return_shared};

public fun assert_eq_within_precision_allowance(a: u64, b: u64) {
    // std::debug::print(&a);
    // std::debug::print(&b);
    if (a >= b) {
        assert!(a - b <= precision_error_allowance())
    };
    assert!(b - a <= precision_error_allowance())
}

public fun create_and_fix_random(bytes: vector<u8>) {
    // Create the random
    let mut scenario = begin(@0x0);
    {
        create_for_testing(scenario.ctx());
    };

    // WE fix the random for testing purposes
    scenario.next_tx(@0x0);
    {
        let mut rand = scenario.take_shared<Random>();
        rand.update_randomness_state_for_testing(
            0,
            // x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            bytes,
            scenario.ctx(),
        );
        return_shared(rand);
    };
    scenario.end();
}

public fun fund_game_for_playing(game: &mut Game, amount: u64, ctx: &mut TxContext): BalanceManager {
    let mut stake_balance_manager = balance_manager::new(ctx);
    let deposit_balance = mint_for_testing<SUI>(amount, ctx).into_balance();
    stake_balance_manager.deposit_int(deposit_balance);
    game.stake(&mut stake_balance_manager, amount, ctx);
    stake_balance_manager
}