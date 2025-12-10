# Balance System Documentation

## Overview

The OpenPlay protocol uses multiple balance types to manage funds across different contexts: shares, gameplay, fees, and user participations. This document explains each balance type, how they interact, and the flow of funds through the system.

## v3.1 Share-Based Model

OpenPlay v3.1 uses a **share-based participation model** where:
- Houses are **always active** (no activation/deactivation cycles)
- Users **buy and sell shares** instead of staking/unstaking
- Shares are valued at **NAV (Net Asset Value)** per share
- Proceeds from selling shares are **immediately available**
- Fees are calculated from **GGR (Gross Gaming Revenue)** at epoch end

## Balance Categories

Balances are organized into four main categories:

1. **Vault Balances** - House-level fund storage and fee collection
2. **State Balances** - House-level share tracking and GGR volumes
3. **Participation Balances** - User-level share ownership
4. **Account Balances** - Player-level transaction tracking for gameplay

## Vault Balances

The Vault is the central storage for all House funds. It manages the house balance and collected fees.

### House Balance

**Location**: `Vault.house_balance`  
**Type**: `Balance<SUI>`

**Purpose**: The single balance for all house funds. This replaces the previous play/reserve balance separation.

**Behavior**:
- All share purchases are deposited into house balance
- Share sales withdraw from house balance
- Game transaction settlements use house balance
- Fees are deducted from house balance at epoch end

**Operations**:
- `vault.deposit(stake)` - Adds funds to house balance (from share purchase)
- `vault.withdraw(amount)` - Withdraws from house balance (for share sale)
- `vault.settle_balance_manager()` - Transfers funds to/from balance managers during gameplay

### Collected Protocol Fees

**Location**: `Vault.collected_protocol_fees`  
**Type**: `Balance<SUI>`

**Purpose**: Accumulates protocol fees collected from GGR at epoch end. These fees go to the OpenPlay protocol.

**Behavior**:
- Fees are calculated from GGR (bet - win) at epoch end
- Collected based on `current_epoch_protocol_fee_bps` captured at epoch start
- Accumulated over time until claimed by protocol admin

**Operations**:
- `vault.process_protocol_fee(amount)` - Adds fee to collection (at epoch end)
- `vault.withdraw_protocol_fees()` - Claims all collected fees (admin only)

### Collected Collector Fees

**Location**: `Vault.collected_collector_fees`  
**Type**: `VecMap<ID, Balance<SUI>>`

**Purpose**: Accumulates fees for each fee collector based on their GGR.

**Behavior**:
- Fees are calculated per fee collector from their GGR at epoch end
- Tracked per fee_collector_id (each collector has its own balance)
- Calculated based on `current_epoch_fee_collector_share_bps` captured at epoch start

**Operations**:
- `vault.process_collector_fee(fee_collector_id, amount)` - Adds fee to collector's collection
- `vault.withdraw_collector_fees(fee_collector_id)` - Claims all collected fees for a collector

### Collected House Fees

**Location**: `Vault.collected_house_fees`  
**Type**: `Balance<SUI>`

**Purpose**: Accumulates house performance fees taken from GGR each epoch.

**Behavior**:
- Collected during end-of-day processing from GGR
- Calculated based on `current_epoch_house_fee_bps` captured at epoch start
- Calculated as a percentage of GGR: `house_fee = ggr * house_fee_bps / 10000`

**Operations**:
- `vault.process_house_fee(amount)` - Adds fee to collection (during end-of-day)
- `vault.withdraw_house_fees()` - Claims all collected fees (house admin only)

## State Balances

The State tracks house-level share management, fee rates, and GGR volumes.

### Total Shares

**Location**: `State.total_shares`  
**Type**: `u64`

**Purpose**: Total shares currently in circulation for this house.

**Behavior**:
- Increases when users buy shares (mint_shares)
- Decreases when users sell shares (burn_shares)
- Used to calculate NAV per share

**Operations**:
- `state.mint_shares(shares)` - Increases total shares
- `state.burn_shares(shares)` - Decreases total shares
- `state.total_shares()` - Returns current total

### Current Epoch Fees

**Location**: `State.current_epoch_protocol_fee_bps`, `State.current_epoch_house_fee_bps`, `State.current_epoch_fee_collector_share_bps`  
**Type**: `u64`

**Purpose**: Fee rates captured at epoch start, used for all calculations during the epoch.

**Behavior**:
- Captured at the start of each epoch during `process_end_of_day()`
- Prevents mid-epoch fee changes from affecting calculations
- Used for NAV calculation (pending fees) and actual fee deduction

**Why Captured at Epoch Start**: This ensures fairness - users who buy/sell shares during an epoch know what fees will be applied.

### Current Volumes

**Location**: `State.current_volumes`  
**Type**: `Volumes` struct

