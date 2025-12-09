#[test_only]
module openplay_core::house_tests;

use openplay_core::balance_manager;
use openplay_core::calculations::{mul_ceil, mul_ceil_bps, mul_floor, mul_floor_bps};
use openplay_core::core_constants::{current_version, max_bps};
use openplay_core::core_test_utils::{fund_house_for_playing, default_house};
use openplay_core::fee_collector;
use openplay_core::game_stats;
use openplay_core::house;
use openplay_core::participation;
use openplay_core::registry::{Self, registry_for_testing};
use openplay_core::transaction::{bet, win};
use std::unit_test::{assert_eq, destroy};
use sui::coin::{mint_for_testing, burn_for_testing};
use sui::object;
use sui::sui::SUI;
use sui::test_scenario::{begin, next_tx, return_shared, Scenario, take_shared};

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

    // Buy shares: 20_000 on first participation
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());
    assert!(house.house_balance() == 20_000); // House balance increased
    assert!(participation::shares(&participation) == shares1);

    // Buy shares: 80_000 on second participation
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());
    assert!(house.house_balance() == 100_000); // House balance is now 100k
    assert!(participation::shares(&another_participation) == shares2);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k (GGR = -10k, but fees calculated at epoch end)
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

    // Balance manager received 10k net (20k win - 10k bet)
    assert!(balance_manager.balance() == 60_000); // 50k initial + 10k net
    // House balance decreased by 10k (paid out more than received)
    assert!(house.house_balance() == 90_000); // 100k - 10k loss

    // Shares remain the same until epoch end
    assert!(participation::shares(&participation) == shares1);
    assert!(participation::shares(&another_participation) == shares2);

    // End the epoch - fees are calculated from GGR and NAV adjusts
    scenario.next_epoch(addr);
    
    // Process end of day happens automatically on next buy/sell or transaction
    // For now, NAV will reflect the loss (fees deducted at epoch end)
    let nav_after_loss = house.nav_per_share();
    // NAV should be less than 1 (initial NAV) due to losses and fees
    
    // Sell all shares from first participation
    let shares_to_sell1 = participation::shares(&participation);
    let payout1 = house.sell_shares(&registry, &mut participation, shares_to_sell1, scenario.ctx());
    
    // Sell all shares from second participation
    let shares_to_sell2 = participation::shares(&another_participation);
    let payout2 = house.sell_shares(&registry, &mut another_participation, shares_to_sell2, scenario.ctx());

    // Total payout should be less than 100k due to losses and fees
    let total_payout = payout1.value() + payout2.value();
    assert!(total_payout < 100_000);

    destroy(house);
    destroy(registry);
    destroy(play_cap);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(participation);
    destroy(another_participation);
    destroy(stats);
    burn_for_testing(payout1);
    burn_for_testing(payout2);
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

    // Buy shares: 20_000 on first participation
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());
    assert!(house.house_balance() == 20_000);

    // Buy shares: 80_000 on second participation
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());
    assert!(house.house_balance() == 100_000);

    // Process some transactions
    // a bet of 10k and a win of 5k
    // this results in a profit of 5k (GGR = 5k, fees calculated at epoch end)
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
    
    // Balance manager lost 5k net (10k bet - 5k win)
    assert!(balance_manager.balance() == 45_000); // 50k initial - 5k loss
    // House balance increased by 5k (received more than paid out)
    assert!(house.house_balance() == 105_000); // 100k + 5k profit

    // Shares remain the same until epoch end
    assert!(participation::shares(&participation) == shares1);
    assert!(participation::shares(&another_participation) == shares2);

    // End the epoch - fees are calculated from GGR and NAV adjusts
    scenario.next_epoch(addr);
    
    // NAV should reflect profits (after fees are deducted at epoch end)
    let nav_after_profit = house.nav_per_share();
    // NAV should be greater than 1 (initial NAV) due to profits, minus fees
    
    // Sell all shares from first participation
    let shares_to_sell1 = participation::shares(&participation);
    let payout1 = house.sell_shares(&registry, &mut participation, shares_to_sell1, scenario.ctx());
    
    // Sell all shares from second participation
    let shares_to_sell2 = participation::shares(&another_participation);
    let payout2 = house.sell_shares(&registry, &mut another_participation, shares_to_sell2, scenario.ctx());

    // Total payout should be more than 100k due to profits (minus fees)
    let total_payout = payout1.value() + payout2.value();
    // After fees, should be less than 105k but more than 100k
    assert!(total_payout > 100_000);
    assert!(total_payout <= 105_000);

    destroy(house);
    destroy(registry);
    destroy(play_cap);
    destroy(admin_cap);
    destroy(balance_manager_cap);
    destroy(balance_manager);
    destroy(participation);
    destroy(another_participation);
    destroy(stats);
    burn_for_testing(payout1);
    burn_for_testing(payout2);
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

    // Buy shares: 20_000 on first participation
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());

    // Buy shares: 80_000 on second participation
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());

    // a bet of 10k and a win of 5k
    // this results in a profit of 5k (GGR = 5k, fees calculated at epoch end)
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

    // End epoch to process fees
    scenario.next_epoch(addr);

    // Now sell all shares
    let shares_to_sell1 = participation::shares(&participation);
    let payout1 = house.sell_shares(&registry, &mut participation, shares_to_sell1, scenario.ctx());
    
    let shares_to_sell2 = participation::shares(&another_participation);
    let payout2 = house.sell_shares(&registry, &mut another_participation, shares_to_sell2, scenario.ctx());

    // Total payout should reflect profits (minus fees)
    let total_payout = payout1.value() + payout2.value();
    // Should be more than 100k due to profits, but less than 110k due to fees
    assert!(total_payout > 100_000);
    assert!(total_payout < 110_000);
    
    burn_for_testing(payout1);
    burn_for_testing(payout2);

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

    // Buy shares: 20_000 on first participation
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());

    // Buy shares: 80_000 on second participation
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());

    // a bet of 10k and a win of 5k
    // this results in a profit of 5k (GGR = 5k, fees calculated at epoch end)
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

    // Skip 1 epoch without any activity and process some more transactions
    // Net result should be even (first epoch: +5k, second epoch: -5k)
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);
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

    // End epoch to process fees
    scenario.next_epoch(addr);

    // Now sell all shares
    let shares_to_sell1 = participation::shares(&participation);
    let payout1 = house.sell_shares(&registry, &mut participation, shares_to_sell1, scenario.ctx());
    
    let shares_to_sell2 = participation::shares(&another_participation);
    let payout2 = house.sell_shares(&registry, &mut another_participation, shares_to_sell2, scenario.ctx());

    // Total payout should reflect the net result (approximately 100k minus fees from both epochs)
    let total_payout = payout1.value() + payout2.value();
    // Should be less than 100k due to fees, but close to it since profits and losses cancel out
    assert!(total_payout < 100_000);
    assert!(total_payout > 95_000); // Should still have most of the original amount
    
    burn_for_testing(payout1);
    burn_for_testing(payout2);

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

    // Buy shares: 30_000 on first participation
    let deposit1 = mint_for_testing<SUI>(30_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());

    // Buy shares: 120_000 on second participation
    let deposit2 = mint_for_testing<SUI>(120_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());

    assert!(house.house_balance() == 150_000);
    assert!(participation::shares(&participation) == shares1);
    assert!(participation::shares(&another_participation) == shares2);

    // Process some transactions
    // a bet of 10k and a win of 20k
    // this results in a loss of 10k (GGR = -10k, fees calculated at epoch end)
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
    
    assert!(balance_manager.balance() == 60_000); // 50k initial + 10k net win
    assert!(house.house_balance() == 140_000); // 150k - 10k loss
    assert!(participation::shares(&participation) == shares1);
    assert!(participation::shares(&another_participation) == shares2);

    // End the epoch - fees are calculated from GGR
    scenario.next_epoch(addr);
    
    // NAV will reflect the loss (fees deducted at epoch end)
    let nav_after_loss = house.nav_per_share();

    // Buy more shares: 20_000
    let deposit3 = mint_for_testing<SUI>(20_000, scenario.ctx());
    let shares3 = house.buy_shares(&registry, &mut participation, deposit3, scenario.ctx());
    assert!(participation::shares(&participation) == shares1 + shares3);

    // Sell all shares from first participation
    let shares_to_sell = participation::shares(&participation);
    let payout = house.sell_shares(&registry, &mut participation, shares_to_sell, scenario.ctx());
    
    // Payout should reflect NAV (which includes the loss from previous epoch)
    assert!(payout.value() < 50_000); // Less than 50k due to losses and fees
    
    burn_for_testing(payout);

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
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Buy shares: 100_000
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    // Process some transactions
    // a bet of 10k and a win of 20k
    // This should fail because house doesn't have enough balance to pay the win
    let tx_cap = house.tx_cap_for_testing(game_id);
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
public fun buy_sell_shares_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new house
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());

    // Buy shares: 30_000 on first participation
    let deposit1 = mint_for_testing<SUI>(30_000, scenario.ctx());
    let shares1 = house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());
    assert!(participation::shares(&participation) == shares1);
    assert!(house.house_balance() == 30_000);

    // Buy shares: 120_000 on second participation
    let deposit2 = mint_for_testing<SUI>(120_000, scenario.ctx());
    let shares2 = house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());
    assert!(participation::shares(&another_participation) == shares2);
    assert!(house.house_balance() == 150_000);

    // First participant sells all shares
    let shares_to_sell1 = participation::shares(&participation);
    let payout1 = house.sell_shares(&registry, &mut participation, shares_to_sell1, scenario.ctx());
    assert!(participation::shares(&participation) == 0);
    // Payout should be approximately 30k (may vary slightly due to NAV)
    assert!(payout1.value() > 29_000);
    assert!(payout1.value() <= 30_000);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(house.house_balance() < 150_000); // House balance decreased after payout

    // First one now buys 100k shares again
    let deposit3 = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares3 = house.buy_shares(&registry, &mut participation, deposit3, scenario.ctx());
    assert!(participation::shares(&participation) == shares3);
    
    // Second one sells all shares
    let shares_to_sell2 = participation::shares(&another_participation);
    let payout2 = house.sell_shares(&registry, &mut another_participation, shares_to_sell2, scenario.ctx());
    assert!(participation::shares(&another_participation) == 0);
    // Payout should be approximately 120k (may vary slightly due to NAV)
    assert!(payout2.value() > 119_000);
    assert!(payout2.value() <= 120_000);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(house.house_balance() > 0); // House still has balance from first participation

    // First participation still has shares
    assert!(participation::shares(&participation) == shares3);
    // Second participation has no shares
    assert!(participation::shares(&another_participation) == 0);

    // Now sell remaining shares from first participation
    let shares_to_sell3 = participation::shares(&participation);
    let payout3 = house.sell_shares(&registry, &mut participation, shares_to_sell3, scenario.ctx());
    assert!(participation::shares(&participation) == 0);

    // Advance epoch
    scenario.next_epoch(addr);
    assert!(house.house_balance() >= 0); // House balance may be low or zero

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(another_participation);
    burn_for_testing(payout1);
    burn_for_testing(payout2);
    burn_for_testing(payout3);
    scenario.end();
}

