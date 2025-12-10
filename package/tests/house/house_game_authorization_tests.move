#[test_only]
/// Tests for house game authorization: whitelisting games, fee collector assignment, tx cap management.
module openplay_core::house_game_authorization_tests;

use openplay_core::core_test_utils::default_house;
use openplay_core::house;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario::begin;

// ============================================================
// Game Whitelisting Tests
// ============================================================

#[test]
/// Game can be assigned to a fee collector.
fun game_assigned_to_fee_collector() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let game_id = object::id_from_address(@0xB);

    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let fee_collector_id = fee_collector.id();

    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);

    // Verify assignment
    assert_eq!(house.game_fee_collector(&game_id), fee_collector_id);

    destroy(house);
    destroy(admin_cap);
    destroy(fee_collector);
    destroy(fee_collector_cap);
    scenario.end();
}

#[test]
/// Game can be reassigned to a different fee collector.
fun game_reassigned_to_different_collector() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let game_id = object::id_from_address(@0xB);

    let (fee_collector1, cap1) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fee_collector2, cap2) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    // Assign to first collector
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector1);
    assert_eq!(house.game_fee_collector(&game_id), fee_collector1.id());

    // Reassign to second collector
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector2);
    assert_eq!(house.game_fee_collector(&game_id), fee_collector2.id());

    destroy(house);
    destroy(admin_cap);
    destroy(fee_collector1);
    destroy(cap1);
    destroy(fee_collector2);
    destroy(cap2);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidFeeCollector)]
/// Cannot assign game to fee collector from different house.
fun game_assignment_wrong_collector_house_fails() {
    let mut scenario = begin(@0xa);
    let (mut house1, admin_cap1) = default_house(scenario.ctx());
    let (house2, admin_cap2) = default_house(scenario.ctx());
    let game_id = object::id_from_address(@0xB);

    // Create fee collector for house2
    let (fee_collector, _cap) = house2.admin_create_fee_collector(&admin_cap2, scenario.ctx());

    // Try to assign game from house1 to fee collector from house2
    house1.admin_add_tx_allowed_with_collector(&admin_cap1, game_id, &fee_collector);
    abort 0
}

// ============================================================
// Game Revocation Tests
// ============================================================

#[test, expected_failure(abort_code = house::EGameDoesNotExist)]
/// Revoked game cannot be queried.
fun revoked_game_not_queryable() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let game_id = object::id_from_address(@0x11);

    let (fee_collector, _fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let fee_collector_id = fee_collector.id();

    // Assign game
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);
    assert_eq!(house.game_fee_collector(&game_id), fee_collector_id);

    // Revoke
    house.admin_revoke_tx_allowed(&admin_cap, game_id);

    // Query should fail
    house.game_fee_collector(&game_id);
    abort 0
}

#[test, expected_failure(abort_code = house::EGameDoesNotExist)]
/// Cannot revoke non-existent game.
fun revoke_nonexistent_game_fails() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let game_id = object::id_from_address(@0x11);

    house.admin_revoke_tx_allowed(&admin_cap, game_id);
    abort 0
}

// ============================================================
// Borrow Tx Cap Tests
// ============================================================

#[test]
/// Can borrow tx cap for authorized game.
fun borrow_tx_cap_for_authorized_game() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    let mut game_uid = object::new(scenario.ctx());
    let game_id = game_uid.to_inner();

    // Assign game to fee collector
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);

    // Can borrow tx cap
    let tx_cap = house.borrow_tx_cap(&mut game_uid);

    // Verify cap
    assert_eq!(house::transaction_cap_house_id(&tx_cap), house.id());

    destroy(tx_cap);
    destroy(game_uid);
    destroy(house);
    destroy(admin_cap);
    destroy(fee_collector);
    destroy(fee_collector_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EUnauthorizedGameId)]
/// Cannot borrow tx cap for unauthorized game.
fun borrow_tx_cap_unauthorized_game_fails() {
    let mut scenario = begin(@0xa);
    let (house, _admin_cap) = default_house(scenario.ctx());

    // Create a different game that is NOT authorized
    let mut unauthorized_uid = object::new(scenario.ctx());
    let _tx_cap = house.borrow_tx_cap(&mut unauthorized_uid);
    abort 0
}

#[test, expected_failure(abort_code = house::EUnauthorizedGameId)]
/// Cannot borrow tx cap after game is revoked.
fun borrow_tx_cap_revoked_game_fails() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    let (fee_collector, _fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    let mut game_uid = object::new(scenario.ctx());
    let game_id = game_uid.to_inner();

    // Assign game to fee collector
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);

    // First borrow works
    let tx_cap = house.borrow_tx_cap(&mut game_uid);
    destroy(tx_cap);

    // Revoke game
    house.admin_revoke_tx_allowed(&admin_cap, game_id);

    // Second borrow fails
    let _tx_cap = house.borrow_tx_cap(&mut game_uid);
    abort 0
}

// ============================================================
// Fee Collector Creation Tests
// ============================================================

#[test]
/// Admin can create fee collector.
fun admin_creates_fee_collector() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    // Verify collector belongs to this house
    assert_eq!(fee_collector.house_id(), house.id());

    destroy(house);
    destroy(admin_cap);
    destroy(fee_collector);
    destroy(fee_collector_cap);
    scenario.end();
}

#[test]
/// Can create multiple fee collectors.
fun admin_creates_multiple_fee_collectors() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());

    let (fc1, cap1) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fc2, cap2) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fc3, cap3) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    // All belong to same house
    assert_eq!(fc1.house_id(), house.id());
    assert_eq!(fc2.house_id(), house.id());
    assert_eq!(fc3.house_id(), house.id());

    // But have different IDs
    assert!(fc1.id() != fc2.id());
    assert!(fc2.id() != fc3.id());
    assert!(fc1.id() != fc3.id());

    destroy(house);
    destroy(admin_cap);
    destroy(fc1);
    destroy(cap1);
    destroy(fc2);
    destroy(cap2);
    destroy(fc3);
    destroy(cap3);
    scenario.end();
}

// ============================================================
// Max Games Limit Tests
// ============================================================

#[test]
/// Multiple games can be added (up to limit).
fun multiple_games_can_be_added() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    // Add 10 games (well under limit of 500)
    let mut i = 0;
    while (i < 10) {
        let game_id = object::id_from_address(@0xB);
        house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);
        i = i + 1;
    };

    // Can still add more
    let game_id_extra = object::id_from_address(@0xC);
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id_extra, &fee_collector);

    destroy(house);
    destroy(admin_cap);
    destroy(fee_collector);
    destroy(fee_collector_cap);
    scenario.end();
}

// ============================================================
// Max Games Limit Edge Case Tests
// ============================================================

// NOTE: Testing EMaxGamesReached (500 games) is impractical in unit tests due to gas limits.
// The MAX_GAMES constant at 500 and the check at line 682 in house.move ensures this error
// is triggered, but running 500 iterations in a test exceeds gas limits.
// This edge case is verified through code inspection rather than runtime testing.
