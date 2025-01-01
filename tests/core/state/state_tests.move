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
        bm.id()
    );
    assert!(credit_balance == 5);
    assert!(debit_balance == 10);
    assert!(owner_fee == int_mul(10, owner_fee()));
    assert!(protocol_fee == int_mul(10, protocol_fee()));

    destroy(bm);
    destroy(state);
    scenario.end();
}
