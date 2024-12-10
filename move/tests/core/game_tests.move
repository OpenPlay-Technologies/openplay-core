module openplay::game_tests;

use openplay::balance_manager;
use openplay::constants::{owner_fee, protocol_fee};
use openplay::game::empty_game_for_testing;
use openplay::test_utils::assert_eq_within_precision_allowance;
use openplay::transaction::{bet, win};
use std::uq32_32::{UQ32_32, int_mul, from_quotient};
use sui::coin::mint_for_testing;
use sui::sui::SUI;
use sui::test_scenario::begin;
use sui::test_utils::destroy;

public fun four_fifths(): UQ32_32 {
    from_quotient(4, 5)
}

public fun one_fifth(): UQ32_32 {
    from_quotient(1, 5)
}

#[test]
public fun complete_flow_share_losses() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let mut another_balance_manager = balance_manager::new(scenario.ctx());

    // Stake 20_000 on first balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 20_000, scenario.ctx());
    assert!(balance_manager.balance() == 480_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    another_balance_manager.deposit(deposit_balance);
    game.stake(&mut another_balance_manager, 80_000, scenario.ctx());
    assert!(another_balance_manager.balance() == 420_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 20_000);
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 80_000);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k + the extra owner and protocol fees
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(20_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 490_000); // The 10k in profits is added to the first balance manager
    assert!(game.play_balance(scenario.ctx()) == 90_000 - expected_fee); // The losses and fees are deducted from the play balance
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 20_000); // Active stake remains the same, losses are only deducted later on
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 80_000); // Idem

    // End the epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Not enough funds for another active round
    assert_eq_within_precision_allowance(
        game.active_stake(&mut balance_manager, scenario.ctx()),
        20_000 - int_mul((10_000 + expected_fee), one_fifth()),
    );
    assert_eq_within_precision_allowance(
        game.active_stake(&mut another_balance_manager, scenario.ctx()),
        80_000 - int_mul((10_000 + expected_fee), four_fifths()),
    );

    // Now unstake everything
    game.unstake(&mut balance_manager, scenario.ctx());
    game.unstake(&mut another_balance_manager, scenario.ctx());
    // Funds should not be added yet
    assert!(balance_manager.balance() == 490_000);
    assert!(another_balance_manager.balance() == 420_000);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Play balance stays the same because it was not funded
    game.settle(&mut balance_manager, scenario.ctx());
    game.settle(&mut another_balance_manager, scenario.ctx());
    assert_eq_within_precision_allowance(
        balance_manager.balance(),
        490_000 + (20_000 - int_mul(10_000 + expected_fee, one_fifth())),
    ); // Now the rest is released, namely 20_000 minus his bm's share of the losses
    assert_eq_within_precision_allowance(
        another_balance_manager.balance(),
        420_000 + (80_000 - int_mul(10_000 + expected_fee, four_fifths())),
    ); // Now the rest is released, namely 80_000 minus his bm's share of the losses

    destroy(game);
    destroy(balance_manager);
    destroy(another_balance_manager);
    scenario.end();
}

#[test]
public fun complete_flow_share_profits() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let mut another_balance_manager = balance_manager::new(scenario.ctx());

    // Stake 20_000 on first balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 20_000, scenario.ctx());
    assert!(balance_manager.balance() == 480_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    another_balance_manager.deposit(deposit_balance);
    game.stake(&mut another_balance_manager, 80_000, scenario.ctx());
    assert!(another_balance_manager.balance() == 420_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 20_000);
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 80_000);

    // Process some transactions
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 475_000); // The 5k in losses is added to the first balance manager
    assert!(game.play_balance(scenario.ctx()) == 105_000 - expected_fee); // The profits are added to the play_balance, minus the fees
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 20_000); // Active stake remains the same, profits are added later on
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 80_000); // Idem

    // End the epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // House is funded again
    assert_eq_within_precision_allowance(
        game.active_stake(&mut balance_manager, scenario.ctx()),
        20_000 + int_mul((5_000 - expected_fee), one_fifth()),
    );
    assert_eq_within_precision_allowance(
        game.active_stake(&mut another_balance_manager, scenario.ctx()),
        80_000 + int_mul((5_000 - expected_fee), four_fifths()),
    );

    // Now unstake everything
    game.unstake(&mut balance_manager, scenario.ctx());
    game.unstake(&mut another_balance_manager, scenario.ctx());
    // Funds should not be added yet
    assert!(balance_manager.balance() == 475_000);
    assert!(another_balance_manager.balance() == 420_000);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Play balance stays the same because it was not funded
    game.settle(&mut balance_manager, scenario.ctx());
    game.settle(&mut another_balance_manager, scenario.ctx());
    assert_eq_within_precision_allowance(
        balance_manager.balance(),
        475_000 + (20_000 + int_mul(5_000 - expected_fee, one_fifth())),
    ); // Now the rest is released, namely 20_000 plus his bm's share of the profits
    assert_eq_within_precision_allowance(
        another_balance_manager.balance(),
        420_000 + (80_000 + int_mul(5_000 - expected_fee, four_fifths())),
    ); // Now the rest is released, namely 80_000 plus his bm's share of the profits

    destroy(game);
    destroy(balance_manager);
    destroy(another_balance_manager);
    scenario.end();
}

