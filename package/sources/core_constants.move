/// Module containing core constants used throughout the OpenPlay protocol.
module openplay_core::core_constants;

use std::string::{String, utf8};

// === Constants ===
/// Current version of the OpenPlay core package.
const CURRENT_VERSION: u64 = 1;

/// Returns the maximum basis points value (10000 = 100%).
/// Used for fee calculations where fees are expressed in basis points.
public fun max_bps(): u64 {
    10_000
}

/// Returns the transaction type string for bet transactions.
public fun tx_type_bet(): String {
    utf8(b"Bet")
}

/// Returns the transaction type string for win transactions.
public fun tx_type_win(): String {
    utf8(b"Win")
}

/// Returns the current version of the OpenPlay core package.
public fun current_version(): u64 {
    CURRENT_VERSION
}

/// Maximum protocol fee in basis points (20% = 2000 bps).
/// Protocol fees cannot exceed this to ensure reasonable staker returns.
public fun max_protocol_fee_bps(): u64 {
    2_000
}

/// Maximum combined house and collector fees in basis points (50% = 5000 bps).
/// House fee + collector fee cannot exceed this to ensure at least 30% remains for stakers.
public fun max_house_and_collector_fees_bps(): u64 {
    5_000
}
