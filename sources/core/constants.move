module openplay::constants;
// === Imports ===
use std::uq32_32::{UQ32_32, from_quotient};
use std::string::{String, utf8};

// === Constant ===
const OWNER_FEE_BPS: u64 = 50; // in bps , taken on bets
const PROTOCOL_FEE_BPS: u64 = 50; // in bps , taken on bets
const PRECISION_ERROR_ALLOWANCE: u64 = 2;

// === Public-View Functions ===

public fun owner_fee(): UQ32_32 {
    from_quotient(OWNER_FEE_BPS, 10000)
}

public fun protocol_fee(): UQ32_32 {
    from_quotient(PROTOCOL_FEE_BPS, 10000)
}

public fun precision_error_allowance(): u64 {
    PRECISION_ERROR_ALLOWANCE
}

public fun type_coin_flip(): String {
    utf8(b"CoinFlip")
}