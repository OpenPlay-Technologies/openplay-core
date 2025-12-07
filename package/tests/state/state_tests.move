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
    let house_fee_bps = 300; // 3% = 300 bps
    let protocol_fee_bps = 700; // 7% = 700 bps
    let mut scenario = begin(addr);

    // Initialize state and balance manager
    let mut state = house_state::new(scenario.ctx());
    let (bm, bm_cap) = balance_manager::new(scenario.ctx());

    // Activate the state so it can process transactions
    assert!(state.maybe_activate(0, scenario.ctx()));

    // Process transactions: total bet of 10 and win of 5
    let txs = vector[bet(10), bet(0), win(5), win(0)];
    let (credit_balance, debit_balance, house_fee, protocol_fee) = state.process_transactions(
        &txs,
        bm.id(),
        house_fee_bps,
        protocol_fee_bps,
        scenario.ctx(),
    );
    // Assert account balance
    assert!(credit_balance == 5);
    assert!(debit_balance == 10);
    // Assert fees (using mul_ceil_bps which rounds up)
    assert!(house_fee == mul_ceil_bps(10, house_fee_bps));
    assert!(protocol_fee == mul_ceil_bps(10, protocol_fee_bps));
    // Assert volumes
    assert!(state.current_volumes().total_bet_amount() == 10);
    assert!(state.current_volumes().total_win_amount() == 5);
    assert!(state.all_time_bet_amount() == 10);
    assert!(state.all_time_win_amount() == 5);

    destroy(bm);
    destroy(state);
    destroy(bm_cap);
    scenario.end();
}

#[test]
public fun stake_unstake_tests() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create empty history
    let mut state = house_state::new(scenario.ctx());

    // Stake 10
    state.process_stake(10, scenario.ctx());

    assert!(state.inactive_stake() == 10);
    assert!(state.active_stake() == 0);
    assert!(state.pending_unstake() == 0);

    // Stake 10 more
    state.process_stake(10, scenario.ctx());

    assert!(state.inactive_stake() == 20);
    assert!(state.active_stake() == 0);
    assert!(state.pending_unstake() == 0);

    // Activate the state
    assert!(state.maybe_activate(0, scenario.ctx()));

    // Stake 10 more
    state.process_stake(10, scenario.ctx());

    assert!(state.inactive_stake() == 10);
    assert!(state.active_stake() == 20);
    assert!(state.pending_unstake() == 0);

    // Unstake: 4 from pending (immediately) and 6 from active (pending until end of epoch)
    state.process_unstake(6, 4, scenario.ctx());

    assert!(state.inactive_stake() == 6); // 4 stake is immediately removed because it was still pending
    assert!(state.active_stake() == 20); // active stake can never change throughout a cycle
    assert!(state.pending_unstake() == 6); // 6 is added to pending_unstake and will be removed at the end of the cycle

    // Process end of day with 5 profits
    scenario.next_epoch(addr);
    state.process_end_of_day(0, 5, 0, scenario.ctx());

    assert!(state.inactive_stake() == 24); // 6 (inactive) + 20 (active) + 5 (profits) - 6 (unstaked) - 1 (profits on the unstaked amount also need to be removed)
    assert!(state.active_stake() == 0);
    assert!(state.pending_unstake() == 0);

    destroy(state);

    scenario.end();
}

#[test, expected_failure(abort_code = house_state::ECannotUnstakeMoreThanStaked)]
public fun unstake_too_much() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    let mut state = house_state::new(scenario.ctx());
    state.process_stake(100, scenario.ctx());
    state.process_unstake(150, 0, scenario.ctx());

    abort 0
}

#[test, expected_failure(abort_code = house_state::EEndOfDayNotAvailable)]
public fun end_of_day_empty() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create empty state
    let state = house_state::new(scenario.ctx());
    state.end_of_day_for_epoch(0);

    abort 0
}

