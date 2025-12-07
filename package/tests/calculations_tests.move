#[test_only]
module openplay_core::calculations_tests;

use openplay_core::calculations::{
    Self,
    actualize_amount,
    mul_ceil,
    mul_ceil_bps,
    mul_floor,
    mul_floor_bps
};
use std::unit_test::assert_eq;

// ===== mul_floor tests =====

#[test]
public fun mul_floor_basic_ok() {
    // 1000 * 1 / 2 = 500
    let result = mul_floor(1000, 1, 2);
    assert_eq!(result, 500);
}

#[test]
public fun mul_floor_exact_division_ok() {
    // 1000 * 3 / 2 = 1500
    let result = mul_floor(1000, 3, 2);
    assert_eq!(result, 1500);
}

#[test]
public fun mul_floor_rounds_down_ok() {
    // 1000 * 1 / 3 = 333.33... -> rounds down to 333
    let result = mul_floor(1000, 1, 3);
    assert_eq!(result, 333);
}

#[test]
public fun mul_floor_small_values_ok() {
    // 1 * 1 / 2 = 0.5 -> rounds down to 0
    let result = mul_floor(1, 1, 2);
    assert_eq!(result, 0);
}

#[test]
public fun mul_floor_large_values_ok() {
    // Large but safe calculation
    let result = mul_floor(1_000_000_000, 50, 100);
    assert_eq!(result, 500_000_000);
}

#[test]
public fun mul_floor_zero_numerator_ok() {
    // 1000 * 0 / 2 = 0
    let result = mul_floor(1000, 0, 2);
    assert_eq!(result, 0);
}

#[test]
public fun mul_floor_zero_value_ok() {
    // 0 * 1 / 2 = 0
    let result = mul_floor(0, 1, 2);
    assert_eq!(result, 0);
}

#[test, expected_failure(abort_code = calculations::EDivisionByZero)]
public fun mul_floor_division_by_zero_error() {
    let _result = mul_floor(1000, 1, 0);
    abort 0
}

// ===== mul_ceil tests =====

#[test]
public fun mul_ceil_basic_ok() {
    // 1000 * 1 / 2 = 500
    let result = mul_ceil(1000, 1, 2);
    assert_eq!(result, 500);
}

#[test]
public fun mul_ceil_exact_division_ok() {
    // 1000 * 3 / 2 = 1500
    let result = mul_ceil(1000, 3, 2);
    assert_eq!(result, 1500);
}

#[test]
public fun mul_ceil_rounds_up_ok() {
    // 1000 * 1 / 3 = 333.33... -> rounds up to 334
    let result = mul_ceil(1000, 1, 3);
    assert_eq!(result, 334);
}

#[test]
public fun mul_ceil_small_values_ok() {
    // 1 * 1 / 2 = 0.5 -> rounds up to 1
    let result = mul_ceil(1, 1, 2);
    assert_eq!(result, 1);
}

#[test]
public fun mul_ceil_large_values_ok() {
    // Large but safe calculation
    let result = mul_ceil(1_000_000_000, 50, 100);
    assert_eq!(result, 500_000_000);
}

#[test]
public fun mul_ceil_zero_numerator_ok() {
    // 1000 * 0 / 2 = 0
    let result = mul_ceil(1000, 0, 2);
    assert_eq!(result, 0);
}

#[test]
public fun mul_ceil_zero_value_ok() {
    // 0 * 1 / 2 = 0
    let result = mul_ceil(0, 1, 2);
    assert_eq!(result, 0);
}

#[test]
public fun mul_ceil_vs_mul_floor_difference() {
    // Test that ceil rounds up when floor rounds down
    let floor_result = mul_floor(1000, 1, 3); // 333
    let ceil_result = mul_ceil(1000, 1, 3); // 334
    assert_eq!(floor_result, 333);
    assert_eq!(ceil_result, 334);
    assert!(ceil_result > floor_result);
}

#[test, expected_failure(abort_code = calculations::EDivisionByZero)]
public fun mul_ceil_division_by_zero_error() {
    let _result = mul_ceil(1000, 1, 0);
    abort 0
}

// ===== mul_floor_bps tests =====

#[test]
public fun mul_floor_bps_one_percent_ok() {
    // 1000 * 100 / 10000 = 10 (1%)
    let result = mul_floor_bps(1000, 100);
    assert_eq!(result, 10);
}

