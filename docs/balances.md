# Balance System Documentation

## Overview

The OpenPlay protocol uses multiple balance types to manage funds across different contexts: staking, gameplay, fees, and user participations. This document explains each balance type, how they interact, and the flow of funds through the system.

## Balance Categories

Balances are organized into four main categories:

1. **Vault Balances** - House-level fund storage and management
2. **State Balances** - House-level stake tracking and activation
3. **Participation Balances** - User-level stake and profit/loss tracking
4. **Account Balances** - Player-level transaction tracking for gameplay

## Vault Balances

The Vault is the central storage for all House funds. It manages the separation between funds available for gameplay and staked reserves.

### Reserve Balance

**Location**: `Vault.reserve_balance`  
**Type**: `Balance<SUI>`

**Purpose**: The primary storage for all staked funds. This is where funds are held when not actively being used for gameplay.

**Behavior**:
- All new stakes are deposited into the reserve balance
- Funds are moved from reserve to play balance when the house activates
- At end of epoch, play balance is cleared back to reserve balance
- Profits and losses are reflected in the reserve balance after end-of-day processing

**Operations**:
- `vault.deposit(stake)` - Adds stake to reserve balance
- `vault.withdraw(amount)` - Withdraws from reserve balance
- `vault.fund_play_balance(target)` - Moves funds from reserve to play balance

### Play Balance

**Location**: `Vault.play_balance`  
**Type**: `Balance<SUI>`

**Purpose**: Funds actively available for game payouts. This balance is used during gameplay to settle wins and losses with players.

**Behavior**:
- Funded from reserve balance when house activates
- Used for all game transaction settlements (bets and wins)
- Fees are deducted from play balance during transaction processing
- Cleared back to reserve balance at end of epoch

**Operations**:
- `vault.fund_play_balance(target)` - Funds from reserve (on activation)
- `vault.settle_balance_manager()` - Transfers funds to/from balance managers
- `vault.process_end_of_day()` - Clears back to reserve balance

**Important**: If play balance runs out during an epoch, gameplay stops until the next epoch when it can be refunded.

### Collected Protocol Fees

**Location**: `Vault.collected_protocol_fees`  
**Type**: `Balance<SUI>`

**Purpose**: Accumulates protocol fees collected from all game transactions. These fees go to the OpenPlay protocol.

**Behavior**:
- Fees are deducted from play balance during transaction processing
- Accumulated over time until claimed by protocol admin
- Collected per transaction based on `protocol_fee_bps` setting

**Operations**:
- `vault.process_protocol_fee(amount)` - Adds fee to collection
- `vault.withdraw_protocol_fees()` - Claims all collected fees (admin only)

### Collected Game Fees

**Location**: `Vault.collected_game_fees`  
**Type**: `VecMap<ID, Balance<SUI>>`

**Purpose**: Accumulates game-specific fees collected from transactions. Each game has its own fee balance.

**Behavior**:
- Fees are deducted from play balance during transaction processing
- Tracked per game ID (each game has its own balance)
- Collected per transaction based on `game_fee_bps` setting for that game

**Operations**:
- `vault.process_game_fee(game_id, amount)` - Adds fee to game's collection
- `vault.withdraw_game_fees(game_id)` - Claims all collected fees for a game

### Collected House Fees

**Location**: `Vault.collected_house_fees`  
**Type**: `Balance<SUI>`

**Purpose**: Accumulates house performance fees (house admin fees) taken from profits each epoch.

**Behavior**:
- Collected during end-of-day processing when there are profits
- Deducted from reserve balance (where profits are stored after end-of-day)
- Calculated as a percentage of profits: `house_fee = profits * house_fee_bps / 10000`
- Remaining profits (after house fee) are distributed to stakers

**Operations**:
- `vault.process_house_fee(amount)` - Adds fee to collection (during end-of-day)
- `vault.withdraw_house_fees()` - Claims all collected fees (house admin only)

## State Balances

The State tracks house-level stake management and activation status. These balances represent the aggregate stake across all participations.

### Inactive Stake

**Location**: `State.inactive_stake`  
**Type**: `u64`

**Purpose**: Stake that is available to be activated in the next cycle. This is the default state for all new stakes.

**Behavior**:
- All new stakes start as inactive stake
- When house activates, inactive stake becomes active stake
- If house is inactive, unstakes are deducted directly from inactive stake
- At end of epoch, active stake returns to inactive stake

