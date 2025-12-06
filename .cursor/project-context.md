# OpenPlay Core - Project Context & Workflow

## Project Overview

**OpenPlay** is a GambleFi protocol on Sui that provides infrastructure for house-based gambling games. It's designed to be a permissionless, community-driven protocol.

### Platform
- **Blockchain**: Sui
- **Language**: Move (edition 2024.beta)
- **Package Version**: 1.1
- **Sui Framework**: mainnet-v1.61.2

## Core Architecture

### Key Components

1. **Registry** (`registry.move`)
   - Central protocol registry tracking all houses
   - Manages protocol fees (currently 0%)
   - Handles version control for package upgrades
   - Maps game IDs to GameStatistics objects

2. **House** (`house.move`)
   - Shared objects that process bet/win transactions
   - Manages whitelisted games (transaction allow list)
   - Handles fee distribution (protocol, game)
   - Manages staking participation
   - Processes end-of-day calculations

3. **Vault** (`vault.move`)
   - Stores all house assets
   - Separates funds into:
     - **Play balance**: Active gameplay funds
     - **Reserve balance**: Staked funds not yet in play
   - Tracks collected fees (protocol, game)

4. **Participation** (`participation.move`)
   - NFT-like objects representing user's stake in a house
   - Tracks profit/loss over epochs
   - Manages stake activation/deactivation
   - Handles claimable balances

5. **Balance Manager** (`balance_manager.move`)
   - Shared objects holding player funds
   - Delegatable PlayCaps for gameplay
   - Owner can mint PlayCaps for delegated access

6. **House State** (`state/house_state.move`)
   - Maintains global state of a House
   - Tracks accounts, stake, volumes, and history
   - Processes transactions and calculates profit/loss sharing
   - Manages epoch-based operations

7. **Game Statistics** (`game_stats.move`)
   - Tracks volume and statistics per game instance
   - Per-epoch and all-time statistics

8. **Transaction** (`transaction.move`)
   - Building blocks for money transfers
   - Bet (debit) and Win (credit) transaction types


## Key Mechanics

### Epoch-Based Operations
- Houses operate in epochs (~24 hours, Sui epochs)
- At end of epoch:
  - Profits/losses are calculated
  - Distributed proportionally to stakers
  - Pending stakes/unstakes are processed

### House Activation
- Houses must reach minimum stake threshold to activate
- When active: funds move from reserve to play balance
- When inactive: new stakes go to inactive stake pool

### Capability-Based Security
Uses Sui capabilities for access control:
- `HouseAdminCap`: Administrative access to a House
- `HouseTransactionCap`: Authorizes games to execute transactions
- `PlayCap`: Delegated access to BalanceManager for gameplay
- `BalanceManagerCap`: Ownership of BalanceManager
- `OpenPlayAdminCap`: Protocol-level administration

### Game Whitelisting
- House admins whitelist game instances (by UID)
- Games must be whitelisted to process transactions
- Maximum 1000 transaction caps per house

## Current Fee Model

1. **Protocol Fee**: Global fee in Registry (currently 0%)
2. **Game Fee**: Per-game instance fee (goes to game owners)

## Vision & Future Plans

See `docs/vision.md` for detailed vision document. Key points:

### Future Model: 1 House = 1 Operator
- Each operator website = one house
- Four roles: Protocol, Package Developers, Instance Creators, House Admins
- Fee hierarchy: Protocol → Package Dev → Instance Creator → House Admin → Stakers

### Planned Changes
- Add house admin fee mechanism
- Package developer fee tracking (by address)
- Instance creator fee tracking (by address)
- Per-game fee configuration (package_dev_fee_bps, instance_creator_fee_bps)
- Game instance attribution standard

## Development Workflow

### CRITICAL: Always Run After Changes

1. **After ANY code changes:**
   ```bash
   cd package
   sui move build
   sui move test
   ```

2. **Both commands must succeed before considering work complete**

3. **Update CHANGELOG.md:**
   - Add a bullet point in `CHANGELOG.md` for every change made
   - Current version: **v2.1** (git branch name)
   - Use categories: Added, Changed, Fixed, Removed
   - Place new entries at the top of the v2.1 section

### Testing Requirements

1. **When adding new functionality:**
   - Add test cases covering ALL flows
   - Test both success and error cases
   - Update existing tests if behavior changes

2. **Testing patterns:**
   - Use `sui::test_scenario` for testing
   - Test utilities available in `core_test_utils.move`
   - Current test suite: 81 tests (all passing)

3. **Test files:**
   - `tests/house_tests.move`
   - `tests/balance_manager_tests.move`
   - `tests/vault_tests.move`
   - `tests/participation_tests.move`
   - `tests/calculations_tests.move`
   - `tests/game_stats_tests.move`
   - `tests/state/account_tests.move`
   - `tests/state/state_tests.move`

## Project Structure

```
openplay-core/
├── CHANGELOG.md (IMPORTANT: Update on every change)
├── package/
│   ├── Move.toml
│   ├── sources/
│   │   ├── house.move
│   │   ├── vault.move
│   │   ├── registry.move
│   │   ├── balance_manager.move
│   │   ├── participation.move
│   │   ├── transaction.move
│   │   ├── game_stats.move
│   │   ├── calculations.move
│   │   ├── core_constants.move
│   │   ├── parameter_store.move
│   │   └── state/
│   │       ├── account.move
│   │       └── house_state.move
│   └── tests/
│       ├── core_test_utils.move
│       ├── house_tests.move
│       ├── balance_manager_tests.move
│       ├── vault_tests.move
│       ├── participation_tests.move
│       ├── calculations_tests.move
│       ├── game_stats_tests.move
│       └── state/
│           ├── account_tests.move
│           └── state_tests.move
├── docs/
│   ├── vision.md (IMPORTANT: Read for future plans)
│   └── balance-explanations.txt
└── audit/
    └── (security audit reports)
```

## Key Concepts

### Balance Types
- **Stake**: Currently activated stake for participation
- **Pending Stake**: Stake waiting until end of epoch to be activated
- **Pending Unstake**: Stake queued to be removed at end of epoch
- **Claimable Balance**: Funds available to withdraw

### Vault Balances
- **Reserve Balance**: All staked funds by default
- **Play Balance**: Funds available for gameplay (moved from reserve when house activates)

### House State
- **Inactive Stake**: Base state, all stakes start here
- **Active Stake**: Stake currently active (house is active)
- **Pending Unstake**: Stake queued for removal next epoch

## Important Invariants

From `docs/balance-explanations.txt`:
- The sums of each state should always be the same
- Money cannot just disappear
- Epoch boundaries are critical for state transitions

## Common Operations

### Creating a House
```move
let (house, admin_cap) = openplay_admin_new_house(
    &openplay_admin_cap,
    private: false,
    min_activation_balance: 100_000,
    ctx
);
```

### Processing Transactions
```move
house.tx_admin_process_transactions_v2(
    &registry,
    &mut game_stats,
    tx_cap,
    &mut balance_manager,
    &transactions,
    &play_cap,
    ctx
);
```

### Staking
```move
let participation = house.new_participation(ctx);
house.stake(&mut participation, stake_coins, ctx);
```

## Notes

- Always check `docs/vision.md` when planning new features
- Referral system has been removed (v2.1)
- Fee attribution needs clarification (see vision doc)
- Game instance attribution standard needs to be established
- All changes must maintain backward compatibility or follow upgrade path