#[test]
public fun mul_floor_bps_ten_percent_ok() {
    // 1000 * 1000 / 10000 = 100 (10%)
    let result = mul_floor_bps(1000, 1000);
    assert_eq!(result, 100);
}

#[test]
public fun mul_floor_bps_hundred_percent_ok() {
    // 1000 * 10000 / 10000 = 1000 (100%)
    let result = mul_floor_bps(1000, 10000);
    assert_eq!(result, 1000);
}

#[test]
public fun mul_floor_bps_rounds_down_ok() {
    // 1000 * 1 / 10000 = 0.1 -> rounds down to 0
    let result = mul_floor_bps(1000, 1);
    assert_eq!(result, 0);
}

#[test]
public fun mul_floor_bps_small_fraction_ok() {
    // 1000 * 33 / 10000 = 3.3 -> rounds down to 3
    let result = mul_floor_bps(1000, 33);
    assert_eq!(result, 3);
}

#[test]
public fun mul_floor_bps_large_amount_ok() {
    // 1_000_000_000 * 100 / 10000 = 10_000_000 (1% of 1B)
    let result = mul_floor_bps(1_000_000_000, 100);
    assert_eq!(result, 10_000_000);
}

// ===== mul_ceil_bps tests =====

#[test]
public fun mul_ceil_bps_one_percent_ok() {
    // 1000 * 100 / 10000 = 10 (1%)
    let result = mul_ceil_bps(1000, 100);
    assert_eq!(result, 10);
}

#[test]
public fun mul_ceil_bps_ten_percent_ok() {
    // 1000 * 1000 / 10000 = 100 (10%)
    let result = mul_ceil_bps(1000, 1000);
    assert_eq!(result, 100);
}

#[test]
public fun mul_ceil_bps_hundred_percent_ok() {
    // 1000 * 10000 / 10000 = 1000 (100%)
    let result = mul_ceil_bps(1000, 10000);
    assert_eq!(result, 1000);
}

#[test]
public fun mul_ceil_bps_rounds_up_ok() {
    // 1000 * 1 / 10000 = 0.1 -> rounds up to 1
    let result = mul_ceil_bps(1000, 1);
    assert_eq!(result, 1);
}

#[test]
public fun mul_ceil_bps_small_fraction_ok() {
    // 1000 * 33 / 10000 = 3.3 -> rounds up to 4
    let result = mul_ceil_bps(1000, 33);
    assert_eq!(result, 4);
}

#[test]
public fun mul_ceil_bps_large_amount_ok() {
    // 1_000_000_000 * 100 / 10000 = 10_000_000 (1% of 1B)
    let result = mul_ceil_bps(1_000_000_000, 100);
    assert_eq!(result, 10_000_000);
}

#[test]
public fun mul_ceil_bps_vs_mul_floor_bps_difference() {
    // Test that ceil_bps rounds up when floor_bps rounds down
    let floor_result = mul_floor_bps(1000, 1); // 0
    let ceil_result = mul_ceil_bps(1000, 1); // 1
    assert_eq!(floor_result, 0);
    assert_eq!(ceil_result, 1);
    assert!(ceil_result > floor_result);
}

// ===== actualize_amount tests =====

#[test]
public fun actualize_share_profits_floor_ok() {
    let base = 100_000;
    let profits = 1_000; // 1% profit
    let amount = 1000;
    // amount * (base + profits) / base = 1000 * 101000 / 100000 = 1010
    let new_amount = actualize_amount(amount, profits, 0, base, false);
    assert_eq!(new_amount, 1010);
}

#[test]
public fun actualize_share_profits_ceil_ok() {
    let base = 100_000;
    let profits = 1_000; // 1% profit
    let amount = 1000;
    // amount * (base + profits) / base = 1000 * 101000 / 100000 = 1010 (exact, so same)
    let new_amount = actualize_amount(amount, profits, 0, base, true);
    assert_eq!(new_amount, 1010);
}

#[test]
public fun actualize_big_share_profits_ok() {
    let base = 100_000;
    let profits = 200_000; // 200% profit
    let amount = 1000;
    // amount * (base + profits) / base = 1000 * 300000 / 100000 = 3000
    let new_amount = actualize_amount(amount, profits, 0, base, false);
    assert_eq!(new_amount, 3000);
}

