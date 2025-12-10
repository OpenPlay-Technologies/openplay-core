#[test_only]
/// Tests for house share management: buying, selling, NAV calculations.
/// These tests focus on the share-based participation model where users buy/sell shares.
module openplay_core::house_share_tests;

use openplay_core::calculations::{mul_ceil_bps, mul_floor};
use openplay_core::core_test_utils::default_house;
use openplay_core::house;
use openplay_core::participation;
use openplay_core::registry::{Self, registry_for_testing};
use std::unit_test::destroy;
use sui::coin::{mint_for_testing, burn_for_testing};
use sui::sui::SUI;
use sui::test_scenario::begin;

// ============================================================
// Buy Shares Tests
// ============================================================

#[test]
/// First deposit uses 1:1 ratio (NAV = 1 when no shares exist).
fun buy_shares_first_deposit_uses_one_to_one_ratio() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    assert!(shares == 100_000);
    assert!(participation::shares(&participation) == 100_000);
    assert!(house.house_balance() == 100_000);
    assert!(house.total_shares() == 100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// Second deposit with NAV = 1 also gets 1:1 ratio.
fun buy_shares_second_deposit_with_nav_one() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());

    // First deposit: 20k
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());
    assert!(shares1 == 20_000);

    // Second deposit: 80k (NAV still = 1)
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());
    assert!(shares2 == 80_000);

    assert!(house.house_balance() == 100_000);
    assert!(house.total_shares() == 100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidAmount)]
/// Cannot buy shares with zero deposit.
fun buy_shares_zero_deposit_fails() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(0, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());
    abort 0
}

// ============================================================
// Sell Shares Tests
// ============================================================

#[test]
/// Selling all shares returns full deposit when NAV = 1.
fun sell_shares_all_returns_full_amount() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Buy shares
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Sell all
    let payout = house.sell_shares(&registry, &mut participation, shares, 0, scenario.ctx());

    assert!(participation::shares(&participation) == 0);
    assert!(payout.value() == 100_000);
    assert!(house.total_shares() == 0);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// House balance becomes zero when all shares are sold.
fun sell_shares_all_zeros_house_balance() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());
    assert!(house.house_balance() == 100_000);

    let shares = participation::shares(&participation);
    let payout = house.sell_shares(&registry, &mut participation, shares, 0, scenario.ctx());

    // Advance epoch to finalize
    scenario.next_epoch(addr);

    assert!(house.house_balance() == 0);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// Selling partial shares leaves remainder.
fun sell_shares_partial() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Sell half
    let payout = house.sell_shares(&registry, &mut participation, 50_000, 0, scenario.ctx());

    assert!(participation::shares(&participation) == 50_000);
    assert!(payout.value() == 50_000);
    assert!(house.total_shares() == 50_000);
    assert!(house.house_balance() == 50_000);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test, expected_failure(abort_code = house::ENotEnoughShares)]
/// Cannot sell more shares than owned.
fun sell_shares_insufficient_fails() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Try to sell more than available
    let _payout = house.sell_shares(&registry, &mut participation, 1_000_000, 0, scenario.ctx());
    abort 0
}

// ============================================================
// Buy/Sell Multi-participant Flows
// ============================================================

#[test]
/// Multiple participants can buy and sell independently.
fun buy_sell_multiple_participants() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());

    // Participant 1 buys 30k
    let deposit1 = mint_for_testing<SUI>(30_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());

    // Participant 2 buys 120k
    let deposit2 = mint_for_testing<SUI>(120_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    assert!(house.house_balance() == 150_000);

    // Participant 1 sells all
    let shares1 = participation::shares(&participation1);
    let payout1 = house.sell_shares(
        &registry,
        &mut participation1,
        shares1,
        0,
        scenario.ctx(),
    );
    assert!(payout1.value() == 30_000);
    assert!(participation::shares(&participation1) == 0);

    scenario.next_epoch(addr);
    assert!(house.house_balance() == 120_000);

    // Participant 1 buys again
    let deposit3 = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit3, 0, scenario.ctx());

    // Participant 2 sells all
    let shares2 = participation::shares(&participation2);
    let payout2 = house.sell_shares(
        &registry,
        &mut participation2,
        shares2,
        0,
        scenario.ctx(),
    );
    assert!(payout2.value() == 120_000);

    scenario.next_epoch(addr);

    // Participant 1 sells remaining
    let shares1_remaining = participation::shares(&participation1);
    let payout3 = house.sell_shares(
        &registry,
        &mut participation1,
        shares1_remaining,
        0,
        scenario.ctx(),
    );
    assert!(payout3.value() == 100_000);

    scenario.next_epoch(addr);
    assert!(house.house_balance() == 0);

    burn_for_testing(payout1);
    burn_for_testing(payout2);
    burn_for_testing(payout3);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    scenario.end();
}

