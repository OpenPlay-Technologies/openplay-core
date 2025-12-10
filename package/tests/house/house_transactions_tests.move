#[test_only]
/// Tests for house transaction processing: tx_admin_process_transactions_v2, tx_admin_process_transactions_v2_no_bm.
/// Also covers balance settlement, statistics updates, and multi-round flows.
module openplay_core::house_transactions_tests;

use openplay_core::balance_manager;
use openplay_core::calculations::mul_ceil_bps;
use openplay_core::core_constants::current_version;
use openplay_core::core_test_utils::{fund_house_for_playing, default_house};
use openplay_core::game_stats;
use openplay_core::house;
use openplay_core::participation;
use openplay_core::registry::{Self, registry_for_testing};
use openplay_core::transaction::{bet, win};
use std::unit_test::{assert_eq, destroy};
use sui::coin::mint_for_testing;
use sui::sui::SUI;
use sui::test_scenario::begin;

// ============================================================
// Basic Transaction Processing Tests
// ============================================================

#[test]
/// Process transactions correctly updates balances and stats.
fun process_transactions_basic() {
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

    // Stats updated
    assert_eq!(stats.current_volumes().bet_count(), 1);
    assert_eq!(stats.current_volumes().bet_sum(), 10_000);
    assert_eq!(stats.current_volumes().win_count(), 1);
    assert_eq!(stats.current_volumes().win_sum(), 5_000);

    // Balances updated: player lost 5k net
    assert_eq!(balance_manager.balance(), 45_000);
    assert_eq!(house.house_balance(), 105_000);

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
/// Process transactions resulting in player win (house loss).
fun process_transactions_player_wins() {
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

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // bet 10k, win 20k = player wins 10k net
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(20_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Player gained 10k net
    assert_eq!(balance_manager.balance(), 60_000);
    // House lost 10k
    assert_eq!(house.house_balance(), 90_000);

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
// No Balance Manager Mode Tests
// ============================================================

#[test]
/// Process transactions without a pre-existing balance manager.
fun process_transactions_no_bm() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    // Provide funds directly
    let funds = mint_for_testing<SUI>(10_000, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // bet 10k, win 5k = player loses 5k
    let remainder = house.tx_admin_process_transactions_v2_no_bm(
        &registry,
        &mut stats,
        tx_cap,
        &vector[bet(10_000), win(5_000)],
        funds,
        scenario.ctx(),
    );

    // Remainder is 5k (10k funds - 10k bet + 5k win)
    assert_eq!(remainder.value(), 5_000);

    // Stats updated
    assert_eq!(stats.current_volumes().bet_count(), 1);
    assert_eq!(stats.current_volumes().bet_sum(), 10_000);
    assert_eq!(stats.current_volumes().win_count(), 1);
    assert_eq!(stats.current_volumes().win_sum(), 5_000);

    // NAV should reflect profit minus pending fees
    let pending_fees = mul_ceil_bps(5_000, 3050);
    assert_eq!(house.effective_house_balance(), 105_000 - pending_fees);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(remainder);
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
/// Process transactions no_bm fails with insufficient funds.
fun process_transactions_no_bm_insufficient_funds_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let _participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    // Only 9,999 but need 10,000 to bet
    let funds = mint_for_testing<SUI>(9_999, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
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

// ============================================================
// Balance Validation Tests
// ============================================================

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
/// Cannot bet without sufficient balance, even if win > bet.
fun bet_without_funds_fails_even_if_win_higher() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Balance manager has 0 funds
    assert_eq!(balance_manager.balance(), 0);

    // Fund house
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);

    // Try to bet 100, win 150 - should fail because no funds to bet
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &mut balance_manager,
        &vector[bet(100), win(150)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
/// Cannot bet without sufficient balance, when win equals bet.
fun bet_without_funds_fails_when_win_equals_bet() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    assert_eq!(balance_manager.balance(), 0);

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);

    // Try to bet 100, win 100 - should fail because no funds
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &mut balance_manager,
        &vector[bet(100), win(100)],
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

#[test]
/// Bet with sufficient funds works correctly.
fun bet_with_sufficient_funds_works() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 200
    let bm_deposit = mint_for_testing<SUI>(200, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, bm_deposit, scenario.ctx());
    assert_eq!(balance_manager.balance(), 200);

    // Fund house
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // bet 100, win 150 - player gains 50
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(100), win(150)],
        &play_cap,
        scenario.ctx(),
    );

    // 200 + 50 net = 250
    assert_eq!(balance_manager.balance(), 250);

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

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
/// House fails when insufficient funds to pay winnings.
fun house_insufficient_funds_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with only 100k
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);

    // bet 10k, win 20k = house needs to pay 10k net, but try huge win
    // This will fail because house can't cover the difference
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(20_000)], // Balance manager has 0, can't cover bet
        &play_cap,
        scenario.ctx(),
    );
    abort 0
}

// ============================================================
// Ensure Sufficient Funds Tests
// ============================================================

#[test]
/// ensure_sufficient_funds passes when house has enough.
fun ensure_sufficient_funds_passes() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    house.ensure_sufficient_funds(50_000);
    house.ensure_sufficient_funds(100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInsufficientFunds)]
/// ensure_sufficient_funds fails when house doesn't have enough.
fun ensure_sufficient_funds_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let _participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    scenario.next_epoch(addr);

    house.ensure_sufficient_funds(100_001);
    abort 0
}

