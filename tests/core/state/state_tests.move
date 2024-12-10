#[test_only]
module openplay::state_tests;

use openplay::balance_manager;
use openplay::constants::{owner_fee, protocol_fee};
use openplay::state;
use openplay::transaction::{bet, win};
use std::uq32_32::int_mul;
use sui::test_scenario::begin;
use sui::test_utils::destroy;

#[test]
public fun transactions_process_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Initialize state and balance manager
    let mut state = state::new(scenario.ctx());
    let bm = balance_manager::new(scenario.ctx());

    // Process transactions: total bet of 10 and win of 5
    let txs = vector[bet(10), bet(0), win(5), win(0)];
    let (credit_balance, debit_balance, owner_fee, protocol_fee) = state.process_transactions(
        &txs,
        bm.id(),
        scenario.ctx(),
    );
    assert!(credit_balance == 5);
    assert!(debit_balance == 10);
    assert!(owner_fee == int_mul(10, owner_fee()));
    assert!(protocol_fee == int_mul(10, protocol_fee()));

    destroy(bm);
    destroy(state);
    scenario.end();
}

#[test]
public fun stake_unstake_no_gameplay_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Initialize state and balance manager
    let mut state = state::new(scenario.ctx());
    let bm = balance_manager::new(scenario.ctx());

    // Stake 100 right now
    let (credit_balance, debit_balance) = state.process_stake(bm.id(), 100, scenario.ctx());
    assert!(credit_balance == 0);
    assert!(debit_balance == 100);

    // Advance epoch WITH 100 profits
    // !! because the stake is not active yet this should not have any impact on our test balance manager
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 100, 0, scenario.ctx());

    // Stake another 50
    let (credit_balance, debit_balance) = state.process_stake(bm.id(), 50, scenario.ctx());
    assert!(credit_balance == 0);
    assert!(debit_balance == 50);

    // Now unstake: should get 50 right away and 100 later
    let (credit_balance, debit_balance) = state.process_unstake(bm.id(), scenario.ctx());
    assert!(credit_balance == 50);
    assert!(debit_balance == 0);

    // Advance epoch without any profits / losses
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 0, scenario.ctx());

    // Settle remaining balances on the account: should get the 100 now
    let (credit_balance, debit_balance) = state.settle_account(bm.id(), scenario.ctx());
    assert!(credit_balance == 100);
    assert!(debit_balance == 0);

    destroy(bm);
    destroy(state);
    scenario.end();
}

#[test]
public fun stake_unstake_profits_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Initialize state and balance manager
    let mut state = state::new(scenario.ctx());
    let bm = balance_manager::new(scenario.ctx());

    // Stake 100 right now
    let (credit_balance, debit_balance) = state.process_stake(bm.id(), 100, scenario.ctx());
    assert!(credit_balance == 0);
    assert!(debit_balance == 100);

    // Advance epoch WITH 100 profits, bringing the total stake to 200
    // !! because the stake is not active yet this should not have any impact on our test balance manager
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 100, 0, scenario.ctx());

    // Stake another 50
    let (credit_balance, debit_balance) = state.process_stake(bm.id(), 50, scenario.ctx());
    assert!(credit_balance == 0);
    assert!(debit_balance == 50);

    // Now unstake: should get 50 right away and 100 later
    let (credit_balance, debit_balance) = state.process_unstake(bm.id(), scenario.ctx());
    assert!(credit_balance == 50);
    assert!(debit_balance == 0);

    // Advance epoch with a profit of 10
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 10, 0, scenario.ctx());

    // Settle remaining balances on the account: should get the 100 now (bcs of unstake) + a shared profit of 5 (we had 100 out of 200 active stake)
    let (credit_balance, debit_balance) = state.settle_account(bm.id(), scenario.ctx());
    assert!(credit_balance == 105);
    assert!(debit_balance == 0);

    destroy(bm);
    destroy(state);
    scenario.end();
}

#[test]
public fun stake_unstake_losses_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Initialize state and balance manager
    let mut state = state::new(scenario.ctx());
    let bm = balance_manager::new(scenario.ctx());

    // Stake 100 right now
    let (credit_balance, debit_balance) = state.process_stake(bm.id(), 100, scenario.ctx());
    assert!(credit_balance == 0);
    assert!(debit_balance == 100);

    // Advance epoch WITH 100 profits, bringing the total stake to 200
    // !! because the stake is not active yet this should not have any impact on our test balance manager
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 100, 0, scenario.ctx());

    // Stake another 50
    let (credit_balance, debit_balance) = state.process_stake(bm.id(), 50, scenario.ctx());
    assert!(credit_balance == 0);
    assert!(debit_balance == 50);

    // Now unstake: should get 50 right away and 100 later
    let (credit_balance, debit_balance) = state.process_unstake(bm.id(), scenario.ctx());
    assert!(credit_balance == 50);
    assert!(debit_balance == 0);

    // Advance epoch with a loss of 10
    scenario.next_epoch(addr);
    state.process_end_of_day(scenario.ctx().epoch() - 1, 0, 10, scenario.ctx());

    // Settle remaining balances on the account: should get the 100 now (bcs of unstake) - a shared loss of 5 (we had 100 out of 200 active stake)
    let (credit_balance, debit_balance) = state.settle_account(bm.id(), scenario.ctx());
    assert!(credit_balance == 95);
    assert!(debit_balance == 0);

    destroy(bm);
    destroy(state);
    scenario.end();
}
