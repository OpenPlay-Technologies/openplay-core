# OpenPlay Core Package Upgrades

## Overview

The OpenPlay Core package is **upgradeable** (not immutable) by design. This document explains why, how upgrades work, and how user funds are protected during the upgrade process.

## Why Upgradeable?

During the **early development phase**, the OpenPlay Core package remains upgradeable to enable:

1. **Rapid Bug Fixes**: Critical security issues or bugs can be patched quickly without requiring users to migrate their funds or houses
2. **Feature Iteration**: New features can be added and refined based on user feedback without breaking existing integrations
3. **No Migration Burden**: Existing houses, participations, and funds continue to work seamlessly after upgrades - no manual migration required
4. **Development Flexibility**: Allows the protocol to evolve and improve while maintaining backward compatibility

**Future Plans**: Once the protocol matures and stabilizes, we plan to make the package immutable to provide maximum decentralization and trustlessness.

## How Upgrades Work

### Package Versioning

Each package upgrade creates a new package version. The current version is tracked in `core_constants.move`:

```move
const CURRENT_VERSION: u64 = 1;
```

When you upgrade the package, you increment this version number. The Registry maintains a list of allowed versions that can interact with the protocol.

### Registry Version Control

The `Registry` object maintains an `allowed_versions` set that controls which package versions can perform certain operations:

- **Allowed versions**: Can process transactions and interact with the protocol normally
- **Disabled versions**: Cannot process new transactions (gameplay is paused)

### Upgrade Process

1. **Deploy New Version**: Use the upgrade capability to deploy a new package version
2. **Allow New Version**: The admin calls `registry.admin_allow_version()` to enable the new version
3. **Disable Old Version** (optional): The admin can call `registry.admin_disallow_version()` to disable the previous version

The upgrade script (`scripts/core/upgrade-core.sh`) automates this process.

## Pause Mechanism: Protecting User Funds

OpenPlay implements a **selective pause mechanism** that pauses gameplay while ensuring user funds are never locked.

### What Gets Paused

When a package version is disabled in the Registry:

- ✅ **Gameplay operations are blocked**: Transaction processing (`tx_admin_process_transactions_v2`) will abort
- ✅ **New house registrations are blocked**: Cannot register new houses with disabled versions
- ❌ **Fund operations are NOT blocked**: Users can always stake, unstake, and claim their funds

### How It Works

The pause mechanism uses version checks in specific functions:

#### Functions WITH Version Checks (Can Be Paused)

1. **`registry.check_version()`**: Called during transaction processing
   - If version is disabled, this aborts and blocks gameplay
   - Location: `house.move::tx_admin_process_transactions_v2()`

2. **`registry.register_house()`**: Called when registering new houses
   - Prevents new houses from being created with disabled versions

**Note**: In v3.1, `protocol_fee_bps()` no longer performs a version check. Use `check_version()` explicitly for gameplay operations.

#### Functions WITHOUT Version Checks (Never Paused)

1. **`house.buy_shares()`**: Users can always buy shares
2. **`house.sell_shares()`**: Users can always sell shares and withdraw funds

This design ensures that:
- **Gameplay can be paused** for security, upgrades, or emergency situations
- **User funds can NEVER be locked** - users always retain control over their assets

### Example: Pausing During Upgrade

```
1. Admin disables version 1: registry.admin_disallow_version(version: 1, ctx)
   → All gameplay using version 1 stops immediately
   → Users can still buy/sell shares (no version check)

2. Admin upgrades package to version 2

3. Admin allows version 2: registry.admin_allow_version(version: 2, ctx)
   → Gameplay resumes with new version
   → All existing houses and funds work seamlessly
```

## Upgrade Safety Features

### 1. Version Compatibility

- Existing houses, participations, and vaults continue to work after upgrades
- No data migration required - the new package version reads existing on-chain state
- Backward compatibility is maintained through careful upgrade planning

### 2. Gradual Rollout

The version control system allows for gradual rollouts:

1. Deploy new version
2. Allow both old and new versions temporarily
3. Monitor new version performance
4. Disable old version once confident

### 3. Emergency Pause

If a critical issue is discovered:

1. Admin can immediately disable the current version
2. Gameplay stops, but users can still manage funds
3. Fix can be deployed and new version enabled
4. No user funds are at risk

## Upgrade Process Guide

### Prerequisites

- Access to the `OpenPlayAdminCap` (required for version management)
- Access to the upgrade capability (stored in `OPENPLAY_CORE_UPGRADE_CAP`)
- Latest deployment state loaded (from `outputs/<env>/latest.env`)

### Step-by-Step Upgrade

1. **Prepare the Upgrade**
   ```bash
   # Ensure you're in the openplay-core root directory
   cd /path/to/openplay-core
   
   # Make your code changes
   # Update CURRENT_VERSION in package/sources/core_constants.move
   ```

