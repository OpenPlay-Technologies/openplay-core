/// Registry holds all created games.
module openplay_core::registry;

use openplay_core::core_constants::current_version;
use openplay_core::game_stats::{Self, GameStatistics};
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

// === Errors ===
const EPackageVersionDisabled: u64 = 1;
const EVersionAlreadyAllowed: u64 = 2;
const EVersionAlreadyDisabled: u64 = 3;
const EStatsAlreadyCreated: u64 = 4;
const EStatsNotAvailable: u64 = 5;

// === Structs ===
/// Central registry that tracks all Houses, manages protocol fees, and version control.
/// Maintains a mapping of game IDs to their GameStatistics objects.
public struct Registry has key {
    id: UID,
    allowed_versions: VecSet<u64>,
    houses: vector<ID>,
    protocol_fee_bps: u64,
    game_stats_id: Table<ID, ID>,
}

/// One-time witness type for the Registry module.
public struct REGISTRY has drop {}

/// Capability object that grants OpenPlay protocol administrator privileges.
/// Allows configuration of protocol fees and version management.
public struct OpenPlayAdminCap has key, store {
    id: UID,
}

// === Public-Package Functions ===
/// Registers a new House in the Registry.
/// Validates that the current package version is allowed.
public(package) fun register_house(self: &mut Registry, house_id: ID) {
    self.assert_version();
    self.houses.push_back(house_id);
}

// === Public-View ===
/// Returns the protocol fee in basis points.
public fun protocol_fee_bps(self: &Registry): u64 {
    self.assert_version();
    self.protocol_fee_bps
}

/// Returns the GameStatistics ID for a given game ID.
/// Aborts if the game is not registered.
public fun game_stats_id(self: &Registry, game_id: ID): ID {
    assert!(self.game_stats_id.contains(game_id), EStatsNotAvailable);
    self.game_stats_id[game_id]
}

// === Public-Mutative Functions ===
/// Initializes GameStatistics for a game and registers it in the Registry.
/// Aborts if statistics already exist for this game.
public fun init_stats(self: &mut Registry, game_id: &UID, ctx: &mut TxContext): GameStatistics {
    assert!(!self.game_stats_id.contains(game_id.to_inner()), EStatsAlreadyCreated);
    let stats = game_stats::new(game_id, ctx);
    self.game_stats_id.add(game_id.to_inner(), stats.id());
    stats
}

// === Admin Functions ===
/// Updates the protocol fee in basis points.
/// Can only be called by the OpenPlay admin.
public fun update_protocol_fee_bps(
    self: &mut Registry,
    _cap: &OpenPlayAdminCap,
    protocol_fee_bps: u64,
) {
    self.protocol_fee_bps = protocol_fee_bps
}

/// Allows a specific package version to interact with the Registry.
/// Aborts if the version is already allowed.
public fun admin_allow_version(self: &mut Registry, _cap: &OpenPlayAdminCap, version: u64) {
    assert!(!self.allowed_versions.contains(&version), EVersionAlreadyAllowed);
    self.allowed_versions.insert(version);
}

/// Disallows a specific package version from interacting with the Registry.
/// Aborts if the version is not currently allowed.
public fun admin_disallow_version(self: &mut Registry, _cap: &OpenPlayAdminCap, version: u64) {
    assert!(self.allowed_versions.contains(&version), EVersionAlreadyDisabled);
    self.allowed_versions.remove(&version);
}

// === Private Functions ===
/// Initializes the Registry as a shared object and creates the OpenPlayAdminCap.
/// Called automatically when the package is published.
fun init(_: REGISTRY, ctx: &mut TxContext) {
    let mut allowed_versions = vec_set::empty();
    allowed_versions.insert(current_version());

    let registry = Registry {
        id: object::new(ctx),
        allowed_versions,
        houses: vector::empty(),
        protocol_fee_bps: 10, // 0.1%
        game_stats_id: table::new(ctx),
    };
    transfer::share_object(registry);
    let admin = OpenPlayAdminCap { id: object::new(ctx) };
    transfer::public_transfer(admin, ctx.sender());
}

/// Asserts that the current package version is allowed to interact with the Registry.
/// Aborts if the version is disabled.
fun assert_version(self: &Registry) {
    let package_version = current_version();
    assert!(self.allowed_versions.contains(&package_version), EPackageVersionDisabled);
}

// === Test Functions ===
#[test_only]
public fun registry_for_testing(ctx: &mut TxContext): Registry {
    let mut allowed_versions = vec_set::empty();
    allowed_versions.insert(current_version());

    Registry {
        id: object::new(ctx),
        allowed_versions,
        houses: vector::empty(),
        protocol_fee_bps: 50,
        game_stats_id: table::new(ctx),
    }
}

#[test_only]
public fun cap_for_testing(ctx: &mut TxContext): OpenPlayAdminCap {
    OpenPlayAdminCap {
        id: object::new(ctx),
    }
}