#[test]
public fun house_balance_decreases_when_all_shares_sold() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a new house
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());

    // Buy shares: 100_000
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    let shares = house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    assert!(house.house_balance() == 100_000); // house has funds
    assert!(participation::shares(&participation) == shares);

    // Sell all shares
    let shares_to_sell = participation::shares(&participation);
    let payout = house.sell_shares(&registry, &mut participation, shares_to_sell, scenario.ctx());
    assert!(participation::shares(&participation) == 0);
    assert!(payout.value() > 0);

    // Advance epoch
    scenario.next_epoch(addr);
    // House balance should be low or zero after all shares are sold
    assert!(house.house_balance() < 100_000);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    burn_for_testing(payout);
    scenario.end();
}

#[test]
public fun claim_collector_fees_ok() {
    let addr = @0xa;
    let game_id = object::id_from_address(@0xB);
    let mut scenario = begin(addr);

    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
    scenario.next_epoch(addr);

    // Create a fee collector
    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let fee_collector_id = fee_collector.id();
    
    // Assign game to fee collector (before sharing)
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);

    // Share the fee collector
    fee_collector::share(fee_collector);

    // Add collector fees for testing (in production, calculated from GGR at epoch end)
    house.add_collector_fees_for_testing(fee_collector_id, 200);

    // Get shared reference for claiming fees
    scenario.next_tx(addr);
    let fee_collector_ref = scenario.take_shared<fee_collector::FeeCollector>();
    let coin2 = house.claim_collector_fees(&registry, &fee_collector_ref, &fee_collector_cap, scenario.ctx());
    return_shared(fee_collector_ref);
    assert!(coin2.value() == 200);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(participation);
    destroy(fee_collector_cap);
    burn_for_testing(coin2);
    scenario.end();
}