**Operations**:
- `state.add_stake(amount)` - Adds to inactive stake
- `state.remove_inactive_stake(amount)` - Removes from inactive stake (when house inactive)
- `state.activate()` - Moves inactive stake to active stake

### Active Stake

**Location**: `State.active_stake`  
**Type**: `u64`

**Purpose**: Stake that is currently active and participating in profit/loss sharing for the current epoch.

**Behavior**:
- Set when house activates (from inactive stake)
- Remains constant throughout the epoch (cannot change during active cycle)
- Used as the base for calculating profit/loss shares
- Returns to inactive stake at end of epoch

**Operations**:
- `state.activate()` - Sets active stake from inactive stake
- `state.process_end_of_day()` - Moves active stake back to inactive (with profits/losses applied)

**Important**: Once a cycle starts, active stake cannot change until the next epoch. New stakes during an active cycle go to inactive stake and will activate next epoch.

### Pending Unstake

**Location**: `State.pending_unstake`  
**Type**: `u64`

**Purpose**: Stake that is currently active but has been requested for unstaking. Will be deactivated at the end of the current epoch.

**Behavior**:
- Only exists when house is active
- Represents active stake that users want to exit
- At end of epoch, actualized based on profits/losses, then removed
- If house is inactive, unstakes are processed immediately (no pending)

**Operations**:
- `state.add_pending_unstake(amount)` - Queues unstake for end of epoch
- `state.process_end_of_day()` - Actualizes and removes pending unstake

**Actualization**: Pending unstake amounts are adjusted based on profits/losses:
- If profits: `actual_unstake = floor(pending_unstake * (stake + profits) / stake)`
- If losses: `actual_unstake = ceil(pending_unstake * (stake - losses) / stake)`

## Participation Balances

Each user's Participation tracks their individual stake and profit/loss shares. These balances are user-specific.

### Stake

**Location**: `Participation.stake`  
**Type**: `u64`

**Purpose**: The user's stake that is currently active and participating in profit/loss sharing.

**Behavior**:
- Increases when pending stake is activated (at end of epoch)
- Increases/decreases based on profits/losses each epoch
- Decreases when unstaked (immediately if house inactive, or queued if active)
- Used as the base for calculating the user's share of profits/losses

**Operations**:
- `participation.add_stake(amount, is_active)` - Adds stake (immediate if inactive, pending if active)
- `participation.process_end_of_day()` - Activates pending stake, applies profits/losses
- `participation.unstake_v2()` - Removes from stake (immediate or queued)

### Pending Stake

**Location**: `Participation.pending_stake`  
**Type**: `u64`

**Purpose**: Stake that has been deposited but is waiting for the current epoch to end before becoming active.

**Behavior**:
- Created when staking during an active house cycle
- Cannot be unstaked directly (must wait for activation or cancel before activation)
- Activated at end of epoch and added to stake
- If unstaked before activation, immediately moved to claimable balance

**Operations**:
- `participation.add_stake(amount, is_active=true)` - Adds to pending stake
- `participation.process_end_of_day()` - Activates pending stake to stake
- `participation.unstake_v2()` - Can cancel pending stake (moves to claimable)

**Why Pending?**: When a house is active, new stakes cannot be added to the active stake pool mid-epoch because it would interfere with profit/loss calculations. They must wait until the epoch ends.

### Pending Unstake

**Location**: `Participation.pending_unstake`  
**Type**: `u64`

**Purpose**: Active stake that has been requested for unstaking but must wait until the end of the current epoch.

**Behavior**:
- Only exists when house is active
- Represents active stake that user wants to exit
- At end of epoch, actualized based on profits/losses, then moved to claimable balance
- If house is inactive, unstakes are processed immediately (no pending)

**Operations**:
- `participation.unstake_v2(amount, is_active=true)` - Queues unstake
- `participation.process_end_of_day()` - Actualizes and moves to claimable balance

**Actualization**: Like state-level pending unstake, this amount is adjusted based on profits/losses to ensure users bear their proportional share.

### Claimable Balance

**Location**: `Participation.claimable_balance`  
**Type**: `u64`

**Purpose**: Funds that are ready to be withdrawn by the user. This includes unstaked amounts and profits.

**Behavior**:
- Increases when:
  - Pending unstake is actualized and released (at end of epoch)
  - Pending stake is cancelled (unstaked before activation)
  - Immediate unstakes (when house is inactive)
