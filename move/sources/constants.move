module openplay::constants;
// === Imports ===
use std::uq32_32::{UQ32_32, from_quotient};

// === Constant ===
const OWNER_FEE_BPS: u64 = 50; // in bps , taken on bets
const PROTOCOL_FEE_BPS: u64 = 50; // in bps , taken on bets

// === Public-View Functions ===

public fun owner_fee(): UQ32_32 {
    from_quotient(OWNER_FEE_BPS, 10000)
}

public fun protocol_fee(): UQ32_32 {
    from_quotient(PROTOCOL_FEE_BPS, 10000)
}