#[test_only]
module openplay_core::core_constants_tests;

use openplay_core::core_constants;
use std::unit_test::assert_eq;

#[test]
public fun test_max_bps() {
    let result = core_constants::max_bps();
    assert_eq!(result, 10_000);
}

#[test]
public fun test_tx_type_bet() {
    let result = core_constants::tx_type_bet();
    assert!(std::string::utf8(b"Bet") == result, 0);
}

#[test]
public fun test_tx_type_win() {
    let result = core_constants::tx_type_win();
    assert!(std::string::utf8(b"Win") == result, 0);
}

#[test]
public fun test_current_version() {
    let result = core_constants::current_version();
    assert_eq!(result, 1);
}

#[test]
public fun test_max_protocol_fee_bps() {
    let result = core_constants::max_protocol_fee_bps();
    assert_eq!(result, 2_000);
}

#[test]
public fun test_max_house_and_collector_fees_bps() {
    let result = core_constants::max_house_and_collector_fees_bps();
    assert_eq!(result, 5_000);
}