**Purpose**: Tracks bet and win volumes for the current epoch.

**Fields**:
- `total_bet_amount: u64` - Total bets this epoch
- `total_win_amount: u64` - Total wins this epoch

**Behavior**:
- Updated during every transaction
- Used to calculate GGR at epoch end: `GGR = bet_amount - win_amount`
- Reset at epoch end (saved to history)

### Collector GGR

**Location**: `State.current_collector_ggr`  
**Type**: `VecMap<ID, CollectorGGR>`

**Purpose**: Tracks bet and win amounts per fee collector for the current epoch.

**Behavior**:
- Updated during every transaction with the fee collector ID
- Used to calculate per-collector fees at epoch end
- Reset at epoch end (saved to historic_collector_ggr)

## Participation Balances

Each user's Participation tracks their share ownership in a house.

### Shares

**Location**: `Participation.shares`  
**Type**: `u64`

**Purpose**: The number of shares the user owns in this house.

**Behavior**:
- Increases when user buys shares
- Decreases when user sells shares
- Multiplied by NAV to calculate current value

**Operations**:
- `participation.add_shares(shares)` - Increases share count
- `participation.remove_shares(shares)` - Decreases share count
- `participation.shares()` - Returns current share count

### Share Value (NAV)

The value of a user's shares is calculated dynamically:

```
value = shares * effective_house_balance / total_shares
```

Where `effective_house_balance = house_balance - pending_fees`

**Pending fees** include:
- Pending protocol fees (calculated from current epoch GGR)
- Pending house fees (calculated from current epoch GGR)
- Pending collector fees (calculated from current epoch GGR)

This ensures NAV reflects the true value after all fees are accounted for.

## Account Balances

Accounts track transaction-level balances for gameplay. Each balance manager has one account.

### Debit Balance

**Location**: `Account.debit_balance`  
**Type**: `u64`

**Purpose**: Tracks bet amounts (debits) for a player's account during transaction processing.

**Behavior**:
- Accumulates bet amounts from transactions
- Reset to zero after settlement
- Used to calculate net settlement with credit balance

### Credit Balance

**Location**: `Account.credit_balance`  
**Type**: `u64`

**Purpose**: Tracks win amounts (credits) for a player's account during transaction processing.

**Behavior**:
- Accumulates win amounts from transactions
- Reset to zero after settlement
- Used to calculate net settlement with debit balance

**Settlement**: After processing transactions, the account is settled:
- If `credit_balance > debit_balance`: Player wins, vault pays difference
- If `debit_balance > credit_balance`: Player loses, balance manager pays difference
- Balances are reset to zero after settlement

## Balance Manager Balance

**Location**: `BalanceManager.balance`  
**Type**: `Balance<SUI>`

**Purpose**: The actual SUI funds held by a player's balance manager for gameplay.

**Behavior**:
- Holds player's deposited funds
- Used for game transactions (bets and wins)
- Settled with house vault after each transaction batch
- Separate from participation (which tracks shares, not SUI)

**Operations**:
- `balance_manager.deposit(cap, coins)` - Adds funds
- `balance_manager.withdraw(cap, amount)` - Removes funds
- `vault.settle_balance_manager()` - Transfers funds to/from vault during gameplay

## Balance Flow Diagrams

### Share Purchase Flow

```
User Wallet
    │
    └─► [buy_shares()] ──► Vault.house_balance
                                │
                                ├─► State.total_shares += new_shares
                                │
                                └─► Participation.shares += new_shares
```

### Share Sale Flow

```
Participation.shares
    │
    └─► [sell_shares()] ──► State.total_shares -= sold_shares
                                │
                                └─► Vault.house_balance → User Wallet
                                    (payout = shares * NAV)
```

### Gameplay Flow

```
BalanceManager.balance
    │
    ├─► [Bet] ──► Account.debit_balance
    │                    │
    │                    └─► [Settlement] ──► Vault.house_balance
    │                                         │
    │                                         └─► State.current_volumes.total_bet_amount
    │                                         └─► State.current_collector_ggr[fee_collector_id].bet_amount
    │
    └─► [Win] ◄─── Account.credit_balance
                          │
                          └─► [Settlement] ◄─── Vault.house_balance
                                                │
                                                └─► State.current_volumes.total_win_amount
                                                └─► State.current_collector_ggr[fee_collector_id].win_amount
```

### End of Epoch Flow (GGR-Based Fees)

