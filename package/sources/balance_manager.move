/// Balance manager is a shared object that keeps the balances for the different assets.
/// It needs to be passed along mutably when playing a game.
/// The balance_manager module works in a similar fashion as the one in deepbookv3.
module openplay_core::balance_manager;

use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::event::emit;
use sui::sui::SUI;
use sui::transfer::share_object;
use sui::vec_set::{Self, VecSet};

// === Errors ===
const EBalanceTooLow: u64 = 1;
const EInvalidOwner: u64 = 2;
const EInvalidPlayer: u64 = 3;
const EMaxPlayCapsReached: u64 = 4;
const EPlayCapNotInList: u64 = 5;
const EInvalidProof: u64 = 6;
const EBalanceNotEmpty: u64 = 7;

// === Constants ===
const MAX_PLAY_CAPS: u64 = 1000;

// === Structs ===
/// Shared object that manages player balances for game transactions.
/// Tracks SUI balance and maintains a list of authorized PlayCap IDs for delegated access.
public struct BalanceManager has key {
    id: UID,
    balance: Balance<SUI>,
    tx_allow_listed: VecSet<ID>,
    cap_id: ID,
}

/// Capability object that grants ownership and administrative access to a BalanceManager.
/// Only the holder of this cap can perform owner-only operations like deposits, withdrawals, and PlayCap management.
public struct BalanceManagerCap has key, store {
    id: UID,
    balance_manager_id: ID,
}

/// Owners of a `PlayCap` need to get a `PlayProof` to interact with games in a single PTB (drops after).
public struct PlayCap has key, store {
    id: UID,
    balance_manager_id: ID,
}

/// BalanceManager owner and `PlayCap` owners can generate a `PlayProof`.
/// `PlayProof` is used to validate the balance_manager when interacting with OpenPlay.
public struct PlayProof has drop {
    balance_manager_id: ID,
    player: address,
}

/// Event emitted when a new BalanceManager is created.
public struct BalanceManagerCreatedEvent has copy, drop {
    balance_manager_id: ID,
    balance_manager_cap_id: ID,
}

/// Event emitted when a deposit is completed to a BalanceManager.
public struct DepositCompletedEvent has copy, drop {
    balance_manager_id: ID,
    amount: u64,
}

/// Event emitted when a withdrawal is processed from a BalanceManager.
public struct WithdrawalProcessedEvent has copy, drop {
    balance_manager_id: ID,
    amount: u64,
}

/// Event emitted when a new PlayCap is minted for a BalanceManager.
public struct PlayCapMintedEvent has copy, drop {
    balance_manager_id: ID,
    play_cap_id: ID,
}

/// Event emitted when a PlayCap is revoked from a BalanceManager.
public struct PlayCapRevokedEvent has copy, drop {
    balance_manager_id: ID,
    play_cap_id: ID,
}

/// Event emitted when a PlayCap is destroyed.
public struct PlayCapDestroyedEvent has copy, drop {
    balance_manager_id: ID,
    play_cap_id: ID,
}

/// Event emitted when a BalanceManager is destroyed.
public struct BalanceManagerDestroyedEvent has copy, drop {
    balance_manager_id: ID,
    balance_manager_cap_id: ID,
}

// === Public-View Functions ===
/// Returns the id of the balance_manager.
public fun id(self: &BalanceManager): ID {
    self.id.to_inner()
}

/// Returns the ID of the PlayCap.
public fun cap_id(play_cap: &PlayCap): ID {
    play_cap.id.to_inner()
}

/// Returns the BalanceManager ID associated with this PlayCap.
public fun cap_balance_manager_id(play_cap: &PlayCap): ID {
    play_cap.balance_manager_id
}

/// Returns the BalanceManager ID from a PlayProof.
public fun proof_balance_manager_id(proof: &PlayProof): ID {
    proof.balance_manager_id
}

/// Returns the player address from a PlayProof.
public fun player(proof: &PlayProof): address {
    proof.player
}

/// Gets the current amount on the balance.
public fun balance(self: &BalanceManager): u64 {
    self.balance.value()
}