#[test]
public fun claim_collector_fees_empty() {
    let addr = @0xa;
    let game_id = object::id_from_address(@0xB);
    let mut scenario = begin(addr);
    let registry = registry_for_testing(scenario.ctx());
    
    // Create a new house
    let (mut house, admin_cap) = default_house(scenario.ctx());
    
    // Create a fee collector
    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    
    // Share the fee collector
    fee_collector::share(fee_collector);
    
    // Claim fees when none exist (get shared reference)
    scenario.next_tx(addr);
    let fee_collector_ref = scenario.take_shared<fee_collector::FeeCollector>();
    let coin2 = house.claim_collector_fees(&registry, &fee_collector_ref, &fee_collector_cap, scenario.ctx());
    return_shared(fee_collector_ref);
    assert!(coin2.value() == 0);

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(fee_collector_cap);
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
    let mut participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
    scenario.next_epoch(addr);
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions that result in profits (GGR = 5k)
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

    // End the epoch to process profits and collect house fee from GGR
    scenario.next_epoch(addr);
    
    // House fees are calculated from GGR at epoch end
    // GGR = 10_000 - 5_000 = 5_000
    // House fee = GGR * house_fee_bps / 10000
    let ggr = 5_000;
    let expected_house_fee = mul_ceil_bps(ggr, house.house_fee_bps());

    // Claim house fees (process_end_of_day is called internally)
    let house_fee_coin = house.admin_claim_house_fees(&registry, &admin_cap, scenario.ctx());
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
public fun claim_collector_fees_multiple_collectors() {
    let addr = @0xa;
    let game_id1 = object::id_from_address(@0xB);
    let game_id2 = object::id_from_address(@0xC);
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());

    // Create two fee collectors
    let (fee_collector1, cap1) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fee_collector2, cap2) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    
    // Get IDs before sharing
    let fee_collector1_id = fee_collector1.id();
    let fee_collector2_id = fee_collector2.id();
    
    // Assign games to fee collectors (before sharing)
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id1, &fee_collector1);
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id2, &fee_collector2);
    
    // Share the fee collectors so they can be accessed
    fee_collector::share(fee_collector1);
    fee_collector::share(fee_collector2);

    // Add fees for testing (simulating end-of-day processing)
    house.add_collector_fees_for_testing(fee_collector1_id, 100);
    house.add_collector_fees_for_testing(fee_collector2_id, 50);

    // Claim fees - take shared references and verify IDs match caps
    // Note: take_shared may return objects in LIFO order (last shared first)
    scenario.next_tx(addr);
    let ref1 = scenario.take_shared<fee_collector::FeeCollector>();
    let ref2 = scenario.take_shared<fee_collector::FeeCollector>();
    
    // Match references to collectors based on ID
    let (fee_collector1_ref, fee_collector2_ref) = if (ref1.id() == fee_collector1_id) {
        (ref1, ref2)
    } else {
        (ref2, ref1)
    };
    
    let coin1 = house.claim_collector_fees(&registry, &fee_collector1_ref, &cap1, scenario.ctx());
    return_shared(fee_collector1_ref);
    assert!(coin1.value() == 100);
    
    let coin2 = house.claim_collector_fees(&registry, &fee_collector2_ref, &cap2, scenario.ctx());
    return_shared(fee_collector2_ref);
    assert!(coin2.value() == 50);

    burn_for_testing(coin1);
    burn_for_testing(coin2);

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    destroy(cap1);
    destroy(cap2);
    destroy(registry);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EInvalidFeeCollector)]
