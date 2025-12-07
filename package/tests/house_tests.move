#[test_only]
module openplay_core::house_tests;

use openplay_core::balance_manager;
use openplay_core::calculations::{mul_ceil, mul_ceil_bps, mul_floor, mul_floor_bps};
use openplay_core::core_constants::{current_version, max_bps};
use openplay_core::core_test_utils::{fund_house_for_playing, default_house};
use openplay_core::game_stats;
use openplay_core::house;
use openplay_core::participation;
use openplay_core::registry::{Self, registry_for_testing};
use openplay_core::transaction::{bet, win};
use std::unit_test::{assert_eq, destroy};
use sui::coin::{mint_for_testing, burn_for_testing};
use sui::sui::SUI;
use sui::test_scenario::begin;

/// Helper function to calculate profits after house fee (20% = 2000 bps)
/// Returns the amount that goes to stakers after house fee is deducted
/// Uses mul_floor to round down (protocol pays less to stakers)
public fun profits_after_house_fee(gross_profits: u64, house_fee_bps: u64): u64 {
    let staker_share_bps = max_bps() - house_fee_bps;
    mul_floor_bps(gross_profits, staker_share_bps)
}

/// Helper to calculate 1/5 share using exact rounding (rounds down for profits, up for losses)
public fun one_fifth_floor(amount: u64): u64 {
    mul_floor(amount, 1, 5)
}

public fun one_fifth_ceil(amount: u64): u64 {
    mul_ceil(amount, 1, 5)
}

public fun four_fifths_floor(amount: u64): u64 {
    mul_floor(amount, 4, 5)
}

public fun four_fifths_ceil(amount: u64): u64 {
    mul_ceil(amount, 4, 5)
}

