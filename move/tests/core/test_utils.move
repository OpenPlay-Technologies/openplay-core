
module openplay::test_utils;

use openplay::constants::precision_error_allowance;

public fun assert_eq_within_precision_allowance(a: u64, b:u64){
    if (a >= b) {
        assert!(a - b <= precision_error_allowance())
    };
    assert!(b - a <= precision_error_allowance())
}