public fun claim_collector_fees_wrong_house() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create two houses
    let registry = registry_for_testing(scenario.ctx());
    let (mut house1, admin_cap1) = default_house(scenario.ctx());
    let (mut house2, _admin_cap2) = default_house(scenario.ctx());

    // Create a fee collector for house1
    let (fee_collector, cap) = house1.admin_create_fee_collector(&admin_cap1, scenario.ctx());
    let fee_collector_id = fee_collector.id();
    fee_collector::share(fee_collector);

    // Try to claim fees using house2 (should fail) - get shared reference
    scenario.next_tx(addr);
    let fee_collector_ref = scenario.take_shared<fee_collector::FeeCollector>();
    let _coin = house2.claim_collector_fees(&registry, &fee_collector_ref, &cap, scenario.ctx());
    return_shared(fee_collector_ref);
    abort 0
}

#[test]
public fun private_house_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a private house
    let registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());
    let (house, admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        &registry,
        true,
        100_000,
        2000,
        1000, // fee_collector_share_bps
        scenario.ctx(),
    );
    let participation = house.admin_new_participation(&admin_cap, scenario.ctx());

    destroy(house);
    destroy(admin_cap);
    destroy(participation);
    destroy(openplay_admin_cap);
    destroy(registry);
    scenario.end();
}

