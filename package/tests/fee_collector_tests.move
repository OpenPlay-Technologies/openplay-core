#[test_only]
module openplay_core::fee_collector_tests;

use openplay_core::fee_collector;
use std::unit_test::destroy;
use sui::test_scenario::begin;

#[test]
public fun test_new() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0xB);
        let (collector, cap) = fee_collector::new(house_id, scenario.ctx());
        
        assert!(fee_collector::id(&collector) != object::id_from_address(@0x0), 0);
        assert!(fee_collector::house_id(&collector) == house_id, 0);
        assert!(fee_collector::cap_fee_collector_id(&cap) == fee_collector::id(&collector), 0);
        
        destroy(collector);
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_id() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0xB);
        let (collector, cap) = fee_collector::new(house_id, scenario.ctx());
        
        let collector_id = fee_collector::id(&collector);
        assert!(collector_id != object::id_from_address(@0x0), 0);
        
        destroy(collector);
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_house_id() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0xB);
        let (collector, cap) = fee_collector::new(house_id, scenario.ctx());
        
        assert!(fee_collector::house_id(&collector) == house_id, 0);
        
        destroy(collector);
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_cap_fee_collector_id() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0xB);
        let (collector, cap) = fee_collector::new(house_id, scenario.ctx());
        
        let collector_id = fee_collector::id(&collector);
        let cap_collector_id = fee_collector::cap_fee_collector_id(&cap);
        assert!(cap_collector_id == collector_id, 0);
        
        destroy(collector);
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_share() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0xB);
        let (collector, cap) = fee_collector::new(house_id, scenario.ctx());
        
        // Share the collector
        fee_collector::share(collector);
        
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_assert_valid_cap_success() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id = object::id_from_address(@0xB);
        let (collector, cap) = fee_collector::new(house_id, scenario.ctx());
        
        // This should not abort
        fee_collector::assert_valid_cap(&collector, &cap);
        
        destroy(collector);
        destroy(cap);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = fee_collector::EInvalidCap)]
public fun test_assert_valid_cap_wrong_collector() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let house_id1 = object::id_from_address(@0xB);
        let house_id2 = object::id_from_address(@0xC);
        let (collector1, cap1) = fee_collector::new(house_id1, scenario.ctx());
        let (collector2, cap2) = fee_collector::new(house_id2, scenario.ctx());
        
        // Try to validate cap2 with collector1 - should fail
        fee_collector::assert_valid_cap(&collector1, &cap2);
        
        // Clean up (though we won't reach here due to expected_failure)
        destroy(collector1);
        destroy(cap1);
        destroy(collector2);
        destroy(cap2);
        scenario.end();
    }
}

