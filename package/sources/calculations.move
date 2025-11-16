module openplay_core::calculations;

use openplay_core::core_constants::precision_error_allowance;
use std::uq32_32::{from_quotient, int_mul, add, sub, from_int};

// === Errors ===
const ELossTooHigh: u64 = 1;

/// Actualizes an amount to include a part of the profits or losses,
/// such that the ratio between amount and base remains the same after added the profits or losses to base.
/// This function returns new amount such that amount/base [before] = new_amount/(base + profits - losses) [after]
/// e.g. if your base is 1 SUI and you have profits of 0.1 SUI, you have a profit of 10%
/// so the provided amount will also be increased by 10%
/// e.g. if your base is 1 SUI and you have a loss of 0.1 SUI, you have a loss of 10%
/// so the provided amount will also be decreased by 10%
public(package) fun actualize_amount(amount: u64, profits: u64, losses: u64, base: u64): u64 {
    let new_amount;
    if (profits > 0) {
        let return_on_investment = from_quotient(profits, base);
        let multiplier = add(from_int(1), return_on_investment);
        new_amount = int_mul(amount, multiplier);
    } else if (losses > 0) {
        if (losses >= base) {
            // edge case: bankrupty (we allow a slight precision error)
            if ((losses - base) <= precision_error_allowance()) {
                new_amount = 0;
            } else {
                abort ELossTooHigh
            }
        } else {
            let loss_on_investment = from_quotient(losses, base);
            let multiplier = sub(from_int(1), loss_on_investment);
            new_amount = int_mul(amount, multiplier)
        }
    } else {
        new_amount = amount;
    };

    new_amount
}