#[test]
public fun complete_flow_share_losses() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start
    assert!(participation.stake() == 20_000);

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());
    assert!(another_participation.stake() == 80_000);

    assert!(house.play_balance(scenario.ctx()) == 100_000); // house cycle started

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k + the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(20_000)],
        &play_cap,
        scenario.ctx(),
    );

    let expected_fee =
        mul_ceil_bps(10_000, house.game_fee_bps(&game_id)) 
        + mul_ceil_bps(10_000, registry.protocol_fee_bps());
    assert!(balance_manager.balance() == 60_000); // The 10k in profits is added to the first balance manager
    assert!(house.play_balance(scenario.ctx()) == 90_000 - expected_fee); // The losses and fees are deducted from the play balance

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());
    // Check active stake
    assert!(participation.stake() == 20_000); // Active stake remains the same, losses are only deducted later on
    assert!(another_participation.stake() == 80_000); // Idem

    // End the epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 0); // Not enough funds for another active round
    assert!(house.reserve_balance(scenario.ctx()) == 90_000 - expected_fee); // The balance manager win + fees are gone from the reserve
    let total_loss = 10_000 + expected_fee;
    // Losses are distributed using mul_ceil (rounds up) - users absorb more losses
    assert_eq!(participation.stake(), 20_000 - one_fifth_ceil(total_loss));
    assert_eq!(another_participation.stake(), 80_000 - four_fifths_ceil(total_loss));

    // Now unstake everything
    let to_unstake = participation.stake();
    house.unstake_v2(
        &mut participation,
        to_unstake,
        scenario.ctx(),
    );
    let to_unstake = another_participation.stake();
    house.unstake_v2(
        &mut another_participation,
        to_unstake,
        scenario.ctx(),
    );

    assert!(house.is_active(scenario.ctx()) == false);
    assert!(house.play_balance(scenario.ctx()) == 0);

    let total_loss = 10_000 + expected_fee;
    // Losses are distributed using mul_ceil (rounds up) - users absorb more losses
    assert_eq!(participation.claimable_balance(), 20_000 - one_fifth_ceil(total_loss)); // Now the rest is released, namely 20_000 minus his bm's share of the losses
    assert_eq!(another_participation.claimable_balance(), 80_000 - four_fifths_ceil(total_loss)); // Now the rest is released, namely 80_000 minus his bm's share of the losses

    destroy(house);

    destroy(registry);
    destroy(play_cap);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(participation);
    destroy(another_participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun complete_flow_share_profits() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 100_000); // house cycle started

    // Process some transactions
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    let expected_fee =
        mul_ceil_bps(10_000, house.game_fee_bps(&game_id)) 
        + mul_ceil_bps(10_000, registry.protocol_fee_bps());
    assert!(balance_manager.balance() == 45_000); // The 5k in losses is added to the first balance manager
    assert!(house.play_balance(scenario.ctx()) == 105_000 - expected_fee); // The profits are added to the play_balance, minus the fees

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());
    assert!(participation.stake() == 20_000); // Unchanged because epoch is still ongoing
    assert!(another_participation.stake() == 80_000); // Unchanged because epoch is still ongoing

    // End the epoch
    scenario.next_epoch(addr);

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    let gross_profits = 5_000 - expected_fee;
    let profits_to_stakers = profits_after_house_fee(gross_profits, house.house_fee_bps());
    let new_active_stake = 100_000 + profits_to_stakers;
    assert_eq!(house.play_balance(scenario.ctx()), new_active_stake); // House is funded again with new active stake (original + profits after house fee)
    // Profits are distributed using mul_floor (rounds down) - protocol pays less
    assert_eq!(participation.stake(), 20_000 + one_fifth_floor(profits_to_stakers));
    assert_eq!(another_participation.stake(), 80_000 + four_fifths_floor(profits_to_stakers));

    // Now unstake everything
    let to_unstake = participation.stake();
    house.unstake_v2(
        &mut participation,
        to_unstake,
        scenario.ctx(),
    );
    let to_unstake = another_participation.stake();
    house.unstake_v2(
        &mut another_participation,
        to_unstake,
        scenario.ctx(),
    );

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(house.is_active(scenario.ctx()) == false); // Not enough funds to start a new cycle

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    // Profits are distributed using mul_floor (rounds down) - protocol pays less
    assert_eq!(participation.claimable_balance(), 20_000 + one_fifth_floor(profits_to_stakers)); // Now the rest is released, namely 20_000 plus his bm's share of the profits (after house fee)
    assert_eq!(
        another_participation.claimable_balance(),
        80_000 + four_fifths_floor(profits_to_stakers),
    ); // Now the rest is released, namely 80_000 plus his bm's share of the profits (after house fee)

    destroy(house);
    destroy(registry);
    destroy(play_cap);

    destroy(admin_cap);
    destroy(balance_manager_cap);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun complete_flow_share_profits_multi_round() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    let expected_fee =
        mul_ceil_bps(10_000, house.game_fee_bps(&game_id)) 
        + mul_ceil_bps(10_000, registry.protocol_fee_bps());

    // Skip 1 epoch without any activity and process some more transactions
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    let tx_cap = house.tx_cap_for_testing(game_id);
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    // Now unstake everything
    let to_unstake = participation.stake();
    house.unstake_v2(
        &mut participation,
        to_unstake,
        scenario.ctx(),
    );
    let to_unstake = another_participation.stake();
    house.unstake_v2(
        &mut another_participation,
        to_unstake,
        scenario.ctx(),
    );

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(house.play_balance(scenario.ctx()) == 0);

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    let gross_profits = 5_000 - expected_fee;
    let profits_to_stakers = profits_after_house_fee(gross_profits, house.house_fee_bps());
    // Profits are distributed using mul_floor (rounds down) - protocol pays less
    assert_eq!(participation.claimable_balance(), 20_000 + 2 * one_fifth_floor(profits_to_stakers));
    assert_eq!(
        another_participation.claimable_balance(),
        80_000 + 2 * four_fifths_floor(profits_to_stakers),
    );

    destroy(house);
    destroy(registry);
    destroy(play_cap);

    destroy(admin_cap);
    destroy(balance_manager_cap);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun complete_flow_profits_and_losses_multi_round() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    let expected_fee =
        mul_ceil_bps(10_000, house.game_fee_bps(&game_id)) 
        + mul_ceil_bps(10_000, registry.protocol_fee_bps());

    // Skip 1 epoch without any activity and process some more transactions
    // Net result should be even
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(15_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    // Now unstake everything
    let to_unstake = participation.stake();
    house.unstake_v2(
        &mut participation,
        to_unstake,
        scenario.ctx(),
    );
    let to_unstake = another_participation.stake();
    house.unstake_v2(
        &mut another_participation,
        to_unstake,
        scenario.ctx(),
    );

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(house.play_balance(scenario.ctx()) == 0);

    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    // First epoch: profit of 5k - fees, house fee deducted, profits distributed (with rounding)
    // Second epoch: loss of 5k + fees, losses distributed (with rounding)
    // Net result: stakers lost the house fee from first epoch + tx fees from both epochs
    let first_epoch_profits = 5_000 - expected_fee;
    let first_epoch_profits_to_stakers = profits_after_house_fee(
        first_epoch_profits,
        house.house_fee_bps(),
    );

    // First epoch: profits distributed (rounds down)
    let first_epoch_profit_share_1 = one_fifth_floor(first_epoch_profits_to_stakers);
    let first_epoch_profit_share_2 = four_fifths_floor(first_epoch_profits_to_stakers);

    // Second epoch: loss of 5k + fees
    let second_epoch_loss = 5_000 + expected_fee;
    // Losses distributed (rounds up)
    let second_epoch_loss_share_1 = one_fifth_ceil(second_epoch_loss);
    let second_epoch_loss_share_2 = four_fifths_ceil(second_epoch_loss);

    // Net: initial stake + first epoch profit - second epoch loss
    let net_1 = 20_000 + first_epoch_profit_share_1 - second_epoch_loss_share_1;
    let net_2 = 80_000 + first_epoch_profit_share_2 - second_epoch_loss_share_2;

    assert_eq!(participation.claimable_balance(), net_1);
    assert_eq!(another_participation.claimable_balance(), net_2);

    destroy(registry);
    destroy(house);
    destroy(play_cap);

    destroy(admin_cap);
    destroy(balance_manager_cap);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun complete_flow_multiple_funded_rounds() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 30_000 on first participation
    let stake = mint_for_testing<SUI>(30_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start

    // Stake 120_000 on second participation
    let stake = mint_for_testing<SUI>(120_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 150_000); // house has stared
    assert!(participation.stake() == 30_000);
    assert!(another_participation.stake() == 120_000);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k + the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(20_000)],
        &play_cap,
        scenario.ctx(),
    );
    let expected_fee =
        mul_ceil_bps(10_000, house.game_fee_bps(&game_id)) 
        + mul_ceil_bps(10_000, registry.protocol_fee_bps());
    assert!(balance_manager.balance() == 60_000); // The 10k in profits is added to the first balance manager
    assert!(house.play_balance(scenario.ctx()) == 140_000 - expected_fee); // The losses and fees are deducted from the play balance
    assert!(participation.stake() == 30_000);
    assert!(another_participation.stake() == 120_000);

    // End the epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 140_000 - expected_fee); // Fresh play balance
    let total_loss = 10_000 + expected_fee;
    // Losses are distributed using mul_ceil (rounds up) - users absorb more losses
    let first_participation_expected_stake = 30_000 - one_fifth_ceil(total_loss);
    assert_eq!(participation.stake(), first_participation_expected_stake); // Losses are deducted now from the active stake
    assert_eq!(another_participation.stake(), 120_000 - four_fifths_ceil(total_loss));

    // Stake another 20_000 with the first balance manager
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 140_000 - expected_fee); // Play balance stays the same

    // Now unstake for first staker
    let to_unstake = participation.stake() + participation.pending_stake();
    house.unstake_v2(
        &mut participation,
        to_unstake,
        scenario.ctx(),
    );
    assert!(participation.claimable_balance() == 20_000); // Only the 20_000 that was still pending is immediately released, the rest is now pending to be unstaked

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());

    assert!(
        house.play_balance(scenario.ctx()) == 140_000 - expected_fee - first_participation_expected_stake,
    ); // Play balance should be funded once again because the second staker has enough funds staked
    let total_loss = 10_000 + expected_fee;
    // Losses are distributed using mul_ceil (rounds up) - users absorb more losses
    assert_eq!(participation.claimable_balance(), 20_000 + 30_000 - one_fifth_ceil(total_loss)); // Now the rest is released, namely 30_000 minus his bm's share of the losses

    destroy(house);
    destroy(registry);
    destroy(play_cap);

    destroy(admin_cap);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    destroy(balance_manager_cap);
    destroy(stats);
    scenario.end();
}

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun insufficient_funds_should_fail() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Stake 100_000
    let stake = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());

    // Process some transactions
    // a bet of 10k and a win of 20k
    // This should fail
    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(20_000)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test]
