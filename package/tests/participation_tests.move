#[test_only]
module openplay_core::participation_tests;

use openplay_core::core_test_utils::{default_house, assert_eq_within_precision_allowance};
use openplay_core::participation;
use sui::test_scenario::begin;
use sui::test_utils::destroy;

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
    // stake of 100 + profits of 10 = total stake of 110
    // 10% of 110 should ne available now on the claimable balance
    // and the 100 remains on the stake

    assert!(participation.stake() == 100);
    assert!(participation.pending_stake() == 0);
    assert!(participation.claimable_balance() == 10);

    // Now we want to unstake everything
    let (_remaining_amount, _pending_stake_removed) = participation.unstake_v2(
        100,
        true,
        scenario.ctx(),
    );
    assert!(participation.pending_unstake() == 100);

    // Advance epoch with profits of 10 (10% of stake)
    scenario.next_epoch(addr);
    participation.process_end_of_day(scenario.ctx().epoch() - 1, 10, 0, scenario.ctx());

    // The pending_unstake should now be actualized
    // stake of 100 + profits of 10 = total stake of 110
    // 100% of 110 should ne available now on the claimable balance
    // and 0 remains on the stake

    // Rounding errors again
    assert_eq_within_precision_allowance(participation.stake(), 0);
    assert!(participation.pending_stake() == 0);
    assert_eq_within_precision_allowance(participation.claimable_balance(), 10 + 110); // 10 from before

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
    // stake of 81 + losses of 8 = total stake of 73
    // 100% of 73 should ne available now on the claimable balance
    // and 0 remains on the stake

    // Rounding errors again
    assert_eq_within_precision_allowance(participation.stake(), 0);
    assert!(participation.pending_stake() == 0);
    assert_eq_within_precision_allowance(participation.claimable_balance(), 9 + 73); // 9 from before

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
    // Can deduct more from active stake than available (because of precision errors)
    scenario.next_epoch(addr);
    participation.process_end_of_day(2, 0, 6, scenario.ctx());
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