#[test]
public fun actualize_share_losses_floor_ok() {
    let base = 100_000;
    let losses = 1_000; // 1% loss
    let amount = 1000;
    // amount * (base - losses) / base = 1000 * 99000 / 100000 = 990
    let new_amount = actualize_amount(amount, 0, losses, base, false);
    assert_eq!(new_amount, 990);
}

#[test]
public fun actualize_share_losses_ceil_ok() {
    let base = 100_000;
    let losses = 1_000; // 1% loss
    let amount = 1000;
    // amount * (base - losses) / base = 1000 * 99000 / 100000 = 990 (exact, so same)
    let new_amount = actualize_amount(amount, 0, losses, base, true);
    assert_eq!(new_amount, 990);
}

#[test]
public fun actualize_big_share_losses_ok() {
    let base = 100_000;
    let losses = 99_000; // 99% loss
    let amount = 1000;
    // amount * (base - losses) / base = 1000 * 1000 / 100000 = 10
    let new_amount = actualize_amount(amount, 0, losses, base, false);
    assert_eq!(new_amount, 10);
}

#[test]
public fun actualize_bankruptcy_ok() {
    let base = 100_000;
    let losses = 100_000; // 100% loss
    let amount = 1000;
    // amount * (base - losses) / base = 1000 * 0 / 100000 = 0
    let new_amount = actualize_amount(amount, 0, losses, base, false);
    assert_eq!(new_amount, 0);
}

#[test]
public fun actualize_losses_rounding_difference() {
    let base = 100_000;
    let losses = 1; // Very small loss
    let amount = 1; // Very small amount
    // amount * (base - losses) / base = 1 * 99999 / 100000 = 0.99999
    let floor_result = actualize_amount(amount, 0, losses, base, false); // rounds to 0
    let ceil_result = actualize_amount(amount, 0, losses, base, true); // rounds to 1
    assert_eq!(floor_result, 0);
    assert_eq!(ceil_result, 1);
}

#[test]
public fun actualize_do_nothing_ok() {
    let base = 100_000;
    let amount = 1000;
    let new_amount = actualize_amount(amount, 0, 0, base, false);
    assert_eq!(new_amount, 1000);
}

#[test, expected_failure(abort_code = calculations::ELossTooHigh)]
public fun actualize_invalid_losses_error() {
    let base = 100_000;
    let losses = 100_010; // > 100% loss
    let amount = 1000;
    let _new_amount = actualize_amount(amount, 0, losses, base, false);
    abort 0
}

#[test, expected_failure(abort_code = calculations::EDivisionByZero)]
public fun actualize_zero_base_error() {
    let amount = 1000;
    let _new_amount = actualize_amount(amount, 1000, 0, 0, false);
    abort 0
}

#[test, expected_failure(abort_code = calculations::EOverflow)]
public fun actualize_profits_overflow_error() {
    let base = std::u64::max_value!();
    let profits = 1; // This will cause base + profits to overflow
    let amount = 1000;
    let _new_amount = actualize_amount(amount, profits, 0, base, false);
    abort 0
}

// ===== Edge cases and stress tests =====

#[test]
public fun mul_floor_max_u64_safe_ok() {
    // Test with large but safe values
    let val = 1_000_000_000_000_000_000; // 10^18
    let num = 1;
    let den = 2;
    let result = mul_floor(val, num, den);
    assert_eq!(result, 500_000_000_000_000_000);
}

#[test]
public fun mul_ceil_max_u64_safe_ok() {
    // Test with large but safe values
    let val = 1_000_000_000_000_000_000; // 10^18
    let num = 1;
    let den = 2;
    let result = mul_ceil(val, num, den);
    assert_eq!(result, 500_000_000_000_000_000);
}

#[test]
public fun mul_floor_very_small_ratio_ok() {
    // Test with very small ratio that rounds to zero
    let result = mul_floor(1_000_000, 1, 1_000_000_000);
    assert_eq!(result, 0);
}

#[test]
public fun mul_ceil_very_small_ratio_ok() {
    // Test with very small ratio that rounds up to 1
    let result = mul_ceil(1_000_000, 1, 1_000_000_000);
    assert_eq!(result, 1);
}

#[test]
public fun mul_floor_large_ratio_ok() {
    // Test with ratio > 1
    let result = mul_floor(1000, 3, 2);
    assert_eq!(result, 1500);
}

