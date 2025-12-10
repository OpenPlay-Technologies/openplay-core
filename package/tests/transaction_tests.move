#[test_only]
module openplay_core::transaction_tests;

use openplay_core::transaction;
use std::unit_test::destroy;
use sui::test_scenario::begin;

/// Test that bet_checked accepts amounts at or above the minimum.
#[test]
public fun bet_checked_accepts_minimum_amount() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        let min_amount = transaction::min_transaction_amount();
        let tx = transaction::bet_checked(min_amount);
        assert!(transaction::amount(&tx) == min_amount, 0);
        assert!(transaction::is_debit(&tx), 0);
        destroy(tx);
        scenario.end();
    }
}

/// Test that bet_checked accepts amounts above the minimum.
#[test]
public fun bet_checked_accepts_above_minimum() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        let min_amount = transaction::min_transaction_amount();
        let tx = transaction::bet_checked(min_amount + 1);
        assert!(transaction::amount(&tx) == min_amount + 1, 0);
        assert!(transaction::is_debit(&tx), 0);
        destroy(tx);
        scenario.end();
    }
}

/// Test that bet_checked rejects amounts below the minimum.
#[test, expected_failure(abort_code = transaction::EAmountTooLow)]
public fun bet_checked_rejects_below_minimum() {
    let min_amount = transaction::min_transaction_amount();
    let tx = transaction::bet_checked(min_amount - 1);
    destroy(tx);
    abort 0
}

/// Test that bet_checked rejects zero amount.
#[test, expected_failure(abort_code = transaction::EAmountTooLow)]
public fun bet_checked_rejects_zero() {
    let tx = transaction::bet_checked(0);
    destroy(tx);
    abort 0
}

/// Test that win_checked accepts amounts at or above the minimum.
#[test]
public fun win_checked_accepts_minimum_amount() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        let min_amount = transaction::min_transaction_amount();
        let tx = transaction::win_checked(min_amount);
        assert!(transaction::amount(&tx) == min_amount, 0);
        assert!(transaction::is_credit(&tx), 0);
        destroy(tx);
        scenario.end();
    }
}

/// Test that win_checked accepts amounts above the minimum.
#[test]
public fun win_checked_accepts_above_minimum() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        let min_amount = transaction::min_transaction_amount();
        let tx = transaction::win_checked(min_amount + 1);
        assert!(transaction::amount(&tx) == min_amount + 1, 0);
        assert!(transaction::is_credit(&tx), 0);
        destroy(tx);
        scenario.end();
    }
}

/// Test that win_checked rejects amounts below the minimum.
#[test, expected_failure(abort_code = transaction::EAmountTooLow)]
public fun win_checked_rejects_below_minimum() {
    let min_amount = transaction::min_transaction_amount();
    let tx = transaction::win_checked(min_amount - 1);
    destroy(tx);
    abort 0
}

/// Test that win_checked rejects zero amount.
#[test, expected_failure(abort_code = transaction::EAmountTooLow)]
public fun win_checked_rejects_zero() { let tx = transaction::win_checked(0); destroy(tx); abort 0 }

/// Test that the test-only bet function still works (bypasses validation).
#[test]
public fun test_only_bet_bypasses_validation() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        // Test-only bet should accept any amount, even below minimum
        let tx = transaction::bet(1);
        assert!(transaction::amount(&tx) == 1, 0);
        assert!(transaction::is_debit(&tx), 0);
        destroy(tx);
        scenario.end();
    }
}

/// Test that the test-only win function still works (bypasses validation).
#[test]
public fun test_only_win_bypasses_validation() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        // Test-only win should accept any amount, even below minimum
        let tx = transaction::win(1);
        assert!(transaction::amount(&tx) == 1, 0);
        assert!(transaction::is_credit(&tx), 0);
        destroy(tx);
        scenario.end();
    }
}

/// Test that min_transaction_amount returns the expected value.
#[test]
public fun min_transaction_amount_returns_correct_value() {
    let addr = @0xA;
    let scenario = begin(addr);
    {
        let min_amount = transaction::min_transaction_amount();
        assert!(min_amount == 100_000, 0);
        scenario.end();
    };
}

/// Test that is_credit aborts with EUnknownTxType for invalid transaction type.
#[test, expected_failure(abort_code = transaction::EUnknownTxType)]
public fun is_credit_aborts_on_invalid_type() {
    let tx = transaction::invalid_type_for_testing(1000);
    transaction::is_credit(&tx);
    abort 0
}

/// Test that is_debit aborts with EUnknownTxType for invalid transaction type.
#[test, expected_failure(abort_code = transaction::EUnknownTxType)]
public fun is_debit_aborts_on_invalid_type() {
    let tx = transaction::invalid_type_for_testing(1000);
    transaction::is_debit(&tx);
    abort 0
}
