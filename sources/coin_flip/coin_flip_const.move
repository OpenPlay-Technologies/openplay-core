/// Module for defining constants in the CoinFlip game.
module openplay::coin_flip_const;

use std::string::{String, utf8};
// use std::uq32_32::{UQ32_32, from_quotient};

// === Constants ===
const MAX_HOUSE_EDGE_BPS: u64 = 10_000; // This is 100% , so house always wins in that case
const MAX_PAYOUT_FACTOR_BPS: u64 = 100_000_000; // This is 10_000 times the stake or 1_000_000%
const MAX_RECENT_THROWS: u64 = 10;

// === Public-View Functions ===
public fun max_house_edge_bps(): u64 {
    MAX_HOUSE_EDGE_BPS
}

public fun max_payout_factor_bps(): u64 {
    MAX_PAYOUT_FACTOR_BPS
}

public fun max_recent_throws(): u64 {
    MAX_RECENT_THROWS
}

public fun head_result(): String {
    utf8(b"Head")
}

public fun tail_result(): String {
    utf8(b"Tail")
}

public fun house_bias_result(): String {
    utf8(b"HouseBias")
}

public fun new_status(): String {
    utf8(b"New")
}

public fun initialized_status(): String {
    utf8(b"Initialized")
}

public fun settled_status(): String {
    utf8(b"Settled")
}

public fun place_bet_action(): String {
    utf8(b"PlaceBet")
}