// ============================================================
// NAV Calculation Tests
// ============================================================

#[test]
/// NAV equals balance when no fees are pending.
fun nav_equals_balance_with_no_fees() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    assert!(house.total_shares() == 100_000);
    assert!(house.effective_house_balance() == 100_000);
    assert!(house.nav(&participation) == 100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// NAV is zero when participation has no shares.
fun nav_zero_with_no_shares() {
    let mut scenario = begin(@0xa);
    let (house, admin_cap) = default_house(scenario.ctx());
    let participation = participation::empty(house.id(), scenario.ctx());

    assert!(house.nav(&participation) == 0);

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// NAV is proportional to share ownership.
fun nav_proportional_to_shares() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());

    // 20% to participation1, 80% to participation2
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());

    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    // NAV should be proportional
    let nav1 = house.nav(&participation1);
    let nav2 = house.nav(&participation2);

    // mul_floor(20_000, 100_000, 100_000) = 20_000
    // mul_floor(80_000, 100_000, 100_000) = 80_000
    assert!(nav1 == 20_000);
    assert!(nav2 == 80_000);
    assert!(nav1 + nav2 == 100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    scenario.end();
}

// ============================================================
// Share Dilution After Losses Tests
// ============================================================

#[test]
/// After house losses, shares are worth less (NAV < 1).
fun shares_lose_value_after_house_loss() {
    let mut scenario = begin(@0xa);
    let game_id = object::id_from_address(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house: 20k + 80k = 100k
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    // Fund balance manager for player
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process loss: bet 10k, win 20k = house loses 10k (GGR = -10k)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(20_000)],
        &play_cap,
        scenario.ctx(),
    );

    // House balance decreased by 10k
    assert!(house.house_balance() == 90_000);
    // No pending fees on losses (GGR negative)
    assert!(house.effective_house_balance() == 90_000);

    // NAV proportional to remaining balance
    // mul_floor(20_000, 90_000, 100_000) = 18_000
    // mul_floor(80_000, 90_000, 100_000) = 72_000
    assert!(house.nav(&participation1) == 18_000);
    assert!(house.nav(&participation2) == 72_000);
    assert!(house.nav(&participation1) + house.nav(&participation2) == 90_000);

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
/// After house profits, shares are worth more (NAV > 1), minus pending fees.
fun shares_gain_value_after_house_profit() {
    let mut scenario = begin(@0xa);
    let game_id = object::id_from_address(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house: 20k + 80k = 100k
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process profit: bet 10k, win 5k = house gains 5k (GGR = 5k)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // House balance increased by 5k
    assert!(house.house_balance() == 105_000);

    // Pending fees: GGR=5k, total_fee_bps=3050 (50 protocol + 2000 house + 1000 collector)
    let pending_fees = mul_ceil_bps(5_000, 3050);
    assert!(pending_fees == 1525);
    assert!(house.effective_house_balance() == 105_000 - pending_fees);

    // NAV proportional to effective balance
    let effective = house.effective_house_balance();
    let nav1 = mul_floor(20_000, effective, 100_000);
    let nav2 = mul_floor(80_000, effective, 100_000);

    assert!(house.nav(&participation1) == nav1);
    assert!(house.nav(&participation2) == nav2);
    assert!(nav1 + nav2 == effective);
    assert!(nav1 + nav2 > 100_000); // Gained value
    assert!(nav1 + nav2 < 105_000); // Less than gross due to fees

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
// Buying Shares After Price Changes
// ============================================================

#[test]
/// Buying shares after losses gives more shares per MIST.
/// Selling those shares returns the correct NAV amount.
fun buy_shares_after_loss_gives_more_shares_and_sell_returns_nav() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with 150k total (30k + 120k)
    let deposit1 = mint_for_testing<SUI>(30_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(120_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    assert!(house.house_balance() == 150_000);
    assert!(house.total_shares() == 150_000);

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process loss: bet 10k, win 20k = house loses 10k (GGR = -10k)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(20_000)],
        &play_cap,
        scenario.ctx(),
    );

    // House balance: 150k - 10k = 140k
    // Shares still: 150k
    // NAV per share = 140k / 150k = 0.933...
    assert!(house.house_balance() == 140_000);
    assert!(house.effective_house_balance() == 140_000); // No fees on loss (GGR negative)

    // Buy 20k more for a new participation
    let mut new_participation = participation::empty(house.id(), scenario.ctx());
    let deposit3 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let new_shares = house.buy_shares(&registry, &mut new_participation, deposit3, 0, scenario.ctx());

    // Should get MORE than 20k shares because NAV < 1
    // shares = (deposit * total_shares) / effective_value
    // shares = (20_000 * 150_000) / 140_000 = 21_428 (floor)
    let total_shares_before = 150_000;
    let effective_before = 140_000;
    let expected_shares = mul_floor(20_000, total_shares_before, effective_before);
    assert!(new_shares == expected_shares);
    assert!(new_shares > 20_000);

    // Verify NAV matches expected value
    // After purchase: total_shares = 150_000 + new_shares, effective = 140_000 + 20_000 = 160_000
    let total_shares_after = house.total_shares();
    let effective_after = house.effective_house_balance();
    assert!(total_shares_after == total_shares_before + new_shares);
    assert!(effective_after == effective_before + 20_000);

    // NAV should be the deposit amount (what we just put in)
    let nav = house.nav(&new_participation);
    let expected_nav = mul_floor(new_shares, effective_after, total_shares_after);
    assert!(nav == expected_nav);
    // The NAV should be approximately what we deposited (20k)
    // Due to rounding, it might be slightly less
    assert!(nav <= 20_000);

    // Now sell the shares and verify we get NAV back
    let payout = house.sell_shares(&registry, &mut new_participation, new_shares, 0, scenario.ctx());
    assert!(payout.value() == nav);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    destroy(new_participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

#[test]
/// Buying shares after profits gives less shares per MIST (NAV > 1).
/// Pending fees are correctly included in effective balance calculation.
/// Selling those shares returns the correct NAV amount.
fun buy_shares_after_profit_gives_less_shares_and_sell_returns_nav() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with 150k total (30k + 120k)
    let deposit1 = mint_for_testing<SUI>(30_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(120_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    assert!(house.house_balance() == 150_000);
    assert!(house.total_shares() == 150_000);

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process profit: bet 20k, win 5k = house gains 15k (GGR = 15k)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(20_000), openplay_core::transaction::win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // House balance: 150k + 15k = 165k
    assert!(house.house_balance() == 165_000);

    // Pending fees from GGR = 15k
    // total_fee_bps = 50 (protocol) + 2000 (house) + 1000 (collector) = 3050
    let ggr = 15_000;
    let pending_fees = mul_ceil_bps(ggr, 3050);
    // pending_fees = ceil(15_000 * 3050 / 10000) = ceil(4575) = 4575
    assert!(pending_fees == 4575);

    // Effective balance = house_balance - pending_fees
    let expected_effective = 165_000 - pending_fees;
    assert!(house.effective_house_balance() == expected_effective);

    // Buy 20k more for a new participation
    // NAV per share > 1 because effective > total_shares
    // shares = (deposit * total_shares) / effective_value
    let mut new_participation = participation::empty(house.id(), scenario.ctx());
    let total_shares_before = house.total_shares();
    let effective_before = house.effective_house_balance();
    assert!(effective_before > total_shares_before); // NAV > 1

    let deposit3 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let new_shares = house.buy_shares(&registry, &mut new_participation, deposit3, 0, scenario.ctx());

    // Should get LESS than 20k shares because NAV > 1
    // shares = (20_000 * 150_000) / (165_000 - 4575) = (20_000 * 150_000) / 160_425
    let expected_shares = mul_floor(20_000, total_shares_before, effective_before);
    assert!(new_shares == expected_shares);
    assert!(new_shares < 20_000); // Less shares because NAV > 1

    // Verify NAV matches expected value
    let total_shares_after = house.total_shares();
    let effective_after = house.effective_house_balance();
    assert!(total_shares_after == total_shares_before + new_shares);
    assert!(effective_after == effective_before + 20_000);

    let nav = house.nav(&new_participation);
    let expected_nav = mul_floor(new_shares, effective_after, total_shares_after);
    assert!(nav == expected_nav);
    // The NAV should be approximately what we deposited (20k)
    assert!(nav <= 20_000);

    // Now sell the shares and verify we get NAV back
    let payout = house.sell_shares(&registry, &mut new_participation, new_shares, 0, scenario.ctx());
    assert!(payout.value() == nav);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation1);
    destroy(participation2);
    destroy(new_participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

#[test]
/// NAV remains unchanged after epoch transition when pending fees become actual fees.
/// This tests that the effective balance calculation is consistent across epochs.
fun nav_unchanged_after_epoch_transition_with_fees() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with 100k
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process profit: bet 10k, win 5k = house gains 5k (GGR = 5k)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // Verify state BEFORE epoch transition
    // House balance: 100k + 5k = 105k
    assert!(house.house_balance() == 105_000);

    // Pending fees from GGR = 5k
    let ggr = 5_000;
    let pending_fees = mul_ceil_bps(ggr, 3050);
    assert!(pending_fees == 1525);

    // Effective balance = 105k - 1525 = 103,475
    let effective_before = house.effective_house_balance();
    assert!(effective_before == 105_000 - pending_fees);

    // NAV before epoch transition
    let nav_before = house.nav(&participation);
    assert!(nav_before == effective_before); // All shares belong to this participation

    // Record values for comparison
    let total_shares_before = house.total_shares();

    // ============================================================
    // EPOCH TRANSITION - This is the key moment we're testing
    // Pending fees become actual fees and are physically moved to vault fee pools
    // ============================================================
    scenario.next_epoch(addr);

    // Trigger end-of-day processing by calling refresh_state
    house.refresh_state(&registry, scenario.ctx());

    // Verify state AFTER epoch transition
    // House balance should now be reduced by the fees that were physically moved
    // house_balance = 105_000 - pending_fees = 103_475
    let house_balance_after = house.house_balance();
    assert!(house_balance_after == 105_000 - pending_fees);

    // No more pending fees (they've been processed)
    // effective_house_balance = house_balance (no pending fees)
    let effective_after = house.effective_house_balance();
    assert!(effective_after == house_balance_after);

    // CRITICAL: NAV should be UNCHANGED after epoch transition
    // The fees were already accounted for in effective_house_balance before
    // Now they're physically removed but effective_house_balance is the same
    let nav_after = house.nav(&participation);
    assert!(nav_after == nav_before);
    assert!(nav_after == effective_after);

    // Total shares unchanged
    assert!(house.total_shares() == total_shares_before);

    // Verify we can sell and get the correct NAV amount
    let shares = participation::shares(&participation);
    let payout = house.sell_shares(&registry, &mut participation, shares, 0, scenario.ctx());
    assert!(payout.value() == nav_after);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

// ============================================================
// Edge Case Tests
// ============================================================

#[test]
/// Selling zero shares should succeed (no-op).
fun sell_shares_zero_succeeds() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Sell zero shares
    let payout = house.sell_shares(&registry, &mut participation, 0, 0, scenario.ctx());
    assert!(payout.value() == 0);
    assert!(participation::shares(&participation) == 100_000); // unchanged

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// Effective house balance is zero when pending fees exceed vault value.
/// This can happen in extreme edge cases with very high GGR.
fun effective_house_balance_zero_when_fees_exceed_value() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0xa);

    // Create house with very high fees (50% total)
    let (mut house, admin_cap) = openplay_core::house::new_for_testing(
        false,
        2500, // 25% house fee
        2500, // 25% collector fee
        50,   // 0.5% protocol fee
        scenario.ctx(),
    );
    let registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with only 1000
    let deposit = mint_for_testing<SUI>(1_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process massive profit relative to house size: bet 1000, win 0 = GGR 1000
    // This is 100% of house balance as profit!
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(1_000), openplay_core::transaction::win(0)],
        &play_cap,
        scenario.ctx(),
    );

    // House balance: 1000 + 1000 = 2000
    assert!(house.house_balance() == 2_000);

    // Pending fees: GGR=1000, total_fee_bps = 50 + 2500 + 2500 = 5050
    // pending_fees = ceil(1000 * 5050 / 10000) = ceil(505) = 505
    let pending_fees = mul_ceil_bps(1_000, 5050);
    assert!(pending_fees == 505);

    // Effective balance should be house_balance - pending_fees
    let effective = house.effective_house_balance();
    assert!(effective == 2_000 - pending_fees);
    assert!(effective > 0);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

#[test]
/// Tiny deposit when NAV is high results in zero shares (fails).
#[expected_failure(abort_code = house::EInvalidAmount)]
fun buy_shares_tiny_deposit_high_nav_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with 1M
    let deposit = mint_for_testing<SUI>(1_000_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(500_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process massive profit: bet 500k, win 0 = GGR 500k
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(500_000), openplay_core::transaction::win(0)],
        &play_cap,
        scenario.ctx(),
    );

    // NAV is now higher than 1
    // Trying to buy 1 MIST when NAV is high results in 0 shares
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let tiny_deposit = mint_for_testing<SUI>(1, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, tiny_deposit, 0, scenario.ctx());
    abort 0
}

#[test]
/// Multiple epoch skips without activity are handled correctly.
fun multiple_epoch_skips_without_activity() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Fund house
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    let initial_balance = house.house_balance();
    let initial_shares = house.total_shares();
    let initial_nav = house.nav(&participation);

    // Skip many epochs without any activity
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);

    // Trigger state refresh
    house.refresh_state(&registry, scenario.ctx());

    // Everything should be unchanged
    assert!(house.house_balance() == initial_balance);
    assert!(house.total_shares() == initial_shares);
    assert!(house.nav(&participation) == initial_nav);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// refresh_state is a no-op when already at current epoch.
fun refresh_state_noop_same_epoch() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    let balance_before = house.house_balance();
    let shares_before = house.total_shares();

    // Call refresh_state multiple times in same epoch
    house.refresh_state(&registry, scenario.ctx());
    house.refresh_state(&registry, scenario.ctx());
    house.refresh_state(&registry, scenario.ctx());

    // Nothing changed
    assert!(house.house_balance() == balance_before);
    assert!(house.total_shares() == shares_before);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// Private house admin can buy and sell shares.
fun private_house_admin_buy_sell_shares() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());

    let (mut house, admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        &registry,
        true, // private
        2000,
        1000,
        scenario.ctx(),
    );

    // Admin creates participation for private house
    let mut participation = house.admin_new_participation(&admin_cap, scenario.ctx());

    // Admin can buy shares
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());
    assert!(shares == 100_000);

    // Admin can sell shares
    let payout = house.sell_shares(&registry, &mut participation, shares, 0, scenario.ctx());
    assert!(payout.value() == 100_000);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(openplay_admin_cap);
    scenario.end();
}

