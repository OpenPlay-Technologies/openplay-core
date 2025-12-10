#[test_only]
module openplay_core::parameter_store_tests;

use openplay_core::parameter_store;
use std::unit_test::destroy;
use sui::test_scenario::begin;

#[test]
public fun test_new() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let store = parameter_store::new(scenario.ctx());
        let id = parameter_store::id(&store);
        assert!(id != object::id_from_address(@0x0), 0);
        destroy(store);
        scenario.end();
    }
}

#[test]
public fun test_add_and_borrow() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let mut store = parameter_store::new(scenario.ctx());
        
        // Add a u64 value
        parameter_store::add(&mut store, b"test_key", 42u64);
        let value = parameter_store::borrow<vector<u8>, u64>(&store, b"test_key");
        assert!(*value == 42, 0);
        
        destroy(store);
        scenario.end();
    }
}

#[test]
public fun test_add_and_borrow_string() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let mut store = parameter_store::new(scenario.ctx());
        
        // Add a string value
        let test_string = std::string::utf8(b"test_value");
        parameter_store::add(&mut store, b"string_key", test_string);
        let value = parameter_store::borrow<vector<u8>, std::string::String>(&store, b"string_key");
        assert!(*value == std::string::utf8(b"test_value"), 0);
        
        destroy(store);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = sui::dynamic_field::EFieldAlreadyExists)]
public fun test_add_duplicate_key_fails() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let mut store = parameter_store::new(scenario.ctx());
        
        parameter_store::add(&mut store, b"key", 1u64);
        parameter_store::add(&mut store, b"key", 2u64); // Should fail
        
        destroy(store);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = sui::dynamic_field::EFieldDoesNotExist)]
public fun test_borrow_nonexistent_key_fails() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let store = parameter_store::new(scenario.ctx());
        let _value = parameter_store::borrow<vector<u8>, u64>(&store, b"nonexistent");
        destroy(store);
        scenario.end();
    }
}

#[test, expected_failure(abort_code = sui::dynamic_field::EFieldTypeMismatch)]
public fun test_borrow_wrong_type_fails() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let mut store = parameter_store::new(scenario.ctx());
        
        parameter_store::add(&mut store, b"key", 42u64);
        let _value = parameter_store::borrow<vector<u8>, std::string::String>(&store, b"key"); // Wrong type
        
        destroy(store);
        scenario.end();
    }
}

#[test]
public fun test_freeze() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let mut store = parameter_store::new(scenario.ctx());
        
        // Add a value before freezing
        parameter_store::add(&mut store, b"key1", 1u64);
        
        // Freeze the store
        parameter_store::freeze_(store);
        
        // After freezing, we can still borrow but cannot add
        // (This is tested by the fact that freeze_ doesn't abort)
        scenario.end();
    }
}

// Note: Testing adding after freeze is not possible in Move because freeze_ consumes the object
// and frozen objects cannot be mutably borrowed. The freeze functionality is tested
// by the fact that freeze_ succeeds without aborting.
// This test is removed as it cannot be properly implemented.

#[test]
public fun test_id() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        let store = parameter_store::new(scenario.ctx());
        let id = parameter_store::id(&store);
        assert!(id != object::id_from_address(@0x0), 0);
        destroy(store);
        scenario.end();
    }
}

