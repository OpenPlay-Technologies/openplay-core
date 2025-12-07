#[test_only]
module openplay_core::participation_tests;

use openplay_core::core_test_utils::default_house;
use openplay_core::participation;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario::begin;

#[test]
public fun stake_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 10
    participation.add_stake(10, false, scenario.ctx());

    // Should be added to stake because house is not active
    assert!(participation.stake() == 10);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);

    // Unstake right away
    let (remaining_amount, pending_stake_removed) = participation.unstake_v2(
        10,
        false,
        scenario.ctx(),
    );
    assert!(remaining_amount == 10);
    assert!(pending_stake_removed == 0);

    assert!(participation.stake() == 0);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 10);

    // Stake 20: 10 with inactive house, and 10 with active house
    participation.add_stake(10, false, scenario.ctx());
    // Now the house is supposedly activated
    participation.add_stake(10, true, scenario.ctx());

    assert!(participation.stake() == 10);
    assert!(participation.pending_stake() == 10);
    assert!(participation.claimable_balance() == 10);

    // Advance epoch, should activate the pending stake
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());

    assert!(participation.stake() == 20);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 10);

    // Stake 5 more
    participation.add_stake(5, true, scenario.ctx());

    assert!(participation.stake() == 20);
    assert!(participation.pending_stake() == 5);
    assert!(participation.claimable_balance() == 10);

    // Unstake: 5 should be instant and 20 pending
    assert!(participation.pending_unstake() == 0);
    let (remaining_amount, pending_stake_removed) = participation.unstake_v2(
        25,
        true,
        scenario.ctx(),
    );

    assert!(pending_stake_removed == 5);
    assert!(remaining_amount == 20);

    assert!(participation.stake() == 20);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 15);
    assert!(participation.pending_unstake() == 20);

    // Advance epoch, should free up the stake
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());

    assert!(participation.stake() == 0);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 35);

    let claimed = participation.claim_all(scenario.ctx());

    assert!(claimed == 35);
    assert!(participation.stake() == 0);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test]
public fun partial_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 10
    participation.add_stake(10, false, scenario.ctx());

    // Should be added to stake because house is not active
    assert!(participation.stake() == 10);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);

    // Unstake 3 right away
    let (remaining_amount, pending_stake_removed) = participation.unstake_v2(
        3,
        false,
        scenario.ctx(),
    );
    assert!(remaining_amount == 3);
    assert!(pending_stake_removed == 0);

    assert!(participation.stake() == 7);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 3);

    // Stake 20: 10 with inactive house, and 10 with active house
    participation.add_stake(10, false, scenario.ctx());
    // Now the house is supposedly activated
    participation.add_stake(10, true, scenario.ctx());

    assert!(participation.stake() == 17);
    assert!(participation.pending_stake() == 10);
    assert!(participation.claimable_balance() == 3);

    // Advance epoch, should activate the pending stake
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());

    assert!(participation.stake() == 27);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 3);

    // Stake 5 more
    participation.add_stake(5, true, scenario.ctx());

    assert!(participation.stake() == 27);
    assert!(participation.pending_stake() == 5);
    assert!(participation.claimable_balance() == 3);

    // Unstake 25: 5 should be instant and 20 pending
    assert!(participation.pending_unstake() == 0);
    let (remaining_amount, pending_stake_removed) = participation.unstake_v2(
        25,
        true,
        scenario.ctx(),
    );

    assert!(pending_stake_removed == 5);
    assert!(remaining_amount == 20);

    assert!(participation.stake() == 27);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 8);
    assert!(participation.pending_unstake() == 20);

    // Advance epoch, should release the stake
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());

    assert!(participation.stake() == 7);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 28);
    assert!(participation.pending_unstake() == 0);

    let claimed = participation.claim_all(scenario.ctx());

    assert!(claimed == 28);
    assert!(participation.stake() == 7);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);
    assert!(participation.pending_unstake() == 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test]
