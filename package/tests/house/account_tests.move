#[test_only]
module openplay_core::account_tests;

use openplay_core::account;
use std::unit_test::destroy;

#[test]
public fun settle_ok() {
    // Create account
    let mut account = account::empty();

    // Debit 10, Credit 20
    account.debit(10);
    account.credit(20);

    let (credit, debit) = account.settle();
    assert!(credit == 20);
    assert!(debit == 10);

    // Now do it twice
    account.debit(10);
    account.credit(20);
    account.debit(10);
    account.credit(20);
    let (credit, debit) = account.settle();
    assert!(credit == 40);
    assert!(debit == 20);

    destroy(account);
}

#[test]
public fun empty_creates_zero_account() {
    // Test that empty() creates an account with all zeros
    let account = account::empty();
    assert!(account::lifetime_total_bets(&account) == 0, 0);
    assert!(account::lifetime_total_wins(&account) == 0, 1);
    assert!(account::debit_balance(&account) == 0, 2);
    assert!(account::credit_balance(&account) == 0, 3);
    destroy(account);
}

#[test]
public fun credit_adds_to_balance() {
    let mut account = account::empty();
    
    account::credit(&mut account, 100);
    assert!(account::credit_balance(&account) == 100, 0);
    
    account::credit(&mut account, 50);
    assert!(account::credit_balance(&account) == 150, 1);
    
    destroy(account);
}

#[test]
public fun debit_adds_to_balance() {
    let mut account = account::empty();
    
    account::debit(&mut account, 200);
    assert!(account::debit_balance(&account) == 200, 0);
    
    account::debit(&mut account, 100);
    assert!(account::debit_balance(&account) == 300, 1);
    
    destroy(account);
}

#[test]
public fun settle_resets_balances() {
    let mut account = account::empty();
    
    account::debit(&mut account, 100);
    account::credit(&mut account, 50);
    
    let (credit, debit) = account::settle(&mut account);
    assert!(credit == 50, 0);
    assert!(debit == 100, 1);
    
    // Balances should be reset
    assert!(account::credit_balance(&account) == 0, 2);
    assert!(account::debit_balance(&account) == 0, 3);
    
    destroy(account);
}

#[test]
public fun settle_multiple_times() {
    let mut account = account::empty();
    
    // First settlement
    account::debit(&mut account, 10);
    account::credit(&mut account, 20);
    let (credit1, debit1) = account::settle(&mut account);
    assert!(credit1 == 20, 0);
    assert!(debit1 == 10, 1);
    
    // Second settlement
    account::debit(&mut account, 30);
    account::credit(&mut account, 40);
    let (credit2, debit2) = account::settle(&mut account);
    assert!(credit2 == 40, 2);
    assert!(debit2 == 30, 3);
    
    destroy(account);
}

#[test]
public fun credit_zero_amount() {
    let mut account = account::empty();
    
    account::credit(&mut account, 0);
    assert!(account::credit_balance(&account) == 0, 0);
    
    destroy(account);
}

#[test]
public fun debit_zero_amount() {
    let mut account = account::empty();
    
    account::debit(&mut account, 0);
    assert!(account::debit_balance(&account) == 0, 0);
    
    destroy(account);
}

#[test]
public fun settle_with_zero_balances() {
    let mut account = account::empty();
    
    let (credit, debit) = account::settle(&mut account);
    assert!(credit == 0, 0);
    assert!(debit == 0, 1);
    
    destroy(account);
}

#[test]
public fun credit_large_amount() {
    let mut account = account::empty();
    
    account::credit(&mut account, std::u64::max_value!());
    assert!(account::credit_balance(&account) == std::u64::max_value!(), 0);
    
    destroy(account);
}

#[test]
public fun debit_large_amount() {
    let mut account = account::empty();
    
    account::debit(&mut account, std::u64::max_value!());
    assert!(account::debit_balance(&account) == std::u64::max_value!(), 0);
    
    destroy(account);
}
