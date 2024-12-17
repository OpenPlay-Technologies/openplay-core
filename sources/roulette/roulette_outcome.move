module openplay::roulette_outcome;
use std::string::String;
use openplay::roulette_const::get_number_slots;


// === Errors ===
const EInvalidResult: u64 = 1;


// === Structs ===
public struct RouletteOutcome has store, drop, copy {
    number: u8,
}

// === Public-View Functions ===
public fun get_number(self: &RouletteOutcome) : u8 {
    self.number
}

// === Public-Mutative Functions ===



// === Public-Package Functions ===
public(package) fun empty() : RouletteOutcome {
    RouletteOutcome {
        number: 0,
    }
}

public fun new(number: u8) : RouletteOutcome {
    RouletteOutcome {
        number,
    }
}

public(package) fun assert_valid_result(self: &RouletteOutcome, wheel_type: String) {
    let maxNumber = get_number_slots(wheel_type) - 1; // subtract one because slots start at 0

    assert!((self.number) >= 0 && (self.number) <= maxNumber, EInvalidResult);
}


// === Private Functions ===


