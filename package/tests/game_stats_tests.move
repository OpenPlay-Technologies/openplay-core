#[test_only]
module openplay_core::game_stats_tests;

use openplay_core::game_stats;
use openplay_core::transaction::{bet, win};
use std::unit_test::destroy;
use sui::test_scenario::{begin, next_epoch};

#[test]
public fun process_transactions_ok() {
    let addr = @0xA;

    let mut scenario = begin(addr);
    let game_id = object::new(scenario.ctx());

    let mut stats = game_stats::new(&game_id, scenario.ctx());

    // Process bet and win
    stats.process_transactions(&vector[bet(10_000), win(20_000)], scenario.ctx());
    // Check current volumes
    assert!(stats.current_volumes().bet_count() == 1);
    assert!(stats.current_volumes().bet_sum() == 10_000);
    assert!(stats.current_volumes().win_count() == 1);
    assert!(stats.current_volumes().win_sum() == 20_000);
    // Check all time volumes
    assert!(stats.all_time_volumes().bet_count() == 1);
    assert!(stats.all_time_volumes().bet_sum() == 10_000);
    assert!(stats.all_time_volumes().win_count() == 1);
    assert!(stats.all_time_volumes().win_sum() == 20_000);

    // Process another bet and a zero-win (shouldn't count as a win)
    stats.process_transactions(&vector[bet(10_000), win(0)], scenario.ctx());
    // Check current volumes
    assert!(stats.current_volumes().bet_count() == 2);
    assert!(stats.current_volumes().bet_sum() == 20_000);
    assert!(stats.current_volumes().win_count() == 1);
    assert!(stats.current_volumes().win_sum() == 20_000);
    // Check all time volumes
    assert!(stats.all_time_volumes().bet_count() == 2);
    assert!(stats.all_time_volumes().bet_sum() == 20_000);
    assert!(stats.all_time_volumes().win_count() == 1);
    assert!(stats.all_time_volumes().win_sum() == 20_000);

    // Advance epoch
    scenario.next_epoch(addr);

    // Process bet and win
    stats.process_transactions(&vector[bet(10_000), win(20_000)], scenario.ctx());
    // Check current volumes
    assert!(stats.current_volumes().bet_count() == 1);
    assert!(stats.current_volumes().bet_sum() == 10_000);
    assert!(stats.current_volumes().win_count() == 1);
    assert!(stats.current_volumes().win_sum() == 20_000);
    // Check all time volumes
    assert!(stats.all_time_volumes().bet_count() == 3);
    assert!(stats.all_time_volumes().bet_sum() == 30_000);
    assert!(stats.all_time_volumes().win_count() == 2);
    assert!(stats.all_time_volumes().win_sum() == 40_000);

    // Check historic volumes
    assert!(stats.historic_volumes(0).bet_count() == 2);
    assert!(stats.historic_volumes(0).bet_sum() == 20_000);
    assert!(stats.historic_volumes(0).win_count() == 1);
    assert!(stats.historic_volumes(0).win_sum() == 20_000);

    destroy(stats);
    destroy(game_id);
    scenario.end();
}

#[test]
public fun test_game_id() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let game_id = object::new(scenario.ctx());
        let stats = game_stats::new(&game_id, scenario.ctx());
        
        assert!(stats.game_id() == game_id.to_inner(), 0);
        
        destroy(stats);
        destroy(game_id);
        scenario.end();
    }
}

#[test]
public fun test_id() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let game_id = object::new(scenario.ctx());
        let stats = game_stats::new(&game_id, scenario.ctx());
        
        let stats_id = stats.id();
        assert!(stats_id != object::id_from_address(@0x0), 0);
        assert!(stats_id != game_id.to_inner(), 0); // Should be different from game_id
        
        destroy(stats);
        destroy(game_id);
        scenario.end();
    }
}

#[test]
public fun test_share() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let game_id = object::new(scenario.ctx());
        let stats = game_stats::new(&game_id, scenario.ctx());
        
        // Share the stats
        stats.share();
        
        destroy(game_id);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = game_stats::EEpochNotFound)]
public fun test_historic_volumes_epoch_not_found() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let game_id = object::new(scenario.ctx());
        let stats = game_stats::new(&game_id, scenario.ctx());
        
        // Try to get historic volumes for an epoch that doesn't exist
        let _volumes = stats.historic_volumes(999);
        
        destroy(stats);
        destroy(game_id);
        scenario.end();
    }
}

#[test]
public fun test_view_functions() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let game_id = object::new(scenario.ctx());
        let mut stats = game_stats::new(&game_id, scenario.ctx());
        
        // Process some transactions
        stats.process_transactions(&vector[bet(10_000), win(5_000)], scenario.ctx());
        
        // Test bet_sum
        let volumes = stats.current_volumes();
        assert!(game_stats::bet_sum(&volumes) == 10_000, 0);
        
        // Test bet_count
        assert!(game_stats::bet_count(&volumes) == 1, 1);
        
        // Test win_sum
        assert!(game_stats::win_sum(&volumes) == 5_000, 2);
        
        // Test win_count
        assert!(game_stats::win_count(&volumes) == 1, 3);
        
        destroy(stats);
        destroy(game_id);
        scenario.end();
    }
}

// NOTE: The EUnknownTransaction error in game_stats is unreachable code.
// When an invalid transaction type is processed, the transaction module's is_credit()
// function aborts with EUnknownTxType BEFORE game_stats can check for unknown types.
// This is defensive programming - the check exists but can never be reached.
// See transaction_tests::is_credit_aborts_on_invalid_type for coverage of this path.
