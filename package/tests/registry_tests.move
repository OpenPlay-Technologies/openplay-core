#[test_only]
module openplay_core::registry_tests;

use openplay_core::core_constants::max_bps;
use openplay_core::registry;
use std::unit_test::destroy;
use sui::test_scenario::begin;

#[test]
public fun test_update_protocol_fee_bps_valid() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    
    let mut registry = registry::registry_for_testing(scenario.ctx());
    let cap = registry::cap_for_testing(scenario.ctx());
    
    // Test with a valid fee (less than 100%)
    let valid_fee = 100; // 1%
    registry::update_protocol_fee_bps(&mut registry, &cap, valid_fee);
    
    assert!(registry::protocol_fee_bps(&registry) == valid_fee, 0);
    
    destroy(registry);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = openplay_core::registry::EInvalidFeeConfiguration)]
public fun test_update_protocol_fee_bps_invalid_100_percent() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    
    let mut registry = registry::registry_for_testing(scenario.ctx());
    let cap = registry::cap_for_testing(scenario.ctx());
    
    // Test with 100% (10000 basis points) - should fail
    let invalid_fee = max_bps(); // 10000 = 100%
    registry::update_protocol_fee_bps(&mut registry, &cap, invalid_fee);
    
    // This line should never be reached due to expected_failure
    destroy(registry);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = openplay_core::registry::EInvalidFeeConfiguration)]
public fun test_update_protocol_fee_bps_invalid_over_100_percent() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    
    let mut registry = registry::registry_for_testing(scenario.ctx());
    let cap = registry::cap_for_testing(scenario.ctx());
    
    // Test with > 100% (more than 10000 basis points) - should fail
    let invalid_fee = max_bps() + 1; // 10001 = 100.01%
    registry::update_protocol_fee_bps(&mut registry, &cap, invalid_fee);
    
    // This line should never be reached due to expected_failure
    destroy(registry);
    destroy(cap);
    scenario.end();
}

#[test]
public fun test_update_protocol_fee_bps_max_valid() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    
    let mut registry = registry::registry_for_testing(scenario.ctx());
    let cap = registry::cap_for_testing(scenario.ctx());
    
    // Test with maximum valid fee (9999 basis points = 99.99%)
    let max_valid_fee = max_bps() - 1; // 9999 = 99.99%
    registry::update_protocol_fee_bps(&mut registry, &cap, max_valid_fee);
    
    assert!(registry::protocol_fee_bps(&registry) == max_valid_fee, 0);
    
    destroy(registry);
    destroy(cap);
    scenario.end();
}
