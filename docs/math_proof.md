# Mathematical Proof: Can actual_unstake > remaining_stake?

## Given:
- `S` = prev_stake (stake before losses)
- `U` = pending_unstake (amount to unstake)
- `L` = losses
- Constraint: `U <= S` (you can't unstake more than you have)
- Constraint: `L <= S` (losses can't exceed stake)

## After losses:
- `remaining_stake = S - L`

## Actualized unstake:
- `actual_unstake = mul_ceil(U, S - L, S)`
- `mul_ceil(val, num, den) = (val * num + den - 1) / den`
- So: `actual_unstake = (U * (S - L) + S - 1) / S`

## Question: Can `actual_unstake > remaining_stake`?

We need to check if: `(U * (S - L) + S - 1) / S > S - L`

Multiplying both sides by S (S > 0):
`U * (S - L) + S - 1 > S * (S - L)`

Expanding:
`U * (S - L) + S - 1 > S^2 - S*L`

Rearranging:
`U * (S - L) > S^2 - S*L - S + 1`
`U * (S - L) > S * (S - L) - S + 1`
`U * (S - L) > (S - L) * S - (S - 1)`

Since `S - L > 0` (assuming L < S), we can divide:
`U > S - (S - 1) / (S - L)`

## Analysis:

For this to be possible, we need:
`U > S - (S - 1) / (S - L)`

But we know `U <= S` from constraints.

So we need: `S - (S - 1) / (S - L) < S`
Which means: `(S - 1) / (S - L) > 0`

This is always true when `L < S - 1`.

But we also need: `S - (S - 1) / (S - L) < U <= S`

## Case 1: U = S (unstake everything)
When U = S:
`actual_unstake = (S * (S - L) + S - 1) / S = (S^2 - S*L + S - 1) / S = S - L + 1 - 1/S`

Since we're using integer division:
`actual_unstake = floor((S^2 - S*L + S - 1) / S) = S - L` (when (S - 1) < S, which is always true)

Wait, let me recalculate with ceiling:
`actual_unstake = ceil(S * (S - L) / S) = ceil(S - L) = S - L` (since S - L is an integer)

Actually, let me use the exact formula:
`actual_unstake = (S * (S - L) + S - 1) / S = (S^2 - S*L + S - 1) / S = S - L + (S - 1) / S`

Since (S - 1) / S < 1, and we're doing integer division:
`actual_unstake = S - L` (exactly)

So when U = S, `actual_unstake = remaining_stake` exactly.

## Case 2: U < S (partial unstake)
When U < S:
`actual_unstake = (U * (S - L) + S - 1) / S`

We need to check if this can be > S - L.

`(U * (S - L) + S - 1) / S > S - L`
`U * (S - L) + S - 1 > S * (S - L)`
`U * (S - L) > S * (S - L) - S + 1`
`U > S - (S - 1) / (S - L)`

Since U <= S, we need:
`S - (S - 1) / (S - L) < S`
Which is: `(S - 1) / (S - L) > 0` ✓ (always true when L < S)

But we also need the right side to be less than S, meaning:
`S - (S - 1) / (S - L) < S`
Which simplifies to: `(S - 1) / (S - L) > 0` ✓

However, for U to satisfy `U > S - (S - 1) / (S - L)`, we need:
`S - (S - 1) / (S - L) < S`

Let's check: `S - (S - 1) / (S - L) < S`
This means: `(S - 1) / (S - L) > 0` ✓

But `(S - 1) / (S - L)` is at least 1 when `L >= 1` and `S - L <= S - 1`, which means `L >= 1`.

So: `S - (S - 1) / (S - L) <= S - 1`

This means we'd need `U > S - 1`, but since U is an integer and U <= S, the only possibility is U = S.

But we already proved that when U = S, `actual_unstake = remaining_stake` exactly.

Therefore, `actual_unstake > remaining_stake` is **mathematically impossible**!