public fun pending_unstake_actualized_profits_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 100
    participation.add_stake(100, false, scenario.ctx());
    assert!(participation.stake() == 100);

    // Unstake 10 with the house actvive
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        10,
        true,
        scenario.ctx(),
    );
    assert!(participation.pending_unstake() == 10);

    // Advance epoch with profits of 10 (10% of stake)
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 10, 0, scenario.ctx());

    // The pending_unstake should now be actualized
    // actualize_amount(10, 10, 0, 100, false) = mul_floor(10, 110, 100) = 11
    // stake = 100 + 10 - 11 = 99
    assert_eq!(participation.stake(), 99);
    assert!(participation.pending_stake() == 0);
    assert_eq!(participation.claimable_balance(), 11);

    // Now we want to unstake everything
    // After first epoch, stake is 99 (100 + 10 - 11)
    let current_stake = participation.stake();
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        current_stake,
        true,
        scenario.ctx(),
    );
    assert!(participation.pending_unstake() == current_stake);

    // Advance epoch with profits of 10 (10% of stake)
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 10, 0, scenario.ctx());

    // The pending_unstake should now be actualized
    // First actualized: actualize_amount(10, 10, 0, 100, false) = mul_floor(10, 110, 100) = 11
    // Second actualized: actualize_amount(99, 10, 0, 99, false) = mul_floor(99, 109, 99) = 109
    // Total claimable: 11 + 109 = 120
    assert_eq!(participation.stake(), 0);
    assert!(participation.pending_stake() == 0);
    assert_eq!(participation.claimable_balance(), 120);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test]
public fun pending_unstake_actualized_losses_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 100
    participation.add_stake(100, false, scenario.ctx());
    assert!(participation.stake() == 100);

    // Unstake 10 with the house actvive
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        10,
        true,
        scenario.ctx(),
    );
    assert!(participation.pending_unstake() == 10);

    // Advance epoch with losses of 10 (10% of stake)
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 10, scenario.ctx());

    // The pending_unstake should now be actualized
    // stake of 100 + losses of 10 = total stake of 90
    // 10% of 90 should be available now on the claimable balance (=9)
    // and the 81 remains on the stake

    assert!(participation.stake() == 81);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 9);

    // Now we want to unstake everything
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        81,
        true,
        scenario.ctx(),
    );
    assert!(participation.pending_unstake() == 81);

    // Advance epoch with losses of 8 (+- 10% of stake)
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 8, scenario.ctx());

    // The pending_unstake should now be actualized
    // First actualized: actualize_amount(10, 0, 10, 100, true) = mul_ceil(10, 90, 100) = 9
    // After first epoch: stake = 100 - 10 - 9 = 81, claimable = 9
    // Second actualized: actualize_amount(81, 0, 8, 81, true) = mul_ceil(81, 73, 81) = 73
    // Total claimable: 9 + 73 = 82
    assert_eq!(participation.stake(), 0);
    assert!(participation.pending_stake() == 0);
    assert_eq!(participation.claimable_balance(), 82);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test]
public fun process_ggr_share_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    assert!(participation.stake() == 0);
    // Profits should be added to the active stake
    scenario.next_epoch(addr);
    participation.process_end_of_day(0, 10, 0, scenario.ctx());
    assert!(participation.stake() == 10);
    // Losses should be deducted from the active stake
    scenario.next_epoch(addr);
    participation.process_end_of_day(1, 0, 5, scenario.ctx());
    assert!(participation.stake() == 5);
    // Can only deduct up to available stake (strict checking, no tolerance for rounding errors)
    scenario.next_epoch(addr);
    participation.process_end_of_day(2, 0, 5, scenario.ctx());
    assert!(participation.stake() == 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test]
public fun end_of_day_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 10 (inactive house)
    participation.add_stake(10, false, scenario.ctx());

    // Request unstake (active house, so it's pending)
    participation.unstake_v2(10, true, scenario.ctx());

    assert!(participation.stake() == 10);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);
    assert!(participation.pending_unstake() == 10);

    // Take losses of 6
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 6, scenario.ctx());

    assert!(participation.stake() == 0);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 4);
    assert!(participation.pending_unstake() == 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test]