#[test]
public fun mul_ceil_large_ratio_ok() {
    // Test with ratio > 1
    let result = mul_ceil(1000, 3, 2);
    assert_eq!(result, 1500);
}

// ===== Missing overflow tests =====

#[test, expected_failure(abort_code = calculations::EOverflow)]
public fun mul_floor_overflow_error() {
    // Test overflow: val * num / den > u64::MAX
    // Use values that will cause result to exceed u64::MAX
    // max_u64 = 18_446_744_073_709_551_615
    // We need: val * num / den > max_u64
    // Example: max_u64 * 2 / 1 = overflow
    let val = std::u64::max_value!();
    let num = 2;
    let den = 1;
    let _result = mul_floor(val, num, den);
    abort 0
}

#[test, expected_failure(abort_code = calculations::EOverflow)]
public fun mul_ceil_overflow_error() {
    // Test overflow: (val * num + den - 1) / den > u64::MAX
    let val = std::u64::max_value!();
    let num = 2;
    let den = 1;
    let _result = mul_ceil(val, num, den);
    abort 0
}

#[test, expected_failure(abort_code = calculations::EOverflow)]
public fun mul_floor_bps_overflow_error() {
    // Test overflow with bps: val * bps / 10000 > u64::MAX
    // Use max value with bps that causes overflow
    let val = std::u64::max_value!();
    let bps = 20000; // 200% - will cause overflow
    let _result = mul_floor_bps(val, bps);
    abort 0
}

#[test, expected_failure(abort_code = calculations::EOverflow)]
public fun mul_ceil_bps_overflow_error() {
    // Test overflow with bps
    let val = std::u64::max_value!();
    let bps = 20000; // 200% - will cause overflow
    let _result = mul_ceil_bps(val, bps);
    abort 0
}

// ===== Missing edge cases =====

#[test]
public fun mul_floor_numerator_equals_denominator_ok() {
    // Test when num == den (should return val)
    let result = mul_floor(1000, 5, 5);
    assert_eq!(result, 1000);
}

#[test]
public fun mul_ceil_numerator_equals_denominator_ok() {
    // Test when num == den (should return val)
    let result = mul_ceil(1000, 5, 5);
    assert_eq!(result, 1000);
}

#[test]
public fun mul_floor_numerator_larger_than_denominator_ok() {
    // Test when num > den (ratio > 1)
    let result = mul_floor(100, 3, 2);
    assert_eq!(result, 150);
}

#[test]
public fun mul_ceil_numerator_larger_than_denominator_ok() {
    // Test when num > den (ratio > 1)
    let result = mul_ceil(100, 3, 2);
    assert_eq!(result, 150);
}

#[test]
public fun mul_floor_very_large_numerator_ok() {
    // Test with very large numerator but safe result
    let result = mul_floor(1, 1_000_000_000, 1_000_000);
    assert_eq!(result, 1000);
}

#[test]
public fun mul_ceil_very_large_numerator_ok() {
    // Test with very large numerator but safe result
    let result = mul_ceil(1, 1_000_000_000, 1_000_000);
    assert_eq!(result, 1000);
}

#[test]
public fun mul_floor_very_large_denominator_ok() {
    // Test with very large denominator
    let result = mul_floor(1_000_000_000, 1, 1_000_000_000);
    assert_eq!(result, 1);
}

#[test]
public fun mul_ceil_very_large_denominator_ok() {
    // Test with very large denominator
    let result = mul_ceil(1_000_000_000, 1, 1_000_000_000);
    assert_eq!(result, 1);
}

#[test]
public fun mul_floor_bps_zero_bps_ok() {
    // Test with 0 bps (0%)
    let result = mul_floor_bps(1000, 0);
    assert_eq!(result, 0);
}

#[test]
public fun mul_ceil_bps_zero_bps_ok() {
    // Test with 0 bps (0%)
    let result = mul_ceil_bps(1000, 0);
    assert_eq!(result, 0);
}

#[test]
public fun mul_floor_bps_over_100_percent_ok() {
    // Test with bps > 10000 (over 100%)
    let result = mul_floor_bps(1000, 20000); // 200%
    assert_eq!(result, 2000);
}

#[test]
public fun mul_ceil_bps_over_100_percent_ok() {
    // Test with bps > 10000 (over 100%)
    let result = mul_ceil_bps(1000, 20000); // 200%
    assert_eq!(result, 2000);
}

// ===== Missing actualize_amount tests =====