#[test]
public fun end_of_day_available() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Create empty state
    let mut state = house_state::new(scenario.ctx());

    // Process end of day for epoch 0: profits of 100 and end of day balance of 200
    scenario.next_epoch(addr);
    state.process_end_of_day(0, 100, 0, scenario.ctx());

    // Check data
    let eod = state.end_of_day_for_epoch(scenario.ctx().epoch() - 1);
    assert!(eod.day_losses() == 0);
    assert!(eod.day_profits() == 100);

    destroy(state);
    scenario.end();
}

#[test, expected_failure(abort_code = house_state::EEpochHasNotFinishedYet)]
public fun cannot_process_eod_before_epoch_ended() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let mut state = house_state::new(scenario.ctx());
    state.process_end_of_day(0, 100, 0, scenario.ctx());

    abort 0
}

#[test, expected_failure(abort_code = house_state::EEpochMismatch)]
public fun cannot_process_eod_for_wrong_epoch() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let mut state = house_state::new(scenario.ctx());

    // Advance to epoch 2
    scenario.next_epoch(addr);
    scenario.next_epoch(addr);

    // Process eod for epoch 1
    state.process_end_of_day(1, 100, 0, scenario.ctx());

    abort 0
}

#[test, expected_failure(abort_code = house_state::EInvalidProfitsOrLosses)]
public fun cannot_process_eod_wrong_profits_or_losses() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    // Initialize history to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Advance to epoch 1
    scenario.next_epoch(addr);
    state.process_end_of_day(0, 100, 100, scenario.ctx());

    abort 0
}

#[test]
public fun stake_amount_correctly_transferred_basic() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    let mut state = house_state::new(scenario.ctx());

    // Add pending stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Add pending unstake of 50
    state.process_unstake(50, 0, scenario.ctx());

    // Transfer next epoch
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());
    assert!(state.inactive_stake() == 50);
    assert!(state.pending_unstake() == 0);
    assert!(state.active_stake() == 0);

    // Activate
    assert!(state.maybe_activate(50, scenario.ctx()));

    // Transfer next epoch with some profits
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 10, 0, scenario.ctx());
    assert!(state.inactive_stake() == 60);

    // Activate
    assert!(state.maybe_activate(60, scenario.ctx()));

    // Transfer next epoch with some losses
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 20, scenario.ctx());
    assert!(state.inactive_stake() == 40);

    destroy(state);
    scenario.end();
}

#[test]
public fun stake_amount_correctly_transferred_profits() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize history to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add pending stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Now do a complete setup, starting from a stake of 100

    // 30 being added
    state.process_stake(30, scenario.ctx());

    // 10 being removed
    // 10 cancelled immediately
    state.process_unstake(10, 10, scenario.ctx());

    // Transfer next epoch with profits of 30
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 30, 0, scenario.ctx());

    // 10 stake is being removed, but this 10 stake has also accrued profits
    // 10 stake is equal to 10% in our example, so they take a share of 3 on the profits
    // this means that 13 should be unstaked
    // We are adding 20 stake, so sums up to +7
    // Plus 30 of the profits

    // Profits: 30 (30% of 100)
    // Unstake: 10, actualize_amount(10, 30, 0, 100, false) = mul_floor(10, 130, 100) = 13
    // Expected: 100 + 30 - 13 + 20 = 137
    assert!(state.inactive_stake() == 137);

    destroy(state);
    scenario.end();
}

#[test]
public fun stake_amount_correctly_transferred_losses() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize history to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add pending stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Now do a complete setup, starting from a stake of 100

    // 30 being added
    state.process_stake(30, scenario.ctx());

    // 10 being removed
    // 10 cancelled immediately
    state.process_unstake(10, 10, scenario.ctx());

    // Transfer next epoch with losses of 30
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 30, scenario.ctx());

    // 10 stake is being removed, but this 10 stake has also accrued losses
    // 10 stake is equal to 10% in our example, so they take a loss of 3
    // this means that only 7 should be unstaked and returned to the stakers
    // We are adding 20 stake, so sums up to +13
    // Minus 30 of the profits
    // This gives 83

    // Losses: 30 (30% of 100)
    // Unstake: 10, actualize_amount(10, 0, 30, 100, true) = mul_ceil(10, 70, 100) = 7
    // Expected: 100 - 30 - 7 + 20 = 83
    assert!(state.inactive_stake() == 83);

    destroy(state);
    scenario.end();
}

