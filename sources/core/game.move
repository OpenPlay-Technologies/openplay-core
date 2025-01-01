/// Game is responsible for executing the flow for placing bets and wins.
/// The game module plays a similar role as Pool in deepbookv3.
module openplay::game;

use openplay::balance_manager::BalanceManager;
use openplay::coin_flip::{Self, CoinFlip};
use openplay::constants::type_coin_flip;
use openplay::participation::{Self, Participation};
use openplay::registry::Registry;
use openplay::state::{Self, State};
use openplay::vault::{Self, Vault};
use std::option::some;
use std::string::String;
use sui::coin::Coin;
use sui::random::Random;
use sui::sui::SUI;
use sui::transfer::share_object;

#[test_only]
use openplay::transaction::Transaction;
#[test_only]
use std::string::utf8;
#[test_only]
use std::option::none;

// === Errors ===
const EInvalidGameType: u64 = 1;
const EInsufficientFunds: u64 = 2;
const EInvalidCap: u64 = 3;
const EInvalidParticipation: u64 = 4;

// === Structs ===
public enum Interaction {
    // SlotMachineInteraction(slot_machine::Interaction),
    CoinFlipInteraction(coin_flip::Interaction),
}

public struct Game has key {
    id: UID,
    // Display properties
    name: String,
    project_url: String,
    image_url: String,
    game_type: String,
    // slot_machine: Option<SlotMachine>,
    coin_flip: Option<CoinFlip>,
    vault: Vault,
    state: State,
    target_balance: u64,
}

public struct GameCap has key, store {
    id: UID,
    game_id: ID
}

// == Public-View Functions==
public fun id(self: &Game): ID {
    self.id.to_inner()
}

// === Public-Mutative Functions ===
public fun share(self: Game) {
    share_object(self)
}

public fun play_balance(self: &mut Game, ctx: &mut TxContext): u64 {
    self.process_end_of_day(ctx);
    self.vault.play_balance()
}

public fun new_coin_flip(
    registry: &mut Registry,
    name: String,
    project_url: String,
    image_url: String,
    target_balance: u64,
    max_stake: u64,
    house_edge_bps: u64,
    payout_factor_bps: u64,
    ctx: &mut TxContext,
): (Game, GameCap) {
    let coin_flip = coin_flip::new(max_stake, house_edge_bps, payout_factor_bps, ctx);
    let game = Game {
        id: object::new(ctx),
        name,
        project_url,
        image_url,
        game_type: type_coin_flip(),
        coin_flip: some(coin_flip),
        vault: vault::empty(ctx),
        state: state::new(ctx),
        target_balance,
    };
    registry.register_game(game.id.to_inner());

    let cap = GameCap {
        id: object::new(ctx),
        game_id: game.id()
    };

    (game, cap)
}

/// Interact entry function that can be used when the game is of type CoinFlip.
/// Enums can not be used in entry functions therefore all parameters need to be provided.
/// Parameters that are not needed for the specific interact will be ignored.
entry fun interact_coin_flip(
    self: &mut Game,
    balance_manager: &mut BalanceManager,
    interact_name: String,
    stake: u64,
    prediction: String,
    random: &Random,
    ctx: &mut TxContext,
): coin_flip::Interaction {
    // Verify that it is indeed a coin flip game
    assert!(self.game_type == type_coin_flip(), EInvalidGameType);
    // Make sure the vault is up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);
    // Make sure we have enough funds in the vault to play this game
    self.ensure_sufficient_funds(self.coin_flip.borrow().max_payout(stake));
    // Interact with coin flip and record any transactions made
    let mut interact = coin_flip::new_interact(
        interact_name,
        balance_manager.id(),
        prediction,
        stake,
    );
    self.coin_flip.borrow_mut().interact(&mut interact, random, ctx);
    // Process transactions by state
    let (credit_balance, debit_balance, owner_fee, protocol_fee) = self
        .state
        .process_transactions(&interact.transactions(), balance_manager.id());

    // Settle the balances in vault
    self.vault.settle_balance_manager(credit_balance, debit_balance, balance_manager);
    self.vault.process_fees(owner_fee, protocol_fee);

    interact
}

/// Create a new participation
public fun new_participation(self: &Game, ctx: &mut TxContext): Participation {
    participation::empty(self.id.to_inner(), ctx)
}

/// Stake money in the protocol to participate in the house winnings.
/// The stake is first added to the account's inactive stake, and is only activated in the next epoch.
public fun stake(
    self: &mut Game,
    participation: &mut Participation,
    stake: Coin<SUI>,
    ctx: &mut TxContext,
) {
    self.assert_valid_participation(participation);

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Process the stake in the history
    self.state.process_stake(stake.value());

    // Add funds to the participation
    participation.add_inactive_stake(stake.value(), ctx);

    // Move funds to the vault
    self.vault.deposit(stake.into_balance());
}

