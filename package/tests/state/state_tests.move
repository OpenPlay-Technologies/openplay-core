#[test_only]
module openplay_core::house_state_tests;

use openplay_core::balance_manager;
use openplay_core::calculations::mul_ceil_bps;
use openplay_core::house_state;
use openplay_core::transaction::{bet, win};
use std::unit_test::destroy;
use sui::test_scenario::begin;

#[test]
public fun transactions_process_ok() {
    let addr = @0xa;
    let protocol_fee_bps = 50; // 0.5% = 50 bps
    let house_fee_bps = 2000; // 20% = 2000 bps
    let fee_collector_share_bps = 1000; // 10% = 1000 bps
    let mut scenario = begin(addr);

    // Initialize state and balance manager
    let house_id = object::id_from_address(@0x0);
    let mut state = house_state::new(house_id, protocol_fee_bps, house_fee_bps, fee_collector_share_bps, scenario.ctx());
    let (bm, bm_cap) = balance_manager::new(scenario.ctx());
    let fee_collector_id = object::id_from_address(@0xB);

    // Process transactions: total bet of 10 and win of 5
    let txs = vector[bet(10), bet(0), win(5), win(0)];
    let (credit_balance, debit_balance) = state.process_transactions(
        &txs,
        bm.id(),
        fee_collector_id,
        scenario.ctx(),
    );
    // Assert account balance
    assert!(credit_balance == 5);
    assert!(debit_balance == 10);
    // Assert volumes
    assert!(state.current_volumes().total_bet_amount() == 10);
    assert!(state.current_volumes().total_win_amount() == 5);
    assert!(state.all_time_bet_amount() == 10);
    assert!(state.all_time_win_amount() == 5);
    
    // Check collector GGR tracking
    let collector_ggr = state.current_collector_ggr(fee_collector_id);
    assert!(house_state::bet_amount(&collector_ggr) == 10);
    assert!(house_state::win_amount(&collector_ggr) == 5);

    destroy(bm);
    destroy(state);
    destroy(bm_cap);
    scenario.end();
}

#[test]
public fun shares_mint_burn_tests() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create state
    let house_id = object::id_from_address(@0x0);
    let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

    // Initially no shares
    assert!(state.total_shares() == 0);

    // Mint 10 shares
    state.mint_shares(10);
    assert!(state.total_shares() == 10);

    // Mint 10 more shares
    state.mint_shares(10);
    assert!(state.total_shares() == 20);

    // Burn 5 shares
    state.burn_shares(5);
    assert!(state.total_shares() == 15);

    // Burn remaining shares
    state.burn_shares(15);
    assert!(state.total_shares() == 0);

    destroy(state);
    scenario.end();
}

#[test, expected_failure(abort_code = house_state::ECannotUnstakeMoreThanStaked)]
public fun burn_too_many_shares() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    let house_id = object::id_from_address(@0x0);
    let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
    state.mint_shares(100);
    state.burn_shares(150); // Try to burn more than available

    abort 0
}

#[test]
public fun process_end_of_day_ok() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Create state
    let house_id = object::id_from_address(@0x0);
    let protocol_fee_bps = 50;
    let house_fee_bps = 2000;
    let fee_collector_share_bps = 1000;
    let mut state = house_state::new(house_id, protocol_fee_bps, house_fee_bps, fee_collector_share_bps, scenario.ctx());
    
    let fee_collector_id = object::id_from_address(@0xB);
    let (bm, bm_cap) = balance_manager::new(scenario.ctx());

    // Process some transactions to generate GGR
    let txs = vector[bet(10_000), win(5_000)];
    state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());
    
    // GGR = 10_000 - 5_000 = 5_000
    // Advance epoch
    scenario.next_epoch(addr);
    
    // Process end of day - fees calculated from GGR
    let (collector_fees, house_fee, protocol_fee) = state.process_end_of_day(
        scenario.ctx().epoch() - 1,
        house_fee_bps,
        fee_collector_share_bps,
        protocol_fee_bps,
        scenario.ctx(),
    );
    
    // Check fees are calculated from GGR
    let expected_collector_fee = mul_ceil_bps(5_000, fee_collector_share_bps);
    let expected_house_fee = mul_ceil_bps(5_000, house_fee_bps);
    let expected_protocol_fee = mul_ceil_bps(5_000, protocol_fee_bps);
    
    assert!(house_fee == expected_house_fee);
    assert!(protocol_fee == expected_protocol_fee);
    // Check collector fees
    assert!(vector::length(&collector_fees) == 1);
    let collector_fee = *vector::borrow(&collector_fees, 0);
    assert!(house_state::collector_id(&collector_fee) == fee_collector_id);
    assert!(house_state::fee_amount(&collector_fee) == expected_collector_fee);

    destroy(state);
    destroy(bm);
    destroy(bm_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = house_state::EEpochHasNotFinishedYet)]
public fun cannot_process_eod_before_epoch_ended() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let house_id = object::id_from_address(@0x0);
    let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
    // Try to process end of day for current epoch (should fail)
    state.process_end_of_day(
        scenario.ctx().epoch(),
        2000,
        1000,
        50,
        scenario.ctx(),
    );

    abort 0
}

