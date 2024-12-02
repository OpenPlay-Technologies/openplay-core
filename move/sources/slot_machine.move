/*
The slot machine is an implementation for slot games. It is a child object of the Game objec hat manages the complete flow from beginning to end.
The slot machine plays a similar role as the Pool in deepbookv3.
*/
module openplay::slot_machine;

// === Imports ===
use std::string;
use std::debug;
use openplay::utils::compute_stopping_value;

// === Errors ===
const EInvalidReels: u64 = 1;


// === Structs ===
public struct SlotMachine has store {
    name: string::String,
    reels: vector<vector<u8>>,
    accepted_stakes: vector<u64>,
    max_payout_factor: u64
}

public struct SlotMachineResult has store, drop, copy {
    win_multiplier: u64,
    symbols: vector<u8>
}

public enum Interaction {
    PLACE_BET { stake: u64 }
}

// === Public-Mutative Functions ===
public fun new(name: string::String, reels: vector<vector<u8>>, accepted_stakes: vector<u64>, max_payout_factor: u64): SlotMachine {
    let nb_of_reels = vector::length(&reels);
    assert!(nb_of_reels == 5, EInvalidReels); // Game should have 5 reels

    let mut y: u64 = 0;
    while (y < nb_of_reels) {
        let this_reel = reels[y];
        assert!(vector::length(&this_reel) > 0, EInvalidReels); // Every real should have at least 1 element
        this_reel.do!(|val| assert!(val >=0 && val < 5, EInvalidReels),); // Accepted symbols are 0, 1, 2, 3, 4
        y = y + 1;
    };

    SlotMachine {
        name,
        reels,
        accepted_stakes,
        max_payout_factor
    }
}

// === Public-View Functions ===
public fun name(slot_game: &SlotMachine): string::String {
    slot_game.name
}

public fun max_payout_factor(slot_game: &SlotMachine): u64 {
    slot_game.max_payout_factor
}

public fun win_multiplier(slot_game_result: &SlotMachineResult): u64 {
    slot_game_result.win_multiplier
}

public fun symbols(slot_game_result: &SlotMachineResult): vector<u8> {
    slot_game_result.symbols
}

// === Public-Package Functions ===
public(package) fun finish_game(slot_game: &SlotMachine, rand: u64): SlotMachineResult {
    // Determine output vals
    let mut output_symbols = vector::empty<u8>();
    std::u64::do!(slot_game.reels.length(),  // for each reel index
    |i| {
        let reel = slot_game.reels.borrow(i);
        let stopping_value = compute_stopping_value(reel, rand, i);
        vector::push_back(&mut output_symbols, stopping_value);
    });
    // Compute the win multiplier
    let win_multiplier = compute_win_multiplier(slot_game, *&output_symbols);
    debug::print(&win_multiplier);
    SlotMachineResult { win_multiplier, symbols: output_symbols }
}

public(package) fun interact(slot_machine: &SlotMachine, interaction: &Interaction){
    abort 0
}


// === Private Functions ===
fun compute_win_multiplier(slot_game: &SlotMachine, symbols: vector<u8>): u64 {
    let mut counts = vector[0u8, 0u8, 0u8, 0u8, 0u8]; // We have 5 possible symbols

    symbols.do!(|val| {
        let count_ref = vector::borrow_mut(&mut counts, val as u64); 
        *count_ref = *count_ref + 1u8;
    });
    let index = vector::find_index!(&counts, |x| *x >= 3);
    if (index.is_none()) {
        0 as u64
    }
    else {
        let mut base_mul:u64 = 1;
        let symbol = index.borrow();
        // Symbol value multiplier
        if (symbol == 0){
            base_mul = base_mul * 1;
        }
        else if (symbol == 1){
            base_mul = base_mul * 2;
        }
        else if (symbol == 2){
            base_mul = base_mul * 3;
        }
        else if (symbol == 3){
            base_mul = base_mul * 4;
        }
        else if (symbol == 4){
            base_mul = base_mul * 5;
        };

        // Count multiplier
        let count = counts[*symbol];
        if (count == 3){
            base_mul = base_mul * 1;
        }
        else if (count == 4){
            base_mul = base_mul * 2;
        }
        else if (count == 5){
            base_mul = base_mul * 3;
        };
        if (base_mul > slot_game.max_payout_factor){
            slot_game.max_payout_factor
        }
        else {
        base_mul
        }
    }
}

// === Test Functions ===
#[test_only]
public fun destroy(slot_game: SlotMachine) {
    let SlotMachine {name: _, reels: _, accepted_stakes: _, max_payout_factor: _} = slot_game;
}