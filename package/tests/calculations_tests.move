#[test_only]
module openplay_core::calculations_tests;

use openplay_core::calculations::{Self, actualize_amount};
use openplay_core::core_test_utils::assert_eq_within_precision_allowance;

#[test]
public fun actualize_share_profits_ok() {
    let base = 100_000;
    let profits = 1_000; // 1% profit
    let amount = 1000;

    let new_amount = actualize_amount(amount, profits, 0, base);

    assert_eq_within_precision_allowance(new_amount, 1010);
}

#[test]
public fun actualize_big_share_profits_ok() {
    let base = 100_000;
    let profits = 200_000; // 200% profit
    let amount = 1000;

    let new_amount = actualize_amount(amount, profits, 0, base);

    assert_eq_within_precision_allowance(new_amount, 3000);
}

#[test]
public fun actualize_share_losses_ok() {
    let base = 100_000;
    let losses = 1_000; // 1% loss
    let amount = 1000;

    let new_amount = actualize_amount(amount, 0, losses, base);

    assert_eq_within_precision_allowance(new_amount, 990);
}

#[test]
public fun actualize_big_share_losses_ok() {
    let base = 100_000;
    let losses = 99_000; // 99% loss
    let amount = 1000;

    let new_amount = actualize_amount(amount, 0, losses, base);

    assert_eq_within_precision_allowance(new_amount, 10);
}

#[test]
public fun actualize_bankruptcy_ok() {
    let base = 100_000;
    let losses = 100_000; // 100% loss
    let amount = 1000;

    let new_amount = actualize_amount(amount, 0, losses, base);

    assert_eq_within_precision_allowance(new_amount, 0);
}

#[test, expected_failure(abort_code = calculations::ELossTooHigh)]
public fun actualize_invalid_losses_error() {
    let base = 100_000;
    let losses = 100_010; // > 100% loss
    let amount = 1000;

    let _new_amount = actualize_amount(amount, 0, losses, base);
    abort 0
}

#[test]
public fun actualize_do_nothing_ok() {
    let base = 100_000;
    let amount = 1000;

    let new_amount = actualize_amount(amount, 0, 0, base);

    assert_eq_within_precision_allowance(new_amount, 1000);
}
