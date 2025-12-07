# OpenPlay Core Rounding Strategy

## Overview

The OpenPlay protocol uses a **protocol-favoring rounding strategy** where all rounding errors accumulate in favor of the protocol. This ensures that over time, small rounding discrepancies create a small surplus in the vault rather than a deficit.

**Core Principle:** Rounding always favors the protocol, never the users.

## Rounding Functions

The protocol provides two fundamental rounding functions in the `calculations` module:

### 1. `mul_floor(val, numerator, denominator)` - Round DOWN

**When to use:** When the protocol **pays out** funds (e.g., profits to users)

**Formula:** `floor(val * num / den) = (val * num) / den` (truncated)

**Effect:** Rounds down, so the protocol pays slightly less than the exact amount.

**Example:**
```move
// User should receive 10.5 MIST, but protocol pays 10 MIST
mul_floor(1000, 1, 3) = 333  // 1000 * 1 / 3 = 333.33... → 333
```

### 2. `mul_ceil(val, numerator, denominator)` - Round UP

**When to use:** When users **owe** the protocol (e.g., fees, losses)

**Formula:** `ceil(val * num / den) = (val * num + den - 1) / den`

**Effect:** Rounds up, so the protocol collects slightly more than the exact amount.

**Example:**
```move
// User should owe 10.5 MIST, but protocol collects 11 MIST
mul_ceil(1000, 1, 3) = 334  // 1000 * 1 / 3 = 333.33... → 334
```

### 3. Basis Points Convenience Functions

For calculations using basis points (bps), where 10,000 bps = 100%:

- **`mul_floor_bps(val, bps)`** - Rounds DOWN (protocol pays less)
- **`mul_ceil_bps(val, bps)`** - Rounds UP (protocol collects more)

These are convenience wrappers that use `max_bps() = 10,000` as the denominator.

## Rounding Locations in the Protocol

### 1. Fee Calculations

**Location:** `house_state.move::calculate_fee()`

**Function:** `mul_ceil_bps(tx.amount(), fee_bps)`

**Rounding Direction:** **UP** (ceiling)

**Rationale:** Fees are amounts users owe to the protocol. Rounding up ensures the protocol collects slightly more fees.

**Example:**
```move
// Transaction amount: 1000 MIST
// Fee: 1% (100 bps)
// Exact fee: 10.0 MIST
// Collected fee: 10 MIST (exact in this case)
// If exact was 10.1 MIST, protocol would collect 11 MIST
```

**Applies to:**
- Game fees (collected by game owners)
- Protocol fees (collected by OpenPlay admin)

### 2. House Performance Fee

**Location:** `house.move::process_end_of_day()`

**Function:** `mul_ceil_bps(profits, house_fee_bps)`

**Rounding Direction:** **UP** (ceiling)

**Rationale:** Performance fees are deducted from profits. Rounding up ensures the house admin collects slightly more fees, leaving slightly less for stakers.

**Example:**
```move
// Profits: 1000 MIST
// House fee: 20% (2000 bps)
// Exact fee: 200.0 MIST
// Collected fee: 200 MIST
// If exact was 200.1 MIST, house would collect 201 MIST
```

### 3. Profit Distribution to Stakers

**Location:** `house_state.move::calculate_ggr_share()`

**Function:** `mul_floor(end_of_day.day_profits, account_stake, epoch_volume.active_stake_amount)`

**Rounding Direction:** **DOWN** (floor)

**Rationale:** Profits are amounts the protocol pays to stakers. Rounding down ensures the protocol pays slightly less, creating a small surplus.

**Example:**
```move
// Total profits: 1000 MIST
// User stake: 333 MIST
// Total stake: 1000 MIST
// User's share: 33.3%
// Exact profit: 333.33... MIST
// User receives: 333 MIST (rounded down)
// Remaining: 0.33... MIST stays in vault
```

### 4. Loss Distribution to Stakers

**Location:** `house_state.move::calculate_ggr_share()`

**Function:** `mul_ceil(end_of_day.day_losses, account_stake, epoch_volume.active_stake_amount)`

**Rounding Direction:** **UP** (ceiling)

**Rationale:** Losses are amounts users owe (their stake decreases). Rounding up ensures users absorb slightly more losses than their exact proportional share, ensuring all losses are fully distributed.

**Example:**
```move
// Total losses: 1000 MIST
// User stake: 333 MIST
// Total stake: 1000 MIST
// User's share: 33.3%
// Exact loss: 333.33... MIST
// User loses: 334 MIST (rounded up)
// This ensures total losses are fully absorbed
```

### 5. Unstake Amount Actualization (with Profits)

**Location:** `participation.move::process_end_of_day()` and `house_state.move::process_end_of_day()`

**Function:** `actualize_amount(pending_unstake, profits, 0, prev_active_stake, round_up=false)`

**Rounding Direction:** **DOWN** (floor)

**Rationale:** When there are profits, the unstake amount increases. Rounding down ensures the user receives slightly less than the exact amount, favoring the protocol.

**Example:**
```move
// Pending unstake: 1000 MIST
// Profits: 100 MIST (10% profit)
// Base stake: 1000 MIST
// Exact unstake: 1100 MIST
// User receives: 1100 MIST (exact in this case)
// If exact was 1100.1 MIST, user would receive 1100 MIST
```

### 6. Unstake Amount Actualization (with Losses)

**Location:** `participation.move::process_end_of_day()` and `house_state.move::process_end_of_day()`

