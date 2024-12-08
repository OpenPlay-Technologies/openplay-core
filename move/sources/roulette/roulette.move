module openplay::roulette;

use std::string::String;
use openplay::coin_flip_const::place_bet_action;
use sui::kiosk::place;
use sui::random::RandomGenerator;
use openplay::transaction::Transaction;
use openplay::roulette_context::{RouletteContext, Prediction, is_valid_prediction, Outcome};
use sui::table::Table;
use openplay::roulette_const::{WheelType};
use openplay::roulette_state::RouletteState;

// === Errors ===
const EUnsupportedStake: u64 = 1;
const EUnsupportedPrediction: u64 = 2;
const EUnsupportedAction: u64 = 3;


// === Structs ===
public struct Roulette has store {
    max_stake: u64,
    contexts: Table<ID,RouletteContext>,
    wheel_type: WheelType,
    state: RouletteState,
}

public struct Interaction has copy, store, drop {
    balance_manager_id: ID,
    interact_type: InteractionType,
    transactions: vector<Transaction>,
}

public enum InteractionType has copy, drop, store {
    PLACE_BET { stake: u64, prediction: Prediction },
}

// === Public-Mutative Functions ===
public fun new(max_stake: u64, wheel_type: WheelType, ctx: &mut TxContext): Roulette {
    Roulette {
        max_stake,
        contexts: table::new(ctx),
        wheel_type,
        state: roulette_state::empty(),
    }
}

// === Public-View Functions ===
public fun transactions(interaction: &Interaction): vector<Transaction> {
    interaction.transactions
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
    self.interact_int(
        context,
        interaction.interact_type,
        &mut interaction.transactions,
        rand,
    );

    // Update the state
    self.state.process_context(context);
}

public(package) fun new_interact(
    interact_name: String,
    balance_manager_id: ID,
    stake: u64,
    bet_type: String,
    numbers: vector<u8>,
    color: String,
) : Interaction {

    if (interact_name != place_bet_action()) {
        abort EUnsupportedAction;
    };

    let transaction = vector::empty<Transaction>();

    let prediction = Prediction {
        numbers,
        color,
        bet_type,
    };

    Interaction {
        balance_manager_id,
        interact_type: InteractionType::PLACE_BET { stake, prediction },
        transactions: transaction,
    }
}


fun interact_int(
    self: &mut Roulette,
    context: &mut RouletteContext,
    interact_type: InteractionType,
    transactions: &mut vector<Transaction>,
    rand: &mut RandomGenerator,
) {
    match (interact_type) {
        InteractionType::PLACE_BET { stake, prediction: prediction } => {
            // Update context
            transactions.push_back(Transaction::new(stake));
            context.bet(stake, prediction, self.wheel_type);


            // Generate result
            let max_number = get_number_slots(self.wheel_type) - 1; // subtract one because slots start at 0

            let x = rand.generate_u64_in_range(0, max_number);
            let result = Outcome {
                number: x,
                color: get_color(x, self.wheel_type),
            };

            context.settle(result, self.wheel_type);

            transactions.push_back(Transaction::new(context.get_payout()));
        },
    }
}



fun validate_interact(self: &Roulette, interaction: &Interaction) {
    match (interaction.interact_type) {
            InteractionType::PLACE_BET { stake, prediction: prediction } => {
            assert!(stake < self.max_stake, EUnsupportedStake);
            assert!(
                is_valid_prediction(prediction, self.wheel_type),
                EUnsupportedPrediction,
            );
        },
    }
}


