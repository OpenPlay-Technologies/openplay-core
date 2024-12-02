#[test_only]
module openplay::game_utils_tests;

use openplay::utils::{to_string, bytes_to_u64, compute_stopping_value};
use std::string;

#[test]
fun u64_to_string_correct() {
    assert!(to_string(&0) == string::utf8(b"0"));
    assert!(to_string(&1) == string::utf8(b"1"));
    assert!(to_string(&5) == string::utf8(b"5"));
    assert!(to_string(&10) == string::utf8(b"10"));
    assert!(to_string(&11) == string::utf8(b"11"));
    assert!(to_string(&1111) == string::utf8(b"1111"));
    assert!(to_string(&854) == string::utf8(b"854"));
    assert!(to_string(&1055) == string::utf8(b"1055"));
    assert!(to_string(&055) == string::utf8(b"55")); // Leading 0 gets removed
}

#[test]
fun bytes_to_u64_correct() {
    assert!(bytes_to_u64(&vector[0u8]) == 0); // 0000000000000000000000000000000000000000000000000000000000000000 in binary
    assert!(bytes_to_u64(&vector[1u8]) == 1); // 0000000000000000000000000000000000000000000000000000000000000001 in binary
    assert!(bytes_to_u64(&vector[11u8]) == 11); // 0000000000000000000000000000000000000000000000000000000000001011 in binary
    assert!(bytes_to_u64(&vector[1u8, 1u8]) == 257); // 0000000000000000000000000000000000000000000000000000000100000001 in binary
    assert!(bytes_to_u64(&vector[1u8, 1u8, 1u8, 1u8, 1u8, 1u8, 1u8, 1u8]) == 72340172838076673); // 0000000100000001000000010000000100000001000000010000000100000001 in binary
}

#[test]
fun compute_value_correct() {
    let input_vec = vector[1u8, 2u8, 3u8, 4u8, 5u8];
    // EXAMPLE 1
    // combined string is: 123451
    // tip: use https://emn178.github.io/online-tools/sha256.html to hash utf-8 directly
    // in utf-8 this is : 0x31 0x32 0x33 0x34 0x35 0x31
    // or: 00110001 00110010 00110011 00110100 00110101 00110001
    // sha2_256 of this is: 0xdd712114fb283417de4da3512e17486adbda004060d0d1646508c8a2740d29b4
    // of which we only take the first 8 bytes 0xdd712114fb283417
    // which is 15956571328747156503 in decimal
    // which is 3 mod 5
    // which should give 4 as a result input_vec[3]
    assert!(compute_stopping_value(&input_vec, 12345u64, 1u64) == 4);  
    // EXAMPLE 2
    // hash of 123452 is 2d75c1a2d01521e3026aa1719256a06604e7bc99aab149cb8cc7de8552fa820d
    // which gives (0x2d75c1a2d01521e3 % 5) <--- can run this directly in python
    // which is 1
    // which should give 2 as a result input_vec[1]
    assert!(compute_stopping_value(&input_vec, 12345u64, 2u64) == 2);
    // EXAMPLE 3
    // hash of 123453 77f919b0fff753c0a6169c8adfe2e7a570321d7009894d9d121ba77e2684f647
    // 0x77f919b0fff753c0 % 5 = 1
    assert!(compute_stopping_value(&input_vec, 12345u64, 3u64) == 2);
}