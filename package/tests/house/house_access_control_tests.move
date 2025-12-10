#[test_only]
/// Tests for house access control: admin caps, private houses, participation validation.
module openplay_core::house_access_control_tests;

use openplay_core::core_test_utils::default_house;
use openplay_core::house;
use openplay_core::participation;
use openplay_core::registry::{Self, registry_for_testing};
use std::unit_test::destroy;
use sui::coin::mint_for_testing;
use sui::sui::SUI;
use sui::test_scenario::begin;

// ============================================================
// Admin Cap Tests
// ============================================================

#[test]
/// Admin cap correctly references its house.
fun admin_cap_has_correct_house_id() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    let house_id = house.id();
    let cap_house_id = house::admin_cap_house_id(&admin_cap);

    assert!(cap_house_id == house_id);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidAdminCap)]
/// Cannot use admin cap from different house.
fun admin_cap_wrong_house_fails() {
    let mut scenario = begin(@0xa);
    let (mut house1, _admin_cap1) = default_house(scenario.ctx());
    let (_house2, admin_cap2) = default_house(scenario.ctx());

    // Try to update fees on house1 with house2's admin cap
    house1.admin_update_fees(&admin_cap2, 1500, 800);
    abort 0
}

// ============================================================
// Transaction Cap Tests
// ============================================================

#[test]
/// Transaction cap correctly references its house.
fun transaction_cap_has_correct_house_id() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let game_id = object::id_from_address(@0xB);

    let tx_cap = house.tx_cap_for_testing(game_id);
    let house_id = house.id();
    let cap_house_id = house::transaction_cap_house_id(&tx_cap);

    assert!(cap_house_id == house_id);

    destroy(tx_cap);
    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidTxCap)]
/// Cannot use tx cap from different house.
fun transaction_cap_wrong_house_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house1, _admin_cap1) = default_house(scenario.ctx());
    let (mut house2, _admin_cap2) = default_house(scenario.ctx());

    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Try to use house2's tx cap on house1
    house1.tx_admin_process_transactions_v2(
        &registry,
        &mut openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx()),
        house2.tx_cap_for_testing(game_id),
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(5_000)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

// ============================================================
// Private House Tests
// ============================================================

#[test]
/// Admin can create participation on private house.
fun private_house_admin_can_create_participation() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());

    let (house, admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        &registry,
        true, // private
        100_000,
        2000,
        1000,
        scenario.ctx(),
    );

    assert!(house.private() == true);

    let participation = house.admin_new_participation(&admin_cap, scenario.ctx());

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    destroy(openplay_admin_cap);
    destroy(registry);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EHouseIsPrivate)]
/// Non-admin cannot create participation on private house.
fun private_house_non_admin_cannot_create_participation() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());

    let (house, _admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        &registry,
        true, // private
        100_000,
        2000,
        1000,
        scenario.ctx(),
    );

    // Try to create participation without admin cap
    let _participation = house.new_participation(scenario.ctx());
    abort 0
}

#[test]
/// Public house allows anyone to create participation.
fun public_house_anyone_can_create_participation() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    assert!(house.private() == false);

    let participation = house.new_participation(scenario.ctx());

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

// ============================================================
// Participation Validation Tests
// ============================================================

#[test, expected_failure(abort_code = house::EInvalidParticipation)]
/// Cannot use participation from different house.
fun participation_wrong_house_fails() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house1, _admin_cap1) = default_house(scenario.ctx());
    let (house2, _admin_cap2) = default_house(scenario.ctx());

    // Create participation for house2 (using wrong house_id)
    let mut participation = participation::empty(house2.id(), scenario.ctx());

    // Try to buy shares on house1 with participation for house2
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house1.buy_shares(&registry, &mut participation, deposit, scenario.ctx());
    abort 0
}

#[test]
/// NAV check validates participation belongs to house.
fun nav_validates_participation() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Create valid participation
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    // NAV works for valid participation
    let nav = house.nav(&participation);
    assert!(nav == 100_000);

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    destroy(registry);
    scenario.end();
}

// ============================================================
// House ID and View Functions Tests
// ============================================================

#[test]
/// House ID is valid non-zero.
fun house_id_is_valid() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    let house_id = house.id();
    assert!(house_id != object::id_from_address(@0x0));

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
/// House fee bps returns correct default value.
fun house_fee_bps_correct() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    // Default house has 20% = 2000 bps
    assert!(house.house_fee_bps() == 2000);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
/// House balance and total shares start at zero.
fun house_initial_state() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    assert!(house.house_balance() == 0);
    assert!(house.total_shares() == 0);
    assert!(house.effective_house_balance() == 0);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

// ============================================================
// Share Function Tests
// ============================================================

#[test]
/// House can be shared and registered with registry.
fun house_share_registers_with_registry() {
    let mut scenario = begin(@0xa);
    let mut registry = registry_for_testing(scenario.ctx());
    let (house, admin_cap) = default_house(scenario.ctx());

    // Share registers house with registry
    house::share(&mut registry, house, scenario.ctx());

    destroy(admin_cap);
    destroy(registry);
    scenario.end();
}
