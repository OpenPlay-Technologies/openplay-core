/// Module for financial calculations used in profit/loss sharing and amount actualization.
/// Provides rounding functions that favor the protocol, ensuring all rounding errors accumulate in the protocol's favor.
module openplay_core::calculations;

use openplay_core::core_constants::max_bps;

// === Errors ===
/// Error code for when a calculation result would overflow u64.
const EOverflow: u64 = 2;
/// Error code for when denominator is zero (division by zero).
const EDivisionByZero: u64 = 3;

// === Public Functions ===
/// Multiplies a value by a ratio (numerator/denominator), rounding DOWN (floor/truncating).
/// Use this when the protocol pays out (e.g., profits to users).
/// This favors the protocol by paying slightly less.
/// Formula: floor(val * num / den) = (val * num) / den (truncated)
///
/// # Errors
/// - `EDivisionByZero`: If denominator is zero
/// - `EOverflow`: If the result would overflow u64
public fun mul_floor(val: u64, numerator: u64, denominator: u64): u64 {
    assert!(denominator > 0, EDivisionByZero);
    // Calculate using u128 to avoid overflow: (val * num) / den
    let val_128 = (val as u128);
    let num_128 = (numerator as u128);
    let den_128 = (denominator as u128);
    let result = (val_128 * num_128) / den_128;
    // Check if result fits in u64
    assert!(result <= (std::u64::max_value!() as u128), EOverflow);
    (result as u64)
}

/// Multiplies a value by a ratio (numerator/denominator), rounding UP (ceiling).
/// Use this when users owe the protocol (e.g., fees, losses).
/// This favors the protocol by collecting slightly more.
/// Formula: ceil(val * num / den) = (val * num + den - 1) / den
///
/// # Errors
/// - `EDivisionByZero`: If denominator is zero
/// - `EOverflow`: If the result would overflow u64
public fun mul_ceil(val: u64, numerator: u64, denominator: u64): u64 {
    assert!(denominator > 0, EDivisionByZero);
    // Calculate using u128 to avoid overflow: (val * num + den - 1) / den
    // Since val and num are u64, product is at most (2^64 - 1)^2 < 2^128, so multiplication is safe
    // Since den is u64, adding (den - 1) is also safe
    let val_128 = (val as u128);
    let num_128 = (numerator as u128);
    let den_128 = (denominator as u128);
    let product = val_128 * num_128;
    let result = (product + den_128 - 1) / den_128;
    // Check if result fits in u64
    assert!(result <= (std::u64::max_value!() as u128), EOverflow);
    (result as u64)
}

/// Multiplies a value by a basis points ratio (bps / 10000), rounding DOWN (floor/truncating).
/// Convenience function for calculations using basis points (bps).
/// Use this when the protocol pays out (e.g., profits to users).
/// This favors the protocol by paying slightly less.
///
/// # Example
/// ```
/// let fee_bps = 100; // 1%
/// let amount = 1000;
/// let fee = mul_floor_bps(amount, fee_bps); // Returns 10 (1% of 1000, rounded down)
/// ```
public fun mul_floor_bps(val: u64, bps: u64): u64 {
    mul_floor(val, bps, max_bps())
}

/// Multiplies a value by a basis points ratio (bps / 10000), rounding UP (ceiling).
/// Convenience function for calculations using basis points (bps).
/// Use this when users owe the protocol (e.g., fees, losses).
/// This favors the protocol by collecting slightly more.
///
/// # Example
/// ```
/// let fee_bps = 100; // 1%
/// let amount = 1000;
/// let fee = mul_ceil_bps(amount, fee_bps); // Returns 10 (1% of 1000, rounded up)
/// ```
public fun mul_ceil_bps(val: u64, bps: u64): u64 {
    mul_ceil(val, bps, max_bps())
}