/// Refreshes the participation to process any unprocessed profits or losses.
public fun update_participation(self: &mut Game, participation: &mut Participation, ctx: &mut TxContext) {
    self.assert_valid_participation(participation);

    // Make sure the end of day is processed
    self.process_end_of_day(ctx);

    // Refresh the participation
    self.state.refresh(participation, ctx);
}

/// Withdraws the stake from the current game. This only goes into effect in the next epoch.
public fun unstake(self: &mut Game, participation: &mut Participation, ctx: &mut TxContext) {
    self.assert_valid_participation(participation);

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Unstake the funds in the participation
    let (unstake_immediately, pending_unstake) = participation.unstake(ctx);

    // Process the unstake in the history
    self.state.process_unstake(unstake_immediately, pending_unstake);
}

public fun claim_all(
    self: &mut Game,
    participation: &mut Participation,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.assert_valid_participation(participation);

    // Make sure the vault and participation are up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Take the claimable balance from participation
    let claimable = participation.claim_all(ctx);

    // Withdraw from vault
    self.vault.withdraw(claimable).into_coin(ctx)
}

/// Claims all the fees for this game. Can only be called by the game owner (using the game_cap)
public fun claim_all_fees(self: &mut Game, game_cap: &GameCap, ctx: &mut TxContext): Coin<SUI> {
    assert_valid_cap(self, game_cap);
    self.vault.withdraw_all_owner_fees().into_coin(ctx)
}

// == Private Functions ==
/// The first time this gets called on a new epoch, the end of the day procedure is initiated for the last known epoch.
/// The vault saves the end of day balance for the house and resets to the target balance if there are enough funds available.
/// Note: there can be a number of epochs in between without any activity.
fun process_end_of_day(self: &mut Game, ctx: &TxContext) {
    let (epoch_switched, prev_epoch, end_of_day_balance, was_active) = self
        .vault
        .process_end_of_day(ctx);

    if (epoch_switched) {
        let profits: u64;
        let losses: u64;
        if (was_active) {
            if (end_of_day_balance > self.target_balance) {
                profits = end_of_day_balance - self.target_balance;
                losses = 0;
            } else {
                losses = self.target_balance - end_of_day_balance;
                profits = 0;
            };
        } else {
            // The house was not funded so no profits or losses were made
            profits = 0;
            losses = 0;
        };
        let new_stake_amount = self.state.process_end_of_day(prev_epoch, profits, losses, ctx);
        if (new_stake_amount >= self.target_balance) {
            self.vault.activate(self.target_balance);
        };
    }
}

/// Ensures that the vault can cover `max_payout` with the play balance
fun ensure_sufficient_funds(self: &Game, max_payout: u64) {
    assert!(self.vault.play_balance() >= max_payout, EInsufficientFunds)
}

fun assert_valid_cap(self: &Game, game_cap: &GameCap){
    assert!(self.id() == game_cap.game_id, EInvalidCap);
}

fun assert_valid_participation(self: &Game, participation: &Participation){
    assert!(self.id() == participation.game_id(), EInvalidParticipation);
}

// === Test Functions ===
#[test_only]
public fun empty_game_for_testing(target_balance: u64, ctx: &mut TxContext): Game {
    Game {
        id: object::new(ctx),
        name: utf8(b""),
        image_url: utf8(b""),
        project_url: utf8(b""),
        game_type: utf8(b""),
        vault: vault::empty(ctx),
        state: state::new(ctx),
        target_balance,
        coin_flip: none(),
    }
}

#[test_only]
public fun cap_for_testing(game: &Game, ctx: &mut TxContext): GameCap {
    GameCap{
        id: object::new(ctx),
        game_id: game.id()
    }
}

#[test_only]
public fun process_transactions_for_testing(
    self: &mut Game,
    txs: &vector<Transaction>,
    balance_manager: &mut BalanceManager,
    ctx: &TxContext,
) {
    // Make sure the vault is up to date (end of day is processed for previous days)
    self.process_end_of_day(ctx);

    // Process transactions by state
    let (credit_balance, debit_balance, owner_fee, protocol_fee) = self
        .state
        .process_transactions(txs, balance_manager.id());

    // Settle the balances in vault
    self.vault.settle_balance_manager(credit_balance, debit_balance, balance_manager);
    self.vault.process_fees(owner_fee, protocol_fee);
}

#[test_only]
public fun add_owner_fees_for_testing(self: &mut Game, amount: u64, ctx: &mut TxContext) {
    self.vault.fund_owner_fees_for_testing(amount, ctx);
}