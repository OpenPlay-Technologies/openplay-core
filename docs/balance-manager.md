# Balance Manager System

## Overview

The Balance Manager is a shared object that manages player funds for game transactions in the OpenPlay protocol. It provides a secure, delegated access system that allows players to deposit funds, play games, and withdraw winnings while maintaining proper access control through capability objects.

## Key Concepts

### BalanceManager (Shared Object)

The `BalanceManager` is a **shared object** that stores SUI balances for players. It:
- Holds the actual SUI funds
- Maintains an allow list of authorized `PlayCap` IDs
- Tracks the owner's `BalanceManagerCap` ID
- Can be accessed by anyone (since it's shared), but operations require proper capabilities

### BalanceManagerCap (Owner Capability)

The `BalanceManagerCap` is an **owned object** that grants full administrative control over a BalanceManager. Only the holder of this cap can:

- ✅ **Deposit funds** into the balance manager
- ✅ **Withdraw funds** from the balance manager
- ✅ **Mint PlayCaps** for delegated gameplay access
- ✅ **Revoke PlayCaps** to revoke delegated access
- ✅ **Destroy the balance manager** (when empty)

**Security**: The `BalanceManagerCap` is the "master key" - losing it means losing control over deposits/withdrawals, but gameplay can continue if PlayCaps were already minted.

### PlayCap (Delegated Capability)

The `PlayCap` is an **owned object** that grants limited gameplay access to a BalanceManager. A PlayCap holder can:

- ✅ **Generate PlayProof** for gameplay transactions
- ✅ **Play games** using the balance manager's funds
- ❌ **Cannot deposit** funds
- ❌ **Cannot withdraw** funds
- ❌ **Cannot mint or revoke** other PlayCaps

**Security**: PlayCaps are limited to gameplay only - they cannot access funds for deposit/withdrawal operations.

### PlayProof (Temporary Proof)

The `PlayProof` is a **temporary proof object** (has `drop`) that is generated per transaction to validate gameplay access. It:
- Contains the balance manager ID and player address
- Is generated from either `BalanceManagerCap` or `PlayCap`
- Is validated by the House/Vault when settling transactions
- Is automatically dropped after the transaction completes

## Capability Comparison

| Feature | BalanceManagerCap | PlayCap |
|---------|------------------|---------|
| **Deposit Funds** | ✅ Yes | ❌ No |
| **Withdraw Funds** | ✅ Yes | ❌ No |
| **Play Games** | ✅ Yes | ✅ Yes |
| **Mint PlayCaps** | ✅ Yes | ❌ No |
| **Revoke PlayCaps** | ✅ Yes | ❌ No |
| **Destroy BalanceManager** | ✅ Yes | ❌ No |
| **Generate PlayProof** | ✅ Yes | ✅ Yes |
| **Use Case** | Owner operations | Delegated gameplay |

## How Funds Work

### Fund Flow Architecture

```
Player Wallet
    │
    ├─► [Deposit] ──► BalanceManager (Shared Object)
    │                      │
    │                      ├─► [Game Transaction] ──► House/Vault
    │                      │         │
    │                      │         └─► [Settlement] ──► BalanceManager
    │                      │
    └─► [Withdraw] ◄───────┘
```

### Deposit Process

1. **Player calls `deposit()`** with their `BalanceManagerCap` and coins
2. **BalanceManager validates** the cap ownership
3. **Funds are added** to the balance manager's internal balance
4. **Event is emitted** (`DepositCompletedEvent`)

```move
// Only owner with BalanceManagerCap can deposit
balance_manager.deposit(&balance_manager_cap, coins, ctx);
```

### Withdrawal Process

1. **Player calls `withdraw()` or `withdraw_all()`** with their `BalanceManagerCap`
2. **BalanceManager validates** the cap ownership
3. **Funds are removed** from the balance manager's internal balance
4. **Coins are returned** to the player
5. **Event is emitted** (`WithdrawalProcessedEvent`)

```move
// Only owner with BalanceManagerCap can withdraw
let coins = balance_manager.withdraw(&balance_manager_cap, amount, ctx);
// or
let coins = balance_manager.withdraw_all(&balance_manager_cap, ctx);
```

### Gameplay Process

1. **Player generates PlayProof** using either:
   - `generate_proof_as_owner()` with `BalanceManagerCap`
   - `generate_proof_as_player()` with `PlayCap`
2. **Game processes transactions** (bets/wins)
3. **House settles balances** via `vault.settle_balance_manager()`
4. **Funds move** between BalanceManager and House Vault based on transaction results

```move
// Using BalanceManagerCap (owner)
let proof = balance_manager.generate_proof_as_owner(&balance_manager_cap, ctx);

// Using PlayCap (delegated)
let proof = balance_manager.generate_proof_as_player(&play_cap, ctx);

// House uses proof to settle balances
vault.settle_balance_manager(amount_out, amount_in, &mut balance_manager, &proof);
```

### Settlement Logic

When the House settles balances with a BalanceManager:

- **If player wins** (`amount_out > amount_in`): Vault pays the difference to BalanceManager
- **If player loses** (`amount_in > amount_out`): BalanceManager pays the difference to Vault
- **If break-even** (`amount_in == amount_out`): No transfer needed

The settlement function ensures the BalanceManager has sufficient funds before processing:

```move
// Vault validates and settles (uses house_balance in v3.1)
vault.settle_balance_manager(
    amount_out,      // How much player should receive
    amount_in,       // How much player bet
    &mut balance_manager,
    &play_proof      // Validates access
);
```

## PlayCap Management

### Minting PlayCaps

Only the BalanceManager owner can mint PlayCaps:

```move
// Owner mints a PlayCap for delegation
let play_cap = balance_manager.mint_play_cap(&balance_manager_cap, ctx);

// PlayCap can be transferred to another address
transfer::public_transfer(play_cap, recipient_address);
```

**Limits**: Maximum 1000 PlayCaps per BalanceManager (prevents DoS attacks)

You can check how many PlayCaps are currently allowed:
```move
let count = balance_manager.allow_list_length();
```

### Revoking PlayCaps

The owner can revoke a PlayCap to remove it from the allow list:

```move
// Owner revokes a PlayCap
balance_manager.revoke_play_cap(&balance_manager_cap, &play_cap_id, ctx);
```

**Note**: Revoking removes the PlayCap from the allow list, but the PlayCap object still exists. The holder should destroy it.

### Pruning All PlayCaps

The owner can revoke all PlayCaps at once by pruning the allow list:

```move
// Owner prunes the entire allow list
balance_manager.prune_allow_list(&balance_manager_cap, ctx);
```

This is useful when you want to revoke all existing PlayCaps without tracking each one individually.

### Destroying PlayCaps

PlayCap holders can destroy their PlayCap:

```move
// Simple destruction (if BalanceManager might not exist)
balance_manager::destroy_play_cap(play_cap, ctx);

// Recommended: Destroy and revoke (if BalanceManager exists)
balance_manager::destroy_play_cap_and_revoke(play_cap, &mut balance_manager, ctx);
```

The `destroy_play_cap_and_revoke()` function is recommended because it:
- Removes the PlayCap from the allow list
- Destroys the PlayCap object
- Works even if the PlayCap was already revoked

## Best Practices

### 1. Capability Storage

**✅ DO:**
- Store `BalanceManagerCap` securely (it's the master key)
- Store `PlayCap` in a wallet or safe location
- Use separate addresses for owner vs delegated gameplay if needed

**❌ DON'T:**
- Store capabilities in shared objects (security risk)
- Share `BalanceManagerCap` with untrusted parties
- Lose track of minted PlayCaps

### 2. PlayCap Delegation

**✅ DO:**
- Mint PlayCaps for trusted game frontends or services
- Revoke PlayCaps when no longer needed
- Use PlayCaps for limited-time gameplay access

**❌ DON'T:**
- Mint unlimited PlayCaps (there's a 1000 cap limit)
- Leave unused PlayCaps in the allow list
- Share PlayCaps with untrusted parties (they can play with your funds)

### 3. Fund Management

**✅ DO:**
- Keep `BalanceManagerCap` secure - it controls all deposits/withdrawals
- Use PlayCaps for gameplay to limit exposure
- Regularly withdraw unused funds
- Monitor balance manager activity

**❌ DON'T:**
- Deposit more than you're willing to risk in gameplay
- Leave large balances in balance managers unnecessarily
- Share `BalanceManagerCap` for "convenience"

### 4. Game Integration

**✅ DO:**
- Generate PlayProof at the start of each game transaction
- Validate PlayProof before processing transactions
- Use `settle_balance_manager()` for all fund transfers
- Handle insufficient funds gracefully

**❌ DON'T:**
- Store PlayProof across transactions (it's single-use)
- Skip proof validation
- Directly manipulate balance manager funds

### 5. Security Considerations

**PlayCap Risk**: A PlayCap holder can generate proofs and play games, potentially losing funds. However, they cannot:
- Withdraw funds (requires BalanceManagerCap)
- Deposit more funds (requires BalanceManagerCap)
- Revoke other PlayCaps (requires BalanceManagerCap)

**BalanceManagerCap Risk**: Losing the BalanceManagerCap means:
- Cannot deposit new funds
- Cannot withdraw existing funds
- Cannot manage PlayCaps
- **However**: Existing PlayCaps still work, so gameplay can continue

**Mitigation**: Consider using a multi-sig or hardware wallet for BalanceManagerCap storage.

## Implementation Details

### Object Structure

```move
public struct BalanceManager has key {
    id: UID,
    balance: Balance<SUI>,           // The actual funds
    tx_allow_listed: VecSet<ID>,      // Authorized PlayCap IDs
    cap_id: ID,                       // Owner's BalanceManagerCap ID
}

public struct BalanceManagerCap has key, store {
    id: UID,
    balance_manager_id: ID,
}

public struct PlayCap has key, store {
    id: UID,
    balance_manager_id: ID,
}

public struct PlayProof has drop {
    balance_manager_id: ID,
    player: address,
}
```

### Access Control

**Owner Validation**:
```move
fun validate_owner(self: &BalanceManager, cap: &BalanceManagerCap) {
    assert!(cap.balance_manager_id == self.id(), EInvalidOwner);
    assert!(cap.id.as_inner() == self.cap_id, EInvalidOwner);
}
```

**Player Validation**:
```move
fun validate_player(balance_manager: &BalanceManager, play_cap: &PlayCap) {
    assert!(
        balance_manager.tx_allow_listed.contains(object::borrow_id(play_cap)),
        EInvalidPlayer
    );
}
```

### Proof Generation

**As Owner**:
```move
public fun generate_proof_as_owner(
    balance_manager: &mut BalanceManager,
    cap: &BalanceManagerCap,
    ctx: &TxContext,
): PlayProof {
    balance_manager.validate_owner(cap);
    PlayProof {
        balance_manager_id: object::id(balance_manager),
        player: ctx.sender(),
    }
}
```

**As Player**:
```move
public fun generate_proof_as_player(
    balance_manager: &mut BalanceManager,
    play_cap: &PlayCap,
    ctx: &TxContext,
): PlayProof {
    balance_manager.validate_player(play_cap);
    PlayProof {
        balance_manager_id: object::id(balance_manager),
        player: ctx.sender(),
    }
}
```

### Settlement Implementation

The vault's `settle_balance_manager()` function handles fund transfers:

```move
public(package) fun settle_balance_manager(
    self: &mut Vault,
    amount_out: u64,      // Player should receive
    amount_in: u64,       // Player bet
    balance_manager: &mut BalanceManager,
    play_proof: &PlayProof,
) {
    // Ensure balance manager has funds for debits
    balance_manager.ensure_sufficient_funds(amount_in);
    
    if (amount_out > amount_in) {
        // Player wins: Vault pays difference from house_balance
        let needed = amount_out - amount_in;
        assert!(self.house_balance.value() >= needed, EInsufficientFunds);
        let balance = self.house_balance.split(needed);
        balance_manager.deposit_with_proof(play_proof, balance);
    } else if (amount_in > amount_out) {
        // Player loses: BalanceManager pays difference to house_balance
        let balance = balance_manager.withdraw_with_proof(
            play_proof,
            amount_in - amount_out
        );
        self.house_balance.join(balance);
    };
    // If equal, no transfer needed
}
```

**Note**: In v3.1, there is a single `house_balance` instead of separate `play_balance` and `reserve_balance`. The house is always active.

## Use Cases

### Use Case 1: Personal Balance Manager

A player creates their own balance manager and uses it directly:

```move
// Create balance manager
let (mut balance_manager, cap) = balance_manager::new(ctx);
balance_manager::share(balance_manager);

// Deposit funds
balance_manager.deposit(&cap, coins, ctx);

// Play games (using owner cap)
let proof = balance_manager.generate_proof_as_owner(&cap, ctx);
// ... game transaction ...

// Withdraw winnings
let winnings = balance_manager.withdraw_all(&cap, ctx);
```

### Use Case 2: Delegated Gameplay

A player delegates gameplay to a game frontend while maintaining control:

```move
// Owner creates balance manager and deposits
let (mut balance_manager, owner_cap) = balance_manager::new(ctx);
balance_manager::share(balance_manager);
balance_manager.deposit(&owner_cap, coins, ctx);

// Owner mints PlayCap for game frontend
let play_cap = balance_manager.mint_play_cap(&owner_cap, ctx);
transfer::public_transfer(play_cap, game_frontend_address);

// Game frontend can now play (but cannot withdraw)
// Game frontend generates proof and plays
let proof = balance_manager.generate_proof_as_player(&play_cap, ctx);
// ... game transaction ...

// Owner can still withdraw anytime
let funds = balance_manager.withdraw_all(&owner_cap, ctx);
```

### Use Case 3: Temporary Balance Manager

A game creates a temporary balance manager for a single session:

```move
// Game creates temporary balance manager
let (mut balance_manager, bm_cap) = balance_manager::new(ctx);
balance_manager.deposit(&bm_cap, player_funds, ctx);

// Generate proof as owner
let proof = balance_manager.generate_proof_as_owner(&bm_cap, ctx);

// Process game transactions
// ... game logic ...

// Withdraw remaining funds
let remainder = balance_manager.withdraw_all(&bm_cap, ctx);
balance_manager.destroy_empty(bm_cap, ctx);

// Return remainder to player
```

## Security Model

### What PlayCap CAN Do
- ✅ Generate PlayProof for gameplay
- ✅ Play games using balance manager funds
- ✅ Potentially lose funds through gameplay

### What PlayCap CANNOT Do
- ❌ Withdraw funds from balance manager
- ❌ Deposit funds into balance manager
- ❌ Mint or revoke other PlayCaps
- ❌ Destroy the balance manager

### What BalanceManagerCap CAN Do
- ✅ All PlayCap operations (via owner proof)
- ✅ Deposit and withdraw funds
- ✅ Mint and revoke PlayCaps
- ✅ Destroy empty balance manager

### Security Guarantees

1. **Fund Safety**: Only BalanceManagerCap can withdraw funds
2. **Access Control**: PlayCaps are validated against an allow list
3. **Proof Validation**: PlayProof is validated before any fund transfers
4. **Settlement Safety**: Vault ensures sufficient funds before settlement
5. **Cap Limits**: Maximum 1000 PlayCaps prevents DoS attacks

## Events

The BalanceManager emits events for all major operations. All events include the address of the user who performed the action:

- `BalanceManagerCreatedEvent`: When a new balance manager is created (includes `creator` address)
- `DepositCompletedEvent`: When funds are deposited (includes `depositor` address)
- `WithdrawalProcessedEvent`: When funds are withdrawn (includes `withdrawer` address)
- `PlayCapMintedEvent`: When a PlayCap is minted (includes `minter` address)
- `PlayCapRevokedEvent`: When a PlayCap is revoked (includes `revoker` address)
- `PlayCapDestroyedEvent`: When a PlayCap is destroyed (includes `destroyer` address)
- `BalanceManagerDestroyedEvent`: When a balance manager is destroyed (includes `destroyer` address)
- `PlayCapAllowListPrunedEvent`: When all PlayCaps are pruned from the allow list (includes `pruner` address and `pruned_count`)

These events can be used for tracking, analytics, and frontend updates. The address fields help identify who performed each action.

## FAQ

### Q: Can I recover funds if I lose my BalanceManagerCap?

**A**: No. The BalanceManagerCap is required for withdrawals. However, if you've minted PlayCaps, gameplay can continue. Consider using a secure wallet or multi-sig.

### Q: Can a PlayCap holder steal my funds?

**A**: A PlayCap holder can play games and potentially lose funds through gameplay, but they cannot directly withdraw funds. The worst case is they play games until the balance is depleted.

### Q: What happens if I revoke a PlayCap?

**A**: The PlayCap is removed from the allow list and can no longer generate valid proofs. The PlayCap object still exists and should be destroyed by the holder.

### Q: Can I have multiple PlayCaps for the same BalanceManager?

**A**: Yes, you can mint up to 1000 PlayCaps per BalanceManager. Each can be given to different services or frontends.

### Q: Do I need to share the BalanceManager?

**A**: Yes, the BalanceManager must be shared (via `balance_manager::share()`) before it can be used in game transactions, as games need to access it as a shared object.

### Q: Can I transfer my BalanceManagerCap?

**A**: Yes, BalanceManagerCap has `key, store` abilities, so it can be transferred. Transferring it transfers ownership of the balance manager.

### Q: What's the difference between `withdraw()` and `withdraw_all()`?

**A**: `withdraw(amount)` withdraws a specific amount, while `withdraw_all()` withdraws the entire balance. Both require the BalanceManagerCap.

## Related Documentation

- [Balance Manager Module](../package/sources/balance_manager.move) - Full implementation
- [Vault Module](../package/sources/vault.move) - Settlement logic
- [House Module](../package/sources/house.move) - Transaction processing
- [Security Audit Report](../audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md) - Security analysis

## Summary

- ✅ **BalanceManagerCap** = Full control (deposit, withdraw, manage PlayCaps)
- ✅ **PlayCap** = Limited gameplay access (play only, no deposit/withdraw)
- ✅ **PlayProof** = Temporary proof for single transaction
- ✅ **Fund Safety** = Only owner can withdraw, PlayCap cannot access funds directly
- ✅ **Delegation** = Secure way to allow gameplay without giving full control
- ✅ **Best Practice** = Use PlayCaps for delegated access, keep BalanceManagerCap secure
