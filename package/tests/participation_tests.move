#[test_only]
module openplay_core::participation_tests;

use openplay_core::core_test_utils::default_house;
use openplay_core::participation;
use std::unit_test::destroy;
use sui::test_scenario::begin;

#[test]
public fun shares_basic_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Initially no shares
    assert!(participation::shares(&participation) == 0);

    // Add shares directly (package function, used by house)
    participation::add_shares(&mut participation, 10);
    assert!(participation::shares(&participation) == 10);

    // Remove shares
    participation::remove_shares(&mut participation, 5);
    assert!(participation::shares(&participation) == 5);

    // Remove all shares
    participation::remove_shares(&mut participation, 5);
    assert!(participation::shares(&participation) == 0);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
public fun shares_add_remove_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Add shares multiple times
    participation::add_shares(&mut participation, 10);
    assert!(participation::shares(&participation) == 10);

    participation::add_shares(&mut participation, 20);
    assert!(participation::shares(&participation) == 30);

    participation::add_shares(&mut participation, 5);
    assert!(participation::shares(&participation) == 35);

    // Remove shares
    participation::remove_shares(&mut participation, 10);
    assert!(participation::shares(&participation) == 25);

    participation::remove_shares(&mut participation, 15);
    assert!(participation::shares(&participation) == 10);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = participation::ENotEnoughShares)]
public fun remove_too_many_shares_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Add 10 shares
    participation::add_shares(&mut participation, 10);
    assert!(participation::shares(&participation) == 10);

    // Try to remove more than available - should fail
    participation::remove_shares(&mut participation, 11);

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
public fun destroy_empty_participation_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let participation = participation::empty(house.id(), scenario.ctx());

    // Destroy empty participation
    participation::destroy_empty(participation, scenario.ctx());

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = participation::ENotEmpty)]
public fun destroy_non_empty_participation_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Add shares
    participation::add_shares(&mut participation, 10);

    // Try to destroy non-empty participation - should fail
    participation::destroy_empty(participation, scenario.ctx());

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
public fun participation_id_and_house_id_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create participation
    let (house, admin_cap) = default_house(scenario.ctx());
    let participation = participation::empty(house.id(), scenario.ctx());

    // Check IDs
    assert!(participation::house_id(&participation) == house.id());
    assert!(participation::id(&participation) != house.id()); // Should be different

    destroy(participation);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}