public fun stake_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());

    // Stake 30_000 on first participation
    let stake = mint_for_testing<SUI>(30_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());

    // Stake 120_000 on second participation
    let stake = mint_for_testing<SUI>(120_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    // Check active stake
    assert!(participation.stake() == 30_000);
    assert!(another_participation.stake() == 120_000);
    assert!(house.play_balance(scenario.ctx()) == 150_000); // house has stared

    // First participant unstakes
    house.unstake_v2(&mut participation, 30_000, scenario.ctx());
    assert!(participation.claimable_balance() == 0); // No funds should be added yet

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());
    // Stake is now released
    assert!(house.play_balance(scenario.ctx()) == 120_000); // Play balance still has enough
    assert!(participation.stake() == 0);
    assert!(participation.claimable_balance() == 30_000);
    assert!(another_participation.stake() == 120_000);

    //  First one now stakes 100k again
    let stake = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(participation.stake() == 0); // Not active yet
    // Second one unstakes
    house.unstake_v2(&mut another_participation, 120_000, scenario.ctx());
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());

    assert!(another_participation.claimable_balance() == 0); // No funds should be added yet
    assert!(another_participation.stake() == 120_000); // Still active

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 100_000); // Play balance still has enough

    // Stake of the first one should be active
    assert!(participation.stake() == 100_000); // Active now
    // Second one should get funds back
    assert!(another_participation.claimable_balance() == 120_000);
    assert!(another_participation.stake() == 0); // Not active anymore

    // Now unstake the remaining funds
    house.unstake_v2(&mut participation, 100_000, scenario.ctx());
    assert!(participation.claimable_balance() == 30_000); // This is the 30k from before

    // Advance epoch
    scenario.next_epoch(addr);
    // Refresh the participations
    house.update_participation(&mut participation, scenario.ctx());
    house.update_participation(&mut another_participation, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // Not enough balance anymore
    // Claim funds
    assert!(participation.claimable_balance() == 130_000); // This is the 30k from before
    assert!(another_participation.claimable_balance() == 120_000);

    destroy(house);

    destroy(admin_cap);
    destroy(participation);
    destroy(another_participation);
    scenario.end();
}