- Decreases when user claims funds
- Represents funds that are no longer staked and can be withdrawn

**Operations**:
- `participation.claim_all()` - Returns all claimable balance and resets to zero
- `participation.process_end_of_day()` - Adds actualized unstake amounts
- `participation.unstake_v2()` - Adds immediate unstakes or cancelled pending stake

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

**Operations**:
- `account.debit(amount)` - Adds bet amount
- `account.settle()` - Returns balance and resets to zero

### Credit Balance

**Location**: `Account.credit_balance`  
**Type**: `u64`

**Purpose**: Tracks win amounts (credits) for a player's account during transaction processing.

**Behavior**:
- Accumulates win amounts from transactions
- Reset to zero after settlement
- Used to calculate net settlement with debit balance

**Operations**:
- `account.credit(amount)` - Adds win amount
- `account.settle()` - Returns balance and resets to zero

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
- Separate from staking balances (which are in the vault)

**Operations**:
- `balance_manager.deposit(cap, coins)` - Adds funds
- `balance_manager.withdraw(cap, amount)` - Removes funds
- `vault.settle_balance_manager()` - Transfers funds to/from vault during gameplay

**Note**: This is separate from participation balances. Balance manager funds are for gameplay, while participation balances are for staking in houses.

## Balance Flow Diagrams

### Staking Flow

```
User Wallet
    │
    ├─► [Stake] ──► Vault.reserve_balance
    │                      │
    │                      ├─► State.inactive_stake
    │                      │
    │                      └─► Participation.pending_stake (if house active)
    │                                  │
    │                                  └─► [End of Epoch] ──► Participation.stake
    │
    └─► [Unstake] ◄─────── Claimable Balance ◄─────── [End of Epoch]
                                                              │
                                                              └─► Actualized Pending Unstake
```

### Gameplay Flow

```
BalanceManager.balance
    │
    ├─► [Bet] ──► Account.debit_balance
    │                    │
    │                    └─► [Settlement] ──► Vault.play_balance
    │
    └─► [Win] ◄─── Account.credit_balance
                          │
                          └─► [Settlement] ◄─── Vault.play_balance
```

### House Activation Flow

```
Vault.reserve_balance
    │
    └─► [House Activates] ──► Vault.play_balance
              │
              └─► State.inactive_stake ──► State.active_stake
```

### End of Epoch Flow

```
Vault.play_balance ──► [End of Day] ──► Vault.reserve_balance
                                                      │
                                                      ├─► [Calculate Profits/Losses]
                                                      │
                                                      ├─► [Apply to Stake]
                                                      │   Participation.stake += profits
                                                      │   Participation.stake -= losses
                                                      │
                                                      ├─► [Actualize Pending Unstake]
                                                      │   └─► Participation.claimable_balance
                                                      │
                                                      └─► [Activate Pending Stake]
                                                          └─► Participation.stake
```

## Balance Invariants

### Vault Invariant

The total value in the vault should equal the sum of all balances:

```
reserve_balance + play_balance + collected_protocol_fees + 
sum(collected_game_fees) + collected_house_fees = Total Staked Funds
```

### State Invariant

The state balances should match the aggregate of all participations:

```
inactive_stake + active_stake = sum(all Participation.stake + Participation.pending_stake)
pending_unstake = sum(all Participation.pending_unstake)
```

### Participation Invariant

For each participation:

```
stake + pending_stake + claimable_balance = Total User Stake + Profits - Losses - Withdrawn
```

**Note**: `pending_unstake` is not included in the sum because it's still part of `stake` until actualized.

## Balance Lifecycle Examples

### Example 1: Staking in Inactive House

1. User stakes 1000 SUI
   - `Vault.reserve_balance` += 1000
   - `State.inactive_stake` += 1000
   - `Participation.stake` += 1000

2. House activates (min_activation = 5000, total stake = 10000)
   - `Vault.play_balance` += 10000 (from reserve)
   - `State.active_stake` = 10000 (from inactive)
   - `State.inactive_stake` = 0
   - `Participation.stake` remains 1000 (now active)

### Example 2: Staking in Active House

1. House is active with 10000 active stake
2. User stakes 500 SUI
   - `Vault.reserve_balance` += 500
   - `State.inactive_stake` += 500
   - `Participation.pending_stake` += 500 (not active yet)

