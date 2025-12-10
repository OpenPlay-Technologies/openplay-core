#[test_only]
/// Tests for house fee collection: house fees, collector fees, protocol fees.
/// GGR-based fee model where all fees are calculated from Gross Gaming Revenue at epoch end.
module openplay_core::house_fees_tests;

use openplay_core::balance_manager;
use openplay_core::calculations::mul_ceil_bps;
use openplay_core::core_test_utils::{fund_house_for_playing, default_house};
use openplay_core::fee_collector;
use openplay_core::game_stats;
use openplay_core::house;
use openplay_core::registry::{Self, registry_for_testing};
use openplay_core::transaction::{bet, win};
use std::unit_test::{assert_eq, destroy};
use sui::coin::{mint_for_testing, burn_for_testing};
use sui::sui::SUI;
use sui::test_scenario::begin;

// ============================================================
// House Fees Tests
// ============================================================

#[test]
/// House fees are calculated from GGR at epoch end and can be claimed.
fun claim_house_fees_calculated_from_ggr() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions: bet 10k, win 5k = GGR 5k (profit)
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

    // End epoch to process GGR-based fees
    scenario.next_epoch(addr);

    // House fee = GGR * house_fee_bps / 10000
    // GGR = 10_000 - 5_000 = 5_000
    // house_fee_bps = 2000 (20%)
    let ggr = 5_000;
    let expected_house_fee = mul_ceil_bps(ggr, house.house_fee_bps());

    let house_fee_coin = house.admin_claim_house_fees(&registry, &admin_cap, scenario.ctx());
    assert_eq!(house_fee_coin.value(), expected_house_fee);

    burn_for_testing(house_fee_coin);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test]
/// No house fees when GGR is negative (house lost money).
fun claim_house_fees_zero_when_ggr_negative() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions: bet 10k, win 15k = GGR -5k (loss)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(15_000)],
        &play_cap,
        scenario.ctx(),
    );

    scenario.next_epoch(addr);

    let house_fee_coin = house.admin_claim_house_fees(&registry, &admin_cap, scenario.ctx());
    assert_eq!(house_fee_coin.value(), 0);

    burn_for_testing(house_fee_coin);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

// ============================================================
// Collector Fees Tests
// ============================================================

#[test]
/// Collector fees can be claimed after being added.
fun claim_collector_fees_works() {
    let addr = @0xa;
    let game_id = object::id_from_address(@0xB);
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    // Create fee collector
    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let fee_collector_id = fee_collector.id();

    // Assign game to fee collector
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);

    // Add collector fees for testing
    house.add_collector_fees_for_testing(fee_collector_id, 200);

    // Claim fees
    let coin = house.claim_collector_fees(&registry, &fee_collector, &fee_collector_cap, scenario.ctx());
    assert_eq!(coin.value(), 200);

    burn_for_testing(coin);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(fee_collector);
    destroy(fee_collector_cap);
    scenario.end();
}

#[test]
/// Claiming collector fees when none exist returns zero.
fun claim_collector_fees_empty_returns_zero() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());

    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    let coin = house.claim_collector_fees(&registry, &fee_collector, &fee_collector_cap, scenario.ctx());
    assert_eq!(coin.value(), 0);

    burn_for_testing(coin);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(fee_collector);
    destroy(fee_collector_cap);
    scenario.end();
}

#[test]
/// Multiple fee collectors accumulate fees independently.
fun claim_collector_fees_multiple_collectors() {
    let addr = @0xa;
    let game_id1 = object::id_from_address(@0xB);
    let game_id2 = object::id_from_address(@0xC);
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    // Create two fee collectors
    let (fee_collector1, cap1) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fee_collector2, cap2) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    // Get IDs
    let fee_collector1_id = fee_collector1.id();
    let fee_collector2_id = fee_collector2.id();

    // Assign games to fee collectors
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id1, &fee_collector1);
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id2, &fee_collector2);

    // Add fees for testing
    house.add_collector_fees_for_testing(fee_collector1_id, 100);
    house.add_collector_fees_for_testing(fee_collector2_id, 50);

    // Claim each
    let coin1 = house.claim_collector_fees(&registry, &fee_collector1, &cap1, scenario.ctx());
    assert_eq!(coin1.value(), 100);

    let coin2 = house.claim_collector_fees(&registry, &fee_collector2, &cap2, scenario.ctx());
    assert_eq!(coin2.value(), 50);

    burn_for_testing(coin1);
    burn_for_testing(coin2);
    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    destroy(fee_collector1);
    destroy(cap1);
    destroy(fee_collector2);
    destroy(cap2);
    destroy(registry);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidFeeCollector)]
