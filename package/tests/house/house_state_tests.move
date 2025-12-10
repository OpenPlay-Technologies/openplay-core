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
    let mut state = house_state::new(
        house_id,
        protocol_fee_bps,
        house_fee_bps,
        fee_collector_share_bps,
        scenario.ctx(),
    );
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
    let mut state = house_state::new(
        house_id,
        protocol_fee_bps,
        house_fee_bps,
        fee_collector_share_bps,
        scenario.ctx(),
    );

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
    let mut state = house_state::new(
        house_id,
        protocol_fee_bps,
        house_fee_bps,
        fee_collector_share_bps,
        scenario.ctx(),
    );

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
    let mut state = house_state::new(
        house_id,
        protocol_fee_bps,
        house_fee_bps,
        fee_collector_share_bps,
        scenario.ctx(),
    );

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
    assert!(vector::length(&collector_fees) == 2);
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

#[test]
public fun test_volume_for_epoch() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions in epoch 0
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch
        scenario.next_epoch(addr);

        // Process end of day for epoch 0
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Get volume for epoch 0
        let volumes = state.volume_for_epoch(0);
        assert!(house_state::total_bet_amount(&volumes) == 10_000, 0);
        assert!(house_state::total_win_amount(&volumes) == 5_000, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = house_state::EVolumeNotAvailable)]
