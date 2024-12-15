module openplay::roulette;

use std::string::String;
use openplay::coin_flip_context::prediction;
use openplay::roulette_outcome;
use openplay::roulette_prediction::{RoulettePrediction, create_predictions};
use openplay::roulette_state;
use openplay::roulette_const::{get_number_slots};
use openplay::roulette_context;
use openplay::coin_flip_const::place_bet_action;
use sui::random::RandomGenerator;
use openplay::transaction::{Transaction, win, bet};
use openplay::roulette_context::{RouletteContext, is_valid_stakes};
use sui::table::{Self, Table};
use openplay::roulette_state::RouletteState;

// === Errors ===
const EUnsupportedStake: u64 = 1;
const EUnsupportedPrediction: u64 = 2;
const EUnsupportedAction: u64 = 3;


// === Structs ===
public struct Roulette has store {
    max_stake: u64,
    contexts: Table<ID,RouletteContext>,
    wheel_type: String,
    state: RouletteState,
}

public struct Interaction has copy, store, drop {
    balance_manager_id: ID,
    interact_type: InteractionType,
    transactions: vector<Transaction>,
}

// === Enums ===
public enum InteractionType has copy, drop, store {
    PLACE_BET { stakes: vector<u64>, predictions: vector<RoulettePrediction> },
}


// === Public-View Functions ===
public fun transactions(interaction: &Interaction): vector<Transaction> {
    interaction.transactions
}

// === Public-Mutative Functions ===
public fun new(max_stake: u64, wheel_type: String, ctx: &mut TxContext): Roulette {
    Roulette {
        max_stake,
        contexts: table::new(ctx),
        wheel_type,
        state: roulette_state::empty(),
    }
}

// === Public-Package Functions ===
public(package) fun interact(
    self: &mut Roulette,
    interaction: &mut Interaction,
    rand: &mut RandomGenerator,
) {
    // Validate the interaction
    self.validate_interact(interaction);

    // Ensure context
    self.ensure_context(interaction.balance_manager_id);
    let context = self.contexts.borrow_mut(interaction.balance_manager_id);

    // Perform the interaction using a mutable borrow
    interact_int(
        context,
        interaction.interact_type,
        &mut interaction.transactions,
        rand,
        self.wheel_type
    );

    // Update the state
    self.state.process_context(context);
}

public(package) fun new_interact(
    self : &Roulette,
    interact_name: String,
    balance_manager_id: ID,
    stakes: vector<u64>,
    bet_types: vector<String>,
    included_numbers: vector<vector<u8>>,
) : Interaction {

    if (interact_name != place_bet_action()) {
        abort EUnsupportedAction
    };

    let transaction = vector::empty<Transaction>();

    let predictions = create_predictions(stakes, bet_types, included_numbers, self.wheel_type);

    Interaction {
        balance_manager_id,
        interact_type: InteractionType::PLACE_BET { stakes, predictions },
        transactions: transaction,
    }
}

// === Private Functions ===
fun interact_int(
    context: &mut RouletteContext,
    interact_type: InteractionType,
    transactions: &mut vector<Transaction>,
    rand: &mut RandomGenerator,
    wheel_type: String,
) {
    match (interact_type) {
        InteractionType::PLACE_BET { stakes, predictions: prediction } => {
            // Update context

            let sum_stakes = sum_stakes(&stakes);

            transactions.push_back(bet(sum_stakes));
            context.bet(stakes, prediction, wheel_type);

            // Generate result
            let max_number = get_number_slots(wheel_type) - 1; // subtract one because slots start at 0

            let x = rand.generate_u64_in_range(0, max_number as u64);

            let result = roulette_outcome::new(x as u8);

            context.settle(result, wheel_type);

            transactions.push_back(win(context.get_payout()));
        },
    }
}



fun validate_interact(self: &Roulette, interaction: &Interaction) {
    match (interaction.interact_type) {
            InteractionType::PLACE_BET { stakes, predictions: predictions } => {
            assert!(is_valid_stakes(stakes, self.max_stake), EUnsupportedStake);
        },
    }
}


fun ensure_context(self: &mut Roulette, balance_manager_id: ID) {
    if (!self.contexts.contains(balance_manager_id)) {
        self.contexts.add(balance_manager_id, roulette_context::empty());
    };
}


fun sum_stakes(stakes: &vector<u64>) : u64 {
    let mut sum = 0;
    let mut i = 0;
    let len = stakes.length();
    loop {
        if (i == len) {
            break
        };
        sum = sum + stakes[i];
        i = i + 1;
    };
    sum
}