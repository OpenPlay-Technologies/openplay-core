# Implementation Plan: Share-Based Model + Fee Collector System

## Overview

Two interconnected features:
1. **Share-Based Participation Model** - Instant buy/sell with NAV-based pricing and cost-basis performance fees
2. **Fee Collector System** - GGR-based revenue sharing for game creators with virtual accrual

---

## Part 1: New Module - `fee_collector.move`

### New Structs

```move
module openplay_core::fee_collector;

/// Shared object representing a fee collector instance.
/// Multiple games can be assigned to the same fee collector.
/// Tracks accumulated fees that can be claimed by the cap owner.
public struct FeeCollector has key {
    id: UID,
    house_id: ID,
    cap_id: ID,                    // Links to the FeeCollectorCap
    claimable_balance: u64,        // Fees ready to be claimed
}

/// Owned capability that proves ownership of a FeeCollector.
/// Required to claim accumulated fees.
public struct FeeCollectorCap has key, store {
    id: UID,
    fee_collector_id: ID,
}

/// Event emitted when a FeeCollector is created.
public struct FeeCollectorCreatedEvent has copy, drop {
    fee_collector_id: ID,
    cap_id: ID,
    house_id: ID,
}

/// Event emitted when fees are claimed.
public struct FeesClaimedEvent has copy, drop {
    fee_collector_id: ID,
    amount: u64,
}
```

### New Functions

```move
// === Public-View Functions ===
public fun id(self: &FeeCollector): ID;
public fun house_id(self: &FeeCollector): ID;
public fun claimable_balance(self: &FeeCollector): u64;
public fun cap_fee_collector_id(cap: &FeeCollectorCap): ID;

// === Public-Package Functions ===

/// Creates a new FeeCollector and its capability.
/// Called by House when admin creates a fee collector.
public(package) fun new(house_id: ID, ctx: &mut TxContext): (FeeCollector, FeeCollectorCap);

/// Credits fees to the collector (called during end-of-day).
public(package) fun credit_fees(self: &mut FeeCollector, amount: u64);

/// Claims all accumulated fees. Requires the matching cap.
public(package) fun claim_fees(
    self: &mut FeeCollector, 
    cap: &FeeCollectorCap
): u64;

/// Validates that the cap matches this collector.
public(package) fun assert_valid_cap(self: &FeeCollector, cap: &FeeCollectorCap);
```

---

## Part 2: Modifications to `house_state.move`

### Struct Changes

```move
public struct State has store {
    // ... existing fields ...
    
    // Remove or deprecate:
    // - active_stake: u64
    // - inactive_stake: u64
    // - pending_unstake: u64
    
    // Add for share model:
    total_shares: u64,
    
    // Add for fee collector tracking:
    collector_epoch_ggr: Table<ID, CollectorGGR>,  // fee_collector_id -> GGR tracking
}

/// Tracks GGR for a fee collector within the current epoch.
public struct CollectorGGR has store, drop {
    bet_amount: u128,
    win_amount: u128,
}
```

### New/Modified Functions

```move
// === Share Model Functions ===

/// Returns total shares in circulation.
public fun total_shares(self: &State): u64;

/// Mints new shares. Called when user buys in.
public(package) fun mint_shares(self: &mut State, shares: u64);

/// Burns shares. Called when user sells.
public(package) fun burn_shares(self: &mut State, shares: u64);

// === Fee Collector Tracking ===

/// Registers a fee collector for tracking (called when game is whitelisted).
public(package) fun register_fee_collector(self: &mut State, fee_collector_id: ID, ctx: &mut TxContext);

/// Updates GGR for a fee collector (called during transaction processing).
public(package) fun update_collector_ggr(
    self: &mut State, 
    fee_collector_id: ID, 
    bet_amount: u64, 
    win_amount: u64
);

/// Calculates total pending collector fees for NAV calculation.
public(package) fun calculate_pending_collector_fees(
    self: &State, 
    fee_collector_share_bps: u64
): u64;

/// Processes end of day for collectors - returns fees per collector.
/// Resets GGR tracking for new epoch.
public(package) fun process_collector_end_of_day(
    self: &mut State
): vector<(ID, u64)>;  // Returns (collector_id, fee_amount) pairs
```