#[test]
public fun house_doesnt_start_when_everything_unstaked() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 100_000 on first participation
    let stake = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 100_000); // house has stared
    assert!(participation.stake() == 100_000);

    // First bm unstakes
    house.unstake_v2(&mut participation, 100_000, scenario.ctx());
    house.update_participation(&mut participation, scenario.ctx());
    assert!(participation.claimable_balance() == 0); // No funds should be added yet

    // Advance epoch
    // Stake is now released
    scenario.next_epoch(addr);
    house.update_participation(&mut participation, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // Not enough anymore
    assert!(participation.stake() == 0);
    assert!(participation.claimable_balance() == 100_000);

    destroy(house);

    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
public fun collect_fees_ok() {
    let addr = @0xa;
    let game_id = object::id_from_address(@0xB);
    let mut scenario = begin(addr);

    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());
    scenario.next_epoch(addr);

    let tx_cap = house.tx_cap_for_testing(game_id);

    house.add_game_fees_for_testing(game_id, 200, scenario.ctx());

    let coin2 = house.tx_admin_claim_game_fees(tx_cap, scenario.ctx());
    assert!(coin2.value() == 200);

    destroy(house);

    destroy(admin_cap);
    destroy(participation);
    burn_for_testing(coin2);
    scenario.end();
}

#[test]
public fun collect_fees_empty() {
    let addr = @0xa;
    let game_id = object::id_from_address(@0xB);
    let mut scenario = begin(addr);
    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let tx_cap = house.tx_cap_for_testing(game_id);
    let coin2 = house.tx_admin_claim_game_fees(tx_cap, scenario.ctx());
    assert!(coin2.value() == 0);

    destroy(house);

    destroy(admin_cap);
    burn_for_testing(coin2);
    scenario.end();
}