#[test]
public fun stake_amount_correctly_transferred_full_unstake_profits() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize history to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add pending stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Now the staker wish to fully unstake
    state.process_unstake(100, 0, scenario.ctx());

    // 5 new stake is coming in
    state.process_stake(5, scenario.ctx());

    // Transfer next epoch with some profits
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 7, 0, scenario.ctx());

    // With exact rounding: actualize_amount(100, 7, 0, 100, false) = mul_floor(100, 107, 100) = 107
    // After unstake: stake = 107 - 107 = 0, new stake: 5
    // Total inactive stake: 5
    assert!(state.inactive_stake() == 5);
    destroy(state);
    scenario.end();
}

#[test]
public fun stake_amount_correctly_transferred_full_unstake_losses() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize state to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add pending stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Now the staker wish to fully unstake
    state.process_unstake(100, 0, scenario.ctx());

    // 5 new stake is coming in
    state.process_stake(5, scenario.ctx());

    // Transfer next epoch with some profits
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 7, scenario.ctx());

    // Losses: 7 (7% of 100)
    // Unstake: 100, actualize_amount(100, 0, 7, 100, true) = mul_ceil(100, 93, 100) = 93
    // Expected: 100 - 7 - 93 + 5 = 5
    assert!(state.inactive_stake() == 5);

    destroy(state);
    scenario.end();
}

#[test]
public fun stake_amount_correctly_transferred_bankrupt() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize state to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add pending stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Now the staker wish to fully unstake
    state.process_unstake(100, 0, scenario.ctx());

    // 5 new stake is coming in
    state.process_stake(5, scenario.ctx());

    // Transfer next epoch with bankrupt losses (100% loss)
    // With strict checking, losses cannot exceed stake, so we use exactly 100
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 100, scenario.ctx());

    // The new stakers should never be taking any sort of losses from the previous epoch
    assert!(state.inactive_stake() == 5);

    destroy(state);
    scenario.end();
}

#[test]
public fun calculate_ggr_share_losses() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize state to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Transfer next epoch with losses of 31
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 31, scenario.ctx());

    let (profits_no_stake, losses_no_stake) = state.calculate_ggr_share(
        scenario.ctx().epoch() - 1,
        0,
    );
    assert!(losses_no_stake == 0);
    assert!(profits_no_stake == 0);

    let volume = state.volume_for_epoch(scenario.ctx().epoch() - 1);
    let eod = state.end_of_day_for_epoch(scenario.ctx().epoch() - 1);
    assert!(volume.active_stake_amount() == 100);
    assert!(eod.day_losses() == 31);
    assert!(eod.day_profits() == 0);

    let (profits_full_stake, losses_full_stake) = state.calculate_ggr_share(
        scenario.ctx().epoch() - 1,
        100,
    );
    assert!(losses_full_stake == 31);
    assert!(profits_full_stake == 0);

    // Losses are distributed using mul_ceil (rounds up) - users absorb more losses
    // Hardcoded expected values: mul_ceil(31, stake, 100) for each stake
    let (profits_1, losses_1) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 1);
    assert!(profits_1 == 0 && losses_1 == 1); // mul_ceil(31, 1, 100) = 1
    let (profits_7, losses_7) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 7);
    assert!(profits_7 == 0 && losses_7 == 3); // mul_ceil(31, 7, 100) = 3
    let (profits_13, losses_13) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 13);
    assert!(profits_13 == 0 && losses_13 == 5); // mul_ceil(31, 13, 100) = 5
    let (profits_21, losses_21) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 21);
    assert!(profits_21 == 0 && losses_21 == 7); // mul_ceil(31, 21, 100) = 7
    let (profits_25, losses_25) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 25);
    assert!(profits_25 == 0 && losses_25 == 8); // mul_ceil(31, 25, 100) = 8
    let (profits_30, losses_30) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 30);
    assert!(profits_30 == 0 && losses_30 == 10); // mul_ceil(31, 30, 100) = 10
    let (profits_40, losses_40) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 40);
    assert!(profits_40 == 0 && losses_40 == 13); // mul_ceil(31, 40, 100) = 13
    let (profits_60, losses_60) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 60);
    assert!(profits_60 == 0 && losses_60 == 19); // mul_ceil(31, 60, 100) = 19
    let (profits_80, losses_80) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 80);
    assert!(profits_80 == 0 && losses_80 == 25); // mul_ceil(31, 80, 100) = 25
    let (profits_99, losses_99) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 99);
    assert!(profits_99 == 0 && losses_99 == 31); // mul_ceil(31, 99, 100) = 31

    destroy(state);
    scenario.end();
}

