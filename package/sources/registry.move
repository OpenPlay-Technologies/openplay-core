/// Registry holds all created games.
module openplay_core::registry;

use openplay_core::core_constants::{current_version, max_bps, max_protocol_fee_bps};
use openplay_core::game_stats::{Self, GameStatistics};
use sui::event::emit;
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

// === Errors ===
const EPackageVersionDisabled: u64 = 1;
const EVersionAlreadyAllowed: u64 = 2;
const EVersionAlreadyDisabled: u64 = 3;
const EStatsAlreadyCreated: u64 = 4;
const EStatsNotAvailable: u64 = 5;
const EInvalidFeeConfiguration: u64 = 6;

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

// === Events ===
/// Event emitted when protocol fee is updated.
public struct ProtocolFeeUpdatedEvent has copy, drop {
    old_fee_bps: u64,
    new_fee_bps: u64,
    admin: address, // Address of the admin who updated the fee
}

/// Event emitted when a package version is allowed.
public struct VersionAllowedEvent has copy, drop {
    version: u64,
    admin: address, // Address of the admin who allowed the version
}

/// Event emitted when a package version is disallowed.
public struct VersionDisallowedEvent has copy, drop {
    version: u64,
    admin: address, // Address of the admin who disallowed the version
}

/// Event emitted when GameStatistics are initialized for a game.
public struct GameStatsInitializedEvent has copy, drop {
    game_id: ID,
    stats_id: ID,
    initializer: address, // Address of the account that initialized the stats
}

/// Event emitted when a House is registered in the Registry.
public struct HouseRegisteredEvent has copy, drop {
    house_id: ID,
    registrar: address, // Address of the account that registered the house
}

// === Package Functions ===
/// Registers a new House in the Registry.
/// Validates that the current package version is allowed.
///
/// # Version Check
/// This function performs a version check to prevent new houses from being registered
/// when the package version is disabled. Note that this only affects NEW house registrations;
/// existing houses continue to operate, and fund operations (stake/unstake/claim) are
/// never blocked by version checks.
public(package) fun register_house(self: &mut Registry, house_id: ID, ctx: &TxContext) {
    self.assert_version();
    self.houses.push_back(house_id);

    // Event
    emit(HouseRegisteredEvent {
        house_id,
        registrar: ctx.sender(),
    });
}

// === View Functions ===
/// Checks if the current package version is allowed to perform gameplay operations.
/// Aborts if the version is disabled, effectively pausing gameplay.
///
/// # Version Check
/// **IMPORTANT**: This function performs a registry version check that can BLOCK GAMEPLAY.
/// If the current package version is not allowed in the registry, this function will abort,
/// which will prevent transaction processing from proceeding. This is intentional - version
/// checks are used to pause gameplay when needed, but note that staking/unstaking operations
/// do NOT call this function, ensuring user funds can never be paused.
///
/// # Usage
/// This function should be called at the start of transaction processing functions to ensure
/// gameplay is not paused. If a version is disabled, gameplay will be blocked, but users
/// can still stake, unstake, and claim their funds.
public fun check_version(self: &Registry) {
    self.assert_version();
}

/// Returns the protocol fee in basis points.
/// This function does NOT perform a version check - use `check_version()` separately if needed.
public fun protocol_fee_bps(self: &Registry): u64 {
    self.protocol_fee_bps
}

/// Returns the GameStatistics ID for a given game ID.
/// Aborts if the game is not registered.
public fun game_stats_id(self: &Registry, game_id: ID): ID {
    assert!(self.game_stats_id.contains(game_id), EStatsNotAvailable);
    self.game_stats_id[game_id]
}

// === Public Functions ===
/// Initializes GameStatistics for a game and registers it in the Registry.
/// Aborts if statistics already exist for this game.
public fun init_stats(self: &mut Registry, game_id: &UID, ctx: &mut TxContext): GameStatistics {
    assert!(!self.game_stats_id.contains(game_id.to_inner()), EStatsAlreadyCreated);
    let stats = game_stats::new(game_id, ctx);
    let game_id_inner = game_id.to_inner();
    let stats_id = stats.id();
    self.game_stats_id.add(game_id_inner, stats_id);

    // Event
    emit(GameStatsInitializedEvent {
        game_id: game_id_inner,
        stats_id,
        initializer: ctx.sender(),
    });

    stats
}

// === Admin Functions ===
/// Updates the protocol fee in basis points.
/// Can only be called by the OpenPlay admin.
/// Aborts if the fee is >= 100% (10000 basis points).
public fun update_protocol_fee_bps(
    self: &mut Registry,
    _cap: &OpenPlayAdminCap,
    protocol_fee_bps: u64,
    ctx: &TxContext,
) {
    assert!(protocol_fee_bps < max_bps(), EInvalidFeeConfiguration);
    // Protocol fee cannot exceed maximum to ensure reasonable staker returns
    // Note: This validation is also checked at end of day in house.move
    assert!(protocol_fee_bps <= max_protocol_fee_bps(), EInvalidFeeConfiguration);
    let old_fee_bps = self.protocol_fee_bps;
    self.protocol_fee_bps = protocol_fee_bps;

    // Event
    emit(ProtocolFeeUpdatedEvent {
        old_fee_bps,
        new_fee_bps: protocol_fee_bps,
        admin: ctx.sender(),
    });
}

/// Allows a specific package version to interact with the Registry.
/// Aborts if the version is already allowed.
public fun admin_allow_version(
    self: &mut Registry,
    _cap: &OpenPlayAdminCap,
    version: u64,
    ctx: &TxContext,
) {
    assert!(!self.allowed_versions.contains(&version), EVersionAlreadyAllowed);
    self.allowed_versions.insert(version);

    // Event
    emit(VersionAllowedEvent {
        version,
        admin: ctx.sender(),
    });
}

/// Disallows a specific package version from interacting with the Registry.
/// Aborts if the version is not currently allowed.
public fun admin_disallow_version(
    self: &mut Registry,
    _cap: &OpenPlayAdminCap,
    version: u64,
    ctx: &TxContext,
) {
    assert!(self.allowed_versions.contains(&version), EVersionAlreadyDisabled);
    self.allowed_versions.remove(&version);

    // Event
    emit(VersionDisallowedEvent {
        version,
        admin: ctx.sender(),
    });
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
///
/// # Version Control Strategy
/// This function is used to control access to registry-dependent operations:
/// - **Gameplay operations** (transaction processing): Version check is performed via `protocol_fee_bps()`
///   to allow pausing gameplay when needed
/// - **Fund operations** (staking/unstaking/claiming): NO version check is performed, ensuring
///   user funds can NEVER be paused or locked, even if a version is disabled
/// - **House registration**: Version check is performed to prevent new houses from being created
///   with disabled versions
///
/// This design ensures that while gameplay can be paused for security or upgrade purposes,
/// users always retain the ability to manage their funds (stake, unstake, claim).
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