2. **Run the Upgrade Script**
   ```bash
   ./scripts/core/upgrade-core.sh
   ```
   
   This script will:
   - Load the current deployment state
   - Upgrade the package using the upgrade capability
   - Save the new package ID and version to environment files
   - Track version history

3. **Allow the New Version** (Manual Step)
   
   You can use the version management script:
   ```bash
   # Load the new environment variables
   source outputs/<env>/latest.env
   
   # Allow the new version using the management script
   ./scripts/core/manage-registry-version.sh allow <NEW_VERSION_NUMBER>
   ```
   
   Or manually using sui client:
   ```bash
   sui client call \
     --package $CURRENT_OPENPLAY_CORE_PACKAGE_ID \
     --module registry \
     --function admin_allow_version \
     --args $OPENPLAY_CORE_REGISTRY_ID $OPENPLAY_CORE_ADMIN_CAP <NEW_VERSION_NUMBER> \
     --gas-budget 10000000
   ```

4. **Optional: Disable Old Version**
   
   After verifying the new version works correctly:
   ```bash
   # Using the management script
   ./scripts/core/manage-registry-version.sh disallow <OLD_VERSION_NUMBER>
   ```
   
   Or manually:
   ```bash
   sui client call \
     --package $CURRENT_OPENPLAY_CORE_PACKAGE_ID \
     --module registry \
     --function admin_disallow_version \
     --args $OPENPLAY_CORE_REGISTRY_ID $OPENPLAY_CORE_ADMIN_CAP <OLD_VERSION_NUMBER> \
     --gas-budget 10000000
   ```

### Version Management

The Registry tracks which versions are allowed. You can check the current allowed versions by inspecting the Registry object on-chain.

**Important**: Always allow the new version before disabling the old one to avoid service interruption.

## Security Considerations

### Admin Capabilities

The `OpenPlayAdminCap` grants significant power:
- Can pause gameplay by disabling versions
- Can update protocol fees
- Can manage version allowlist

**Protection**: The admin cannot:
- Steal user funds (funds are in shared objects with proper access control)
- Modify existing house or participation data directly
- Bypass the version check system

### Upgrade Authority

The upgrade capability is separate from the admin cap:
- **Upgrade Cap**: Controls package code upgrades
- **Admin Cap**: Controls protocol parameters and version management

This separation ensures that:
- Package upgrades require the upgrade capability
- Protocol configuration requires the admin capability
- Both are needed for a complete upgrade process

## Best Practices

1. **Test Upgrades on Testnet First**: Always test upgrade procedures on testnet before mainnet
2. **Increment Version Numbers**: Always increment `CURRENT_VERSION` in `core_constants.move` before upgrading
3. **Allow New Version Before Disabling Old**: Maintain service continuity during upgrades
4. **Monitor After Upgrade**: Watch for any issues after enabling the new version
5. **Document Changes**: Update CHANGELOG.md with upgrade notes and breaking changes
6. **Communicate with Users**: Inform users about planned upgrades and any expected downtime

## FAQ

### Q: Will my funds be locked during an upgrade?

**A**: No. User funds are never locked. You can always stake, unstake, and claim your funds, even if gameplay is paused.

### Q: What happens to my house during an upgrade?

**A**: Your house continues to exist and function. After the upgrade, it will use the new package version automatically. No migration is needed.

### Q: Can the admin steal my funds?

**A**: No. The admin cannot directly access user funds. Funds are stored in shared objects with proper access controls. The admin can only pause gameplay, not lock or steal funds.

### Q: How long does an upgrade take?

**A**: The upgrade itself is instant (single transaction). However, you may want to pause gameplay briefly during the upgrade process for safety.

### Q: Will I need to do anything after an upgrade?

**A**: No. Existing houses, participations, and funds work automatically with the new version. Games may need to update their integration if there are breaking changes, but end users don't need to do anything.

### Q: What if something goes wrong during an upgrade?

**A**: If issues are discovered:
1. The admin can immediately disable the problematic version
2. Users can still manage their funds (stake/unstake/claim)
3. A fix can be deployed and enabled
4. No user funds are at risk

## Related Documentation

- [Registry Module](../package/sources/registry.move) - Version control implementation
- [House Module](../package/sources/house.move) - Transaction processing with version checks
- [Upgrade Script](../scripts/core/upgrade-core.sh) - Automated upgrade process
- [Version Management Script](../scripts/core/manage-registry-version.sh) - Helper script for allowing/disallowing versions
- [Security Audit Report](../audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md) - Security considerations

## Summary

- ✅ Package is upgradeable for rapid development and bug fixes
- ✅ Version control system allows pausing gameplay when needed
- ✅ User funds are NEVER locked - stake/unstake/claim always work
- ✅ Existing houses and funds work seamlessly after upgrades
- ✅ No migration required for users or houses
- 🔒 Future plan: Make package immutable once protocol matures