/// Cannot claim collector fees using wrong house.
fun claim_collector_fees_wrong_house_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());

    let (house1, admin_cap1) = default_house(scenario.ctx());
    let (mut house2, _admin_cap2) = default_house(scenario.ctx());

    // Create fee collector for house1
    let (fee_collector, cap) = house1.admin_create_fee_collector(&admin_cap1, scenario.ctx());

    // Try to claim using house2
    let _coin = house2.claim_collector_fees(&registry, &fee_collector, &cap, scenario.ctx());
    abort 0
}

#[test, expected_failure(abort_code = fee_collector::EInvalidCap)]
/// Cannot claim collector fees with wrong cap.
fun claim_collector_fees_wrong_cap_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());

    let (mut house1, admin_cap1) = default_house(scenario.ctx());
    let (house2, admin_cap2) = default_house(scenario.ctx());

    // Create fee collector for house1
    let (fee_collector1, _cap1) = house1.admin_create_fee_collector(&admin_cap1, scenario.ctx());
    // Create fee collector for house2
    let (_fee_collector2, cap2) = house2.admin_create_fee_collector(&admin_cap2, scenario.ctx());

    // Try to claim with wrong cap
    let _coin = house1.claim_collector_fees(&registry, &fee_collector1, &cap2, scenario.ctx());
    abort 0
}

// ============================================================
// Protocol Fees Tests
// ============================================================

#[test]
/// Protocol fees are calculated from GGR and can be claimed.
fun claim_protocol_fees_calculated_from_ggr() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions: bet 10k, win 5k = GGR 5k
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

    scenario.next_epoch(addr);

    // Protocol fee = GGR * protocol_fee_bps / 10000
    // GGR = 5_000, protocol_fee_bps = 50 (0.5%)
    let ggr = 5_000;
    let expected_protocol_fee = mul_ceil_bps(ggr, 50);

    let protocol_fee_coin = house.openplay_admin_claim_protocol_fees(
        &openplay_admin_cap,
        &registry,
        scenario.ctx(),
    );
    assert_eq!(protocol_fee_coin.value(), expected_protocol_fee);

    burn_for_testing(protocol_fee_coin);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(openplay_admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

// ============================================================
// Fee Configuration Tests
// ============================================================

#[test]
/// Admin can update fees within valid range.
fun admin_update_fees_works() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Update to 15% house fee, 8% collector share
    house.admin_update_fees(&admin_cap, 1500, 800);

    assert_eq!(house.house_fee_bps(), 1500);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidFeeConfiguration)]
/// House fee cannot be >= 100%.
fun admin_update_fees_house_fee_too_high_fails() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    house.admin_update_fees(&admin_cap, openplay_core::core_constants::max_bps(), 1000);
    abort 0
}

#[test, expected_failure(abort_code = house::EInvalidFeeConfiguration)]
/// Collector share cannot be >= 100%.
fun admin_update_fees_collector_share_too_high_fails() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    house.admin_update_fees(&admin_cap, 2000, openplay_core::core_constants::max_bps());
    abort 0
}

#[test, expected_failure(abort_code = house::EHouseAndCollectorFeesTooHigh)]
/// House fee + collector share cannot exceed 50%.
fun admin_update_fees_combined_too_high_fails() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // 30% + 30% = 60% > 50%
    house.admin_update_fees(&admin_cap, 3000, 3000);
    abort 0
}

#[test, expected_failure(abort_code = house::EHouseAndCollectorFeesTooHigh)]
/// Cannot create house with fees > 50%.
fun new_house_fees_too_high_fails() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());

    // 30% + 30% = 60% > 50%
    let (_house, _admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        &registry,
        false,
        100_000,
        3000,
        3000,
        scenario.ctx(),
    );
    abort 0
}

#[test, expected_failure(abort_code = registry::EInvalidFeeConfiguration)]
/// Cannot set protocol fee above maximum.
fun protocol_fee_above_max_fails() {
    let mut scenario = begin(@0xa);
    let mut registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());

    // Try to set protocol fee above max (20%)
    registry.update_protocol_fee_bps(
        &openplay_admin_cap,
        openplay_core::core_constants::max_protocol_fee_bps() + 1,
        scenario.ctx(),
    );
    abort 0
}

// ============================================================
// Fee Collector from GGR Integration Test
// ============================================================

