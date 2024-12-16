module openplay::roulette_prediction;
use std::string::String;
use openplay::roulette_const::{straight_up_bet, split_bet,
    street_bet, corner_bet, column_bet, dozen_bet, five_number_bet, half_bet,
    even_odd_bet, color_bet, line_bet, wheel_type_american, color_red, color_black, get_number_slots
};

// === Errors ===
const EInvalidPrediction: u64 = 1;

// === Constants ===
const STREET_1 : vector<u8> = vector[1,2,3];
const STREET_2 : vector<u8> = vector[4,5,6];
const STREET_3 : vector<u8> = vector[7,8,9];
const STREET_4 : vector<u8> = vector[10,11,12];
const STREET_5 : vector<u8> = vector[13,14,15];
const STREET_6 : vector<u8> = vector[16,17,18];
const STREET_7 : vector<u8> = vector[19,20,21];
const STREET_8 : vector<u8> = vector[22,23,24];
const STREET_9 : vector<u8> = vector[25,26,27];
const STREET_10 : vector<u8> = vector[28,29,30];
const STREET_11 : vector<u8> = vector[31,32,33];
const STREET_12 : vector<u8> = vector[34,35,36];


const CORNER_1 : vector<u8> = vector[1,2,4,5];
const CORNER_2 : vector<u8> = vector[2,3,5,6];
const CORNER_3 : vector<u8> = vector[4,5,7,8];
const CORNER_4 : vector<u8> = vector[5,6,8,9];
const CORNER_5 : vector<u8> = vector[7,8,10,11];
const CORNER_6 : vector<u8> = vector[8,9,11,12];
const CORNER_7 : vector<u8> = vector[10,11,13,14];
const CORNER_8 : vector<u8> = vector[11,12,14,15];
const CORNER_9 : vector<u8> = vector[13,14,16,17];
const CORNER_10 : vector<u8> = vector[14,15,17,18];
const CORNER_11 : vector<u8> = vector[16,17,19,20];
const CORNER_12 : vector<u8> = vector[17,18,20,21];
const CORNER_13 : vector<u8> = vector[19,20,22,23];
const CORNER_14 : vector<u8> = vector[20,21,23,24];
const CORNER_15 : vector<u8> = vector[22,23,25,26];
const CORNER_16 : vector<u8> = vector[23,24,26,27];
const CORNER_17 : vector<u8> = vector[25,26,28,29];
const CORNER_18 : vector<u8> = vector[26,27,29,30];
const CORNER_19 : vector<u8> = vector[28,29,31,32];
const CORNER_20 : vector<u8> = vector[29,30,32,33];
const CORNER_21 : vector<u8> = vector[31,32,34,35];
const CORNER_22 : vector<u8> = vector[32,33,35,36];

const FIVE_NUMBER : vector<u8> = vector[0,1,2,3,37];

const LINE_1 : vector<u8> = vector[1,2,3,4,5,6];
const LINE_2 : vector<u8> = vector[4,5,6,7,8,9];
const LINE_3 : vector<u8> = vector[7,8,9,10,11,12];
const LINE_4 : vector<u8> = vector[10,11,12,13,14,15];
const LINE_5 : vector<u8> = vector[13,14,15,16,17,18];
const LINE_6 : vector<u8> = vector[16,17,18,19,20,21];
const LINE_7 : vector<u8> = vector[19,20,21,22,23,24];
const LINE_8 : vector<u8> = vector[22,23,24,25,26,27];
const LINE_9 : vector<u8> = vector[25,26,27,28,29,30];
const LINE_10 : vector<u8> = vector[28,29,30,31,32,33];
const LINE_11 : vector<u8> = vector[31,32,33,34,35,36];

const COLUMN_1 : vector<u8> = vector[1,4,7,10,13,16,19,22,25,28,31,34];
const COLUMN_2 : vector<u8> = vector[2,5,8,11,14,17,20,23,26,29,32,35];
const COLUMN_3 : vector<u8> = vector[3,6,9,12,15,18,21,24,27,30,33,36];

const DOZEN_1 : vector<u8> = vector[1,2,3,4,5,6,7,8,9,10,11,12];
const DOZEN_2 : vector<u8> = vector[13,14,15,16,17,18,19,20,21,22,23,24];
const DOZEN_3 : vector<u8> = vector[25,26,27,28,29,30,31,32,33,34,35,36];