#[test]
public fun actualize_profits_rounding_difference() {
    // Test that profits with round_up=true vs false can differ
    // Use values that will actually show a difference
    let base = 3;
    let profits = 1;
    let amount = 1;
    // amount * (base + profits) / base = 1 * 4 / 3 = 1.333...
    let floor_result = actualize_amount(amount, profits, 0, base, false); // rounds to 1
    let ceil_result = actualize_amount(amount, profits, 0, base, true); // rounds to 2
    assert_eq!(floor_result, 1);
    assert_eq!(ceil_result, 2);
    assert!(ceil_result > floor_result);
}

#[test]
public fun actualize_losses_exact_100_percent_ok() {
    // Test losses exactly equal to base (100% loss)
    let base = 100_000;
    let losses = 100_000;
    let amount = 1000;
    let new_amount = actualize_amount(amount, 0, losses, base, false);
    assert_eq!(new_amount, 0);
}

#[test]
public fun actualize_losses_exact_100_percent_ceil_ok() {
    // Test losses exactly equal to base with ceil
    let base = 100_000;
    let losses = 100_000;
    let amount = 1000;
    let new_amount = actualize_amount(amount, 0, losses, base, true);
    assert_eq!(new_amount, 0);
}

#[test]
public fun actualize_profits_zero_amount_ok() {
    // Test with zero amount
    let base = 100_000;
    let profits = 1_000;
    let amount = 0;
    let new_amount = actualize_amount(amount, profits, 0, base, false);
    assert_eq!(new_amount, 0);
}

#[test]
public fun actualize_losses_zero_amount_ok() {
    // Test with zero amount
    let base = 100_000;
    let losses = 1_000;
    let amount = 0;
    let new_amount = actualize_amount(amount, 0, losses, base, false);
    assert_eq!(new_amount, 0);
}

#[test]
public fun actualize_profits_large_ratio_ok() {
    // Test with very large profit ratio
    let base = 1;
    let profits = 999; // 99900% profit
    let amount = 1;
    // amount * (base + profits) / base = 1 * 1000 / 1 = 1000
    let new_amount = actualize_amount(amount, profits, 0, base, false);
    assert_eq!(new_amount, 1000);
}

#[test]
public fun actualize_losses_boundary_ok() {
    // Test with losses = base - 1 (just under 100%)
    let base = 100_000;
    let losses = 99_999; // 99.999% loss
    let amount = 1000;
    // amount * (base - losses) / base = 1000 * 1 / 100000 = 0.01 -> rounds to 0
    let new_amount = actualize_amount(amount, 0, losses, base, false);
    assert_eq!(new_amount, 0);
}

#[test]
public fun actualize_losses_boundary_ceil_ok() {
    // Test with losses = base - 1 with ceil
    let base = 100_000;
    let losses = 99_999;
    let amount = 1000;
    // amount * (base - losses) / base = 1000 * 1 / 100000 = 0.01 -> rounds up to 1
    let new_amount = actualize_amount(amount, 0, losses, base, true);
    assert_eq!(new_amount, 1);
}

#[test]
public fun actualize_do_nothing_with_round_up_true_ok() {
    // Test do_nothing path with round_up = true
    let base = 100_000;
    let amount = 1000;
    let new_amount = actualize_amount(amount, 0, 0, base, true);
    assert_eq!(new_amount, 1000);
}

// ===== Boundary value tests =====

#[test]
public fun mul_floor_at_u64_max_boundary_ok() {
    // Test with values that result in exactly u64::MAX
    let val = std::u64::max_value!();
    let num = 1;
    let den = 1;
    let result = mul_floor(val, num, den);
    assert_eq!(result, std::u64::max_value!());
}

#[test]
public fun mul_ceil_at_u64_max_boundary_ok() {
    // Test with values that result in exactly u64::MAX
    let val = std::u64::max_value!();
    let num = 1;
    let den = 1;
    let result = mul_ceil(val, num, den);
    assert_eq!(result, std::u64::max_value!());
}

#[test]
public fun mul_floor_one_over_one_ok() {
    // Test 1/1 = 1
    let result = mul_floor(1, 1, 1);
    assert_eq!(result, 1);
}

#[test]
public fun mul_ceil_one_over_one_ok() {
    // Test 1/1 = 1
    let result = mul_ceil(1, 1, 1);
    assert_eq!(result, 1);
}
