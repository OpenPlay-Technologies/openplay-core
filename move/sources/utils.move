module openplay::utils;

// === Imports ===
use std::string;
use std::debug;
use std::hash;

// === Public-Package Functions ===
public(package) fun to_string(num: &u64): string::String {
    // Handle the special case when the number is zero
    if (num == 0) {
        return string::utf8(b"0")
    };

    let mut digits_rev = vector::empty<u8>();
    let mut n = *num;

    // Extract digits and store them in reverse order
    while (n > 0) {
        let digit = (n % 10) as u8;
        let char_code = digit + 48; // ASCII code for '0' is 48
        vector::push_back(&mut digits_rev, char_code);
        n = n / 10;
    };

    // Reverse the digits to get the correct order
    let len = vector::length(&digits_rev);
    let mut digits = vector::empty<u8>();
    let mut i = len;
    while (i > 0) {
        i = i - 1;
        let ch = *vector::borrow(&digits_rev, i);
        vector::push_back(&mut digits, ch);
    };

    // Convert the vector of bytes into a string
    let str = string::utf8(digits);

    str
}

public(package) fun bytes_to_u64(bytes: &vector<u8>): u64 {
    // Process the first 8 bytes and ignore the rest
    let mut value: u64 = 0;
    let len = vector::length(bytes);
    let limit = if (len < 8) { len } else { 8 };
    let mut i = 0;
    while (i < limit) {
        value = (value << 8) | (*vector::borrow(bytes, i) as u64);
        i = i + 1;
    };
    debug::print(&value);
    value
}

public(package) fun compute_stopping_value(reel: &vector<u8>, rand_seed: u64, rand_offset: u64): u8 {
    // Get the stringified version of both numbers
    let mut rand_str = rand_seed.to_string();
    let rand_offset_str = rand_offset.to_string();
    // Append them together
    string::append(&mut rand_str, rand_offset_str);
    debug::print(&rand_str);
    // Convert the combined string to bytes
    let combined_bytes = string::into_bytes(rand_str);
    // Compute the hash of the combined bytes
    let hash = hash::sha2_256(combined_bytes);
    debug::print(&hash);
    // Convert the first 8 bytes of the hash to u64
    let hash_int = bytes_to_u64(&hash);
    debug::print(&hash_int);
    let stop_index = hash_int % vector::length(reel);
    debug::print(&stop_index);
    let reel_val = *reel.borrow(stop_index);
    debug::print(&reel_val);
    reel_val
}