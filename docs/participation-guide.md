# House Participation Guide

## Overview

This guide explains how to become a shareholder in an OpenPlay house, what fees apply, and what returns you can expect. OpenPlay uses a **share-based participation model** where you buy and sell shares valued at NAV (Net Asset Value).

## Key Highlights

- ✅ **No Lock-Up Period**: Sell your shares anytime and receive funds immediately
- ✅ **NAV-Based Valuation**: Share value reflects true house performance
- ✅ **Transparent Fees**: All fees calculated from GGR at epoch end
- ✅ **Instant Liquidity**: Buy and sell shares in a single transaction
- ✅ **Proportional Ownership**: Your shares represent proportional ownership of the house

## How It Works

### 1. Create a Participation

Before you can buy shares in a house, you need to create a Participation object:

```move
// Create a participation for a house
let participation = house.new_participation(ctx);
```

This creates your "account" for that specific house. You need one Participation per house you want to invest in.

### 2. Buy Shares

Once you have a Participation, you can buy shares:

```move
// Buy shares with SUI
house.buy_shares(&mut participation, sui_coins, ctx);
```

The number of shares you receive depends on the current NAV:

```
shares_received = deposit_amount × total_shares / effective_house_balance
```

**Example**: If NAV is 1.05 SUI per share and you deposit 105 SUI, you receive 100 shares.

### 3. Monitor Your Investment

Your share value changes based on house performance:

- **When players lose** (positive GGR): House balance increases → NAV increases → your shares are worth more
- **When players win** (negative GGR): House balance decreases → NAV decreases → your shares are worth less

You can check your current value at any time:

```
your_value = your_shares × NAV
```

### 4. Sell Shares

When you want to exit, simply sell your shares:

```move
// Sell shares and receive SUI immediately
let sui_coins = house.sell_shares(&mut participation, shares_to_sell, ctx);
```

**No lock-up period**: You receive your funds immediately in the same transaction.

The payout is calculated at current NAV:

```
payout = shares_sold × effective_house_balance / total_shares
```

## Understanding NAV (Net Asset Value)

NAV is the value of each share, calculated as:

```
NAV = effective_house_balance / total_shares
```

Where:
- **effective_house_balance** = house_balance - pending_fees

### Why "Effective" Balance?

Fees are calculated at epoch end, but we account for pending fees continuously to ensure fair NAV. This means:

- Users who buy shares don't pay extra for fees that will be deducted
- Users who sell shares don't take more than their fair share before fees
- The NAV accurately reflects what each share is worth right now

### NAV Changes

| Event | Effect on NAV |
|-------|---------------|
| Players lose (positive GGR) | NAV increases |
| Players win (negative GGR) | NAV decreases |
| Fees deducted at epoch end | Reflected in effective balance |
| New shares purchased | NAV unchanged (proportional) |
| Shares sold | NAV unchanged (proportional) |

## Fee Structure

All fees are calculated from **GGR (Gross Gaming Revenue)** at the end of each epoch:

```
GGR = Total Bets - Total Wins
```

### Fee Types

| Fee | Who Receives | Typical Range | Description |
|-----|--------------|---------------|-------------|
| **Protocol Fee** | OpenPlay Treasury | 0-20% | Platform maintenance and development |
| **House Fee** | House Operator | Varies | Performance fee for running the house |
| **Collector Fee** | Game Creators | Varies | Shared among fee collectors based on their games' GGR |

### Fee Limits

To protect shareholders, fee limits are enforced:

- **House Fee + Collector Fee**: Cannot exceed 50%
- **Protocol Fee**: Cannot exceed 20%

This ensures shareholders receive **at least 30%** of positive GGR.

### Fee Calculation Example

**Scenario**: Epoch ends with 1,000 SUI GGR

| Fee | Rate | Amount | Recipient |
|-----|------|--------|-----------|
| Protocol Fee | 10% | 100 SUI | OpenPlay Treasury |
| House Fee | 20% | 200 SUI | House Operator |
| Collector Fee | 20% | 200 SUI | Game Creators |
| **Remaining** | **50%** | **500 SUI** | **Shareholders (via NAV increase)** |

Your share of the 500 SUI depends on what percentage of total shares you own.

### When Are Fees Deducted?

Fees are deducted at **epoch end** (approximately every 24 hours, aligned with Sui epochs). However:

- **NAV reflects pending fees continuously** via "effective balance"
- You always see the fair value of your shares
- No surprises when fees are actually moved

## What to Expect

### Returns

Your returns depend on:

1. **House Performance**: How much players bet vs. win (GGR)
2. **Fee Structure**: Higher fees = less return to shareholders
3. **Your Share Percentage**: Your slice of the total shares

**Positive GGR**: House profits, your shares become worth more  
**Negative GGR**: House loses, your shares become worth less

### Risk Factors

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Player Wins** | If players win more than they bet, NAV decreases | Diversify across houses; understand game edges |
| **Variance** | Short-term luck can cause swings | Long-term: house edge should prevail |
| **Game Quality** | Poor games may have unfavorable odds | Check which games the house offers |
| **Operator Trust** | Operator controls which games are whitelisted | Research the house and operator |

### Expected Behavior by Scenario