// === Public-Mutative Functions ===
/// Creates a new BalanceManager and its associated BalanceManagerCap.
/// Returns both objects, with the cap granting ownership rights to the manager.
public fun new(ctx: &mut TxContext): (BalanceManager, BalanceManagerCap) {
    let cap_id = object::new(ctx);

    let balance_manager = BalanceManager {
        id: object::new(ctx),
        balance: balance::zero(),
        tx_allow_listed: vec_set::empty(),
        cap_id: cap_id.to_inner(),
    };

    let balance_manager_cap = BalanceManagerCap {
        id: cap_id,
        balance_manager_id: balance_manager.id(),
    };

    emit(BalanceManagerCreatedEvent {
        balance_manager_id: balance_manager.id(),
        balance_manager_cap_id: balance_manager_cap.id.to_inner(),
    });

    (balance_manager, balance_manager_cap)
}

/// Shares the BalanceManager object, making it accessible to all users.
/// This is required before the BalanceManager can be used in game transactions.
public fun share(self: BalanceManager) {
    share_object(self)
}

/// Mint a `PlayCap`, only owner can mint a `PlayCap`.
public fun mint_play_cap(
    self: &mut BalanceManager,
    cap: &BalanceManagerCap,
    ctx: &mut TxContext,
): PlayCap {
    self.validate_owner(cap);
    assert!(self.tx_allow_listed.length() < MAX_PLAY_CAPS, EMaxPlayCapsReached);

    let id = object::new(ctx);
    self.tx_allow_listed.insert(id.to_inner());

    emit(PlayCapMintedEvent {
        balance_manager_id: self.id(),
        play_cap_id: id.to_inner(),
    });

    PlayCap {
        id,
        balance_manager_id: self.id(),
    }
}

/// Revoke a `PlayCap`. Only the owner can revoke a `PlayCap`.
public fun revoke_play_cap(self: &mut BalanceManager, cap: &BalanceManagerCap, player_cap_id: &ID) {
    self.validate_owner(cap);

    assert!(self.tx_allow_listed.contains(player_cap_id), EPlayCapNotInList);
    self.tx_allow_listed.remove(player_cap_id);

    emit(PlayCapRevokedEvent {
        balance_manager_id: self.id(),
        play_cap_id: *player_cap_id,
    });
}

/// Destroys a `PlayCap`. This function always works, even if the associated BalanceManager no longer exists.
/// The PlayCap owner can call this to permanently destroy their PlayCap.
public fun destroy_play_cap(play_cap: PlayCap) {
    let PlayCap { id, balance_manager_id } = play_cap;
    let play_cap_id = id.to_inner();

    emit(PlayCapDestroyedEvent {
        balance_manager_id,
        play_cap_id,
    });

    object::delete(id);
}

/// Destroys a `PlayCap` and revokes it from the BalanceManager's allow list if it's still present.
/// This is the recommended way to destroy a PlayCap when the BalanceManager still exists,
/// as it ensures the PlayCap is removed from the allow list.
/// The PlayCap will be destroyed even if it's not in the allow list.
public fun destroy_play_cap_and_revoke(
    play_cap: PlayCap,
    balance_manager: &mut BalanceManager,
) {
    let play_cap_id = cap_id(&play_cap);
    let balance_manager_id = cap_balance_manager_id(&play_cap);

    // Verify that the PlayCap belongs to this BalanceManager
    assert!(balance_manager.id() == balance_manager_id, EInvalidPlayer);

    // Remove from allow list if present (no error if not present)
    if (balance_manager.tx_allow_listed.contains(&play_cap_id)) {
        balance_manager.tx_allow_listed.remove(&play_cap_id);
        emit(PlayCapRevokedEvent {
            balance_manager_id,
            play_cap_id,
        });
    };

    // Destroy the PlayCap (extract fields and delete)
    let PlayCap { id, balance_manager_id: _ } = play_cap;
    emit(PlayCapDestroyedEvent {
        balance_manager_id,
        play_cap_id,
    });
    object::delete(id);
}

/// Generate a `PlayProof` by the owner.
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

/// Generate a `PlayProof` with a `PlayCap`.
/// Risk of equivocation since `PlayCap` is an owned object.
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

/// Deposits the provided balance into the `balance`. Only owner can call this directly.
public fun deposit(
    self: &mut BalanceManager,
    cap: &BalanceManagerCap,
    to_deposit: Coin<SUI>,
    ctx: &mut TxContext,
) {
    let proof = generate_proof_as_owner(self, cap, ctx);

    emit(DepositCompletedEvent {
        balance_manager_id: self.id(),
        amount: to_deposit.value(),
    });

    deposit_with_proof(self, &proof, to_deposit.into_balance());
}