public fun end_of_day_pending_stake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 10 (active house)
    participation.add_stake(10, true, scenario.ctx());

    assert!(participation.stake() == 0);
    assert!(participation.pending_stake() == 10);
    assert!(participation.claimable_balance() == 0);

    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());

    assert!(participation.stake() == 10);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);

    scenario.end();
}

#[test, expected_failure(abort_code = participation::EInvalidProfitsOrLosses)]
public fun end_of_day_cannot_bear_more_losses_than_available() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 10 (active house)
    participation.add_stake(10, false, scenario.ctx());

    assert!(participation.stake() == 10);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 0);

    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 50, scenario.ctx());
    abort 0
}

#[test, expected_failure(abort_code = participation::EEpochMismatch)]
public fun cannot_stake_invalid_epoch() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    // Stake 10
    participation.add_stake(10, false, scenario.ctx());
    abort 0
}

#[test, expected_failure(abort_code = participation::EEpochMismatch)]
public fun cannot_unstake_invalid_epoch() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    participation.add_stake(10, false, scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    // Unstake
    participation.unstake_v2(10, false, scenario.ctx());
    abort 0
}

#[test, expected_failure(abort_code = participation::EEpochMismatch)]
public fun cannot_process_eod_invalid_epoch() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    participation.add_stake(10, false, scenario.ctx());

    // Advance epoch
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    // Unstake
    participation.process_end_of_day(1, 0, 0, scenario.ctx());
    abort 0
}