#[test]
public fun claim_house_fees_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());
    scenario.next_epoch(addr);
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions that result in profits
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    let expected_fee =
        mul_ceil_bps(10_000, house.game_fee_bps(&game_id))
        + mul_ceil_bps(10_000, registry.protocol_fee_bps());
    let gross_profits = 5_000 - expected_fee;
    let expected_house_fee = mul_ceil_bps(gross_profits, house.house_fee_bps());

    // End the epoch to process profits and collect house fee
    scenario.next_epoch(addr);
    house.update_participation(&mut participation, scenario.ctx());

    // Claim house fees
    let house_fee_coin = house.admin_claim_house_fees(&admin_cap, scenario.ctx());
    assert_eq!(house_fee_coin.value(), expected_house_fee);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    burn_for_testing(house_fee_coin);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun collect_game_fees_multiple_caps() {
    let addr = @0xa;
    let game_id1 = object::id_from_address(@0xB);
    let game_id2 = object::id_from_address(@0xC);
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    house.add_game_fees_for_testing(game_id1, 100, scenario.ctx());

    let tx_cap1 = house.tx_cap_for_testing(game_id1);
    let coin1 = house.tx_admin_claim_game_fees(tx_cap1, scenario.ctx());
    assert!(coin1.value() == 100);
    let tx_cap2 = house.tx_cap_for_testing(game_id2);
    let coin2 = house.tx_admin_claim_game_fees(tx_cap2, scenario.ctx());
    assert!(coin2.value() == 0);

    burn_for_testing(coin1);
    burn_for_testing(coin2);

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidTxCap)]
public fun collect_game_fees_wrong_cap() {
    let addr = @0xa;
    let game_id = object::id_from_address(@0xB);
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let (mut house1, _admin_cap1) = default_house(scenario.ctx());
    let (mut house2, _admin_cap2) = default_house(scenario.ctx());

    let tx_cap = house1.tx_cap_for_testing(game_id);

    let _coin = house2.tx_admin_claim_game_fees(tx_cap, scenario.ctx());
    abort 0
}

#[test]
public fun private_house_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a private house
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());
    let (house, admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        true,
        100_000,
        2000,
        scenario.ctx(),
    );
    let participation = house.admin_new_participation(&admin_cap, scenario.ctx());

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    destroy(openplay_admin_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EHouseIsPrivate)]
public fun private_house_error() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a private house
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());
    let (house, _admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        true,
        100_000,
        2000,
        scenario.ctx(),
    );
    let _participation = house.new_participation(scenario.ctx());
    abort 0
}

#[test, expected_failure(abort_code = house::EInvalidTxCap)]
public fun process_transactions_wrong_cap() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house1, _admin_cap1) = default_house(scenario.ctx());
    let (mut house2, _admin_cap2) = default_house(scenario.ctx());

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    house1.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        house2.tx_cap_for_testing(game_id),
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test]
public fun process_transactions_basic() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());
    scenario.next_epoch(addr);
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    let game_fee_coin = house.tx_admin_claim_game_fees(tx_cap, scenario.ctx());
    let expected_game_fee = mul_ceil_bps(10_000, house.game_fee_bps(&game_id));

    assert!(game_fee_coin.value() == expected_game_fee);

    // Check stats
    assert!(stats.current_volumes().bet_count() == 1);
    assert!(stats.current_volumes().bet_sum() == 10_000);
    assert!(stats.current_volumes().win_count() == 1);
    assert!(stats.current_volumes().win_sum() == 5_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);

    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(game_fee_coin);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun process_transactions_different_game_fees() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id1 = object::id_from_address(@0x11);
    let game_id2 = object::id_from_address(@0x12);
    let fake_game_id = object::id_from_address(@0x13);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Set different fees
    house.admin_set_game_fee(&admin_cap, game_id1, 100);
    house.admin_set_game_fee(&admin_cap, game_id2, 150);

    // Test game fee BPS getters
    assert_eq!(house.game_fee_bps(&game_id1), 100);
    assert_eq!(house.game_fee_bps(&game_id2), 150);
    assert_eq!(house.game_fee_bps(&fake_game_id), 0);

    let participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());
    scenario.next_epoch(addr);
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Check fee for first game
    let tx_cap = house.tx_cap_for_testing(game_id1);
    let mut stats1 = game_stats::stats_for_testing(game_id1, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats1,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    let tx_cap = house.tx_cap_for_testing(game_id1);
    let game_fee_coin1 = house.tx_admin_claim_game_fees(tx_cap, scenario.ctx());
    let expected_game_fee = mul_ceil_bps(10_000, house.game_fee_bps(&game_id1));
    assert!(game_fee_coin1.value() == expected_game_fee);

    // Check fee for second game
    let tx_cap = house.tx_cap_for_testing(game_id2);
    let mut stats2 = game_stats::stats_for_testing(game_id2, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats2,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    let tx_cap = house.tx_cap_for_testing(game_id2);
    let game_fee_coin2 = house.tx_admin_claim_game_fees(tx_cap, scenario.ctx());
    let expected_game_fee = mul_ceil_bps(10_000, house.game_fee_bps(&game_id2));
    assert!(game_fee_coin2.value() == expected_game_fee);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);

    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(game_fee_coin1);
    destroy(game_fee_coin2);
    destroy(participation);

    destroy(stats1);
    destroy(stats2);
    scenario.end();
}

