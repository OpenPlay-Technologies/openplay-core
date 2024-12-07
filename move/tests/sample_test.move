#[test_only]
module openplay::sample_test;

use sui::test_scenario::{begin};
use sui::transfer::public_transfer;
use openplay::balance_manager;

#[test]
public fun hello_world(){

    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let balance_manager = balance_manager::new(scenario.ctx());
        public_transfer(balance_manager, addr);        
    };
    scenario.end();
}

