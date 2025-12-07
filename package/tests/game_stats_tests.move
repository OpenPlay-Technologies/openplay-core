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