#[test]
public fun complete_flow_share_profits_multi_round() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let mut another_balance_manager = balance_manager::new(scenario.ctx());

    // Stake 20_000 on first balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 20_000, scenario.ctx());
    assert!(balance_manager.balance() == 480_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    another_balance_manager.deposit(deposit_balance);
    game.stake(&mut another_balance_manager, 80_000, scenario.ctx());
    assert!(another_balance_manager.balance() == 420_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start


    // Advance epoch and play
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());

    // Skip 1 epoch without any activity and process some more transactions
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );

    // Now unstake everything
    game.unstake(&mut balance_manager, scenario.ctx());
    game.unstake(&mut another_balance_manager, scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0);
    game.settle(&mut balance_manager, scenario.ctx());
    game.settle(&mut another_balance_manager, scenario.ctx());
    assert_eq_within_precision_allowance(
        balance_manager.balance(),
        470_000 + (20_000 + 2 * int_mul(5_000 - expected_fee, one_fifth())),
    );
    assert_eq_within_precision_allowance(
        another_balance_manager.balance(),
        420_000 + (80_000 + 2 * int_mul(5_000 - expected_fee, four_fifths())),
    );

    destroy(game);
    destroy(balance_manager);
    destroy(another_balance_manager);
    scenario.end();
}

#[test]
public fun complete_flow_profits_and_losses_multi_round() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let mut another_balance_manager = balance_manager::new(scenario.ctx());

    // Stake 20_000 on first balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 20_000, scenario.ctx());
    assert!(balance_manager.balance() == 480_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    another_balance_manager.deposit(deposit_balance);
    game.stake(&mut another_balance_manager, 80_000, scenario.ctx());
    assert!(another_balance_manager.balance() == 420_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch and play
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());

    // Skip 1 epoch without any activity and process some more transactions
    // Net result should be even
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(15_000)],
        &mut balance_manager,
        scenario.ctx(),
    );

    // Now unstake everything
    game.unstake(&mut balance_manager, scenario.ctx());
    game.unstake(&mut another_balance_manager, scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0);
    game.settle(&mut balance_manager, scenario.ctx());
    game.settle(&mut another_balance_manager, scenario.ctx());
    assert_eq_within_precision_allowance(
        balance_manager.balance(),
        500_000 - 2 * int_mul(expected_fee, one_fifth()), // We only lost the tx fees
    );
    assert_eq_within_precision_allowance(
        another_balance_manager.balance(),
        500_000 - 2 * int_mul(expected_fee, four_fifths()), // We only lost the tx fees
    );

    destroy(game);
    destroy(balance_manager);
    destroy(another_balance_manager);
    scenario.end();
}

