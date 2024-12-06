module openplay::coin_flip;

use openplay::coin_flip_const::{
    head_result,
    tail_result,
    house_bias_result,
    max_house_edge,
    max_payout_factor,
    place_bet_action
};
use openplay::coin_flip_context::{Self, CoinFlipContext, player_won};
use openplay::coin_flip_state::{Self, CoinFlipState};
use openplay::transaction::{Transaction, bet, win};
use std::string::String;
use sui::random::RandomGenerator;
use sui::table::{Self, Table};

// === Errors ===
const EUnsupportedStake: u64 = 1;
const EUnsupportedHouseEdge: u64 = 2;
const EUnsupportedPayoutFactor: u64 = 3;
const EUnsupportedPrediction: u64 = 4;
const EUnsupportedAction: u64 = 5;

// === Structs ===
public struct CoinFlip has store {
    max_stake: u64,
    contexts: Table<ID, CoinFlipContext>,
    house_edge: u64, // Percentage bias in favor of the house (0 to MAX_HOUSE_EDGE, where MAX_HOUSE_EDGE = 100%)
    payout_factor: u64, // Percentage multiplier of the payout factor,
    state: CoinFlipState, // Global state specific to the CoinFLip game
}

public struct Interaction has copy, store, drop {
    balance_manager_id: ID,
    interact_type: InteractionType,
    transactions: vector<Transaction>,
}

public enum InteractionType has copy, drop, store {
    PLACE_BET { stake: u64, prediction: String },
}

// === Public-Mutative Functions ===
public fun new(max_stake: u64, house_edge: u64, payout_factor: u64, ctx: &mut TxContext): CoinFlip {
    assert!(house_edge < max_house_edge(), EUnsupportedHouseEdge);
    assert!(payout_factor < max_payout_factor(), EUnsupportedPayoutFactor);
    CoinFlip {
        max_stake,
        contexts: table::new(ctx),
        house_edge,
        payout_factor,
        state: coin_flip_state::empty(),
    }
}

// === Public-View Functions ===
public fun transactions(interaction: &Interaction): vector<Transaction> {
    interaction.transactions
}

// === Public-Package Functions ===
public(package) fun interact(
    self: &mut CoinFlip,
    interaction: &mut Interaction,
    rand: &mut RandomGenerator,
) {
    // Validate the interaction
    self.validate_interact(interaction);

    // Extract context and params
    let house_edge = self.house_edge;
    let payout_factor = self.payout_factor;

    // Ensure context
    self.ensure_context(interaction.balance_manager_id);
    let context = self.contexts.borrow_mut(interaction.balance_manager_id);

    // Perform the interaction using a mutable borrow
    interact_int(
        context,
        interaction.interact_type,
        house_edge,
        payout_factor,
        &mut interaction.transactions,
        rand,
    );

    // Update the state
    self.state.process_context(context);
}

public(package) fun new_interact(
    interact_name: String,
    balance_manager_id: ID,
    prediction: String,
    stake: u64,
): Interaction {
    // Transaction vec
    let transactions = vector::empty<Transaction>();
    // Construct the correct interact type
    let interact_type;
    if (interact_name == place_bet_action()) {
        interact_type = InteractionType::PLACE_BET { stake, prediction: prediction };
    } else {
        abort EUnsupportedAction
    };
    Interaction {
        balance_manager_id,
        transactions,
        interact_type,
    }
}

// Gets the max payout of the game. This ensures that the vault has sufficient funds to accept the bet.
public(package) fun max_payout(self: &CoinFlip, stake: u64): u64 {
    stake / 100 * self.payout_factor
}

// === Private Functions ===
fun interact_int(
    context: &mut CoinFlipContext,
    interaction_type: InteractionType,
    house_edge: u64,
    payout_factor: u64,
    transactions: &mut vector<Transaction>,
    rand: &mut RandomGenerator,
) {
    match (interaction_type) {
        InteractionType::PLACE_BET { stake, prediction } => {
            // Place bet and deduct stake
            transactions.push_back(bet(stake));
            context.bet(stake, prediction);
            // Generate result
            let x = rand.generate_u64_in_range(0, house_edge);
            let result;
            if (x <= house_edge) {
                result = house_bias_result();
            } else if (x % 2 == 0) {
                result = head_result();
            } else {
                result = tail_result();
            };
            // Update context
            context.settle(result);
            // Pay out winnings, or zero win if player lost
            if (context.player_won()) {
                transactions.push_back(win(stake / 100 * payout_factor));
            } else {
                transactions.push_back(win(0));
            };
        },
    }
}

fun validate_interact(self: &CoinFlip, interaction: &Interaction) {
    match (interaction.interact_type) {
        InteractionType::PLACE_BET { stake, prediction: prediction } => {
            assert!(stake < self.max_stake, EUnsupportedStake);
            assert!(
                prediction == head_result() || prediction == tail_result(),
                EUnsupportedPrediction,
            );
        },
    }
}

fun ensure_context(self: &mut CoinFlip, balance_manager_id: ID) {
    if (!self.contexts.contains(balance_manager_id)) {
        self.contexts.add(balance_manager_id, coin_flip_context::empty());
    };
}