```
State.current_volumes ──► [process_end_of_day()] ──► Calculate GGR
                                                         │
                                                         ├─► GGR = bet_amount - win_amount
                                                         │
                                                         ├─► [Calculate Fees from GGR]
                                                         │   ├─► collector_fees = GGR * collector_share_bps
                                                         │   ├─► house_fee = GGR * house_fee_bps
                                                         │   └─► protocol_fee = GGR * protocol_fee_bps
                                                         │
                                                         ├─► [Move Fees to Vault]
                                                         │   ├─► Vault.collected_collector_fees
                                                         │   ├─► Vault.collected_house_fees
                                                         │   └─► Vault.collected_protocol_fees
                                                         │
                                                         └─► [Capture New Epoch Fees]
                                                             ├─► current_epoch_protocol_fee_bps
                                                             ├─► current_epoch_house_fee_bps
                                                             └─► current_epoch_fee_collector_share_bps
```

## NAV Calculation

NAV (Net Asset Value) per share determines the value of each share:

```
NAV = effective_house_balance / total_shares
```

Where:
```
effective_house_balance = house_balance - pending_fees
pending_fees = protocol_fee + house_fee + collector_fees
```

### Example NAV Calculation

1. House balance: 10,000 SUI
2. Total shares: 10,000
3. Current epoch GGR: 100 SUI
4. Fee rates: 10% protocol, 20% house, 20% collector

Calculation:
- Protocol fee pending: 100 * 10% = 10 SUI
- House fee pending: 100 * 20% = 20 SUI
- Collector fee pending: 100 * 20% = 20 SUI
- Total pending fees: 50 SUI
- Effective house balance: 10,000 - 50 = 9,950 SUI
- NAV per share: 9,950 / 10,000 = 0.995 SUI

This ensures users who sell shares don't take more than their fair share before fees are deducted.

## Balance Invariants

### Vault Invariant

The total value in the vault should equal:

```
house_balance + collected_protocol_fees + collected_house_fees + 
sum(collected_collector_fees) = Total Deposited Funds - Total Withdrawn Funds
```

### State Invariant

```
total_shares = sum(all Participation.shares)
```

### Participation Value Invariant

For each participation:
```
shares * NAV = proportional share of effective_house_balance
```

## Best Practices

### For Users

1. **Understand NAV**: 
   - Share value = shares × NAV
   - NAV changes based on house performance and pending fees

2. **Instant Liquidity**:
   - Selling shares immediately returns funds
   - No pending periods or claimable balances

3. **Balance Manager vs Participation**:
   - Balance Manager: For gameplay funds (SUI)
   - Participation: For house ownership (shares)
   - These are separate systems

### For Developers

1. **Always Process End of Day**:
   - Call `refresh_state()` before reading NAV
   - Ensures fees are captured and state is current

2. **Use Effective Balance for NAV**:
   - `effective_house_balance()` accounts for pending fees
   - Don't use raw `house_balance()` for NAV calculations

3. **Track Fee Collectors**:
   - Each game must have a fee collector assigned
   - GGR is tracked per fee collector

4. **Balance Invariants**:
   - Verify invariants hold after operations
   - Total shares must match sum of participations

## FAQ

### Q: Why don't I have pending stake anymore?

**A**: v3.1 uses shares instead of stake. When you buy shares, they're yours immediately. No waiting for epoch activation.

### Q: What happened to claimable balance?

**A**: Removed. When you sell shares, you get SUI immediately. No separate claim step needed.

### Q: How do I know my share value?

**A**: Use `house.nav(participation)` to get your current value, or calculate:
```
value = participation.shares() * house.effective_house_balance() / house.total_shares()
```

### Q: Why are fees captured at epoch start?

**A**: This ensures fairness. If fees could change mid-epoch, it would be unpredictable for users buying/selling shares.

### Q: What is GGR?

**A**: Gross Gaming Revenue = total bets - total wins. It represents the house's profit from gameplay before fees.

### Q: How are fees calculated?

**A**: All fees (protocol, house, collector) are calculated as a percentage of GGR at epoch end, not per-transaction.

### Q: What if GGR is negative (house lost)?

**A**: No fees are collected when GGR is negative. The loss is reflected in reduced NAV for shareholders.

## Related Documentation

- [Balance Manager System](./balance-manager.md) - Player balance management
- [Vault Module](../package/sources/vault.move) - Vault implementation
- [House State Module](../package/sources/state/house_state.move) - State implementation
- [Participation Module](../package/sources/participation.move) - Participation implementation
- [Rounding Strategy](./rounding-strategy.md) - How rounding affects balances

## Summary

- **Vault**: Stores house funds and collected fees (protocol, house, collector)
- **State**: Tracks total shares, volumes, GGR, and epoch-captured fee rates
- **Participation**: Tracks individual user share ownership
- **Account**: Tracks transaction-level bets and wins
- **Balance Manager**: Holds player gameplay funds
- **NAV**: Share value = effective_house_balance / total_shares
- **GGR-Based Fees**: All fees calculated from GGR at epoch end
- **Immediate Liquidity**: Sell shares anytime, get SUI immediately
