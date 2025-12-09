/// Fee collector module manages fee collection for game creators.
/// Multiple games can be assigned to the same fee collector.
/// The FeeCollector is a reference object that links to a capability for claiming fees.
/// Actual fee balances are tracked in the house state and vault.
module openplay_core::fee_collector;

use sui::event::emit;

// === Errors ===
const EInvalidCap: u64 = 1;

// === Structs ===
/// Shared object representing a fee collector instance.
/// Multiple games can be assigned to the same fee collector.
/// This is a reference object - actual fees are tracked in house state and vault.
public struct FeeCollector has key {
    id: UID,
    house_id: ID,
    cap_id: ID, // Links to the FeeCollectorCap
}

/// Owned capability that proves ownership of a FeeCollector.
/// Required to claim accumulated fees.
public struct FeeCollectorCap has key, store {
    id: UID,
    fee_collector_id: ID,
}

// === Events ===
/// Event emitted when a FeeCollector is created.
public struct FeeCollectorCreatedEvent has copy, drop {
    fee_collector_id: ID,
    cap_id: ID,
    house_id: ID,
    creator: address, // Address of the admin who created the fee collector
}

// === View Functions ===
/// Returns the ID of the FeeCollector.
public fun id(self: &FeeCollector): ID {
    self.id.to_inner()
}

/// Returns the house ID associated with this FeeCollector.
public fun house_id(self: &FeeCollector): ID {
    self.house_id
}

/// Returns the fee collector ID associated with a cap.
public fun cap_fee_collector_id(cap: &FeeCollectorCap): ID {
    cap.fee_collector_id
}

// === Package Functions ===
/// Creates a new FeeCollector and its capability.
/// Called by House when admin creates a fee collector.
public(package) fun new(house_id: ID, ctx: &mut TxContext): (FeeCollector, FeeCollectorCap) {
    let fee_collector_id = object::new(ctx);
    let cap_id = object::new(ctx);

    let fee_collector = FeeCollector {
        id: fee_collector_id,
        house_id,
        cap_id: cap_id.to_inner(),
    };

    let cap = FeeCollectorCap {
        id: cap_id,
        fee_collector_id: fee_collector.id(),
    };

    // Event
    emit(FeeCollectorCreatedEvent {
        fee_collector_id: fee_collector.id(),
        cap_id: cap.id.to_inner(),
        house_id,
        creator: ctx.sender(),
    });

    (fee_collector, cap)
}

/// Validates that the cap matches this collector.
/// Aborts if the cap's fee_collector_id or cap_id doesn't match.
public(package) fun assert_valid_cap(self: &FeeCollector, cap: &FeeCollectorCap) {
    assert!(cap.fee_collector_id == self.id(), EInvalidCap);
    assert!(cap.id.to_inner() == self.cap_id, EInvalidCap);
}

/// Shares the FeeCollector object, making it accessible to everyone.
/// After sharing, the object can be accessed by its ID by any caller.
public fun share(self: FeeCollector) {
    transfer::share_object(self);
}
