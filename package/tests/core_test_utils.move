#[test_only]
module openplay_core::core_test_utils;

use openplay_core::house::{Self, House, HouseAdminCap};
use openplay_core::participation::Participation;
use sui::coin::mint_for_testing;
use sui::random::{Random, create_for_testing};
use sui::sui::SUI;
use sui::test_scenario::{begin, return_shared};

public fun create_and_fix_random(bytes: vector<u8>) {
    // Create the random
    let mut scenario = begin(@0x0);
    {
        create_for_testing(scenario.ctx());
    };

    // WE fix the random for testing purposes
    scenario.next_tx(@0x0);
    {
        let mut rand = scenario.take_shared<Random>();
        rand.update_randomness_state_for_testing(
            0,
            // x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            bytes,
            scenario.ctx(),
        );
        return_shared(rand);
    };
    scenario.end();
}

public fun fund_house_for_playing(
    house: &mut House,
    amount: u64,
    ctx: &mut TxContext,
): Participation {
    let mut participation = house.new_participation(ctx);
    let stake = mint_for_testing<SUI>(amount, ctx);
    house.stake(&mut participation, stake, ctx);
    participation
}

public fun default_house(ctx: &mut TxContext): (House, HouseAdminCap) {
    let (mut house, house_admin) = house::new_for_testing(
        false,
        100_000,
        2000, // 20% house fee (performance fee)
        ctx,
    );
    let game_id = object::id_from_address(@0xA);
    house.admin_set_game_fee(&house_admin, game_id, 69);

    (house, house_admin)
}