const HALF_1 : vector<u8> = vector[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18];
const HALF_2 : vector<u8> = vector[19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36];

const COLOR_RED : vector<u8> = vector[1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
const COLOR_BLACK : vector<u8> = vector[2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35];

const EVEN : vector<u8> = vector[2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36];
const ODD : vector<u8> = vector[1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35];



public enum RoulettePrediction has copy, drop, store {
    SINGLE_NUMBER {number: u8, stake : u64 }, // 1 possibility
    SPLIT { numbers : vector<u8>, stake : u64 },
    STREET { index: u8, stake : u64 }, // 12 possibilities
    CORNER { index: u8, stake : u64 }, // 22 possibilities
    FIVE_NUMBER { stake : u64}, // 1 possibility
    LINE { index : u8, stake : u64 }, // 11 possibilities
    DOZEN { index : u8, stake : u64 }, // 3 possibilities
    COLUMN { index : u8, stake : u64 }, // 3 possibilities
    HALF { index : u8, stake : u64 }, // 2 possibilities`
    COLOR { color: String, stake : u64 }, // 2 possibilities
    EVEN_ODD { is_even: bool, stake : u64 }, // 2 possibilities
}





// === Public-View Functions ===
#[allow(unused_variable)]
public(package) fun get_prediction_numbers(self: &RoulettePrediction) : vector<u8> {
    match (self) {
            RoulettePrediction::SINGLE_NUMBER { number, stake } => {
            let mut numbers : vector<u8> = vector::empty();
            vector::push_back(&mut numbers, *number);
            numbers
        },
            RoulettePrediction::SPLIT { numbers, stake } => *numbers,
            RoulettePrediction::STREET { index, stake } => {
            get_street(*index)
        },
            RoulettePrediction::CORNER { index, stake } => {
            get_corner(*index)
        },
            RoulettePrediction::FIVE_NUMBER { stake } => {
            FIVE_NUMBER
        },
            RoulettePrediction::LINE { index, stake } => {
            get_line(*index)
        },
            RoulettePrediction::DOZEN { index, stake } => {
            get_dozen(*index)
        },
            RoulettePrediction::COLUMN { index, stake } => {
            get_column(*index)
        },
            RoulettePrediction::HALF { index, stake } => {
            get_half(*index)
        },
            RoulettePrediction::COLOR { color, stake } => {
            if (*color == color_red()) {
                COLOR_RED
            }
            else {
                COLOR_BLACK
            }
        },
            RoulettePrediction::EVEN_ODD { is_even, stake } => {
            if (*is_even) {
                EVEN
            }
            else {
                ODD
            }
        },
    }
}

#[allow(unused_variable)]
public fun get_bet_type(self: &RoulettePrediction) : String {
    match (self) {
        RoulettePrediction::SINGLE_NUMBER { number, stake } => straight_up_bet(),
        RoulettePrediction::SPLIT { numbers, stake } => split_bet(),
        RoulettePrediction::STREET { index, stake } => street_bet(),
        RoulettePrediction::CORNER { index, stake } => corner_bet(),
        RoulettePrediction::FIVE_NUMBER { stake } => five_number_bet(),
        RoulettePrediction::LINE { index, stake } => line_bet(),
        RoulettePrediction::DOZEN { index, stake } => dozen_bet(),
        RoulettePrediction::COLUMN { index, stake } => column_bet(),
        RoulettePrediction::HALF { index, stake } => half_bet(),
        RoulettePrediction::COLOR { color, stake } => color_bet(),
        RoulettePrediction::EVEN_ODD { is_even, stake } => even_odd_bet(),
    }
}


/// === Public-Package Functions ===

public(package) fun create_predictions(stakes : vector<u64>, bet_types : vector<String>, prediction_values : vector<vector<u8>>, wheel_type : String) : vector<RoulettePrediction> {
    let mut i = 0;
    let len = bet_types.length();
    let mut result : vector<RoulettePrediction> = vector::empty();
    loop {
        if (i == len) {
            break
        };
        let bet_type = bet_types[i];
        let values = prediction_values[i];

        let prediction = create_prediction(stakes[i], bet_type, values, wheel_type);

        vector::push_back(&mut result, prediction);
        i = i + 1;
    };
    result
}

public(package) fun create_prediction(stake : u64, bet_type : String, prediction_value : vector<u8>, wheel_type : String) : RoulettePrediction {
    assert!(is_valid_prediction_value(bet_type, prediction_value, wheel_type), EInvalidPrediction);
    if (bet_type == straight_up_bet()) {
        RoulettePrediction::SINGLE_NUMBER { number: prediction_value[0], stake }
    }
    else if (bet_type == split_bet()) {
        RoulettePrediction::SPLIT { numbers: prediction_value, stake }
    }
    else if (bet_type == street_bet()) {
        RoulettePrediction::STREET { index: prediction_value[0], stake }
    }
    else if (bet_type == corner_bet()) {
        RoulettePrediction::CORNER { index: prediction_value[0], stake }
    }
    else if (bet_type == five_number_bet()) {
        RoulettePrediction::FIVE_NUMBER { stake }
    }
    else if (bet_type == line_bet()) {
        RoulettePrediction::LINE { index: prediction_value[0], stake }
    }
    else if (bet_type == dozen_bet()) {
        RoulettePrediction::DOZEN { index: prediction_value[0], stake }
    }
    else if (bet_type == column_bet()) {
        RoulettePrediction::COLUMN { index: prediction_value[0], stake }
    }
    else if (bet_type == half_bet()) {
        RoulettePrediction::HALF { index: prediction_value[0], stake }
    }
    else if (bet_type == color_bet()) {
        RoulettePrediction::COLOR { color: get_color(prediction_value[0]), stake }
    }
    else if (bet_type == even_odd_bet()) {
        RoulettePrediction::EVEN_ODD { is_even: prediction_value[0] == 0, stake }
    }
    else {
        abort(EInvalidPrediction)
    };
    abort(EInvalidPrediction)
}

public(package) fun get_color(num : u8) : String {
    if (num == 0) {
        color_red()
    }
    else {
        color_black()
    }
}

fun is_valid_prediction_value(bet_type: String, values : vector<u8>, wheel_type : String) : bool {
    if (bet_type == straight_up_bet()) {
        let max = get_number_slots(wheel_type) - 1;
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= max)
    }
    else if (bet_type == split_bet()) {
        let max = get_number_slots(wheel_type) - 1;
        (values.length() == 2) && (values[0] >= 0) && (values[0] <= max) && (values[1] >= 0) && (values[1] <= max)
    }
    else if (bet_type == street_bet()) {
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= 11)
    }
    else if (bet_type == corner_bet()) {
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= 21)
    }
    else if (bet_type == five_number_bet()) {
        wheel_type == wheel_type_american()
    }
    else if (bet_type == line_bet()) {
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= 10)
    }
    else if (bet_type == dozen_bet()) {
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= 2)
    }
    else if (bet_type == column_bet()) {
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= 2)
    }
    else if (bet_type == half_bet()) {
        (values.length() == 1) && (values[0] >= 0) && (values[0] <= 1)
    }
    else if (bet_type == color_bet()) {
        (values.length() == 1) && (values[0] == 0 || values[0] == 1) // 0 is red, 1 is black
    }
    else if (bet_type == even_odd_bet()) {
        (values.length() == 1) && (values[0] == 0 || values[0] == 1)
    }
    else {
        false
    }
}

