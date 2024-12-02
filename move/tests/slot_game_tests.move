module openplay::slot_game_tests;
use sui::test_scenario;
use openplay::slot_game::{new, destroy};
use std::string;

#[test]
fun slot_finish_game_success() {
    let addr = @0xA;
    let scenario = test_scenario::begin(addr);
    {
        // Create new game
        let slot_game = new(
            string::utf8(b"Slotty Cubes"), 
            vector<vector<u8>>[
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
            ], 
            vector<u64>[100000000], // 0.1 SUI or 100M Mist 
            10);
        // Get a result for rand equal to 3
        let result = slot_game.finish_game(3);
        // Assert correct outcome
        // Can calculate this using all the game_utils functions, or just use the debug prints to find it for this specific rand
        assert!(result.win_multiplier() == 3);
        assert!(result.symbols() == vector<u8>[1, 2, 0, 2, 2]);
        slot_game.destroy();
    };
    scenario.end();
}