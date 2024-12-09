module openplay::account_tests;

use sui::test_scenario::begin;
use sui::test_utils::destroy;
use openplay::account::{Self};

#[test]
public fun settle_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create account
    let mut account = account::empty(scenario.ctx());

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
    scenario.end();
}

#[test]
public fun stake_unstake_ok() {
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create account
    let mut account = account::empty(scenario.ctx());

    // Stake 10
    account.add_stake(10);
    // Active stake should be 0 because it is still pending
    assert!(account.active_stake() == 0);
    // Unstake right away
    account.unstake();
    let (credit, debit) = account.settle();
    assert!(credit == 10);
    assert!(debit == 10);

    // Stake 10
    account.add_stake(10);
    // Advance epoch
    scenario.next_epoch(addr);
    account.process_end_of_day(0, 0, 0, scenario.ctx());
    // Active stake should be updated now
    assert!(account.active_stake() == 10);
    // Stake 5 more
    account.add_stake(5);
    assert!(account.active_stake() == 10);
    // Unstake: 5 should be instant and 10 pending
    account.unstake();
    let (credit, debit) = account.settle();
    assert!(credit == 5);
    assert!(debit == 15);
    assert!(account.active_stake() == 10);
    // Advance epoch, should free up the stake
    scenario.next_epoch(addr);
    account.process_end_of_day(1, 0, 0, scenario.ctx());
    let (credit, debit) = account.settle();
    assert!(credit == 10);
    assert!(debit == 0);
    assert!(account.active_stake() == 0);

    destroy(account);
    scenario.end();
}

#[test, expected_failure(abort_code = account::ECancellationWasRequested)]
public fun cannot_unstake_twice(){
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create account
    let mut account = account::empty(scenario.ctx());
    // Stake and advance epoch
    account.add_stake(10);
    scenario.next_epoch(addr);
    account.process_end_of_day(0, 0, 0, scenario.ctx());
    // Unstake twice
    account.unstake();
    account.unstake();
    abort 0
}

#[test, expected_failure(abort_code = account::ECancellationWasRequested)]
public fun cannot_stake_after_unstake(){
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create account
    let mut account = account::empty(scenario.ctx());
    // Stake and advance epoch
    account.add_stake(10);
    scenario.next_epoch(addr);
    account.process_end_of_day(0, 0, 0, scenario.ctx());
    // Unstake twice
    account.unstake();
    account.add_stake(10);
    abort 0
}

#[test]
public fun process_ggr_share_ok(){
    let addr = @0xa;
    let mut scenario = begin(addr);

    // Create account
    let mut account = account::empty(scenario.ctx());

    assert!(account.active_stake() == 0);
    // Profits should be added to the active stake
    scenario.next_epoch(addr);
    account.process_end_of_day(0, 10, 0, scenario.ctx());
    assert!(account.active_stake() == 10);
    // Losses should be deducted from the active stake
    scenario.next_epoch(addr);
    account.process_end_of_day(1, 0, 5, scenario.ctx());
    assert!(account.active_stake() == 5);
    // Can deduct more from active stake than available (because of precision errors)
    scenario.next_epoch(addr);
    account.process_end_of_day(2, 0, 6, scenario.ctx());
    assert!(account.active_stake() == 0);

    destroy(account);
    scenario.end();
}