public fun test_volume_for_epoch_not_found() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // Try to get volume for non-existent epoch
        let _volumes = state.volume_for_epoch(999);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_all_time_profits_and_losses() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process profitable transactions: GGR = 5k
        let txs1 = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs1, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch and process
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Process loss transactions: GGR = -5k (loss)
        let txs2 = vector[bet(10_000), win(15_000)];
        state.process_transactions(&txs2, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch and process
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Check all-time stats
        assert!(state.all_time_profits() == 5_000, 0);
        assert!(state.all_time_losses() == 5_000, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_total_bet_amount_and_total_win_amount() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        let volumes = state.current_volumes();
        assert!(house_state::total_bet_amount(&volumes) == 10_000, 0);
        assert!(house_state::total_win_amount(&volumes) == 5_000, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_historic_collector_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Get historic collector GGR for epoch 0
        let historic_ggr = state.historic_collector_ggr(0, fee_collector_id);
        assert!(house_state::bet_amount(&historic_ggr) == 10_000, 0);
        assert!(house_state::win_amount(&historic_ggr) == 5_000, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_historic_collector_ggr_nonexistent_epoch() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Get historic GGR for non-existent epoch - should return empty
        let historic_ggr = state.historic_collector_ggr(999, fee_collector_id);
        assert!(house_state::bet_amount(&historic_ggr) == 0, 0);
        assert!(house_state::win_amount(&historic_ggr) == 0, 1);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_historic_collector_ggr_nonexistent_collector() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id1 = object::id_from_address(@0xB);
        let fee_collector_id2 = object::id_from_address(@0xC);

        // Process transactions for collector 1
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id1, scenario.ctx());

        // Advance epoch and process
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Get historic GGR for non-existent collector - should return empty
        let historic_ggr = state.historic_collector_ggr(0, fee_collector_id2);
        assert!(house_state::bet_amount(&historic_ggr) == 0, 0);
        assert!(house_state::win_amount(&historic_ggr) == 0, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_collector_fees() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id1 = object::id_from_address(@0xB);
        let fee_collector_id2 = object::id_from_address(@0xC);

        // Process transactions for two collectors
        // Collector 1: GGR = 5k
        let txs1 = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs1, bm.id(), fee_collector_id1, scenario.ctx());

        // Collector 2: GGR = 3k
        let txs2 = vector[bet(8_000), win(5_000)];
        state.process_transactions(&txs2, bm.id(), fee_collector_id2, scenario.ctx());

        // Calculate pending collector fees
        // fee_collector_share_bps = 1000 (10%)
        // Collector 1: 5k * 10% = 500 (rounded up)
        // Collector 2: 3k * 10% = 300 (rounded up)
        // Total: 800
        let pending_fees = state.calculate_pending_collector_fees();
        let expected_fee1 = mul_ceil_bps(5_000, 1000); // Collector 1: 5k * 10%
        let expected_fee2 = mul_ceil_bps(3_000, 1000); // Collector 2: 3k * 10%
        assert!(pending_fees == expected_fee1 + expected_fee2, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_collector_fees_no_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // No transactions, so no GGR
        let pending_fees = state.calculate_pending_collector_fees();
        assert!(pending_fees == 0, 0);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_house_fees() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Calculate pending house fees
        // house_fee_bps = 2000 (20%)
        // GGR = 5k
        // Fee = 5k * 20% = 1000 (rounded up)
        let pending_fees = state.calculate_pending_house_fees();
        let expected_fee = mul_ceil_bps(5_000, 2000); // GGR = 5k * 20% = 1000 (rounded up)
        assert!(pending_fees == expected_fee, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_house_fees_no_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // No transactions, so no GGR
        let pending_fees = state.calculate_pending_house_fees();
        assert!(pending_fees == 0, 0);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_house_fees_zero_fee_bps() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 0, 1000, scenario.ctx()); // house_fee_bps = 0
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // With zero house fee, should return 0
        let pending_fees = state.calculate_pending_house_fees();
        assert!(pending_fees == 0, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_protocol_fees() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx()); // protocol_fee_bps = 50 (0.5%)
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Calculate pending protocol fees
        // protocol_fee_bps = 50 (0.5%)
        // GGR = 5k
        // Fee = 5k * 0.5% = 25 (rounded up)
        let pending_fees = state.calculate_pending_protocol_fees();
        let expected_fee = mul_ceil_bps(5_000, 50); // GGR = 5k * 0.5% = 25 (rounded up)
        assert!(pending_fees == expected_fee, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_protocol_fees_no_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // No transactions, so no GGR
        let pending_fees = state.calculate_pending_protocol_fees();
        assert!(pending_fees == 0, 0);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_calculate_pending_protocol_fees_zero_fee_bps() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 0, 2000, 1000, scenario.ctx()); // protocol_fee_bps = 0
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // With zero protocol fee, should return 0
        let pending_fees = state.calculate_pending_protocol_fees();
        assert!(pending_fees == 0, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_total_pending_fees() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Calculate total pending fees
        // protocol_fee_bps = 50 (0.5%), house_fee_bps = 2000 (20%), fee_collector_share_bps = 1000 (10%)
        // Total fee bps = 3050 (30.5%)
        // GGR = 5k
        // Total fee = 5k * 30.5% = 1525 (rounded up)
        let total_pending = state.calculate_total_pending_fees();
        let expected_fee = mul_ceil_bps(5_000, 3050); // GGR = 5k * 30.5% = 1525 (rounded up)
        assert!(total_pending == expected_fee, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_calculate_total_pending_fees_no_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // No transactions, so no GGR
        let total_pending = state.calculate_total_pending_fees();
        assert!(total_pending == 0, 0);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_total_shares() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // Initially no shares
        assert!(state.total_shares() == 0, 0);

        // Mint shares
        state.mint_shares(100);
        assert!(state.total_shares() == 100, 1);

        // Mint more
        state.mint_shares(50);
        assert!(state.total_shares() == 150, 2);

        // Burn some
        state.burn_shares(30);
        assert!(state.total_shares() == 120, 3);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_process_end_of_day_collector_no_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions with equal bets and wins (no GGR)
        let txs = vector[bet(10_000), win(10_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch
        scenario.next_epoch(addr);

        // Process end of day - collector fees should be empty (no GGR = no fees)
        let (collector_fees, house_fee, protocol_fee) = state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        assert!(vector::length(&collector_fees) == 0, 0);
        assert!(house_fee == 0, 1);
        assert!(protocol_fee == 0, 2);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_process_end_of_day_resets_collector_ggr() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Check current GGR
        let ggr = state.current_collector_ggr(fee_collector_id);
        assert!(house_state::bet_amount(&ggr) == 10_000, 0);
        assert!(house_state::win_amount(&ggr) == 5_000, 1);

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Current GGR should be reset
        let ggr_after = state.current_collector_ggr(fee_collector_id);
        assert!(house_state::bet_amount(&ggr_after) == 0, 2);
        assert!(house_state::win_amount(&ggr_after) == 0, 3);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_process_end_of_day_saves_collector_ggr_to_history() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Historic GGR should be saved
        let historic_ggr = state.historic_collector_ggr(0, fee_collector_id);
        assert!(house_state::bet_amount(&historic_ggr) == 10_000, 0);
        assert!(house_state::win_amount(&historic_ggr) == 5_000, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_new_captures_fees() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let protocol_fee_bps = 50;
        let house_fee_bps = 2000;
        let fee_collector_share_bps = 1000;
        let mut state = house_state::new(
            house_id,
            protocol_fee_bps,
            house_fee_bps,
            fee_collector_share_bps,
            scenario.ctx(),
        );

        // Verify initial fees are captured at creation
        assert!(state.current_epoch_protocol_fee_bps() == protocol_fee_bps, 0);
        assert!(state.current_epoch_house_fee_bps() == house_fee_bps, 1);
        assert!(state.current_epoch_fee_collector_share_bps() == fee_collector_share_bps, 2);

        // Now change the fees and verify they are captured on end of day
        let new_protocol_fee_bps = 75;
        let new_house_fee_bps = 2500;
        let new_fee_collector_share_bps = 1500;

        // Advance epoch to trigger end of day processing
        scenario.next_epoch(addr);

        // Process end of day with new fees - these should be captured for the new epoch
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            new_house_fee_bps,
            new_fee_collector_share_bps,
            new_protocol_fee_bps,
            scenario.ctx(),
        );

        // Verify fees have been updated to the new values
        assert!(state.current_epoch_protocol_fee_bps() == new_protocol_fee_bps, 3);
        assert!(state.current_epoch_house_fee_bps() == new_house_fee_bps, 4);
        assert!(state.current_epoch_fee_collector_share_bps() == new_fee_collector_share_bps, 5);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_epoch() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        scenario.next_epoch(addr);
        scenario.next_epoch(addr);

        let house_id = object::id_from_address(@0x0);
        let state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // Epoch should match current epoch
        let current_epoch = scenario.ctx().epoch();
        assert!(state.epoch() == current_epoch, 0);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_process_collector_end_of_day_direct() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Process collector end of day directly (package function)
        let collector_fees = house_state::process_collector_end_of_day(
            &mut state,
            0,
            scenario.ctx(),
        );
        assert!(vector::length(&collector_fees) == 1, 0);

        let fee = *vector::borrow(&collector_fees, 0);
        assert!(house_state::collector_id(&fee) == fee_collector_id, 1);
        assert!(house_state::fee_amount(&fee) > 0, 2);

        // Current GGR should be reset
        let ggr = state.current_collector_ggr(fee_collector_id);
        assert!(house_state::bet_amount(&ggr) == 0, 3);
        assert!(house_state::win_amount(&ggr) == 0, 4);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_process_collector_end_of_day_multiple_collectors() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id1 = object::id_from_address(@0xB);
        let fee_collector_id2 = object::id_from_address(@0xC);

        // Process transactions for collector 1: GGR = 5k
        let txs1 = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs1, bm.id(), fee_collector_id1, scenario.ctx());

        // Process transactions for collector 2: GGR = 3k
        let txs2 = vector[bet(8_000), win(5_000)];
        state.process_transactions(&txs2, bm.id(), fee_collector_id2, scenario.ctx());

        // Process collector end of day
        let collector_fees = house_state::process_collector_end_of_day(
            &mut state,
            0,
            scenario.ctx(),
        );
        assert!(vector::length(&collector_fees) == 2, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_process_collector_end_of_day_no_collectors() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());

        // Process collector end of day with no collector activity
        let collector_fees = house_state::process_collector_end_of_day(
            &mut state,
            0,
            scenario.ctx(),
        );
        assert!(vector::length(&collector_fees) == 0, 0);

        destroy(state);
        scenario.end();
    }
}

#[test]
public fun test_process_collector_end_of_day_collector_with_loss() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions with loss (win > bet): GGR = -5k (no GGR)
        let txs = vector[bet(10_000), win(15_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Process collector end of day - should return empty (no GGR = no fees)
        let collector_fees = house_state::process_collector_end_of_day(
            &mut state,
            0,
            scenario.ctx(),
        );
        assert!(vector::length(&collector_fees) == 0, 0);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = house_state::EEpochMismatch)]
public fun test_process_transactions_epoch_mismatch() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Advance epoch
        scenario.next_epoch(addr);

        // Try to process transactions in wrong epoch - should fail
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_empty_collector_ggr() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        // Test the empty_collector_ggr function
        let ggr = house_state::empty_collector_ggr();
        assert!(house_state::bet_amount(&ggr) == 0, 0);
        assert!(house_state::win_amount(&ggr) == 0, 1);

        scenario.end();
    }
}

#[test]
public fun test_collector_id_and_fee_amount() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        let (collector_fees, _house_fee, _protocol_fee) = state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Test collector_id and fee_amount functions
        assert!(vector::length(&collector_fees) == 1, 0);
        let fee = *vector::borrow(&collector_fees, 0);
        assert!(house_state::collector_id(&fee) == fee_collector_id, 1);
        assert!(house_state::fee_amount(&fee) == mul_ceil_bps(5_000, 1000), 2);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_pending_collector_fees_reset_after_eod() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Check pending collector fees are non-zero
        let pending_before = state.calculate_pending_collector_fees();
        assert!(pending_before > 0, 0);

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Check pending collector fees are reset to zero
        let pending_after = state.calculate_pending_collector_fees();
        assert!(pending_after == 0, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_pending_house_fees_reset_after_eod() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Check pending house fees are non-zero
        let pending_before = state.calculate_pending_house_fees();
        assert!(pending_before > 0, 0);

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Check pending house fees are reset to zero
        let pending_after = state.calculate_pending_house_fees();
        assert!(pending_after == 0, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_pending_protocol_fees_reset_after_eod() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Check pending protocol fees are non-zero
        let pending_before = state.calculate_pending_protocol_fees();
        assert!(pending_before > 0, 0);

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Check pending protocol fees are reset to zero
        let pending_after = state.calculate_pending_protocol_fees();
        assert!(pending_after == 0, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_total_pending_fees_reset_after_eod() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Process transactions: GGR = 5k
        let txs = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs, bm.id(), fee_collector_id, scenario.ctx());

        // Check total pending fees are non-zero
        let pending_before = state.calculate_total_pending_fees();
        assert!(pending_before > 0, 0);

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Check total pending fees are reset to zero
        let pending_after = state.calculate_total_pending_fees();
        assert!(pending_after == 0, 1);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_all_pending_fees_reset_after_eod_comprehensive() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id1 = object::id_from_address(@0xB);
        let fee_collector_id2 = object::id_from_address(@0xC);

        // Process transactions for multiple collectors: GGR = 5k + 3k = 8k total
        let txs1 = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs1, bm.id(), fee_collector_id1, scenario.ctx());

        let txs2 = vector[bet(8_000), win(5_000)];
        state.process_transactions(&txs2, bm.id(), fee_collector_id2, scenario.ctx());

        // Check all pending fees are non-zero
        let collector_pending_before = state.calculate_pending_collector_fees();
        let house_pending_before = state.calculate_pending_house_fees();
        let protocol_pending_before = state.calculate_pending_protocol_fees();
        let total_pending_before = state.calculate_total_pending_fees();

        assert!(collector_pending_before > 0, 0);
        assert!(house_pending_before > 0, 1);
        assert!(protocol_pending_before > 0, 2);
        assert!(total_pending_before > 0, 3);

        // Advance epoch and process end of day
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Check all pending fees are reset to zero
        let collector_pending_after = state.calculate_pending_collector_fees();
        let house_pending_after = state.calculate_pending_house_fees();
        let protocol_pending_after = state.calculate_pending_protocol_fees();
        let total_pending_after = state.calculate_total_pending_fees();

        assert!(collector_pending_after == 0, 4);
        assert!(house_pending_after == 0, 5);
        assert!(protocol_pending_after == 0, 6);
        assert!(total_pending_after == 0, 7);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

#[test]
public fun test_pending_fees_reset_then_new_epoch_accumulates() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0x0);
        let mut state = house_state::new(house_id, 50, 2000, 1000, scenario.ctx());
        let (bm, bm_cap) = balance_manager::new(scenario.ctx());
        let fee_collector_id = object::id_from_address(@0xB);

        // Epoch 0: Process transactions: GGR = 5k
        let txs1 = vector[bet(10_000), win(5_000)];
        state.process_transactions(&txs1, bm.id(), fee_collector_id, scenario.ctx());

        let pending_before_eod = state.calculate_total_pending_fees();
        assert!(pending_before_eod > 0, 0);

        // Process end of day for epoch 0
        scenario.next_epoch(addr);
        state.process_end_of_day(
            scenario.ctx().epoch() - 1,
            2000,
            1000,
            50,
            scenario.ctx(),
        );

        // Pending fees should be reset
        let pending_after_eod = state.calculate_total_pending_fees();
        assert!(pending_after_eod == 0, 1);

        // Epoch 1: Process new transactions: GGR = 3k
        let txs2 = vector[bet(8_000), win(5_000)];
        state.process_transactions(&txs2, bm.id(), fee_collector_id, scenario.ctx());

        // Pending fees should accumulate again in new epoch
        let pending_new_epoch = state.calculate_total_pending_fees();
        assert!(pending_new_epoch > 0, 2);

        destroy(state);
        destroy(bm);
        destroy(bm_cap);
        scenario.end();
    }
}

// NOTE: The EUnknownTransaction error in house_state is unreachable code.
// When an invalid transaction type is processed, the transaction module's is_credit()
// function aborts with EUnknownTxType BEFORE house_state can check for unknown types.
// This is defensive programming - the check exists but can never be reached.
// See transaction_tests::is_credit_aborts_on_invalid_type for coverage of this path.
