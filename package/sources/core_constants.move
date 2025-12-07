/// Module containing core constants used throughout the OpenPlay protocol.
module openplay_core::core_constants;

use std::string::{String, utf8};

// === Constant ===
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
