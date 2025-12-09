/// The participation module maintains all the house participation state.
/// Responsible for managing share-based participation.
module openplay_core::participation;

use sui::event::emit;

// === Errors ===
const ENotEmpty: u64 = 6;
const ENotEnoughShares: u64 = 7;

// === Structs ===
/// Represents a user's participation in a House using a share-based model.
/// Tracks shares owned. When shares are sold, proceeds are immediately available.
/// House performance fees are handled at the house level (like fee collectors),
/// so cost basis tracking is not needed.
public struct Participation has key, store {
    id: UID,
    house_id: ID,
    shares: u64, // Number of shares owned
}

// === Events ===
/// Event emitted when a new Participation is created.
public struct ParticipationCreatedEvent has copy, drop {
    participation_id: ID,
    house_id: ID, // House this participation belongs to
    player: address, // Address of the player creating the participation
}

/// Event emitted when a Participation is removed (destroyed).
public struct ParticipationRemovedEvent has copy, drop {
    participation_id: ID,
    house_id: ID, // House this participation belonged to
    player: address, // Address of the player removing the participation
}

// === View Functions ===
/// Returns the number of shares owned.
public fun shares(self: &Participation): u64 {
    self.shares
}

/// Returns the house ID associated with this participation.
public fun house_id(self: &Participation): ID {
    self.house_id
}

/// Returns the participation ID.
public fun id(self: &Participation): ID {
    self.id.to_inner()
}

// === Public Functions ===
/// Destroys an empty participation (no shares).
public fun destroy_empty(self: Participation, ctx: &mut TxContext) {
    assert!(self.shares == 0, ENotEmpty);

    let Participation {
        id,
        house_id,
        shares: _,
    } = self;
    let participation_id = id.to_inner();
    let player = ctx.sender();

    // Event
    emit(ParticipationRemovedEvent {
        participation_id,
        house_id,
        player,
    });

    object::delete(id);
}

// === Package Functions ===
/// Creates a new empty participation object.
public(package) fun empty(house_id: ID, ctx: &mut TxContext): Participation {
    let participation = Participation {
        id: object::new(ctx),
        house_id,
        shares: 0,
    };
    let participation_id = participation.id();
    let player = ctx.sender();

    // Event
    emit(ParticipationCreatedEvent {
        participation_id,
        house_id,
        player,
    });

    participation
}

/// Adds shares to participation.
public(package) fun add_shares(self: &mut Participation, shares: u64) {
    self.shares = self.shares + shares;
}

/// Removes shares from participation.
public(package) fun remove_shares(self: &mut Participation, shares: u64) {
    assert!(self.shares >= shares, ENotEnoughShares);
    self.shares = self.shares - shares;
}
