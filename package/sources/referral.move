/// Module for managing referral programs that earn fees from game transactions.
module openplay_core::referral;

use sui::transfer::share_object;

// === Structs ===
/// Shared object representing a referral program for a House.
/// Referrals earn fees when their referral ID is used in transactions.
public struct Referral has key {
    id: UID,
    house_id: ID,
    cap_id: ID,
}

/// Capability object that grants ownership of a Referral.
/// Allows claiming accumulated referral fees.
public struct ReferralCap has key, store {
    id: UID,
    referral_id: ID,
}

// === Public-View Functions ===
/// Returns the ID of the Referral.
public fun id(self: &Referral): ID {
    self.id.to_inner()
}

/// Returns the Referral ID from a ReferralCap.
public fun referral_id(cap: &ReferralCap): ID {
    cap.referral_id
}

// === Public-Package Functions ===
/// Creates a new Referral and its associated ReferralCap for a House.
public(package) fun new(house_id: ID, ctx: &mut TxContext): (Referral, ReferralCap) {
    let referral_cap_id = object::new(ctx);

    let referral = Referral {
        id: object::new(ctx),
        house_id,
        cap_id: referral_cap_id.to_inner(),
    };

    let referral_cap = ReferralCap {
        id: referral_cap_id,
        referral_id: referral.id(),
    };

    (referral, referral_cap)
}

/// Shares the Referral object, making it publicly accessible.
public fun share(referral: Referral) {
    share_object(referral);
}
