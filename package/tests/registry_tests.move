#[test_only]
module openplay_core::registry_tests;

use openplay_core::core_constants::{current_version, max_bps, max_protocol_fee_bps};
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
    registry::update_protocol_fee_bps(&mut registry, &cap, valid_fee, scenario.ctx());
    
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
    registry::update_protocol_fee_bps(&mut registry, &cap, invalid_fee, scenario.ctx());
    
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
    registry::update_protocol_fee_bps(&mut registry, &cap, invalid_fee, scenario.ctx());
    
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
    
    // Test with maximum valid fee (2000 basis points = 20%)
    // Protocol fee is capped at max_protocol_fee_bps() = 2000, not max_bps() - 1
    let max_valid_fee = max_protocol_fee_bps(); // 2000 = 20%
    registry::update_protocol_fee_bps(&mut registry, &cap, max_valid_fee, scenario.ctx());
    
    assert!(registry::protocol_fee_bps(&registry) == max_valid_fee, 0);
    
    destroy(registry);
    destroy(cap);
    scenario.end();
}

#[test]
public fun test_check_version_success() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let registry = registry::registry_for_testing(scenario.ctx());
        
        // Current version should be allowed by default
        registry.check_version(); // Should not abort
        
        destroy(registry);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = registry::EPackageVersionDisabled)]
public fun test_check_version_disabled() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let cap = registry::cap_for_testing(scenario.ctx());
        
        // Disable current version
        registry.admin_disallow_version(&cap, current_version(), scenario.ctx());
        
        // Check version should now fail
        registry.check_version();
        
        destroy(registry);
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_init_stats() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let game_id = object::new(scenario.ctx());
        
        // Initialize stats
        let stats = registry.init_stats(&game_id, scenario.ctx());
        
        // Verify stats are registered
        let stats_id = registry.game_stats_id(game_id.to_inner());
        assert!(stats_id == stats.id(), 0);
        
        // Share stats (key object, can't be destroyed)
        stats.share();
        
        destroy(registry);
        destroy(game_id);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = registry::EStatsAlreadyCreated)]
public fun test_init_stats_already_exists() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let game_id = object::new(scenario.ctx());
        
        // Initialize stats first time
        let stats1 = registry.init_stats(&game_id, scenario.ctx());
        stats1.share(); // Share it so it can be cleaned up
        
        // Try to initialize again - should fail
        let stats2 = registry.init_stats(&game_id, scenario.ctx());
        stats2.share(); // Share it so it can be cleaned up
        
        destroy(registry);
        destroy(game_id);
        scenario.end();
    }
}

#[test]
public fun test_game_stats_id() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let game_id = object::new(scenario.ctx());
        
        // Initialize stats
        let stats = registry.init_stats(&game_id, scenario.ctx());
        let expected_stats_id = stats.id();
        
        // Get stats ID from registry
        let stats_id = registry.game_stats_id(game_id.to_inner());
        assert!(stats_id == expected_stats_id, 0);
        
        // Share stats (key object, can't be destroyed)
        stats.share();
        
        destroy(registry);
        destroy(game_id);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = registry::EStatsNotAvailable)]
public fun test_game_stats_id_not_found() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let registry = registry::registry_for_testing(scenario.ctx());
        let game_id = object::id_from_address(@0xB);
        
        // Try to get stats for unregistered game - should fail
        let _stats_id = registry.game_stats_id(game_id);
        
        destroy(registry);
        scenario.end();
    }
}

#[test]
public fun test_admin_allow_version() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let cap = registry::cap_for_testing(scenario.ctx());
        
        // Allow a new version
        let new_version = 2;
        registry.admin_allow_version(&cap, new_version, scenario.ctx());
        
        // Version should now be allowed (we can't directly check, but it shouldn't abort)
        destroy(registry);
        destroy(cap);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = registry::EVersionAlreadyAllowed)]
public fun test_admin_allow_version_already_allowed() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let cap = registry::cap_for_testing(scenario.ctx());
        
        // Current version is already allowed by default
        // Try to allow it again - should fail
        registry.admin_allow_version(&cap, current_version(), scenario.ctx());
        
        destroy(registry);
        destroy(cap);
        scenario.end();
    }
}

#[test]
public fun test_admin_disallow_version() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let cap = registry::cap_for_testing(scenario.ctx());
        
        // First allow a version
        let version = 2;
        registry.admin_allow_version(&cap, version, scenario.ctx());
        
        // Then disallow it
        registry.admin_disallow_version(&cap, version, scenario.ctx());
        
        destroy(registry);
        destroy(cap);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = registry::EVersionAlreadyDisabled)]
public fun test_admin_disallow_version_not_allowed() {
    let addr = @0xa;
    let mut scenario = begin(addr);
    {
        let mut registry = registry::registry_for_testing(scenario.ctx());
        let cap = registry::cap_for_testing(scenario.ctx());
        
        // Try to disallow a version that was never allowed - should fail
        registry.admin_disallow_version(&cap, 999, scenario.ctx());
        
        destroy(registry);
        destroy(cap);
        scenario.end();
    }
}