#[test]
public fun calculate_ggr_share_profits() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Initialize state to epoch 0
    let mut state = house_state::new(scenario.ctx());

    // Add stake of 100
    state.process_stake(100, scenario.ctx());

    // Activate
    assert!(state.maybe_activate(100, scenario.ctx()));

    // Transfer next epoch with profits of 81
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 81, 0, scenario.ctx());

    let (profits_no_stake, losses_no_stake) = state.calculate_ggr_share(
        scenario.ctx().epoch() - 1,
        0,
    );
    assert!(losses_no_stake == 0);
    assert!(profits_no_stake == 0);

    let volume = state.volume_for_epoch(scenario.ctx().epoch() - 1);
    let eod = state.end_of_day_for_epoch(scenario.ctx().epoch() - 1);
    assert!(volume.active_stake_amount() == 100);
    assert!(eod.day_losses() == 0);
    assert!(eod.day_profits() == 81);

    let (profits_full_stake, losses_full_stake) = state.calculate_ggr_share(
        scenario.ctx().epoch() - 1,
        100,
    );
    assert!(losses_full_stake == 0);
    assert!(profits_full_stake == 81);

    // Profits are distributed using mul_floor (rounds down) - protocol pays less
    // Hardcoded expected values: mul_floor(81, stake, 100) for each stake
    let (profits_1, losses_1) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 1);
    assert!(profits_1 == 0 && losses_1 == 0); // mul_floor(81, 1, 100) = 0
    let (profits_7, losses_7) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 7);
    assert!(profits_7 == 5 && losses_7 == 0); // mul_floor(81, 7, 100) = 5
    let (profits_13, losses_13) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 13);
    assert!(profits_13 == 10 && losses_13 == 0); // mul_floor(81, 13, 100) = 10
    let (profits_21, losses_21) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 21);
    assert!(profits_21 == 17 && losses_21 == 0); // mul_floor(81, 21, 100) = 17
    let (profits_25, losses_25) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 25);
    assert!(profits_25 == 20 && losses_25 == 0); // mul_floor(81, 25, 100) = 20
    let (profits_30, losses_30) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 30);
    assert!(profits_30 == 24 && losses_30 == 0); // mul_floor(81, 30, 100) = 24
    let (profits_40, losses_40) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 40);
    assert!(profits_40 == 32 && losses_40 == 0); // mul_floor(81, 40, 100) = 32
    let (profits_60, losses_60) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 60);
    assert!(profits_60 == 48 && losses_60 == 0); // mul_floor(81, 60, 100) = 48
    let (profits_80, losses_80) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 80);
    assert!(profits_80 == 64 && losses_80 == 0); // mul_floor(81, 80, 100) = 64
    let (profits_99, losses_99) = state.calculate_ggr_share(scenario.ctx().epoch() - 1, 99);
    assert!(profits_99 == 80 && losses_99 == 0); // mul_floor(81, 99, 100) = 80

    destroy(state);
    scenario.end();
}
