# Complete Mathematical Proof: actual_unstake <= remaining_stake

## Question
Can `actual_unstake_amount > remaining_stake` occur when losses are applied to a participation?

## Answer
**No, this is mathematically impossible** with our rounding strategy and constraints.

## Given
- `S` = prev_stake (stake before losses)
- `U` = pending_unstake (amount to unstake)
- `L` = losses
- **Constraints:**
  - `U <= S` (you can't unstake more than you have)
  - `L <= S` (losses cannot exceed stake - enforced by `assert!(self.stake >= losses)`)

## Why L <= S is Guaranteed

Losses are calculated per user using:
```move
user_loss = mul_ceil(total_losses, user_stake, total_stake)
```

**Mathematical proof that user_loss <= user_stake when total_losses <= total_stake:**

We need: `user_loss > user_stake`
i.e., `(total_losses * user_stake + total_stake - 1) / total_stake > user_stake`

This simplifies to: `total_losses > total_stake - 1 + 1/user_stake`

Since `1/user_stake <= 1` when `user_stake >= 1`:
`total_losses > total_stake - 1 + 1/user_stake <= total_stake`

So we need: `total_losses > total_stake`

But we have the constraint: `total_losses <= total_stake` (enforced at house level)

**Therefore: `user_loss <= user_stake` always holds when `total_losses <= total_stake`.**

This is enforced by `assert!(self.stake >= losses, EInvalidProfitsOrLosses)` before deducting losses.

## After Losses
- `remaining_stake = S - L`

## Actualized Unstake
- `actual_unstake = mul_ceil(U, S - L, S)`
- Formula: `actual_unstake = (U * (S - L) + S - 1) / S`

## Complete Proof

### Case 1: L = S (losses equal stake)

- `remaining_stake = S - S = 0`
- `actual_unstake = mul_ceil(U, 0, S) = (U * 0 + S - 1) / S = (S - 1) / S = 0`
  - (Integer division: since `(S - 1) / S < 1`, result is `0`)
- **Result:** `0 <= 0` ✓

### Case 2: L < S (losses less than stake)

- `remaining_stake = S - L > 0`
- We need to prove: `(U * (S - L) + S - 1) / S <= S - L`

**Proof:**
1. Multiplying both sides by S: `U * (S - L) + S - 1 <= S * (S - L)`
2. Rearranging: `U * (S - L) <= S * (S - L) - S + 1`
3. Dividing by `(S - L) > 0`: `U <= S - (S - 1) / (S - L)`
4. Since `(S - 1) / (S - L) >= 1` when `L >= 1`: `S - (S - 1) / (S - L) <= S - 1`
5. So we need: `U <= S - 1`
6. Given `U <= S`:
   - When `U = S`: `actual_unstake = S - L = remaining_stake` (exactly equal) ✓
   - When `U < S`: `U <= S - 1`, so `actual_unstake <= remaining_stake` ✓

## Conclusion

**`actual_unstake <= remaining_stake` is ALWAYS true!**

The edge case where `actual_unstake > remaining_stake` is **mathematically impossible** with:
1. Our rounding strategy (ceiling rounding for losses)
2. The constraint `L <= S` (enforced by assertion)
3. The constraint `U <= S` (enforced by unstake validation)
4. The constraint `total_losses <= total_stake` (enforced at house level)

## Verification

Tested with Python script across multiple scenarios:
- L = S (losses equal stake)
- L < S (various loss percentages)
- U = S (unstake everything)
- U < S (partial unstake)
- Small and large values
- Edge cases with very small remaining stake

**Result: No violations found. The property always holds.**

## Runtime Enforcement

The mathematical property is enforced at runtime with an assertion:
- `assert!(actual_unstake_amount <= self.stake, EActualizedUnstakeExceedsStake)`
- If this assertion fails, it indicates a bug in rounding logic or constraint enforcement
- The assertion serves as both a runtime check and documentation of the mathematical guarantee