/// Withdraw funds from a balance_manager. Only owner can call this directly.
public fun withdraw(
    self: &mut BalanceManager,
    cap: &BalanceManagerCap,
    withdraw_amount: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    let proof = generate_proof_as_owner(self, cap, ctx);

    emit(WithdrawalProcessedEvent {
        balance_manager_id: self.id(),
        amount: withdraw_amount,
    });
    withdraw_with_proof(self, &proof, withdraw_amount).into_coin(ctx)
}

/// Withdraw ALL funds from a balance_manager. Only owner can call this directly.
public fun withdraw_all(
    self: &mut BalanceManager,
    cap: &BalanceManagerCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    let proof = generate_proof_as_owner(self, cap, ctx);
    let withdraw_amount = self.balance();

    emit(WithdrawalProcessedEvent {
        balance_manager_id: self.id(),
        amount: withdraw_amount,
    });
    withdraw_with_proof(self, &proof, withdraw_amount).into_coin(ctx)
}

/// Validates that a PlayProof is valid for the given BalanceManager.
/// Aborts if the proof's balance_manager_id doesn't match the BalanceManager's ID.
public fun validate_proof(balance_manager: &BalanceManager, proof: &PlayProof) {
    assert!(object::id(balance_manager) == proof.balance_manager_id, EInvalidProof);
}

/// Destroys an empty BalanceManager and its cap.
/// Can only be called by the owner and only when the balance is zero.
public fun destroy_empty(self: BalanceManager, cap: BalanceManagerCap) {
    self.validate_owner(&cap);
    self.validate_balance_empty();

    let balance_manager_id = self.id();
    let cap_id = cap.id.to_inner();

    let BalanceManager { id, balance, tx_allow_listed: _, cap_id: _ } = self;
    balance.destroy_zero();
    object::delete(id);

    let BalanceManagerCap { id, balance_manager_id: _ } = cap;
    object::delete(id);

    // Event
    emit(BalanceManagerDestroyedEvent {
        balance_manager_id,
        balance_manager_cap_id: cap_id,
    });
}

// === Public-Package Functions ===
/// Withdraws the provided amount from the `balance`. Fails if there are not sufficient funds.
public(package) fun withdraw_with_proof(
    self: &mut BalanceManager,
    proof: &PlayProof,
    withdraw_amount: u64,
): Balance<SUI> {
    self.validate_proof(proof);

    assert!(self.balance.value() >= withdraw_amount, EBalanceTooLow);
    self.balance.split(withdraw_amount)
}

/// Deposits the provided balance into the `balance`.
public(package) fun deposit_with_proof(
    self: &mut BalanceManager,
    proof: &PlayProof,
    to_deposit: Balance<SUI>,
) {
    self.validate_proof(proof);

    self.balance.join(to_deposit);
}

/// Ensures the BalanceManager has sufficient funds for the requested amount.
/// Aborts if the balance is less than the required amount.
public(package) fun ensure_sufficient_funds(self: &BalanceManager, amount: u64) {
    assert!(self.balance.value() >= amount, EBalanceTooLow);
}

// === Private Functions ===
/// Validates that the provided cap is the owner of this BalanceManager.
/// Aborts if the cap doesn't match the stored cap_id or balance_manager_id.
fun validate_owner(self: &BalanceManager, cap: &BalanceManagerCap) {
    assert!(cap.balance_manager_id == self.id(), EInvalidOwner);
    assert!(cap.id.as_inner() == self.cap_id, EInvalidOwner);
}

/// Validates that the provided PlayCap is authorized for this BalanceManager.
/// Aborts if the PlayCap ID is not in the allow list.
fun validate_player(balance_manager: &BalanceManager, play_cap: &PlayCap) {
    assert!(balance_manager.tx_allow_listed.contains(object::borrow_id(play_cap)), EInvalidPlayer);
}

/// Validates that the BalanceManager has zero balance.
/// Aborts if there are any remaining funds.
fun validate_balance_empty(self: &BalanceManager) {
    assert!(self.balance() == 0, EBalanceNotEmpty);
}

// === Test Functions ===
#[test_only]
public fun generate_proof_for_testing(
    balance_manager: &mut BalanceManager,
    ctx: &TxContext,
): PlayProof {
    PlayProof {
        balance_manager_id: object::id(balance_manager),
        player: ctx.sender(),
    }
}