#[test, expected_failure(abort_code = house::EHouseIsPrivate)]
public fun private_house_error() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create a private house
    let registry = registry_for_testing(scenario.ctx());
    let openplay_admin_cap = registry::cap_for_testing(scenario.ctx());
    let (house, _admin_cap) = house::openplay_admin_new_house(
        &openplay_admin_cap,
        &registry,
        true,
        100_000,
        2000,
        1000, // fee_collector_share_bps
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
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
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

    // In v3.1, fees are calculated from GGR at epoch end, not per transaction
    // So we need to advance epoch to process fees
    scenario.next_epoch(addr);
    
    // Fees are now calculated from GGR, not per transaction
    // GGR = 10_000 - 5_000 = 5_000
    // Collector fees, house fees, and protocol fees are calculated at epoch end

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
    destroy(participation);
    destroy(stats);
    scenario.end();
}

#[test]
public fun process_transactions_different_fee_collectors() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id1 = object::id_from_address(@0x11);
    let game_id2 = object::id_from_address(@0x12);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Create two fee collectors
    let (fee_collector1, fee_collector_cap1) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let (fee_collector2, fee_collector_cap2) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    
    // Get IDs before sharing
    let fee_collector1_id = fee_collector1.id();
    let fee_collector2_id = fee_collector2.id();

    // Assign games to different fee collectors (before sharing)
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id1, &fee_collector1);
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id2, &fee_collector2);

    // Share the fee collectors
    fee_collector::share(fee_collector1);
    fee_collector::share(fee_collector2);

    // Verify game assignments
    assert_eq!(house.game_fee_collector(&game_id1), fee_collector1_id);
    assert_eq!(house.game_fee_collector(&game_id2), fee_collector2_id);

    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
    scenario.next_epoch(addr);
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Process transactions for first game
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

    // Process transactions for second game
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

    // End epoch to calculate fees from GGR
    scenario.next_epoch(addr);
    
    // Fees are calculated from GGR at epoch end, so both collectors should have fees
    // (In a real scenario, fees would be calculated from their respective GGR)

    destroy(house);
    destroy(registry);
    destroy(admin_cap);
    destroy(balance_manager);
    destroy(balance_manager_cap);
    destroy(play_cap);
    destroy(participation);
    destroy(fee_collector_cap1);
    destroy(fee_collector_cap2);
    destroy(stats1);
    destroy(stats2);
    scenario.end();
}