#[test]
public fun process_transactions_no_bm() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());
    scenario.next_epoch(addr);

    // let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit 50_000 on the balance manager
    let funds = mint_for_testing<SUI>(10_000, scenario.ctx());
    // balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    // let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    let remainder = house.tx_admin_process_transactions_v2_no_bm(
        &registry,
        &mut stats,
        tx_cap,
        &vector[bet(10_000), win(5_000)],
        funds,
        scenario.ctx(),
    );

    let expected_game_fee = mul_ceil_bps(10_000, house.game_fee_bps(&game_id));

    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    let game_fee_coin = house.tx_admin_claim_game_fees(tx_cap, scenario.ctx());

    assert!(game_fee_coin.value() == expected_game_fee);
    assert!(remainder.value() == 5_000);

    // Check stats
    assert!(stats.current_volumes().bet_count() == 1);
    assert!(stats.current_volumes().bet_sum() == 10_000);
    assert!(stats.current_volumes().win_count() == 1);
    assert!(stats.current_volumes().win_sum() == 5_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(remainder);

    destroy(game_fee_coin);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun process_transactions_no_bm_insufficient_balance() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let _participation = fund_house_for_playing(&mut house, 100_000, scenario.ctx());
    scenario.next_epoch(addr);

    let funds = mint_for_testing<SUI>(9_999, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    let _remainder = house.tx_admin_process_transactions_v2_no_bm(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &vector[bet(10_000), win(11_000)],
        funds,
        scenario.ctx(),
    );

    abort 0
}

#[test, expected_failure(abort_code = house::EUnauthorizedGameId)]
public fun tx_cap_wrong_uid() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    let mut obj1 = object::new(scenario.ctx());
    house.admin_add_tx_allowed(&admin_cap, obj1.to_inner());
    let _tx_cap = house.borrow_tx_cap(&mut obj1);

    let mut obj2 = object::new(scenario.ctx());
    let _tx_cap = house.borrow_tx_cap(&mut obj2);
    abort 0
}

#[test, expected_failure(abort_code = house::EUnauthorizedGameId)]
public fun tx_cap_revoked() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    let mut obj1 = object::new(scenario.ctx());
    house.admin_add_tx_allowed(&admin_cap, obj1.to_inner());
    let _tx_cap = house.borrow_tx_cap(&mut obj1);

    house.admin_revoke_tx_allowed(&admin_cap, &obj1.to_inner());
    let _tx_cap = house.borrow_tx_cap(&mut obj1);
    abort 0
}