---

## Part 3: Modifications to `participation.move`

### Struct Changes

```move
public struct Participation has key, store {
    id: UID,
    house_id: ID,
    
    // Remove epoch-based fields:
    // - last_updated_epoch: u64
    // - stake: u64
    // - pending_stake: u64
    // - pending_unstake: u64
    
    // Add share-based fields:
    shares: u64,
    cost_basis: u64,          // Total amount paid for shares (in MIST)
    claimable_balance: u64,   // Funds ready to withdraw
}
```

### New/Modified Functions

```move
// === Public-View Functions ===
public fun shares(self: &Participation): u64;
public fun cost_basis(self: &Participation): u64;
public fun cost_basis_per_share(self: &Participation): u64;  // cost_basis / shares (with precision)

// === Public-Package Functions ===

/// Adds shares to participation and updates cost basis.
public(package) fun add_shares(
    self: &mut Participation, 
    shares: u64, 
    cost: u64  // Amount paid for these shares
);

/// Removes shares and adjusts cost basis proportionally.
/// Returns the cost basis portion being removed.
public(package) fun remove_shares(
    self: &mut Participation, 
    shares: u64
): u64;  // Returns cost_basis_removed

/// Adds to claimable balance (for payouts).
public(package) fun add_claimable(self: &mut Participation, amount: u64);

// Remove: process_end_of_day, add_stake, unstake_v2
```

---

## Part 4: Modifications to `vault.move`

### Struct Changes

```move
public struct Vault has store {
    // ... existing fields ...
    
    // Add for fee collectors:
    collected_collector_fees: VecMap<ID, Balance<SUI>>,  // fee_collector_id -> balance
}
```

### New/Modified Functions

```move
// === NAV Calculation ===

/// Returns total vault value available for share calculation.
/// This is play_balance + reserve_balance (excludes all collected fees).
public fun total_stake_value(self: &Vault): u64;

// === Fee Collector Functions ===

/// Moves funds from reserve to collector fee balance (called at end-of-day).
public(package) fun process_collector_fee(
    self: &mut Vault, 
    fee_collector_id: ID, 
    amount: u64
);

/// Withdraws collector fees for claiming.
public(package) fun withdraw_collector_fees(
    self: &mut Vault, 
    fee_collector_id: ID
): Balance<SUI>;
```

---

## Part 5: Modifications to `house.move`

### Struct Changes

```move
public struct House has store, key {
    // ... existing fields ...
    
    // Remove:
    // - games_fee_bps: VecMap<ID, u64>
    
    // Add:
    game_fee_collectors: VecMap<ID, ID>,    // game_id -> fee_collector_id
    fee_collector_share_bps: u64,           // Global: % of GGR for collectors
}

/// Updated transaction cap includes fee collector ID.
public struct HouseTransactionCap {
    house_id: ID,
    game_id: ID,
    fee_collector_id: ID,  // NEW: for GGR attribution
}
```

### New Functions