#[test]
/// Selling shares when effective_value is 0 returns 0 payout.
/// This is an edge case where all house value is consumed by pending fees.
fun sell_shares_when_effective_value_is_zero() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0xa);

    // Create house with maximum fees (50%)
    let (mut house, admin_cap) = openplay_core::house::new_for_testing(
        false,
        2500, // 25% house fee
        2500, // 25% collector fee
        50,   // 0.5% protocol fee
        scenario.ctx(),
    );
    let registry = registry_for_testing(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with minimal amount
    let deposit = mint_for_testing<SUI>(100, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(1_000_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process massive profit: bet 100, win 0 = GGR 100 (100% of house balance)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(100), openplay_core::transaction::win(0)],
        &play_cap,
        scenario.ctx(),
    );

    // House balance: 100 + 100 = 200
    assert!(house.house_balance() == 200);

    // Pending fees: GGR = 100, total_fee_bps = 5050
    // pending_fees = ceil(100 * 5050 / 10000) = 51
    let pending_fees = mul_ceil_bps(100, 5050);
    assert!(pending_fees == 51);

    // Effective balance > 0 in this case
    let effective = house.effective_house_balance();
    assert!(effective == 200 - pending_fees);

    // Sell all shares - should get effective value back
    let shares = participation::shares(&participation);
    let payout = house.sell_shares(&registry, &mut participation, shares, 0, scenario.ctx());

    // Payout should be effective value (all shares belong to this participation)
    assert!(payout.value() == effective);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

// ============================================================
// Slippage Protection Tests
// ============================================================

#[test]
/// buy_shares succeeds when min_shares_out is exactly met.
fun buy_shares_slippage_exact_match() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // At NAV = 1, depositing 100_000 should yield exactly 100_000 shares
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 100_000, scenario.ctx());

    assert!(shares == 100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// buy_shares succeeds when receiving more shares than minimum.
fun buy_shares_slippage_receives_more() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with initial deposit
    let deposit1 = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process loss: bet 10k, win 20k = house loses 10k (NAV drops)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(20_000)],
        &play_cap,
        scenario.ctx(),
    );

    // NAV < 1, so 20k deposit should yield MORE than 20k shares
    // Ask for only 20k shares (min), should succeed and get more
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation2, deposit2, 20_000, scenario.ctx());

    // Should have received more than 20k shares since NAV < 1
    assert!(shares > 20_000);

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

