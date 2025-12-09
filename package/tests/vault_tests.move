#[test_only]
module openplay_core::vault_tests;

use openplay_core::balance_manager;
use openplay_core::vault;
use std::unit_test::destroy;
use sui::coin::mint_for_testing;
use sui::sui::SUI;
use sui::test_scenario::{begin, next_epoch};

#[test]
public fun deposit_withdraw_ok() {
    let addr = @0xA;
    let mut scenario = begin(addr);

    // Create empty vault
    let house_id = object::id_from_address(@0x0);
    let mut vault = vault::empty(house_id);
    assert!(vault.house_balance() == 0);

    // Deposit 100
    let deposit_balance = mint_for_testing<SUI>(100, scenario.ctx()).into_balance();
    vault.deposit(deposit_balance);
    assert!(vault.house_balance() == 100);

    // Withdraw 20
    let withdraw1 = vault.withdraw(20);
    assert!(vault.house_balance() == 80);

    // Deposit 20
    let deposit_balance = mint_for_testing<SUI>(20, scenario.ctx()).into_balance();
    vault.deposit(deposit_balance);
    assert!(vault.house_balance() == 100);

    // Deposit 20
    let deposit_balance = mint_for_testing<SUI>(20, scenario.ctx()).into_balance();
    vault.deposit(deposit_balance);
    assert!(vault.house_balance() == 120);

    // Withdraw all
    let withdraw2 = vault.withdraw(120);
    assert!(vault.house_balance() == 0);

    destroy(vault);
    destroy(withdraw1);
    destroy(withdraw2);
    scenario.end();
}

#[test]
public fun settle_balance_manager_gameplay_ok() { 
    let addr = @0xA; 
    let mut scenario = begin(addr); 
    {
        // Initialize balance manager with 100 MIST
        let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
        let proof = balance_manager.generate_proof_as_owner(&balance_manager_cap, scenario.ctx());
        let deposit_balance = mint_for_testing<SUI>(100, scenario.ctx()).into_balance();
        balance_manager.deposit_with_proof(&proof, deposit_balance);

        // Create empty vault
        let house_id = object::id_from_address(@0x0);
        let mut vault = vault::empty(house_id);
        assert!(vault.house_balance() == 0);

        // Settle balance for 20 MIST from balance manager to vault
        vault.settle_balance_manager(0, 80, &mut balance_manager, &proof);
        assert!(vault.house_balance() == 0 + 80);
        assert!(balance_manager.balance() == 100 - 80);

        // Settle balance for 10 MIST from vault to balance manager
        vault.settle_balance_manager(20, 0, &mut balance_manager, &proof);
        assert!(vault.house_balance() == 0 + 80 - 20);
        assert!(balance_manager.balance() == 100 - 80 + 20);

        // Now a mix
        vault.settle_balance_manager(30, 40, &mut balance_manager, &proof);
        assert!(vault.house_balance() == 0 + 80 - 20 - 30 + 40);
        assert!(balance_manager.balance() == 100 - 80 + 20 + 30 - 40);

        destroy(vault);
        destroy(balance_manager);
        destroy(balance_manager_cap);
    }; 
    scenario.end(); 
}

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun settle_balance_manager_insufficient_funds_bm() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        // Initialize balance manager with 100 MIST
        let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
        let proof = balance_manager.generate_proof_as_owner(&balance_manager_cap, scenario.ctx());
        let deposit_balance = mint_for_testing<SUI>(100, scenario.ctx()).into_balance();
        balance_manager.deposit_with_proof(&proof, deposit_balance);

        // Create empty vault
        let house_id = object::id_from_address(@0x0);
        let mut vault = vault::empty(house_id);
        assert!(vault.house_balance() == 0);

        // Try to move 101 MIST from bm to vault
        vault.settle_balance_manager(0, 101, &mut balance_manager, &proof);
        abort 0
    }
}

#[test, expected_failure(abort_code = vault::EInsufficientFunds)]
public fun settle_balance_manager_insufficient_funds_vault() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        // Initialize balance manager with 100 MIST
        let (mut balance_manager, balance_manager_cap) = balance_manager::new(scenario.ctx());
        let proof = balance_manager.generate_proof_as_owner(&balance_manager_cap, scenario.ctx());

        // Create empty vault
        let house_id = object::id_from_address(@0x0);
        let mut vault = vault::empty(house_id);
        assert!(vault.house_balance() == 0);

        // Try to move 5 MIST from vault to bm
        vault.settle_balance_manager(5, 0, &mut balance_manager, &proof);
        abort 0
    }
}

#[test]
public fun process_fees_ok() {
    let addr = @0xA;
    let fee_collector_id = object::id_from_address(@0xB);

    let mut scenario = begin(addr);
    {
        // Create and fund vault with 100 MIST
        let house_id = object::id_from_address(@0x0);
        let mut vault = vault::empty(house_id);
        vault.fund_house_balance_for_testing(100, scenario.ctx());

        // Process fees (collector fees and protocol fees)
        vault.process_collector_fee(fee_collector_id, 5);
        vault.process_protocol_fee(7);

        assert!(vault.house_balance() == 88);
        assert!(vault.collected_collector_fees(fee_collector_id) == 5);
        assert!(vault.collected_protocol_fees() == 7);

        destroy(vault);
    };
    scenario.end();
}

#[test, expected_failure(abort_code = vault::EInsufficientFunds)]
public fun process_protocol_fees_fail() {
    let addr = @0xA;
    let mut scenario = begin(addr);
    {
        // Create and fund vault with 100 MIST
        let house_id = object::id_from_address(@0x0);
        let mut vault = vault::empty(house_id);
        vault.fund_house_balance_for_testing(100, scenario.ctx());

        // Process fees
        vault.process_protocol_fee(101);
        destroy(vault);
        abort 0
    }
}

#[test, expected_failure(abort_code = vault::EInsufficientFunds)]
public fun process_collector_fees_fail() {
    let addr = @0xA;
    let fee_collector_id = object::id_from_address(@0xB);

    let mut scenario = begin(addr);
    {
        // Create and fund vault with 100 MIST
        let house_id = object::id_from_address(@0x0);
        let mut vault = vault::empty(house_id);
        vault.fund_house_balance_for_testing(100, scenario.ctx());

        // Process fees
        vault.process_collector_fee(fee_collector_id, 101);
        destroy(vault);
        abort 0
    }
}
