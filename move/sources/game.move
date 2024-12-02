/*
Game is responsible for executing the flow for placing bets and wins.
The game module plays a similar role as Pool in deepbookv3.
*/ 
module openplay::game;

// === Imports ===
use openplay::slot_machine::{Self, SlotMachine};
use openplay::coin_flip::{Self, CoinFlip};
use openplay::coin_flip_interaction::{Self};
use openplay::balance_manager::{BalanceManager};

// === Errors ===
const EInvalidGameType: u64 = 1;

// === Structs ===
public enum GameType has store, copy, drop {
    SlotMachine,
    CoinFlip
}

public enum Interaction {
    SlotMachineInteraction(slot_machine::Interaction),
    CoinFlipInteraction(coin_flip_interaction::Interaction)
}

public struct Game has key {
    id: UID,
    game_type: GameType,
    slot_machine: Option<SlotMachine>,
    coin_flip: Option<CoinFlip>
}

// === Public-Mutative Functions ===
public entry fun interact(game: &Game, interaction: slot_machine::Interaction, balance_manager: &BalanceManager){

    match (interaction) {
        Interaction::SlotMachineInteraction(interaction) => game.slot_machine.borrow().interact(interaction),
        Interaction::CoinFlipInteraction(interaction) => game.coin_flip.borrow().interact(interaction)
    };
}

public entry fun interact_coin_flip(game: &Game, balance_manager: &BalanceManager, interact_type: u8, stake: u64){
    assert!(game.game_type == GameType::SlotMachine, EInvalidGameType);
    let interact = coin_flip_interaction::new(interact_type, stake);
}