#[test_only]
module openplay::game_tests;

use openplay::balance_manager;
use openplay::constants::{owner_fee, protocol_fee};
use openplay::game::{Self, empty_game_for_testing};
use openplay::participation;
use openplay::test_utils::assert_eq_within_precision_allowance;
use openplay::transaction::{bet, win};
use std::uq32_32::{UQ32_32, int_mul, from_quotient};
use sui::coin::{mint_for_testing, burn_for_testing};
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
    let mut participation = participation::empty(game.id(), scenario.ctx());
    let mut another_participation = participation::empty(game.id(), scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(deposit);

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    game.stake(&mut another_participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    // Check active stake
    assert!(participation.active_stake() == 20_000);
    assert!(another_participation.active_stake() == 80_000);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k + the extra owner and protocol fees
    game.process_transactions_for_testing(
        &vector[bet(10_000), win(20_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 60_000); // The 10k in profits is added to the first balance manager
    assert!(game.play_balance(scenario.ctx()) == 90_000 - expected_fee); // The losses and fees are deducted from the play balance

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    // Check active stake
    assert!(participation.active_stake() == 20_000); // Active stake remains the same, losses are only deducted later on
    assert!(another_participation.active_stake() == 80_000); // Idem

    // End the epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert!(game.play_balance(scenario.ctx()) == 0); // Not enough funds for another active round
    assert_eq_within_precision_allowance(
        participation.active_stake(),
        20_000 - int_mul((10_000 + expected_fee), one_fifth()),
    );
    assert_eq_within_precision_allowance(
        another_participation.active_stake(),
        80_000 - int_mul((10_000 + expected_fee), four_fifths()),
    );

    // Now unstake everything
    game.unstake(&mut participation, scenario.ctx());
    game.unstake(&mut another_participation, scenario.ctx());
    // Funds should not be added yet
    assert!(participation.claimable_balance() == 0);
    assert!(another_participation.claimable_balance() == 0);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Play balance stays the same because it was not funded

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert_eq_within_precision_allowance(
        participation.claimable_balance(),
        20_000 - int_mul(10_000 + expected_fee, one_fifth()),
    ); // Now the rest is released, namely 20_000 minus his bm's share of the losses
    assert_eq_within_precision_allowance(
        another_participation.claimable_balance(),
        80_000 - int_mul(10_000 + expected_fee, four_fifths()),
    ); // Now the rest is released, namely 80_000 minus his bm's share of the losses

    destroy(game);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun complete_flow_share_profits() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut participation = participation::empty(game.id(), scenario.ctx());
    let mut another_participation = participation::empty(game.id(), scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(deposit);

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    game.stake(&mut another_participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared

    // Process some transactions
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    game.process_transactions_for_testing(
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 45_000); // The 5k in losses is added to the first balance manager
    assert!(game.play_balance(scenario.ctx()) == 105_000 - expected_fee); // The profits are added to the play_balance, minus the fees

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    assert!(participation.active_stake() == 20_000);
    assert!(another_participation.active_stake() == 80_000);

    // End the epoch
    scenario.next_epoch(addr);

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert!(game.play_balance(scenario.ctx()) == 100_000); // House is funded again
    assert_eq_within_precision_allowance(
        participation.active_stake(),
        20_000 + int_mul((5_000 - expected_fee), one_fifth()),
    );
    assert_eq_within_precision_allowance(
        another_participation.active_stake(),
        80_000 + int_mul((5_000 - expected_fee), four_fifths()),
    );

    // Now unstake everything
    game.unstake(&mut participation, scenario.ctx());
    game.unstake(&mut another_participation, scenario.ctx());
    // Funds should not be added yet
    assert!(participation.claimable_balance() == 0);
    assert!(another_participation.claimable_balance() == 0);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0); // Play balance stays the same because it was not funded

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert_eq_within_precision_allowance(
        participation.claimable_balance(),
        20_000 + int_mul(5_000 - expected_fee, one_fifth()),
    ); // Now the rest is released, namely 20_000 plus his bm's share of the profits
    assert_eq_within_precision_allowance(
        another_participation.claimable_balance(),
        80_000 + int_mul(5_000 - expected_fee, four_fifths()),
    ); // Now the rest is released, namely 80_000 plus his bm's share of the profits

    destroy(game);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun complete_flow_share_profits_multi_round() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut participation = participation::empty(game.id(), scenario.ctx());
    let mut another_participation = participation::empty(game.id(), scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(deposit);

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    game.stake(&mut another_participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch and play
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());

    // Skip 1 epoch without any activity and process some more transactions
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
        &vector[bet(10_000), win(5_000)],
        &mut balance_manager,
        scenario.ctx(),
    );

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    // Now unstake everything
    game.unstake(&mut participation, scenario.ctx());
    game.unstake(&mut another_participation, scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0);

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert_eq_within_precision_allowance(
        participation.claimable_balance(),
        20_000 + 2 * int_mul(5_000 - expected_fee, one_fifth()),
    );
    assert_eq_within_precision_allowance(
        another_participation.claimable_balance(),
        80_000 + 2 * int_mul(5_000 - expected_fee, four_fifths()),
    );

    destroy(game);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun complete_flow_profits_and_losses_multi_round() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut participation = participation::empty(game.id(), scenario.ctx());
    let mut another_participation = participation::empty(game.id(), scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(deposit);

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    game.stake(&mut another_participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch and play
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    scenario.next_epoch(addr);
    game.process_transactions_for_testing(
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
        &vector[bet(10_000), win(15_000)],
        &mut balance_manager,
        scenario.ctx(),
    );

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    // Now unstake everything
    game.unstake(&mut participation, scenario.ctx());
    game.unstake(&mut another_participation, scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 0);

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert_eq_within_precision_allowance(
        participation.claimable_balance(),
        20_000 - 2 * int_mul(expected_fee, one_fifth()), // We only lost the tx fees
    );
    assert_eq_within_precision_allowance(
        another_participation.claimable_balance(),
        80_000 - 2 * int_mul(expected_fee, four_fifths()), // We only lost the tx fees
    );

    destroy(game);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun complete_flow_multiple_funded_rounds() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut participation = participation::empty(game.id(), scenario.ctx());
    let mut another_participation = participation::empty(game.id(), scenario.ctx());
    let mut balance_manager = balance_manager::new(scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(deposit);

    // Stake 30_000 on first participation
    let stake = mint_for_testing<SUI>(30_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 120_000 on second participation
    let stake = mint_for_testing<SUI>(120_000, scenario.ctx());
    game.stake(&mut another_participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance
    scenario.next_epoch(addr);

    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    assert!(participation.active_stake() == 30_000);
    assert!(another_participation.active_stake() == 120_000);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k + the extra owner and protocol fees
    game.process_transactions_for_testing(
        &vector[bet(10_000), win(20_000)],
        &mut balance_manager,
        scenario.ctx(),
    );
    let expected_fee = int_mul(10_000, owner_fee()) + int_mul(10_000, protocol_fee());
    assert!(balance_manager.balance() == 60_000); // The 10k in profits is added to the first balance manager
    assert!(game.play_balance(scenario.ctx()) == 90_000 - expected_fee); // The losses and fees are deducted from the play balance
    assert!(participation.active_stake() == 30_000);
    assert!(another_participation.active_stake() == 120_000);

    // End the epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert!(game.play_balance(scenario.ctx()) == 100_000); // Fresh play balance
    assert_eq_within_precision_allowance(
        participation.active_stake(),
        30_000 - int_mul((10_000 + expected_fee), one_fifth()),
    ); // Losses are deducted now from the active stake
    assert_eq_within_precision_allowance(
        another_participation.active_stake(),
        120_000 - int_mul((10_000 + expected_fee), four_fifths()),
    );

    // Stake another 20_000 with the first balance manager
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance stays the same

    // Now unstake for first staker
    game.unstake(&mut participation, scenario.ctx());
    assert!(participation.claimable_balance() == 20_000); // Only the 20_000 that was still pending is immediately released, the rest is now pending to be unstaked

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());

    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance should be funded once again because the second staker has enough funds staked
    assert_eq_within_precision_allowance(
        participation.claimable_balance(),
        20_000 + 30_000 - int_mul(10_000 + expected_fee, one_fifth()),
    ); // Now the rest is released, namely 30_000 minus his bm's share of the losses

    destroy(game);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun stake_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut participation = participation::empty(game.id(), scenario.ctx());
    let mut another_participation = participation::empty(game.id(), scenario.ctx());

    // Stake 30_000 on first participation
    let stake = mint_for_testing<SUI>(30_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Stake 120_000 on second participation
    let stake = mint_for_testing<SUI>(120_000, scenario.ctx());
    game.stake(&mut another_participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance. 50k is left in reserve
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    // Check active stake
    assert!(participation.active_stake() == 30_000);
    assert!(another_participation.active_stake() == 120_000);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared

    // First participant unstakes
    game.unstake(&mut participation, scenario.ctx());
    assert!(participation.claimable_balance() == 0); // No funds should be added yet

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    // Stake is now released
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance still has enough
    assert!(participation.active_stake() == 0);
    assert!(participation.claimable_balance() == 30_000);
    assert!(another_participation.active_stake() == 120_000);

    //  First one now stakes 100k again
    let stake = mint_for_testing<SUI>(100_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(participation.active_stake() == 0); // Not active yet
    // Second one unstakes
    game.unstake(&mut another_participation, scenario.ctx());
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());

    assert!(another_participation.claimable_balance() == 0); // No funds should be added yet
    assert!(another_participation.active_stake() == 120_000); // Still active

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Play balance still has enough

    // Stake of the first one should be active
    assert!(participation.active_stake() == 100_000); // Active now
    // Second one should get funds back
    assert!(another_participation.claimable_balance() == 120_000);
    assert!(another_participation.active_stake() == 0); // Not active anymore

    // Now unstake the remaining funds
    game.unstake(&mut participation, scenario.ctx());
    assert!(participation.claimable_balance() == 30_000); // This is the 30k from before

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    game.update_participation(&mut participation, scenario.ctx());
    game.update_participation(&mut another_participation, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Not enough balance anymore
    // Claim funds
    assert!(participation.claimable_balance() == 130_000); // This is the 30k from before
    assert!(another_participation.claimable_balance() == 120_000);

    destroy(game);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun game_doesnt_start_when_everything_unstaked() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game = empty_game_for_testing(100_000, scenario.ctx());
    let mut participation = participation::empty(game.id(), scenario.ctx());

    // Stake 100_000 on first participation
    let stake = mint_for_testing<SUI>(100_000, scenario.ctx());
    game.stake(&mut participation, stake, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start
    assert!(game.play_balance(scenario.ctx()) == 0); // Game is yet to start

    // Advance epoch
    // At this point, the game starts. 100k is moved to the play balance. 50k is left in reserve
    scenario.next_epoch(addr);
    assert!(game.play_balance(scenario.ctx()) == 100_000); // Game has stared
    game.update_participation(&mut participation, scenario.ctx());
    assert!(participation.active_stake() == 100_000);

    // First bm unstakes
    game.unstake(&mut participation, scenario.ctx());
    game.update_participation(&mut participation, scenario.ctx());
    assert!(participation.claimable_balance() == 0); // No funds should be added yet

    // Advance epoch
    // Stake is now released
    scenario.next_epoch(addr);
    game.update_participation(&mut participation, scenario.ctx());
    assert!(game.play_balance(scenario.ctx()) == 0); // Not enough anymore
    assert!(participation.active_stake() == 0);
    assert!(participation.claimable_balance() == 100_000);

    destroy(game);
    destroy(participation);
    scenario.end();
}

#[test]
public fun collect_owner_fees_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game1 = empty_game_for_testing(100_000, scenario.ctx());
    let cap1 = game1.cap_for_testing(scenario.ctx());

    game1.add_owner_fees_for_testing(100, scenario.ctx());

    let coin = game1.claim_all_fees(&cap1, scenario.ctx());
    assert!(coin.value() == 100);

    destroy(game1);
    destroy(cap1);
    burn_for_testing(coin);
    scenario.end();
}

#[test]
public fun collect_owner_fees_empty() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game1 = empty_game_for_testing(100_000, scenario.ctx());
    let cap1 = game1.cap_for_testing(scenario.ctx());

    let coin = game1.claim_all_fees(&cap1, scenario.ctx());
    assert!(coin.value() == 0);

    destroy(game1);
    destroy(cap1);
    burn_for_testing(coin);
    scenario.end();
}

#[test, expected_failure(abort_code = game::EInvalidCap)]
public fun collect_owner_fees_wrong_cap() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new game and balance manager
    let mut game1 = empty_game_for_testing(100_000, scenario.ctx());
    let game2 = empty_game_for_testing(100_000, scenario.ctx());
    let cap2 = game2.cap_for_testing(scenario.ctx());

    game1.add_owner_fees_for_testing(100, scenario.ctx());

    let _coin = game1.claim_all_fees(&cap2, scenario.ctx());
    abort 0
}
