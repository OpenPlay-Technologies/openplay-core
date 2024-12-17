module openplay::roulette_const;

use std::string::{String, utf8};

const MAX_RECENT_OUTCOMES: u64 = 10;

public fun state_new(): String {
    utf8(b"New")
}

public fun state_initialized(): String {
    utf8(b"Initialized")
}

public fun state_settled(): String {
    utf8(b"Settled")
}

public fun wheel_type_american(): String {
    utf8(b"American")
}

public fun wheel_type_european(): String {
    utf8(b"European")
}

public fun max_recent_outcomes(): u64 {
    MAX_RECENT_OUTCOMES
}

public fun get_number_slots(wheel_type:String) : u8 {
    if (wheel_type == wheel_type_american()) {
        38
    } else {
        37
    }
}

public fun straight_up_bet(): String {
    utf8(b"StraightUp")
}

public fun split_bet(): String {
    utf8(b"Split")
}

public fun street_bet(): String {
    utf8(b"Street")
}

public fun corner_bet(): String {
    utf8(b"Corner")
}

public fun line_bet(): String {
    utf8(b"Line")
}

public fun five_number_bet(): String {
    utf8(b"FiveNumber")
}

public fun column_bet(): String {
    utf8(b"Column")
}

public fun dozen_bet(): String {
    utf8(b"Dozen")
}

public fun half_bet(): String {
    utf8(b"Half")
}

public fun color_bet(): String {
    utf8(b"Color")
}

public fun even_odd_bet(): String {
    utf8(b"EvenOdd")
}


public fun color_red(): String {
    utf8(b"Red")
}

public fun color_black(): String {
    utf8(b"Black")
}

public fun color_green(): String {
    utf8(b"Green")
}


public fun place_bet_action(): String {
    utf8(b"PlaceBet")
}


public fun straight_up_payout_factor(): u8 {
    36
}

public fun split_payout_factor(): u8 {
    18
}

public fun street_payout_factor(): u8 {
    12
}

public fun corner_payout_factor(): u8 {
    9
}

public fun five_number_payout_factor(): u8 {
    7
}

public fun line_payout_factor(): u8 {
    6
}

public fun column_payout_factor(): u8 {
    3
}

public fun dozen_payout_factor(): u8 {
    3
}

public fun half_payout_factor(): u8 {
    2
}

public fun color_payout_factor(): u8 {
    2
}

public fun even_odd_payout_factor(): u8 {
    2
}