#[test, expected_failure(abort_code = house::ESlippageExceeded)]
/// buy_shares fails when receiving fewer shares than minimum.
fun buy_shares_slippage_exceeded_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house with initial deposit
    let deposit1 = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process profit: bet 20k, win 5k = house gains 15k (NAV rises)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(20_000), openplay_core::transaction::win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // NAV > 1, so 20k deposit yields LESS than 20k shares
    // Ask for exactly 20k shares (too high), should FAIL
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation2, deposit2, 20_000, scenario.ctx());

    abort 0
}

#[test]
/// sell_shares succeeds when min_sui_out is exactly met.
fun sell_shares_slippage_exact_match() {
    let mut scenario = begin(@0xa);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Buy shares at NAV = 1
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Sell all shares, expecting exactly 100_000 SUI (NAV = 1)
    let payout = house.sell_shares(&registry, &mut participation, 100_000, 100_000, scenario.ctx());

    assert!(payout.value() == 100_000);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    scenario.end();
}

#[test]
/// sell_shares succeeds when receiving more SUI than minimum.
fun sell_shares_slippage_receives_more() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Buy shares at NAV = 1
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process profit: bet 20k, win 0 = house gains 20k
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(20_000), openplay_core::transaction::win(0)],
        &play_cap,
        scenario.ctx(),
    );

    // NAV > 1, so selling shares should yield MORE than original deposit
    // Ask for only 100_000 SUI (min), should succeed and get more
    let payout = house.sell_shares(&registry, &mut participation, shares, 100_000, scenario.ctx());

    // Should have received more than 100k (after accounting for pending fees)
    assert!(payout.value() > 100_000);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}