#[test]
public fun complete_flow_multiple_funded_rounds() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let mut another_balance_manager = balance_manager::new(scenario.ctx());

    // Stake 30_000 on first balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 30_000, scenario.ctx());
    assert!(balance_manager.balance() == 470_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 120_000 on second balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    another_balance_manager.deposit(deposit_balance);
    game.stake(&mut another_balance_manager, 120_000, scenario.ctx());
    assert!(another_balance_manager.balance() == 380_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 30_000);
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 120_000);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k + the extra owner and protocol fees
    game.process_transactions_for_testing(
        50_000,
        &vector[bet(10_000), win(20_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 480_000); // The 10k in profits is added to the first balance manager
    assert!(game.play_balance(scenario.ctx()) == 90_000 - expected_fee); // The losses and fees are deducted from the play balance
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 30_000); // Active stake remains the same, losses are only deducted later on
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 120_000); // Idem

    // End the epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Fresh play balance
    assert!(
        game.active_stake(&mut balance_manager, scenario.ctx()) == 30_000 - int_mul((10_000 + expected_fee), one_fifth()),
    ); // Losses are deducted now from the active stake
    assert!(
        game.active_stake(&mut another_balance_manager, scenario.ctx()) == 120_000 - int_mul((10_000 + expected_fee), four_fifths()),
    );

    // Stake another 20_000 with the first balance manager
    game.stake(&mut balance_manager, 20_000, scenario.ctx());
    assert!(balance_manager.balance() == 460_000);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance stays the same

    // Now unstake everything
    game.unstake(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 480_000); // Only the 20_000 that was still pending is immediately released, the rest is now pending to be unstaked

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance should be funded once again because the second staker has enough funds staked
    game.settle(&mut balance_manager, scenario.ctx());
    assert!(
        balance_manager.balance() == 480_000 + (30_000 - int_mul(10_000 + expected_fee, one_fifth())),
    ); // Now the rest is released, namely 30_000 minus his bm's share of the losses

    destroy(game);
    destroy(balance_manager);
    destroy(another_balance_manager);
    scenario.end();
}

#[test]
public fun stake_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());
    let mut another_balance_manager = balance_manager::new(scenario.ctx());

    // Stake 30_000 on first balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 30_000, scenario.ctx());
    assert!(balance_manager.balance() == 470_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 120_000 on second balance manager
    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    another_balance_manager.deposit(deposit_balance);
    game.stake(&mut another_balance_manager, 120_000, scenario.ctx());
    assert!(another_balance_manager.balance() == 380_000);
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance. 50k is left in reserve
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 30_000);
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 120_000);

    // First bm unstakes
    game.unstake(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 470_000); // No funds should be added yet

    // Advance epoch
    // Stake is now released
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance still has enough
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 0);
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 120_000);
    // Stake should be released
    game.settle(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 500_000);

    //  First one now stakes 100k again
    game.stake(&mut balance_manager, 100_000, scenario.ctx());
    assert!(balance_manager.balance() == 400_000);
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 0); // Not active yet
    // Second one unstakes
    game.unstake(&mut another_balance_manager, scenario.ctx());
    assert!(another_balance_manager.balance() == 380_000); // No funds should be added yet
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 120_000); // Still active

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance still has enough

    // Stake of the first one should be active
    game.settle(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 400_000);
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 100_000); // Active now
    // Second one should get funds back
    game.settle(&mut another_balance_manager, scenario.ctx());
    assert!(another_balance_manager.balance() == 500_000);
    assert!(game.active_stake(&mut another_balance_manager, scenario.ctx()) == 0); // Not active anymore

    // Now unstake the remaining funds
    game.unstake(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 400_000); // No funds should be added yet

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Not enough balance anymore
    // Claim funds
    game.settle(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 500_000);
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 0); // Not active anymore

    destroy(game);
    destroy(balance_manager);
    destroy(another_balance_manager);
    scenario.end();
}

#[test]
public fun game_doesnt_start_when_everything_unstaked() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    let deposit_balance = mint_for_testing<SUI>(500_000, scenario.ctx()).into_balance();
    balance_manager.deposit(deposit_balance);
    game.stake(&mut balance_manager, 100_000, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance. 50k is left in reserve
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 100_000);

    // First bm unstakes
    game.unstake(&mut balance_manager, scenario.ctx());
    assert!(balance_manager.balance() == 400_000); // No funds should be added yet

    // Advance epoch
    // Stake is now released
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Not enough anymore
    assert!(game.active_stake(&mut balance_manager, scenario.ctx()) == 0);
    assert!(balance_manager.balance() == 500_000);

    destroy(game);
    destroy(balance_manager);
    scenario.end();
}