**Function:** `actualize_amount(pending_unstake, 0, losses, prev_active_stake, round_up=true)`

**Rounding Direction:** **UP** (ceiling)

**Rationale:** When there are losses, the unstake amount decreases. Rounding up ensures the user receives even less (or the protocol keeps more), favoring the protocol.

**Example:**
```move
// Pending unstake: 1000 MIST
// Losses: 100 MIST (10% loss)
// Base stake: 1000 MIST
// Exact unstake: 900 MIST
// User receives: 900 MIST (exact in this case)
// If exact was 899.9 MIST, user would receive 900 MIST (rounded up)
```

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
| Fee calculation | 1 MIST | Per transaction | Negligible |
| Profit distribution | 1 MIST | Per user per epoch | Small surplus in vault |
| Loss distribution | 1 MIST | Per user per epoch | Ensures full loss absorption |
| Unstake actualization | 1 MIST | Per unstake | Small surplus in vault |

### Cumulative Effect

Over time, rounding errors accumulate in the vault as small surpluses:

- **Per transaction:** Maximum 1 MIST rounding error
- **Per epoch:** Maximum 1 MIST per user for profit/loss distribution
- **Long-term:** These small amounts accumulate in the vault, creating a safety buffer

**Example Scenario:**
- 1,000 users
- 10,000 epochs
- Average 1 MIST rounding error per user per epoch
- Total accumulation: ~10,000,000 MIST = 0.01 SUI

This is a **bounded and negligible** amount that provides a small safety buffer for the protocol.

## Implementation Details

### Overflow Protection

All rounding functions:
1. Use `u128` arithmetic for intermediate calculations to prevent overflow
2. Check that results fit in `u64` before returning
3. Abort with `EOverflow` if result would exceed `u64::MAX`

### Error Handling

The rounding functions handle three error cases:
- **`EDivisionByZero`**: Denominator is zero
- **`EOverflow`**: Result would exceed `u64::MAX`
- **`ELossTooHigh`**: Losses exceed base (in `actualize_amount`)

### No Precision Error Allowance

The protocol **does not** use a precision error allowance in production code. All calculations must be exact or round according to the protocol-favoring strategy. Any mismatch will cause the transaction to abort, ensuring strict accounting.

## Decision Matrix

Use this matrix to determine which rounding function to use:

| Scenario | Who Benefits from Rounding? | Rounding Direction | Function |
|----------|----------------------------|-------------------|----------|
| Protocol pays users | Protocol (pays less) | DOWN (floor) | `mul_floor` / `mul_floor_bps` |
| Users owe protocol | Protocol (collects more) | UP (ceiling) | `mul_ceil` / `mul_ceil_bps` |
| Profit distribution | Protocol (pays less) | DOWN (floor) | `mul_floor` |
| Loss distribution | Protocol (users owe more) | UP (ceiling) | `mul_ceil` |
| Fee collection | Protocol (collects more) | UP (ceiling) | `mul_ceil_bps` |
| Unstake with profits | Protocol (pays less) | DOWN (floor) | `actualize_amount(..., round_up=false)` |
| Unstake with losses | Protocol (keeps more) | UP (ceiling) | `actualize_amount(..., round_up=true)` |

## Examples

### Example 1: Fee Calculation
```move
// Transaction: 1000 MIST bet
// Game fee: 1% (100 bps)
let fee = mul_ceil_bps(1000, 100);
// Result: 10 MIST (exact in this case)
// If amount was 1001 MIST: fee = 11 MIST (rounded up from 10.01)
```

### Example 2: Profit Distribution
```move
// Total profits: 1000 MIST
// User stake: 333 MIST
// Total stake: 1000 MIST
let user_profit = mul_floor(1000, 333, 1000);
// Result: 333 MIST (rounded down from 333.33...)
// Remaining 0.33... MIST stays in vault
```

### Example 3: Loss Distribution
```move
// Total losses: 1000 MIST
// User stake: 333 MIST
// Total stake: 1000 MIST
let user_loss = mul_ceil(1000, 333, 1000);
// Result: 334 MIST (rounded up from 333.33...)
// Ensures all losses are fully absorbed
```

### Example 4: Unstake with Profits
```move
// Pending unstake: 1000 MIST
// Profits: 100 MIST (10% profit)
// Base stake: 1000 MIST
let actual_unstake = actualize_amount(1000, 100, 0, 1000, false);
// Calculation: 1000 * 1100 / 1000 = 1100 MIST
// Result: 1100 MIST (exact in this case)
```

### Example 5: Unstake with Losses
```move
// Pending unstake: 1000 MIST
// Losses: 100 MIST (10% loss)
// Base stake: 1000 MIST
let actual_unstake = actualize_amount(1000, 0, 100, 1000, true);
// Calculation: 1000 * 900 / 1000 = 900 MIST
// Result: 900 MIST (exact in this case)
// If calculation resulted in 899.9, would round up to 900
```

## Summary

The OpenPlay protocol uses a **strict protocol-favoring rounding strategy**:

1. **When protocol pays:** Round DOWN (floor) → Protocol pays less
2. **When users owe:** Round UP (ceiling) → Protocol collects more
3. **No tolerance:** All calculations must be exact or round according to strategy
4. **Bounded impact:** Maximum 1 MIST rounding error per operation
5. **Cumulative effect:** Small surpluses accumulate in vault over time

This ensures that all rounding errors work in favor of the protocol, creating a small safety buffer while maintaining strict accounting accuracy.