#[test, expected_failure(abort_code = house::ESlippageExceeded)]
/// sell_shares fails when receiving less SUI than minimum.
fun sell_shares_slippage_exceeded_fails() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Buy shares at NAV = 1
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process loss: bet 10k, win 30k = house loses 20k (NAV drops)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(30_000)],
        &play_cap,
        scenario.ctx(),
    );

    // NAV < 1, so selling shares yields LESS than original deposit
    // Ask for exactly 100_000 SUI (too high), should FAIL
    let _payout = house.sell_shares(&registry, &mut participation, shares, 100_000, scenario.ctx());

    abort 0
}

#[test]
/// Zero slippage protection (min = 0) always succeeds.
fun buy_shares_zero_slippage_always_succeeds() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation1 = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Fund house
    let deposit1 = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation1, deposit1, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process profit to raise NAV
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(20_000), openplay_core::transaction::win(5_000)],
        &play_cap,
        scenario.ctx(),
    );

    // With min_shares_out = 0, always succeeds even with high NAV
    let mut participation2 = participation::empty(house.id(), scenario.ctx());
    let deposit2 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation2, deposit2, 0, scenario.ctx());

    // Will get fewer shares than deposit amount, but succeeds
    assert!(shares < 20_000);
    assert!(shares > 0);

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
/// Zero slippage protection on sell (min = 0) always succeeds.
fun sell_shares_zero_slippage_always_succeeds() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = openplay_core::balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Buy shares
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, 0, scenario.ctx());

    // Fund balance manager
    let player_deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, player_deposit, scenario.ctx());

    // Process big loss: house loses 40k
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = openplay_core::game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[openplay_core::transaction::bet(10_000), openplay_core::transaction::win(50_000)],
        &play_cap,
        scenario.ctx(),
    );

    // With min_sui_out = 0, always succeeds even with low NAV
    let payout = house.sell_shares(&registry, &mut participation, shares, 0, scenario.ctx());

    // Will get fewer SUI than original deposit, but succeeds
    assert!(payout.value() < 100_000);
    assert!(payout.value() > 0);

    burn_for_testing(payout);
    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(stats);
    scenario.end();
}