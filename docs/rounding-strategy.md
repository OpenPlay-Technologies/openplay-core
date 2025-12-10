# OpenPlay Core Rounding Strategy

## Overview

The OpenPlay protocol uses a **protocol-favoring rounding strategy** where all rounding errors accumulate in favor of the protocol. This ensures that over time, small rounding discrepancies create a small surplus in the vault rather than a deficit.

**Core Principle:** Rounding always favors the protocol, never the users.

## Rounding Functions

The protocol provides two fundamental rounding functions in the `calculations` module:

### 1. `mul_floor(val, numerator, denominator)` - Round DOWN

**When to use:** When the protocol **pays out** funds (e.g., share sales, NAV calculations)

**Formula:** `floor(val * num / den) = (val * num) / den` (truncated)

**Effect:** Rounds down, so the protocol pays slightly less than the exact amount.

**Example:**
```move
// User should receive 333.33 MIST, but protocol pays 333 MIST
mul_floor(1000, 1, 3) = 333  // 1000 * 1 / 3 = 333.33... → 333
```

### 2. `mul_ceil(val, numerator, denominator)` - Round UP

**When to use:** When users **owe** the protocol (e.g., fees, losses)

**Formula:** `ceil(val * num / den) = (val * num + den - 1) / den`

**Effect:** Rounds up, so the protocol collects slightly more than the exact amount.

**Example:**
```move
// User should owe 333.33 MIST, but protocol collects 334 MIST
mul_ceil(1000, 1, 3) = 334  // 1000 * 1 / 3 = 333.33... → 334
```

### 3. Basis Points Convenience Functions

For calculations using basis points (bps), where 10,000 bps = 100%:

- **`mul_floor_bps(val, bps)`** - Rounds DOWN (protocol pays less)
- **`mul_ceil_bps(val, bps)`** - Rounds UP (protocol collects more)

These are convenience wrappers that use `max_bps() = 10,000` as the denominator.

## Rounding Locations in the Protocol

### 1. GGR-Based Fee Calculations (Epoch End)

**Location:** `house_state.move::process_end_of_day()`

**Functions:** 
- `mul_ceil_bps(ggr, protocol_fee_bps)` - Protocol fee
- `mul_ceil_bps(ggr, house_fee_bps)` - House fee  
- `mul_ceil_bps(ggr, fee_collector_share_bps)` - Collector fees

**Rounding Direction:** **UP** (ceiling)

**Rationale:** Fees are amounts owed to the protocol, house admin, and game creators. Rounding up ensures these parties collect slightly more fees.

**Example:**
```move
// GGR: 1000 MIST
// Protocol fee: 10% (1000 bps)
// Exact fee: 100.0 MIST
// Collected fee: 100 MIST (exact in this case)
// If exact was 100.1 MIST, protocol would collect 101 MIST
```

**Applies to:**
- Protocol fees (collected by OpenPlay admin)
- House performance fees (collected by house admin)
- Collector fees (collected by game creators)

### 2. NAV Calculation for Share Sales

**Location:** `house.move::sell_shares()`

**Function:** `mul_floor(shares_to_sell, effective_value, total_shares)`

**Rounding Direction:** **DOWN** (floor)

**Rationale:** When users sell shares, the payout is calculated from NAV. Rounding down ensures the protocol pays slightly less.

**Example:**
```move
// Shares to sell: 1000
// Effective house balance: 10,500 MIST
// Total shares: 10,000
// Exact payout: 1050.0 MIST
// User receives: 1050 MIST (exact in this case)
// If exact was 1050.5 MIST, user would receive 1050 MIST
```

### 3. Share Calculation for Purchases

**Location:** `house.move::buy_shares()`

**Function:** `mul_floor(deposit_amount, total_shares, effective_value)`

**Rounding Direction:** **DOWN** (floor)

**Rationale:** When users buy shares, we calculate how many shares their deposit buys. Rounding down means users get slightly fewer shares, favoring the protocol.

**Example:**
```move
// Deposit: 1000 MIST
// Effective house balance: 10,000 MIST
// Total shares: 10,000
// Exact shares: 1000.0 shares
// User gets: 1000 shares (exact in this case)
// If exact was 1000.5 shares, user would get 1000 shares
```

### 4. Pending Fee Calculations for NAV

**Location:** `house_state.move::calculate_total_pending_fees()`

**Function:** `mul_ceil_bps(ggr, total_fee_bps)`

**Rounding Direction:** **UP** (ceiling)

**Rationale:** When calculating NAV, pending fees are subtracted from house balance. Rounding fees UP means effective balance is slightly LOWER, giving users slightly less value per share. This favors the protocol.

## Mathematical Formulas

### Floor Rounding (Round Down)
```
result = floor(val * num / den) = (val * num) / den
```
- Uses integer division (truncation)
- Always rounds toward zero
- Protocol pays less

### Ceiling Rounding (Round Up)
```
result = ceil(val * num / den) = (val * num + den - 1) / den
```
- Adds `(den - 1)` before division
- Always rounds away from zero
- Protocol collects more