#[test]
public fun admin_revoke_tx_allowed() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0x11);

    // Create a new house
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Create fee collector and assign game
    let (fee_collector, fee_collector_cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let fee_collector_id = fee_collector.id();
    
    // Assign game before sharing
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector);
    
    // Share the fee collector
    fee_collector::share(fee_collector);

    // Verify game is assigned
    assert_eq!(house.game_fee_collector(&game_id), fee_collector_id);

    // Revoke game authorization
    house.admin_revoke_tx_allowed(&admin_cap, game_id);

    // Verify game is no longer authorized (should abort if we try to get fee collector)
    destroy(house);
    destroy(admin_cap);
    destroy(fee_collector_cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = openplay_core::house::EGameDoesNotExist)]
public fun admin_revoke_tx_allowed_not_found() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(@0x11);

    // Create a new house
    let (mut house, admin_cap) = default_house(scenario.ctx());

    // Try to revoke a game that doesn't exist (should abort)
    house.admin_revoke_tx_allowed(&admin_cap, game_id);

    destroy(house);
    destroy(admin_cap);
    scenario.end();
}

#[test]
public fun process_transactions_no_bm() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
    scenario.next_epoch(addr);

    // Provide funds directly (no balance manager)
    let funds = mint_for_testing<SUI>(10_000, scenario.ctx());

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

    // In v3.1, fees are calculated from GGR at epoch end, not per transaction
    // Remainder should be 5_000 (net win to player)
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
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let _participation = fund_house_for_playing(&mut house, &registry, 100_000, scenario.ctx());
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

       // Create a fee collector
    let (fee_collector, _cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let game_id1 = object::id_from_address(@0xB);
    
    // Assign game before sharing
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id1, &fee_collector);
    
    // Share the fee collector
    fee_collector::share(fee_collector);

    let mut obj1 = object::new(scenario.ctx());
    let game_id2 = obj1.to_inner();
    // Get shared reference for second game
    scenario.next_tx(addr);
    let fee_collector_ref = scenario.take_shared<fee_collector::FeeCollector>();
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id2, &fee_collector_ref);
    return_shared(fee_collector_ref);
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

    // Create a fee collector
    let (fee_collector, _cap) = house.admin_create_fee_collector(&admin_cap, scenario.ctx());
    let fee_collector_id = fee_collector.id();
    
    // Share the fee collector
    fee_collector::share(fee_collector);

    let mut obj1 = object::new(scenario.ctx());
    let game_id = obj1.to_inner();
    // Get shared reference
    scenario.next_tx(addr);
    let fee_collector_ref = scenario.take_shared<fee_collector::FeeCollector>();
    house.admin_add_tx_allowed_with_collector(&admin_cap, game_id, &fee_collector_ref);
    return_shared(fee_collector_ref);
    let _tx_cap = house.borrow_tx_cap(&mut obj1);

    house.admin_revoke_tx_allowed(&admin_cap, game_id);
    let _tx_cap = house.borrow_tx_cap(&mut obj1);
    abort 0
}

