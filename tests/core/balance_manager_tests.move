#[test_only]
module openplay::balance_manager_tests;

use openplay::balance_manager;
use sui::coin::{mint_for_testing, burn_for_testing};
use sui::sui::SUI;
use sui::test_scenario::begin;
use sui::test_utils::destroy;

#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun deposit_withdraw_int() { let addr = @0xA; let mut scenario = begin(addr); {
        let mut balance_manager = balance_manager::new(scenario.ctx());
        assert!(balance_manager.balance() == 0);

        // Deposit 100 OK
        let deposit_balance = mint_for_testing<SUI>(100, scenario.ctx()).into_balance();
        balance_manager.deposit_int(deposit_balance);

        // Withdraw 50 OK
        let withdraw_balance = balance_manager.withdraw_int(50);
        burn_for_testing(withdraw_balance.into_coin(scenario.ctx()));

        // Withdraw 51 fails
        let fail = balance_manager.withdraw_int(51);
        burn_for_testing(fail.into_coin(scenario.ctx()));

        destroy(balance_manager);
        abort 0
    } }


#[test, expected_failure(abort_code = balance_manager::EBalanceTooLow)]
public fun deposit_withdraw() { let addr = @0xA; let mut scenario = begin(addr); {
        let mut balance_manager = balance_manager::new(scenario.ctx());
        assert!(balance_manager.balance() == 0);

        // Deposit 100 OK
        let deposit_balance = mint_for_testing<SUI>(100, scenario.ctx());
        balance_manager.deposit(deposit_balance);

        // Withdraw 50 OK
        let withdraw_balance = balance_manager.withdraw(50, scenario.ctx());
        burn_for_testing(withdraw_balance);

        // Withdraw 51 fails
        let fail = balance_manager.withdraw(51, scenario.ctx());
        burn_for_testing(fail);

        destroy(balance_manager);
        abort 0
    } }