public(package) fun is_valid_predictions(predictions : vector<RoulettePrediction>, wheel_type : String) {
    let len = predictions.length();
    let mut i = 0;
    loop {
        if (i == len) {
            break
        };
        let prediction = &predictions[i];
        assert!(
            prediction.is_valid_prediction_bet(wheel_type),
            EInvalidPrediction,
        );
        i = i + 1;
    };
}




/// === Private Functions ===
#[allow(unused_variable)]
public(package) fun is_valid_prediction_bet(self: &RoulettePrediction, wheel_type: String) : bool { // i prob need to add extra validation that the numbers themselves are valid combinations...
    match (self) {
        RoulettePrediction::SINGLE_NUMBER { number, stake } => {
            let maxNumber = get_number_slots(wheel_type) - 1; // subtract one because slots start at 0
            (*number >= 0) && (*number <= maxNumber)
        },
        RoulettePrediction::SPLIT { numbers, stake } => {
            let maxNumber = get_number_slots(wheel_type) - 1; // subtract one because slots start at 0
            let mut i = 0;
            let len = numbers.length();
            loop {
                if (i == len) {
                    break
                };
                let number = numbers[i];
                if (!(number >= 0) || !(number <= maxNumber)) {
                    return false
                };
                i = i + 1;
            };
            true
        },
        RoulettePrediction::STREET { index, stake } => {
            (*index >= 0) && (*index <= 11)
        },
        RoulettePrediction::CORNER { index, stake } => {
            (*index >= 0) && (*index <= 21)
        },
        RoulettePrediction::FIVE_NUMBER { stake } => {
            wheel_type == wheel_type_american()
        },
        RoulettePrediction::LINE { index, stake } => {
            (*index >= 0) && (*index <= 10)
        },
        RoulettePrediction::DOZEN { index, stake } => {
            (*index >= 0) && (*index <= 2)
        },

        RoulettePrediction::COLUMN { index, stake } => {
            (*index >= 0) && (*index <= 2)
        },
        RoulettePrediction::HALF { index, stake } => {
            (*index >= 0) && (*index <= 1)
        },
        RoulettePrediction::COLOR { color, stake } => {
            *color == color_red() || *color == color_black()
        },
        RoulettePrediction::EVEN_ODD { is_even, stake } => {
            true
        },
        _ => false
    }
}