#[test]
/// Fee collectors receive fees proportional to their game's GGR.
fun collector_fees_from_ggr_by_game() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id1 = object::id_from_address(@0x11);
    let game_id2 = object::id_from_address(@0x12);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Create two fee collectors
    let (fee_collector1, fee_collector_cap1) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fee_collector2, fee_collector_cap2) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());

    // Assign games
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id1, &fee_collector1);
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id2, &fee_collector2);

    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
    scenario.next_epoch(addr);

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Game 1: bet 10k, win 5k = GGR 5k
    let tx_cap1 = house.tx_cap_for_testing(game_id1);
    let mut stats1 = game_stats::stats_for_testing(game_id1, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats1,
        tx_cap1,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Game 2: bet 15k, win 5k = GGR 10k
    let tx_cap2 = house.tx_cap_for_testing(game_id2);
    let mut stats2 = game_stats::stats_for_testing(game_id2, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats2,
        tx_cap2,
        &mut balance_manager,
        &vector[bet(15_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // End epoch to calculate fees
    scenario.next_epoch(addr);

    // Collector fee share = 10% = 1000 bps
    // Collector 1: GGR 5k * 10% = 500
    // Collector 2: GGR 10k * 10% = 1000
    let expected_fees1 = mul_ceil_bps(5_000, 1000);
    let expected_fees2 = mul_ceil_bps(10_000, 1000);

    let coin1 = house.claim_collector_fees(&registry, &fee_collector1, &fee_collector_cap1, scenario.ctx());
    let coin2 = house.claim_collector_fees(&registry, &fee_collector2, &fee_collector_cap2, scenario.ctx());

    assert_eq!(coin1.value(), expected_fees1);
    assert_eq!(coin2.value(), expected_fees2);

    burn_for_testing(coin1);
    burn_for_testing(coin2);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(fee_collector1);
    destroy(fee_collector_cap1);
    destroy(fee_collector2);
    destroy(fee_collector_cap2);
    destroy(stats1);
    destroy(stats2);
    scenario.end();
}

// ============================================================
// Edge Case Tests
// ============================================================

#[test]
/// Claiming fees multiple times in same epoch returns zero after first claim.
fun claim_fees_twice_second_is_zero() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions: bet 10k, win 5k = GGR 5k
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

    scenario.next_epoch(addr);

    // First claim gets fees
    let ggr = 5_000;
    let expected_house_fee = mul_ceil_bps(ggr, house.house_fee_bps());
    let first_claim = house.admin_claim_house_fees(&registry, &admin_cap, scenario.ctx());
    assert_eq!(first_claim.value(), expected_house_fee);

    // Second claim gets zero
    let second_claim = house.admin_claim_house_fees(&registry, &admin_cap, scenario.ctx());
    assert_eq!(second_claim.value(), 0);

    burn_for_testing(first_claim);
    burn_for_testing(second_claim);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test]
/// Fees accumulate correctly across multiple epochs.
fun fees_accumulate_across_epochs() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // Epoch 1: GGR 5k
    let tx_cap1 = house.tx_cap_for_testing(game_id);
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap1,
        &mut balance_manager,
        &vector[bet(10_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    scenario.next_epoch(addr);

    // Epoch 2: GGR 3k
    let tx_cap2 = house.tx_cap_for_testing(game_id);
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap2,
        &mut balance_manager,
        &vector[bet(5_000), win(2_000)],
        &play_cap,
        scenario.ctx(),
    );

    scenario.next_epoch(addr);

    // Epoch 3: GGR 2k
    let tx_cap3 = house.tx_cap_for_testing(game_id);
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap3,
        &mut balance_manager,
        &vector[bet(4_000), win(2_000)],
        &play_cap,
        scenario.ctx(),
    );

    scenario.next_epoch(addr);

    // Claim accumulated fees: 5k + 3k + 2k = 10k GGR
    let total_ggr = 10_000;
    let expected_total_fee = mul_ceil_bps(total_ggr, house.house_fee_bps());

    let claimed = house.admin_claim_house_fees(&registry, &admin_cap, scenario.ctx());
    assert_eq!(claimed.value(), expected_total_fee);

    burn_for_testing(claimed);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test]
/// Fees at boundary values (exactly 50% combined).
fun fees_at_boundary_50_percent() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Update to exactly 50% (25% + 25%)
    house.admin_update_fees(&admin_cap, 2500, 2500);

    assert_eq!(house.house_fee_bps(), 2500);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
/// Zero house fee is valid.
fun zero_house_fee_valid() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Zero house fee
    house.admin_update_fees(&admin_cap, 0, 1000);
    assert_eq!(house.house_fee_bps(), 0);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
/// Zero collector fee is valid.
fun zero_collector_fee_valid() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Zero collector fee
    house.admin_update_fees(&admin_cap, 2000, 0);
    assert_eq!(house.house_fee_bps(), 2000);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
/// Both fees zero is valid.
fun both_fees_zero_valid() {
    let mut scenario = begin(@0xa);
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Zero everything
    house.admin_update_fees(&admin_cap, 0, 0);
    assert_eq!(house.house_fee_bps(), 0);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}