### Basis Points Calculation
```
result = floor/ceil(val * bps / 10000)
```
- `max_bps() = 10,000` represents 100%
- `bps = 100` represents 1%
- `bps = 2000` represents 20%

## Rounding Impact Analysis

### Maximum Rounding Error Per Operation

| Operation | Max Error | Frequency | Cumulative Impact |
|-----------|-----------|-----------|-------------------|
| Fee calculation | 1 MIST | Per epoch per fee type | Negligible |
| Share purchase | 1 share | Per purchase | Small surplus |
| Share sale | 1 MIST | Per sale | Small surplus |
| NAV calculation | 1 MIST | Per NAV query | Favors protocol |

### Cumulative Effect

Over time, rounding errors accumulate in the vault as small surpluses:

- **Per epoch:** Maximum 1 MIST rounding error per fee type
- **Per transaction:** Maximum 1 MIST or 1 share rounding error
- **Long-term:** These small amounts accumulate in the vault, creating a safety buffer

**Example Scenario:**
- 1,000 share transactions per epoch
- 100 epochs
- Average 1 MIST rounding error per transaction
- Total accumulation: ~100,000 MIST = 0.0001 SUI

This is a **bounded and negligible** amount that provides a small safety buffer for the protocol.

## Implementation Details

### Overflow Protection

All rounding functions:
1. Use `u128` arithmetic for intermediate calculations to prevent overflow
2. Check that results fit in `u64` before returning
3. Abort with `EOverflow` if result would exceed `u64::MAX`

### Error Handling

The rounding functions handle two error cases:
- **`EDivisionByZero`**: Denominator is zero
- **`EOverflow`**: Result would exceed `u64::MAX`

### No Precision Error Allowance

The protocol **does not** use a precision error allowance in production code. All calculations must be exact or round according to the protocol-favoring strategy. Any mismatch will cause the transaction to abort, ensuring strict accounting.

## Decision Matrix

Use this matrix to determine which rounding function to use:

| Scenario | Who Benefits from Rounding? | Rounding Direction | Function |
|----------|----------------------------|-------------------|----------|
| Protocol pays users | Protocol (pays less) | DOWN (floor) | `mul_floor` / `mul_floor_bps` |
| Users owe protocol | Protocol (collects more) | UP (ceiling) | `mul_ceil` / `mul_ceil_bps` |
| Fee collection (GGR-based) | Protocol (collects more) | UP (ceiling) | `mul_ceil_bps` |
| Share sale payout | Protocol (pays less) | DOWN (floor) | `mul_floor` |
| Share purchase calculation | Protocol (gives fewer shares) | DOWN (floor) | `mul_floor` |
| Pending fee calculation | Protocol (lower NAV) | UP (ceiling) | `mul_ceil_bps` |

## Examples

### Example 1: GGR-Based Fee Calculation
```move
// GGR: 1000 MIST (bet - win for the epoch)
// Protocol fee: 10% (1000 bps)
let protocol_fee = mul_ceil_bps(1000, 1000);
// Result: 100 MIST (exact in this case)
// If GGR was 1001 MIST: fee = 101 MIST (rounded up from 100.1)
```

### Example 2: Share Sale
```move
// Shares to sell: 333 shares
// Effective house balance: 10,000 MIST
// Total shares: 10,000
let payout = mul_floor(333, 10000, 10000);
// Result: 333 MIST (exact in this case)
// Remaining shares worth 9667 MIST
```

### Example 3: Share Purchase
```move
// Deposit: 333 MIST
// Effective house balance: 10,000 MIST
// Total shares: 10,000
let shares_minted = mul_floor(333, 10000, 10000);
// Result: 333 shares (exact in this case)
// If deposit was 333.5 MIST: still 333 shares (rounded down)
```

### Example 4: Collector Fee Calculation
```move
// Collector GGR: 500 MIST
// Collector share: 20% (2000 bps)
let collector_fee = mul_ceil_bps(500, 2000);
// Result: 100 MIST (exact in this case)
// If GGR was 501 MIST: fee = 101 MIST (rounded up from 100.2)
```

## Changes from v2.1

In v3.1, the following rounding-related changes were made:

1. **Removed `actualize_amount()` function**: No longer needed in share-based model
2. **Removed stake profit/loss distribution**: Shares have NAV instead
3. **Added GGR-based fee calculations**: All fees from epoch GGR
4. **Added share purchase/sale rounding**: NAV-based calculations
5. **Removed `ELossTooHigh` error**: No longer applicable

The core principle remains: **all rounding favors the protocol**.

## Summary

The OpenPlay protocol uses a **strict protocol-favoring rounding strategy**:

1. **When protocol pays:** Round DOWN (floor) → Protocol pays less
2. **When users owe:** Round UP (ceiling) → Protocol collects more
3. **No tolerance:** All calculations must be exact or round according to strategy
4. **Bounded impact:** Maximum 1 MIST or 1 share rounding error per operation
5. **Cumulative effect:** Small surpluses accumulate in vault over time
6. **GGR-based fees:** All fees calculated from Gross Gaming Revenue at epoch end

This ensures that all rounding errors work in favor of the protocol, creating a small safety buffer while maintaining strict accounting accuracy.