fun get_street(index : u8) : vector<u8> {
    if (index == 0) {
        STREET_1
    }
    else if (index == 1) {
        STREET_2
    }
    else if (index == 2) {
        STREET_3
    }
    else if (index == 3) {
        STREET_4
    }
    else if (index == 4) {
        STREET_5
    }
    else if (index == 5) {
        STREET_6
    }
    else if (index == 6) {
        STREET_7
    }
    else if (index == 7) {
        STREET_8
    }
    else if (index == 8) {
        STREET_9
    }
    else if (index == 9) {
        STREET_10
    }
    else if (index == 10) {
        STREET_11
    }
    else if (index == 11) {
        STREET_12
    }
    else {
        vector::empty()
    }
}

fun get_corner(index: u8) : vector<u8> {
    if (index == 0) {
        CORNER_1
    }
    else if (index == 1) {
        CORNER_2
    }
    else if (index == 2) {
        CORNER_3
    }
    else if (index == 3) {
        CORNER_4
    }
    else if (index == 4) {
        CORNER_5
    }
    else if (index == 5) {
        CORNER_6
    }
    else if (index == 6) {
        CORNER_7
    }
    else if (index == 7) {
        CORNER_8
    }
    else if (index == 8) {
        CORNER_9
    }
    else if (index == 9) {
        CORNER_10
    }
    else if (index == 10) {
        CORNER_11
    }
    else if (index == 11) {
        CORNER_12
    }
    else if (index == 12) {
        CORNER_13
    }
    else if (index == 13) {
        CORNER_14
    }
    else if (index == 14) {
        CORNER_15
    }
    else if (index == 15) {
        CORNER_16
    }
    else if (index == 16) {
        CORNER_17
    }
    else if (index == 17) {
        CORNER_18
    }
    else if (index == 18) {
        CORNER_19
    }
    else if (index == 19) {
        CORNER_20
    }
    else if (index == 20) {
        CORNER_21
    }
    else if (index == 21) {
        CORNER_22
    }
    else {
        vector::empty()
    }
}

fun get_line(index : u8) : vector<u8> {
    if (index == 0) {
        LINE_1
    }
    else if (index == 1) {
        LINE_2
    }
    else if (index == 2) {
        LINE_3
    }
    else if (index == 3) {
        LINE_4
    }
    else if (index == 4) {
        LINE_5
    }
    else if (index == 5) {
        LINE_6
    }
    else if (index == 6) {
        LINE_7
    }
    else if (index == 7) {
        LINE_8
    }
    else if (index == 8) {
        LINE_9
    }
    else if (index == 9) {
        LINE_10
    }
    else if (index == 10) {
        LINE_11
    }
    else {
        vector::empty()
    }
}


fun get_column(index : u8) : vector<u8> {
    if (index == 0) {
        COLUMN_1
    }
    else if (index == 1) {
        COLUMN_2
    }
    else if (index == 2) {
        COLUMN_3
    }
    else {
        vector::empty()
    }
}

fun get_dozen(index : u8) : vector<u8> {
    if (index == 0) {
        DOZEN_1
    }
    else if (index == 1) {
        DOZEN_2
    }
    else if (index == 2) {
        DOZEN_3
    }
    else {
        vector::empty()
    }
}

fun get_half(index : u8) : vector<u8> {
    if (index == 0) {
        HALF_1
    }
    else if (index == 1) {
        HALF_2
    }
    else {
        vector::empty()
    }
}