/// Tests the mathematical property that actualized unstake amount is always <= remaining stake.
/// This verifies the property holds when losses are applied first, then unstake is actualized.
/// The assertion in the code ensures this property is enforced at runtime.
#[test]
public fun process_end_of_day_losses_actualized_unstake_exceeds_stake() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake a small amount
    participation.add_stake(10, false, scenario.ctx());
    assert_eq!(participation.stake(), 10);
    assert_eq!(participation.claimable_balance(), 0);

    // Request to unstake everything (10 MIST)
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        10,
        true, // house is active
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 10);
    assert_eq!(participation.stake(), 10); // Still in stake until end of day

    // Advance epoch with large losses (90% loss)
    // This will reduce stake to 1 MIST (10 - 9 = 1)
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 9, scenario.ctx());

    // After losses are deducted: stake = 10 - 9 = 1 MIST
    // Actualized unstake: actualize_amount(10, 0, 9, 10, true) = mul_ceil(10, 1, 10) = 1 MIST
    // Since actual_unstake_amount (1) <= stake (1), normal case applies
    assert_eq!(participation.stake(), 0); // All stake was unstaked
    assert_eq!(participation.claimable_balance(), 1); // Received the 1 MIST remaining
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the mathematical property with different values to verify actual_unstake <= remaining_stake.
/// This test demonstrates that even with extreme values, the property always holds.
#[test]
public fun process_end_of_day_losses_actualized_unstake_exceeds_stake_edge_case() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 3 MIST
    participation.add_stake(3, false, scenario.ctx());
    assert_eq!(participation.stake(), 3);

    // Request to unstake everything
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        3,
        true, // house is active
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 3);

    // Advance epoch with losses of 2 MIST (66.67% loss)
    // After losses: stake = 3 - 2 = 1 MIST
    // Actualized unstake: actualize_amount(3, 0, 2, 3, true) = mul_ceil(3, 1, 3) = 1 MIST
    // In this case: actual_unstake_amount (1) <= stake (1), so normal case
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 2, scenario.ctx());

    assert_eq!(participation.stake(), 0);
    assert_eq!(participation.claimable_balance(), 1); // Received the 1 MIST remaining
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the mathematical property with values that verify actual_unstake <= remaining_stake.
/// This test demonstrates that even with various rounding scenarios, the property always holds.
#[test]
public fun process_end_of_day_losses_actualized_unstake_exceeds_stake_rounding() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 100 MIST
    participation.add_stake(100, false, scenario.ctx());
    assert_eq!(participation.stake(), 100);

    // Request to unstake 99 MIST (leaving 1 MIST staked)
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        99,
        true, // house is active
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 99);
    assert_eq!(participation.stake(), 100); // Still in stake

    // Advance epoch with losses of 99 MIST (99% loss)
    // After losses: stake = 100 - 99 = 1 MIST remaining
    // Actualized unstake: actualize_amount(99, 0, 99, 100, true) = mul_ceil(99, 1, 100) = 1 MIST
    // Since actual_unstake_amount (1) <= stake (1), normal case applies
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 99, scenario.ctx());

    // The actualized unstake of 1 MIST equals the remaining stake of 1 MIST
    // So all stake is moved to claimable
    assert_eq!(participation.stake(), 0);
    assert_eq!(participation.claimable_balance(), 1); // Received the 1 MIST
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the mathematical property with small stake values.
/// Verifies that even with small stake and large unstake, actual_unstake <= remaining_stake always holds.
#[test]
public fun process_end_of_day_losses_small_stake_large_unstake() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 5 MIST
    participation.add_stake(5, false, scenario.ctx());
    assert_eq!(participation.stake(), 5);

    // Request to unstake 4 MIST
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        4,
        true,
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 4);
    assert_eq!(participation.stake(), 5);

    // Advance epoch with losses of 4 MIST (80% loss)
    // After losses: stake = 5 - 4 = 1 MIST
    // Actualized unstake: actualize_amount(4, 0, 4, 5, true) = mul_ceil(4, 1, 5) = 1 MIST
    // Since actual_unstake_amount (1) <= stake (1), normal case
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 4, scenario.ctx());

    assert_eq!(participation.stake(), 0);
    assert_eq!(participation.claimable_balance(), 1); // Received the 1 MIST remaining
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the documented scenario to verify the mathematical property holds.
///
/// This test demonstrates that the documented example correctly shows
/// `actual_unstake <= remaining_stake`, verifying the mathematical proof.
#[test]
public fun process_end_of_day_losses_actualized_exceeds_stake_documented_case() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Scenario from documentation:
    // Initial stake: 10 MIST
    // Pending unstake: 10 MIST
    // Losses: 9 MIST (90% loss)

    participation.add_stake(10, false, scenario.ctx());
    assert_eq!(participation.stake(), 10);

    // Request to unstake everything
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        10,
        true,
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 10);

    // Advance epoch with losses of 9 MIST
    // Step 1: Deduct losses from stake
    //   stake = 10 - 9 = 1 MIST remaining
    // Step 2: Actualize pending unstake with losses
    //   actual_unstake = actualize_amount(10, 0, 9, 10, true)
    //   actual_unstake = mul_ceil(10, 1, 10) = 1 MIST
    //   Since 1 <= 1, the mathematical property holds
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 9, scenario.ctx());

    // In this specific case, actual_unstake_amount (1) equals stake (1), so all stake is moved
    assert_eq!(participation.stake(), 0);
    assert_eq!(participation.claimable_balance(), 1); // User receives the 1 MIST remaining
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the mathematical property that actual_unstake <= remaining_stake.
///
/// This test demonstrates that the code correctly handles the scenario where losses are applied
/// and unstake is actualized. The mathematical proof guarantees that actual_unstake <= remaining_stake
/// always holds, and the assertion in the code enforces this property at runtime.
///
/// **Test Scenario:**
/// - Partial unstake (99 out of 100 MIST)
/// - Large losses (99 MIST, 99% loss)
/// - Demonstrates the actualization logic and verifies the mathematical property
#[test]
public fun process_end_of_day_losses_partial_unstake_verification() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 100 MIST
    participation.add_stake(100, false, scenario.ctx());
    assert_eq!(participation.stake(), 100);

    // Request to unstake 99 MIST (leaving 1 MIST staked)
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        99,
        true,
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 99);
    assert_eq!(participation.stake(), 100); // Still in stake

    // Advance epoch with losses of 99 MIST (99% loss)
    // Step 1: Deduct losses from stake
    //   stake = 100 - 99 = 1 MIST remaining
    // Step 2: Actualize pending unstake (99 MIST) with losses
    //   actual_unstake = actualize_amount(99, 0, 99, 100, true)
    //   actual_unstake = mul_ceil(99, 1, 100) = ceil(99/100) = 1 MIST
    //   Since actual_unstake_amount (1) <= stake (1), normal case applies
    //   The assertion ensures this property is enforced at runtime
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 99, scenario.ctx());

    // The actualized unstake of 1 MIST equals the remaining stake of 1 MIST
    // All stake is moved to claimable, leaving 0 stake
    // This demonstrates the mathematical property holds: actual_unstake <= remaining_stake
    assert_eq!(participation.stake(), 0);
    assert_eq!(participation.claimable_balance(), 1); // User receives the 1 MIST remaining
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the mathematical property and demonstrates transparency in how losses affect unstake amounts.
///
/// **Key Points:**
/// - Losses are applied first, reducing stake
/// - Unstake is then actualized based on the original stake
/// - Mathematical proof guarantees: actual_unstake <= remaining_stake (always)
/// - This test verifies the property holds and demonstrates the calculation process
/// - Protocol benefits from rounding differences (actual_unstake may be less than proportional share)
#[test]
public fun process_end_of_day_losses_transparency_demonstration() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 50 MIST
    participation.add_stake(50, false, scenario.ctx());
    assert_eq!(participation.stake(), 50);
    assert_eq!(participation.claimable_balance(), 0);

    // Request to unstake 40 MIST
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        40,
        true,
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 40);
    assert_eq!(participation.stake(), 50); // Still in stake until end of day

    // Advance epoch with losses of 45 MIST (90% loss)
    // Step 1: Deduct losses from stake
    //   stake = 50 - 45 = 5 MIST remaining
    // Step 2: Actualize pending unstake (40 MIST) with losses
    //   actual_unstake = actualize_amount(40, 0, 45, 50, true)
    //   actual_unstake = mul_ceil(40, 5, 50) = ceil(200/50) = 4 MIST
    //   Since actual_unstake_amount (4) <= stake (5), normal case applies
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 45, scenario.ctx());

    // User receives the actualized unstake amount (4 MIST)
    // Remaining stake: 5 - 4 = 1 MIST
    assert_eq!(participation.stake(), 1);
    assert_eq!(participation.claimable_balance(), 4); // User receives 4 MIST (actualized from 40 MIST)
    assert_eq!(participation.pending_unstake(), 0);

    // This demonstrates:
    // 1. Losses reduced stake from 50 to 5 MIST
    // 2. Unstake of 40 MIST was actualized to 4 MIST (10% of original, matching the loss ratio)
    // 3. User received 4 MIST, protocol keeps 1 MIST remaining stake
    // 4. The mathematical property ensures actual_unstake <= remaining_stake always holds

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

/// Tests the mathematical property when losses equal stake (L = S).
/// This verifies the mathematical proof covers the case where remaining_stake = 0.
///
/// When L = S:
/// - remaining_stake = S - S = 0
/// - actual_unstake = mul_ceil(U, 0, S) = 0
/// - Result: 0 <= 0 ✓
#[test]
public fun process_end_of_day_losses_equal_stake() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Stake 100 MIST
    participation.add_stake(100, false, scenario.ctx());
    assert_eq!(participation.stake(), 100);

    // Request to unstake 50 MIST
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        50,
        true,
        scenario.ctx(),
    );
    assert_eq!(participation.pending_unstake(), 50);
    assert_eq!(participation.stake(), 100);

    // Advance epoch with losses equal to stake (100% loss)
    // Case: L = S
    // remaining_stake = 100 - 100 = 0
    // actual_unstake = mul_ceil(50, 0, 100) = (50 * 0 + 100 - 1) / 100 = 99 / 100 = 0
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 0, 100, scenario.ctx());

    // When L = S, remaining_stake = 0 and actual_unstake = 0
    assert_eq!(participation.stake(), 0);
    assert_eq!(participation.claimable_balance(), 0); // No stake remaining to claim
    assert_eq!(participation.pending_unstake(), 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}