3. End of epoch
   - `Participation.pending_stake` → `Participation.stake`
   - `Participation.pending_stake` = 0
   - `Participation.stake` += 500

### Example 3: Unstaking from Active House

1. User has 1000 active stake, house is active
2. User unstakes 300 SUI
   - `Participation.pending_unstake` += 300
   - `Participation.stake` remains 1000 (still active until end of epoch)

3. End of epoch (with 100 SUI profits)
   - Profits applied: `Participation.stake` = 1000 + 100 = 1100
   - Actualize pending unstake: `actual = floor(300 * 1100 / 1000) = 330`
   - `Participation.claimable_balance` += 330
   - `Participation.stake` -= 330 = 770
   - `Participation.pending_unstake` = 0

### Example 4: Gameplay Transaction

1. Player has 500 SUI in BalanceManager
2. Player bets 100 SUI, wins 150 SUI
   - `Account.debit_balance` = 100
   - `Account.credit_balance` = 150
   - `BalanceManager.balance` = 500

3. Settlement
   - Net: 150 - 100 = 50 SUI win
   - `Vault.play_balance` -= 50 (pays player)
   - `BalanceManager.balance` += 50 = 550
   - `Account.debit_balance` = 0
   - `Account.credit_balance` = 0

## Best Practices

### For Users

1. **Understand Pending States**: 
   - Stakes during active cycles become pending and activate next epoch
   - Unstakes during active cycles become pending and are released next epoch

2. **Monitor Claimable Balance**:
   - Regularly check and claim your claimable balance
   - Unstaked amounts and profits accumulate here

3. **Balance Manager vs Participation**:
   - Balance Manager: For gameplay funds
   - Participation: For staking in houses
   - These are separate systems

### For Developers

1. **Always Process End of Day**:
   - Call `process_end_of_day()` before checking balances
   - Ensures all pending states are resolved

2. **Check House State**:
   - Verify if house is active before staking/unstaking
   - Active houses queue operations, inactive houses process immediately

3. **Account Settlement**:
   - Always settle accounts after processing transactions
   - Reset debit/credit balances for next batch

4. **Balance Invariants**:
   - Verify invariants hold after operations
   - Helps catch bugs early

## FAQ

### Q: Why do I have pending stake?

**A**: When you stake during an active house cycle, your stake must wait until the epoch ends to become active. This ensures fair profit/loss distribution.

### Q: Can I unstake my pending stake?

**A**: Yes, you can cancel pending stake before it activates. It will be moved directly to your claimable balance.

### Q: What's the difference between stake and claimable balance?

**A**: 
- **Stake**: Active stake participating in profit/loss sharing
- **Claimable Balance**: Funds ready to withdraw (unstaked amounts, profits)

### Q: Why is my pending unstake different from what I requested?

**A**: Pending unstake is actualized at end of epoch based on profits/losses. If there were profits, you get more. If there were losses, you get less (proportional to your share).

### Q: What happens if play balance runs out?

**A**: Gameplay stops until the next epoch. The play balance is refunded from reserve balance at end of epoch, and if sufficient funds exist, the house reactivates.

### Q: How are fees collected?

**A**: 
- Protocol and game fees: Deducted from play balance during transactions
- House fees: Deducted from reserve balance (profits) at end of epoch

### Q: Can I see all my balances?

**A**: Yes, you can query:
- `Participation.stake()` - Your active stake
- `Participation.pending_stake()` - Pending stake
- `Participation.claimable_balance()` - Claimable funds
- `BalanceManager.balance()` - Your gameplay funds

## Related Documentation

- [Balance Manager System](./balance-manager.md) - Player balance management
- [Vault Module](../package/sources/vault.move) - Vault implementation
- [House State Module](../package/sources/state/house_state.move) - State implementation
- [Participation Module](../package/sources/participation.move) - Participation implementation
- [Rounding Strategy](./rounding-strategy.md) - How rounding affects balances

## Summary

- **Vault**: Stores all house funds (reserve, play, fees)
- **State**: Tracks aggregate stake (inactive, active, pending unstake)
- **Participation**: Tracks individual user stake and profits/losses
- **Account**: Tracks transaction-level bets and wins
- **Balance Manager**: Holds player gameplay funds
- **Pending States**: Ensure fair profit/loss distribution across epochs
- **Invariants**: All balances must sum correctly - funds cannot disappear