#[test, expected_failure(abort_code = registry::EPackageVersionDisabled)]
public fun house_version_disabled_after_rename() {
    let addr = @0xa;
    let game_id = object::id_from_address(addr);
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 100_000); // house cycle started

    // Disable the version
    let admin_cap = registry::cap_for_testing(scenario.ctx());
    registry.admin_disallow_version(&admin_cap, current_version());

    // Process some transactions
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test, expected_failure(abort_code = registry::EPackageVersionDisabled)]
public fun house_version_disabled() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Stake 20_000 on first participation
    let stake = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());
    assert!(house.play_balance(scenario.ctx()) == 0); // house is yet to start

    // Stake 80_000 on second participation
    let stake = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.stake(&mut another_participation, stake, scenario.ctx());

    assert!(house.play_balance(scenario.ctx()) == 100_000); // house cycle started

    // Disable the version
    let admin_cap = registry::cap_for_testing(scenario.ctx());
    registry.admin_disallow_version(&admin_cap, current_version());

    // Process some transactions
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k - the extra owner and protocol fees
    let tx_cap = house.tx_cap_for_testing(object::id_from_address(addr));
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test, expected_failure(abort_code = house::EInvalidGameStats)]
public fun process_transactions_invalid_stats() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let wrong_game_id = object::id_from_address(@0xB);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house1, _admin_cap1) = default_house(scenario.ctx());
    let (mut house2, _admin_cap2) = default_house(scenario.ctx());

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    house1.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(wrong_game_id, scenario.ctx()),
        house2.tx_cap_for_testing(game_id),
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test]
public fun update_participation_with_epoch_limit() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and participation
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake funds to activate the house
    let stake = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.stake(&mut participation, stake, scenario.ctx());

    // Process some transactions to generate profits
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit funds to the balance manager
    let deposit_coins = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit_coins, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    let tx_cap = house.tx_cap_for_testing(game_id);

    // Generate some profits
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Advance 10 epochs without updating participation (simulating user inactivity)
    // Use a dummy participation to trigger end-of-day processing for the house
    let mut dummy_participation = participation::empty(house.id(), scenario.ctx());
    let last_updated_epoch = participation.last_updated_epoch();

    // Advance epochs and process end of day for each to generate history
    // We use dummy_participation to trigger house.process_end_of_day via update_participation
    let mut i = 0;
    while (i < 10) {
        scenario.next_epoch(addr);
        // Update dummy participation to trigger house end-of-day processing
        house.update_participation(&mut dummy_participation, scenario.ctx());
        i = i + 1;
    };

    // Verify participation is still at the initial epoch (not updated)
    assert!(participation.last_updated_epoch() == last_updated_epoch);

    // Try to update with a limit of 3 epochs at a time
    // First call: should process 3 epochs and return false (more epochs remain)
    let all_processed_1 = house.update_participation_with_limit(
        &mut participation,
        3,
        scenario.ctx(),
    );
    assert!(all_processed_1 == false);
    assert!(participation.last_updated_epoch() == last_updated_epoch + 3);

    // Second call: should process 3 more epochs
    let all_processed_2 = house.update_participation_with_limit(
        &mut participation,
        3,
        scenario.ctx(),
    );
    assert!(all_processed_2 == false);
    assert!(participation.last_updated_epoch() == last_updated_epoch + 6);

    // Third call: should process 3 more epochs
    let all_processed_3 = house.update_participation_with_limit(
        &mut participation,
        3,
        scenario.ctx(),
    );
    assert!(all_processed_3 == false);
    assert!(participation.last_updated_epoch() == last_updated_epoch + 9);

    // Fourth call: should process the remaining 1 epoch and return true (all processed)
    let all_processed_4 = house.update_participation_with_limit(
        &mut participation,
        3,
        scenario.ctx(),
    );
    assert!(all_processed_4 == true);
    assert!(participation.last_updated_epoch() == scenario.ctx().epoch());

    // Verify that the default update_participation still works (processes all epochs)
    // Advance one more epoch
    scenario.next_epoch(addr);
    // Use dummy participation to trigger end-of-day processing
    house.update_participation(&mut dummy_participation, scenario.ctx());

    // Update without limit - should process all epochs in one call
    house.update_participation(&mut participation, scenario.ctx());
    assert!(participation.last_updated_epoch() == scenario.ctx().epoch());

    destroy(participation);
    destroy(dummy_participation);
    destroy(house);
    destroy(admin_cap);
    destroy(registry);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}