```move
// === Fee Collector Admin Functions ===

/// Creates a new fee collector for this house.
/// Returns the shared FeeCollector and owned FeeCollectorCap.
public fun admin_create_fee_collector(
    self: &House,
    admin_cap: &HouseAdminCap,
    ctx: &mut TxContext
): (FeeCollector, FeeCollectorCap);

/// Whitelists a game AND assigns it to a fee collector.
public fun admin_add_tx_allowed_with_collector(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    game_id: ID,
    fee_collector: &FeeCollector,  // Must be for this house
);

/// Claims fees for a fee collector. Requires the cap.
public fun claim_collector_fees(
    self: &mut House,
    fee_collector: &mut FeeCollector,
    cap: &FeeCollectorCap,
    ctx: &mut TxContext
): Coin<SUI>;

// === Share-Based Staking Functions ===

/// Calculates current NAV per share, accounting for pending collector fees.
public fun nav_per_share(self: &House): u64;

/// Buy shares with instant execution.
public fun buy_shares(
    self: &mut House,
    participation: &mut Participation,
    deposit: Coin<SUI>,
    ctx: &mut TxContext,
);

/// Sell shares with instant execution.
/// Charges house performance fee on gains.
public fun sell_shares(
    self: &mut House,
    participation: &mut Participation,
    shares_to_sell: u64,
    ctx: &mut TxContext,
): Coin<SUI>;

// === Updated Transaction Processing ===

/// Updated to include fee collector GGR tracking.
public fun tx_admin_process_transactions_v3(
    self: &mut House,
    registry: &Registry,
    game_stats: &mut GameStatistics,
    cap: HouseTransactionCap,  // Now includes fee_collector_id
    balance_manager: &mut BalanceManager,
    transactions: &vector<Transaction>,
    play_cap: &PlayCap,
    ctx: &TxContext,
);
```

### Modified: `borrow_tx_cap`

```move
/// Borrows a transaction cap - now includes fee collector ID.
public fun borrow_tx_cap(self: &House, game_id: &mut UID): HouseTransactionCap {
    let game_id_inner = game_id.to_inner();
    assert!(self.tx_allow_listed.contains(&game_id_inner), EUnauthorizedGameId);
    
    // Get the fee collector for this game
    let fee_collector_id = self.game_fee_collectors[&game_id_inner];
    
    HouseTransactionCap {
        house_id: self.id(),
        game_id: game_id_inner,
        fee_collector_id,
    }
}
```

### Modified: `process_end_of_day`

```move
fun process_end_of_day(self: &mut House, ctx: &TxContext) {
    let (epoch_switched, prev_epoch, end_of_day_balance) = self.vault.process_end_of_day(ctx);

    if (epoch_switched) {
        // 1. Calculate raw profits/losses
        let total_stake_value = self.state.total_shares * self.last_nav;  // Or track differently
        let profits = if end_of_day_balance > total_stake_value { 
            end_of_day_balance - total_stake_value 
        } else { 0 };
        
        // 2. Process collector fees (finalize from pending to actual)
        let collector_fees = self.state.process_collector_end_of_day();
        collector_fees.do!(|(collector_id, fee_amount)| {
            self.vault.process_collector_fee(collector_id, fee_amount);
        });
        
        // 3. House fee is now charged per-exit, not here
        // (Remove epoch-based house fee calculation)
        
        // 4. Update any epoch-based tracking
        self.state.process_end_of_day(prev_epoch, ctx);
        
        // 5. Try to activate if needed
        self.activate_if_possible(ctx);
    }
}
```

---

## Part 6: NAV Calculation Details

```move
/// Precision for share calculations (1 share = 1e9 units internally).
const SHARE_PRECISION: u64 = 1_000_000_000;

/// Initial NAV when no shares exist (1 SUI = 1 share at start).
const INITIAL_NAV: u64 = 1_000_000_000;  // 1 SUI in MIST

/// Calculates current NAV per share.
public fun nav_per_share(self: &House): u64 {
    let total_shares = self.state.total_shares();
    
    if (total_shares == 0) {
        return INITIAL_NAV
    };
    
    // Vault value = play + reserve (excludes collected fees)
    let vault_value = self.vault.total_stake_value();
    
    // Subtract pending collector fees (not yet moved to collected)
    let pending_collector_fees = self.state.calculate_pending_collector_fees(
        self.fee_collector_share_bps
    );
    
    let effective_value = if vault_value > pending_collector_fees {
        vault_value - pending_collector_fees
    } else {
        0
    };
    
    // NAV = effective_value / total_shares
    // Use precision to avoid rounding issues
    (effective_value * SHARE_PRECISION) / total_shares
}
```

