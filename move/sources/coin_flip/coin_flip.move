module openplay::coin_flip;

use openplay::coin_flip_const::{
    head_result,
    tail_result,
    house_bias_result,
    max_house_edge_bps,
    max_payout_factor_bps,
    place_bet_action
};
use openplay::coin_flip_context::{Self, CoinFlipContext, player_won};
use openplay::coin_flip_state::{Self, CoinFlipState};
use openplay::transaction::{Transaction, bet, win};
use std::string::String;
use sui::random::{Random, RandomGenerator};
use sui::table::{Self, Table};
use std::uq32_32::{UQ32_32, from_quotient, int_mul, from_int};

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
    house_edge_bps: u64, // House bias in basis points (e.g. `100` will give the house a 1% change of winning)
    payout_factor_bps: u64, // Payout factor in basis points (e.g. `20_000` will give 2x or 200% of stake)
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
public fun new(max_stake: u64, house_edge_bps: u64, payout_factor_bps: u64, ctx: &mut TxContext): CoinFlip {
    assert!(house_edge_bps < max_house_edge_bps(), EUnsupportedHouseEdge);
    assert!(payout_factor_bps < max_payout_factor_bps(), EUnsupportedPayoutFactor);
    CoinFlip {
        max_stake,
        contexts: table::new(ctx),
        house_edge_bps,
        payout_factor_bps,
        state: coin_flip_state::empty(),
    }
}

// === Public-View Functions ===
public fun transactions(interaction: &Interaction): vector<Transaction> {
    interaction.transactions
}

public fun payout_factor(self: &CoinFlip): UQ32_32 {
    from_quotient(self.payout_factor_bps, 10_000)
}

// === Public-Package Functions ===
public(package) fun interact(
    self: &mut CoinFlip,
    interaction: &mut Interaction,
    rand: &Random,
    ctx: &mut TxContext
) {
    // Validate the interaction
    self.validate_interact(interaction);

    // Extract context and params
    let house_edge_bps = self.house_edge_bps;
    let payout_factor = self.payout_factor();

    // Ensure context
    self.ensure_context(interaction.balance_manager_id);
    let context = self.contexts.borrow_mut(interaction.balance_manager_id);

    // Perform the interaction using a mutable borrow
    interact_int(
        context,
        interaction.interact_type,
        house_edge_bps,
        payout_factor,
        &mut interaction.transactions,
        &mut rand.new_generator(ctx),
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
    int_mul(stake, self.payout_factor())
}

public(package) fun get_context(self: &mut CoinFlip, balance_manager_id: ID): &CoinFlipContext {
    self.ensure_context(balance_manager_id);
    self.contexts.borrow(balance_manager_id)
}

// === Private Functions ===
fun interact_int(
    context: &mut CoinFlipContext,
    interaction_type: InteractionType,
    house_edge: u64,
    payout_factor: UQ32_32,
    transactions: &mut vector<Transaction>,
    rand: &mut RandomGenerator,
) {
    match (interaction_type) {
        InteractionType::PLACE_BET { stake, prediction } => {
            // Place bet and deduct stake
            transactions.push_back(bet(stake));
            context.bet(stake, prediction);
            // Generate result
            let x = rand.generate_u64_in_range(0, 10_000);
            let result;
            if (x < house_edge) {
                result = house_bias_result();
            } else if (x % 2 == 0) {
                result = head_result();
            } else {
                result = tail_result();
            };
            // Update context
            context.settle(result);
            // Pay out winnings, or zero win if player lost
            let payout;
            if (context.player_won()) {
                payout = payout_factor;
            } else {
                payout = from_int(0);
            };
            transactions.push_back(win(int_mul(stake, payout)));
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