| Scenario | GGR | Your Shares | What Happens |
|----------|-----|-------------|--------------|
| Players lose big | +500 SUI | 10% of total | You gain ~25 SUI (after 50% fees) |
| Players break even | 0 SUI | 10% of total | No change to NAV |
| Players win big | -500 SUI | 10% of total | You lose ~50 SUI |
| You buy more shares | N/A | Increases | NAV unchanged, more exposure |
| You sell shares | N/A | Decreases | Receive NAV × shares sold |

## No Lock-Up Period

**OpenPlay has no lock-up period.** You can:

- ✅ Buy shares at any time
- ✅ Sell shares at any time  
- ✅ Receive proceeds immediately
- ✅ Partially sell (keep some shares)

This is a key advantage over traditional staking models that require:
- ❌ Waiting for epoch end to unstake
- ❌ Pending periods before funds are available
- ❌ Separate claim transactions

With OpenPlay, your liquidity is immediate.

## Step-by-Step Guide

### Becoming a Shareholder

1. **Research Houses**: Look at game selection, fee structure, and historical performance
2. **Create Participation**: Call `house.new_participation(ctx)` for your chosen house
3. **Buy Shares**: Call `house.buy_shares(&mut participation, coins, ctx)`
4. **Monitor**: Check your share value periodically
5. **Sell When Ready**: Call `house.sell_shares(&mut participation, shares, ctx)`

### Checking Your Position

You can query:

```move
// How many shares do you own?
let my_shares = participation.shares();

// What is the current NAV?
let nav = house.nav(&participation);

// What are your shares worth?
let my_value = my_shares * house.effective_house_balance() / house.total_shares();
```

### Exiting Your Position

```move
// Sell all your shares
let all_my_shares = participation.shares();
let payout = house.sell_shares(&mut participation, all_my_shares, ctx);
// payout is a Coin<SUI> you can use immediately

// Or sell partially
let half_my_shares = participation.shares() / 2;
let partial_payout = house.sell_shares(&mut participation, half_my_shares, ctx);
```

## Comparing to Traditional Staking

| Feature | OpenPlay Shares | Traditional Staking |
|---------|-----------------|---------------------|
| **Lock-up** | None | Often 1+ epochs |
| **Exit** | Immediate | Pending period |
| **Claim** | Not needed | Separate transaction |
| **Value Tracking** | Real-time NAV | Complex calculations |
| **Partial Exit** | Any amount | Often all-or-nothing |
| **Pending State** | None | Pending stake/unstake |

## Advanced Topics

### Fee Capture at Epoch Start

Fee rates are **captured at the start of each epoch**. This means:

- If fees change mid-epoch, your current epoch uses the old rates
- New rates apply starting next epoch
- This ensures predictable calculations for all participants

### Multiple Houses

You can participate in multiple houses simultaneously:

- Create separate Participation objects for each house
- Diversify your risk across different game selections and operators
- Each house has independent performance and fees

### Initial NAV

When a house is first created:
- Initial NAV is set to 1 SUI per share (configurable)
- First buyer sets the baseline
- Subsequent buyers receive shares at current NAV

### Epoch Timing

Epochs align with Sui blockchain epochs (approximately 24 hours). At epoch end:

1. GGR is calculated (total bets - total wins)
2. Fees are computed from GGR
3. Fees are moved to collection balances
4. New fee rates are captured for next epoch
5. NAV is updated to reflect new effective balance

## FAQ

### Q: Can I lose more than I invested?

**A**: No. Your maximum loss is limited to your investment. Shares cannot have negative value.

### Q: What if the house has no players?

**A**: No bets = no GGR = no gains or losses. Your shares maintain their value, minus any fixed costs (if any).

### Q: Are there minimum amounts?

**A**: There may be minimum transaction amounts enforced by the protocol (currently 1 MIST). Check the specific house for any additional minimums.

### Q: How do I know a house is trustworthy?

**A**: Research the operator, review whitelisted games, check the fee structure, and look at historical performance. All data is on-chain and verifiable.

### Q: What happens if the house runs out of funds?

**A**: If house balance reaches zero, NAV becomes zero. This is a total loss scenario. Only invest what you can afford to lose.

### Q: Can I be a shareholder and a player?

**A**: Yes! You can hold shares (through a Participation) and also play games (through a Balance Manager). These are separate systems.

### Q: How often should I check my investment?

**A**: That's up to you. NAV changes continuously based on game results. Epoch-end fee deductions happen daily.

### Q: What are fee collectors?

**A**: Fee collectors group games together for fee calculation. Game creators receive fees based on the GGR their games generate.

## Summary

| Aspect | Details |
|--------|---------|
| **Investment Model** | Buy/sell shares at NAV |
| **Lock-up Period** | **None** - instant liquidity |
| **Fee Basis** | GGR (bets - wins) at epoch end |
| **Your Returns** | Proportional share of GGR after fees |
| **Risk** | Can lose up to 100% if house loses |
| **Transparency** | All on-chain and verifiable |

OpenPlay's share-based model provides a simple, liquid way to participate in house profits. With no lock-up periods and real-time NAV tracking, you have full control over your investment at all times.

## Related Documentation

- [Vision & Overview](./vision.md) - Full protocol overview
- [Balance System](./balances.md) - Technical details on balances
- [Rounding Strategy](./rounding-strategy.md) - How rounding affects calculations
- [Upgrades & Security](./upgrades.md) - Protocol security and upgrades