// ============================================================
// Multi-Round and Epoch Transition Tests
// ============================================================

#[test]
/// Multi-round transactions with epoch transitions.
fun multi_round_with_epoch_transitions() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit to balance manager
    let bm_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, bm_deposit, scenario.ctx());

    // Fund house
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, scenario.ctx());

    // Round 1: bet 10k, win 5k = profit 5k
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

    // Skip epochs
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);

    // Round 2: bet 10k, win 5k = profit 5k
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

    // Total profit: 10k
    // Pending fees for current epoch only (5k GGR)
    let pending_fees = mul_ceil_bps(10_000, 3050);
    let effective_balance = house.effective_house_balance();
    assert_eq!(effective_balance, 110_000 - pending_fees);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

#[test]
/// Profit followed by loss nets out correctly.
fun profit_then_loss_nets_out() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    let bm_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, bm_deposit, scenario.ctx());

    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, scenario.ctx());

    // Round 1: profit 5k
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
    scenario.next_epoch(addr);

    // Round 2: loss 5k (bet 10k, win 15k)
    let tx_cap = house.tx_cap_for_testing(game_id);
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(15_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Net: +5k - 5k = 0
    // But fees were taken from first epoch's profit
    let pending_fees = mul_ceil_bps(5_000, 3050);
    let effective_balance = house.effective_house_balance();
    assert_eq!(effective_balance, 100_000 - pending_fees);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

// ============================================================
// Version Control Tests
// ============================================================

#[test, expected_failure(abort_code = registry::EPackageVersionDisabled)]
/// Transactions fail when version is disabled.
fun process_transactions_version_disabled_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    let bm_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, bm_deposit, scenario.ctx());

    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, scenario.ctx());

    // Disable version
    let admin_cap = registry::cap_for_testing(scenario.ctx());
    registry.admin_disallow_version(&admin_cap, current_version(), scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
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
/// No-BM transactions also fail when version is disabled.
fun process_transactions_no_bm_version_disabled_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());

    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, scenario.ctx());

    // Disable version
    let admin_cap = registry::cap_for_testing(scenario.ctx());
    registry.admin_disallow_version(&admin_cap, current_version(), scenario.ctx());

    let tx_cap = house.tx_cap_for_testing(game_id);
    let _remainder = house.tx_admin_process_transactions_v2_no_bm(
        &registry,
        &mut game_stats::stats_for_testing(game_id, scenario.ctx()),
        tx_cap,
        &vector[bet(10_000), win(11_000)],
        mint_for_testing<SUI>(10_000, scenario.ctx()),
        scenario.ctx(),
    );
    abort 0
}

// ============================================================
// Invalid Stats Tests
// ============================================================

#[test, expected_failure(abort_code = house::EInvalidGameStats)]
/// Processing with wrong game stats fails.
fun process_transactions_wrong_stats_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let wrong_game_id = object::id_from_address(@0xB);
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

// ============================================================
// Edge Case Tests
// ============================================================

#[test]
/// Empty transactions vector is handled correctly.
fun process_transactions_empty_vector() {
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

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // Process empty transactions
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[],
        &play_cap,
        scenario.ctx(),
    );

    // No changes
    assert_eq!(balance_manager.balance(), 50_000);
    assert_eq!(house.house_balance(), 100_000);
    assert_eq!(stats.current_volumes().bet_count(), 0);
    assert_eq!(stats.current_volumes().win_count(), 0);

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
/// Multiple transactions in same call accumulate correctly.
fun process_transactions_multiple_in_one_call() {
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

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // Process multiple transactions at once
    // bet 5k, win 2k, bet 3k, win 1k, bet 2k, win 5k
    // Total bet: 10k, Total win: 8k, Net: player loses 2k
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(5_000), win(2_000), bet(3_000), win(1_000), bet(2_000), win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Verify stats
    assert_eq!(stats.current_volumes().bet_count(), 3);
    assert_eq!(stats.current_volumes().bet_sum(), 10_000);
    assert_eq!(stats.current_volumes().win_count(), 3);
    assert_eq!(stats.current_volumes().win_sum(), 8_000);

    // Verify balances
    assert_eq!(balance_manager.balance(), 48_000); // 50k - 2k net loss
    assert_eq!(house.house_balance(), 102_000); // 100k + 2k net profit

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
/// Break-even transaction (bet = win) works correctly.
fun process_transactions_break_even() {
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

    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // bet 10k, win 10k = break even (GGR = 0)
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(10_000), win(10_000)],
        &play_cap,
        scenario.ctx(),
    );

    // No net change in balances
    assert_eq!(balance_manager.balance(), 50_000);
    assert_eq!(house.house_balance(), 100_000);

    // No pending fees (GGR = 0)
    assert_eq!(house.effective_house_balance(), 100_000);

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
/// Transactions accumulate fees correctly within same epoch.
fun process_transactions_accumulate_fees_same_epoch() {
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

    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());

    // First round: bet 10k, win 5k = GGR 5k
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

    let _pending_fees_1 = mul_ceil_bps(5_000, 3050);

    // Second round: bet 5k, win 2k = GGR 3k
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

    // Total GGR = 5k + 3k = 8k
    let total_pending_fees = mul_ceil_bps(8_000, 3050);

    // House balance: 100k + 5k + 3k = 108k
    assert_eq!(house.house_balance(), 108_000);

    // Effective balance accounts for accumulated fees
    assert_eq!(house.effective_house_balance(), 108_000 - total_pending_fees);

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