---

## Part 7: Buy/Sell Shares Implementation

### Buy Shares

```move
public fun buy_shares(
    self: &mut House,
    participation: &mut Participation,
    deposit: Coin<SUI>,
    ctx: &mut TxContext,
) {
    self.assert_valid_participation(participation);
    self.process_end_of_day(ctx);
    
    let deposit_amount = deposit.value();
    let nav = self.nav_per_share();
    
    // Calculate shares to mint
    // shares = deposit_amount * PRECISION / nav
    let shares_to_mint = (deposit_amount * SHARE_PRECISION) / nav;
    
    // Update participation
    participation.add_shares(shares_to_mint, deposit_amount);
    
    // Update global state
    self.state.mint_shares(shares_to_mint);
    
    // Deposit funds to vault
    self.vault.deposit(deposit.into_balance());
    
    // Event
    emit(SharesPurchasedEvent {
        house_id: self.id(),
        participation_id: participation.id(),
        shares: shares_to_mint,
        amount: deposit_amount,
        nav: nav,
    });
    
    // Try to activate house if needed
    self.activate_if_possible(ctx);
}
```

### Sell Shares

```move
public fun sell_shares(
    self: &mut House,
    participation: &mut Participation,
    shares_to_sell: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.assert_valid_participation(participation);
    self.process_end_of_day(ctx);
    
    assert!(participation.shares() >= shares_to_sell, ENotEnoughShares);
    
    let nav = self.nav_per_share();
    
    // Calculate gross value
    // gross_value = shares * nav / PRECISION
    let gross_value = (shares_to_sell * nav) / SHARE_PRECISION;
    
    // Calculate cost basis being removed (proportional)
    let cost_basis_removed = participation.remove_shares(shares_to_sell);
    
    // Calculate gain and house performance fee
    let payout = if gross_value > cost_basis_removed {
        let gain = gross_value - cost_basis_removed;
        let house_fee = mul_ceil_bps(gain, self.house_fee_bps);
        
        // Store house fee
        if (house_fee > 0) {
            self.vault.process_house_fee(house_fee);
            emit(HouseFeeProcessedEvent { 
                house_id: self.id(), 
                amount: house_fee 
            });
        };
        
        gross_value - house_fee
    } else {
        // No gain (loss or break-even), no fee
        gross_value
    };
    
    // Update global state
    self.state.burn_shares(shares_to_sell);
    
    // Withdraw from vault
    let payout_coin = self.vault.withdraw(payout).into_coin(ctx);
    
    // Event
    emit(SharesSoldEvent {
        house_id: self.id(),
        participation_id: participation.id(),
        shares: shares_to_sell,
        gross_value: gross_value,
        payout: payout,
        nav: nav,
    });
    
    payout_coin
}
```

---

## Part 8: Transaction Processing with GGR Tracking

```move
public fun tx_admin_process_transactions_v3(
    self: &mut House,
    registry: &Registry,
    game_stats: &mut GameStatistics,
    cap: HouseTransactionCap,
    balance_manager: &mut BalanceManager,
    transactions: &vector<Transaction>,
    play_cap: &PlayCap,
    ctx: &TxContext,
) {
    let HouseTransactionCap { house_id, game_id, fee_collector_id } = cap;
    
    // ... existing validation ...
    
    self.process_end_of_day(ctx);
    
    // Process transactions (returns credit/debit)
    let (credit_balance, debit_balance, protocol_fee) = self.state.process_transactions(
        transactions,
        balance_manager.id(),
        registry.protocol_fee_bps(),
        ctx,
    );
    
    // Update fee collector GGR tracking
    // bet_amount = debit (what house received)
    // win_amount = credit (what house paid out)
    self.state.update_collector_ggr(fee_collector_id, debit_balance, credit_balance);
    
    // Settle with balance manager
    self.vault.settle_balance_manager(/* ... */);
    
    // Process protocol fee
    self.vault.process_protocol_fee(protocol_fee);
    
    // Update game stats
    game_stats.process_transactions(transactions, ctx);
    
    // Event
    emit(TransactionsProcessedEvent { /* ... */ });
}
```

