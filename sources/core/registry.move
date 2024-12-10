/// Registry holds all created games.
module openplay::registry;

// === Structs ===
public struct Registry has key {
    id: UID,
    games: vector<ID>,
}

public struct REGISTRY has drop {}

/// OpenPlayAdminCap is used to call admin functions.
public struct OpenPlayAdminCap has key, store {
    id: UID,
}

// === Public-Package Functions ===
public(package) fun register_game(self: &mut Registry, game_id: ID) {
    self.games.push_back(game_id);
}
// === Private Functions ===
fun init(_: REGISTRY, ctx: &mut TxContext) {
    let registry = Registry {
        id: object::new(ctx),
        games: vector::empty(),
    };
    transfer::share_object(registry);
    let admin = OpenPlayAdminCap { id: object::new(ctx) };
    transfer::public_transfer(admin, ctx.sender());
}

// === Test Functions ===
#[test_only]
public fun registry_for_testing(ctx: &mut TxContext): Registry {
    Registry {
        id: object::new(ctx),
        games: vector::empty()
    }
}