#[test, expected_failure(abort_code = house_state::EEpochMismatch)]
public fun cannot_process_eod_for_wrong_epoch() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let house_id = object::id_from_address(@0x0);
    let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

    // Advance to epoch 2
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);

    // Process eod for epoch 1 (wrong epoch, should be 0)
    state.process_end_of_day(1, 2000, 1000, 50, scenario.ctx());

    abort 0
}

#[test]
public fun collector_ggr_tracking_ok() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let house_id = object::id_from_address(@0x0);
    let protocol_fee_bps = 50;
    let house_fee_bps = 2000;
    let fee_collector_share_bps = 1000;
    let mut state = house_state::new(house_id, protocol_fee_bps, house_fee_bps, fee_collector_share_bps, scenario.ctx());
    
    let fee_collector_id1 = object::id_from_address(@0xB);
    let fee_collector_id2 = object::id_from_address(@0xC);
    let (bm, bm_cap) = balance_manager::new(scenario.ctx());

    // Process transactions for first collector
    let txs1 = vector[bet(10_000), win(5_000)];
    state.process_transactions(&txs1, bm.id(), fee_collector_id1, scenario.ctx());
    
    // Check collector GGR
    let ggr1 = state.current_collector_ggr(fee_collector_id1);
    assert!(house_state::bet_amount(&ggr1) == 10_000);
    assert!(house_state::win_amount(&ggr1) == 5_000);
    
    // Process transactions for second collector
    let txs2 = vector[bet(20_000), win(15_000)];
    state.process_transactions(&txs2, bm.id(), fee_collector_id2, scenario.ctx());
    
    // Check second collector GGR
    let ggr2 = state.current_collector_ggr(fee_collector_id2);
    assert!(house_state::bet_amount(&ggr2) == 20_000);
    assert!(house_state::win_amount(&ggr2) == 15_000);
    
    // First collector GGR should still be there
    let ggr1_again = state.current_collector_ggr(fee_collector_id1);
    assert!(house_state::bet_amount(&ggr1_again) == 10_000);
    assert!(house_state::win_amount(&ggr1_again) == 5_000);

    destroy(state);
    destroy(bm);
    destroy(bm_cap);
    scenario.end();
}

#[test]
public fun process_end_of_day_collector_fees() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let house_id = object::id_from_address(@0x0);
    let protocol_fee_bps = 50;
    let house_fee_bps = 2000;
    let fee_collector_share_bps = 1000;
    let mut state = house_state::new(house_id, protocol_fee_bps, house_fee_bps, fee_collector_share_bps, scenario.ctx());
    
    let fee_collector_id1 = object::id_from_address(@0xB);
    let fee_collector_id2 = object::id_from_address(@0xC);
    let (bm, bm_cap) = balance_manager::new(scenario.ctx());

    // Process transactions for first collector: GGR = 5k
    let txs1 = vector[bet(10_000), win(5_000)];
    state.process_transactions(&txs1, bm.id(), fee_collector_id1, scenario.ctx());
    
    // Process transactions for second collector: GGR = 5k
    let txs2 = vector[bet(20_000), win(15_000)];
    state.process_transactions(&txs2, bm.id(), fee_collector_id2, scenario.ctx());
    
    // Advance epoch
    scenario.next_epoch(addr);
    
    // Process end of day - fees calculated from GGR
    let (collector_fees, house_fee, protocol_fee) = state.process_end_of_day(
        scenario.ctx().epoch() - 1,
        house_fee_bps,
        fee_collector_share_bps,
        protocol_fee_bps,
        scenario.ctx(),
    );
    
    // Total GGR = 5k + 5k = 10k
    let total_ggr = 10_000;
    let expected_house_fee = mul_ceil_bps(total_ggr, house_fee_bps);
    let expected_protocol_fee = mul_ceil_bps(total_ggr, protocol_fee_bps);
    
    assert!(house_fee == expected_house_fee);
    assert!(protocol_fee == expected_protocol_fee);
    
    // Check collector fees
    assert!(vector::length(&collector_fees) == 2);
    
    // Each collector should have fee from their GGR (5k each)
    let expected_collector_fee = mul_ceil_bps(5_000, fee_collector_share_bps);
    let mut found1 = false;
    let mut found2 = false;
    let mut i = 0;
    while (i < vector::length(&collector_fees)) {
        let fee = *vector::borrow(&collector_fees, i);
        if (house_state::collector_id(&fee) == fee_collector_id1) {
            assert!(house_state::fee_amount(&fee) == expected_collector_fee);
            found1 = true;
        };
        if (house_state::collector_id(&fee) == fee_collector_id2) {
            assert!(house_state::fee_amount(&fee) == expected_collector_fee);
            found2 = true;
        };
        i = i + 1;
    };
    assert!(found1);
    assert!(found2);

    destroy(state);
    destroy(bm);
    destroy(bm_cap);
    scenario.end();
}