---

## Part 9: Fee Collector Claims

```move
public fun claim_collector_fees(
    self: &mut House,
    fee_collector: &mut FeeCollector,
    cap: &FeeCollectorCap,
    ctx: &mut TxContext
): Coin<SUI> {
    // Validate fee collector belongs to this house
    assert!(fee_collector.house_id() == self.id(), EInvalidFeeCollector);
    
    // Validate cap ownership
    fee_collector.assert_valid_cap(cap);
    
    // Process any pending end-of-day first
    self.process_end_of_day(ctx);
    
    // Withdraw from vault
    let balance = self.vault.withdraw_collector_fees(fee_collector.id());
    let amount = balance.value();
    
    // Reset claimable on collector (if tracking there too)
    fee_collector.claim_fees(cap);
    
    // Event
    emit(CollectorFeesClaimedEvent {
        house_id: self.id(),
        fee_collector_id: fee_collector.id(),
        amount: amount,
    });
    
    balance.into_coin(ctx)
}
```

---

## Part 10: Migration Considerations

### Breaking Changes
1. `Participation` struct changes (shares instead of stake)
2. `HouseTransactionCap` struct changes (includes fee_collector_id)
3. Staking functions renamed (`stake` → `buy_shares`, `unstake` → `sell_shares`)
4. Game whitelisting requires fee collector
5. Game fees are now GGR-based, not bet-based

### Migration Strategy
1. Deploy new package version
2. Existing participations need migration function to convert stake → shares
3. Existing whitelisted games need fee collector assignment
4. Consider v2 vs v3 function naming for backwards compatibility period

### Suggested Migration Functions
```move
/// Migrates an old participation to the new share model.
/// Should be called once per participation.
public fun migrate_participation_to_shares(
    self: &mut House,
    participation: &mut Participation,  // Old format
    ctx: &mut TxContext,
);

/// Assigns a fee collector to an already-whitelisted game.
public fun admin_assign_collector_to_game(
    self: &mut House,
    admin_cap: &HouseAdminCap,
    game_id: ID,
    fee_collector: &FeeCollector,
);
```

---

## Implementation Order

### Phase 1: Fee Collector Foundation
1. Create `fee_collector.move` module
2. Add `collector_epoch_ggr` tracking to `house_state.move`
3. Add `collected_collector_fees` to `vault.move`
4. Add collector management to `house.move`

### Phase 2: Share Model
1. Update `participation.move` (shares, cost_basis)
2. Add `total_shares` to `house_state.move`
3. Implement NAV calculation in `house.move`
4. Implement `buy_shares` / `sell_shares`

### Phase 3: Integration
1. Update transaction processing with GGR tracking
2. Update `process_end_of_day` for new flow
3. Connect NAV calculation with pending collector fees

### Phase 4: Testing & Migration
1. Unit tests for each module
2. Integration tests for full flows
3. Migration functions for existing data

---

## Files Changed Summary

| File | Changes |
|------|---------|
| `fee_collector.move` | **NEW** - FeeCollector, FeeCollectorCap structs and functions |
| `participation.move` | **MAJOR** - Replace stake with shares/cost_basis |
| `house_state.move` | **MODERATE** - Add total_shares, collector GGR tracking |
| `vault.move` | **MODERATE** - Add collector fee storage, NAV helpers |
| `house.move` | **MAJOR** - NAV calc, buy/sell shares, collector management, updated tx processing |
| `calculations.move` | **MINOR** - May need new precision helpers |

---

Would you like me to elaborate on any specific part, or shall we start implementing?