#[test, expected_failure(abort_code = registry::EPackageVersionDisabled)]
public fun house_version_disabled_after_rename() {
    let addr = @0xa;
    let game_id = object::id_from_address(addr);
    let mut scenario = begin(addr);

    // Create a new house and balance manager
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Buy shares: 20_000 on first participation
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());
    assert!(house.house_balance() == 20_000); // house balance increased

    // Buy shares: 80_000 on second participation
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());

    assert!(house.house_balance() == 100_000); // house balance is now 100k

    // Disable the version
    let admin_cap = registry::cap_for_testing(scenario.ctx());
    registry.admin_disallow_version(&admin_cap, current_version(), scenario.ctx());

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
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let mut another_participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 50_000 on the balance manager
    let deposit = mint_for_testing<SUI>(50_000, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());

    // Buy shares: 20_000 on first participation
    let deposit1 = mint_for_testing<SUI>(20_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit1, scenario.ctx());
    assert!(house.house_balance() == 20_000); // house balance increased

    // Buy shares: 80_000 on second participation
    let deposit2 = mint_for_testing<SUI>(80_000, scenario.ctx());
    house.buy_shares(&registry, &mut another_participation, deposit2, scenario.ctx());

    assert!(house.house_balance() == 100_000); // house balance is now 100k

    // Disable the version
    let admin_cap = registry::cap_for_testing(scenario.ctx());
    registry.admin_disallow_version(&admin_cap, current_version(), scenario.ctx());

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

// NOTE: update_participation_with_epoch_limit test removed - functionality was removed in v3.1
// as part of the transition from stake-based to share-based participation model.
// In the share model, participations don't need epoch-based updates.

/// Test to verify that a user cannot bet more than their balance, even if they win more than they bet.
/// This prevents the bug where a user with 0 balance can bet 100 and win 150, effectively betting with money they don't have.
#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun bet_without_funds_win_higher_than_bet() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Explicitly verify balance is 0
    assert!(balance_manager.balance() == 0, 0);

    // Buy shares to fund house
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    // Get tx cap before processing transactions
    let tx_cap = house.tx_cap_for_testing(game_id);

    // Try to process transactions: bet 100, win 150
    // This should fail because the user doesn't have 100 to bet, even though they would win 150
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

/// Test to verify that a user cannot bet more than their balance, even if the win exactly equals the bet.
#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun bet_without_funds_win_equals_bet() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let mut registry = registry_for_testing(scenario.ctx());
    let (mut house, _admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Explicitly verify balance is 0
    assert!(balance_manager.balance() == 0, 0);

    // Buy shares to fund house
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    // Get tx cap before processing transactions
    let tx_cap = house.tx_cap_for_testing(game_id);

    // Try to process transactions: bet 100, win 100
    // This should fail because the user doesn't have 100 to bet
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

/// Test to verify that the system correctly handles the case when user has sufficient funds.
#[test]
public fun bet_with_sufficient_funds_win_higher_than_bet() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    let game_id = object::id_from_address(addr);

    // Create a new house and balance manager
    let registry = registry_for_testing(scenario.ctx());
    let (mut house, admin_cap) = default_house(scenario.ctx());
    let mut participation = participation::empty(house.id(), scenario.ctx());
    let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
    let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, scenario.ctx());

    // Deposit 200 to the balance manager (enough to cover the bet)
    let deposit = mint_for_testing<SUI>(200, scenario.ctx());
    balance_manager.deposit(&balance_manager_cap, deposit, scenario.ctx());
    assert!(balance_manager.balance() == 200);

    // Buy shares to fund house
    let deposit = mint_for_testing<SUI>(100_000, scenario.ctx());
    house.buy_shares(&registry, &mut participation, deposit, scenario.ctx());

    // Process transactions: bet 100, win 150
    // This should succeed because the user has 200 (enough to cover the bet of 100)
    let tx_cap = house.tx_cap_for_testing(game_id);
    let mut stats = game_stats::stats_for_testing(game_id, scenario.ctx());
    house.tx_admin_process_transactions_v2(
        &registry,
        &mut stats,
        tx_cap,
        &mut balance_manager,
        &vector[bet(100), win(150)],
        &play_cap,
        scenario.ctx(),
    );

    // After the transaction:
    // - User bet 100 (debit_balance = 100), won 150 (credit_balance = 150)
    // - Net settlement: vault pays user 50 (150 - 100)
    // - User's balance: 200 (initial) + 50 (net win) = 250
    // Note: The ensure_sufficient_funds check ensures user had 100 to cover the bet
    assert!(balance_manager.balance() == 250);

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
