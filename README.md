# OpenPlay Core

[![Sui](https://img.shields.io/badge/Built%20on-Sui-6fbcf0)](https://sui.io)
[![Move](https://img.shields.io/badge/Language-Move-00d4ff)](https://move-language.github.io/move/)

**Decentralized casino infrastructure protocol on Sui blockchain**

OpenPlay Core is a permissionless smart contract protocol that enables anyone to create, operate, and participate in transparent, on-chain gambling houses. Players enjoy provably fair games, shareholders earn returns by providing liquidity, and operators can launch their own casinos - all built on Sui with full transparency and security.

## 🎯 What is OpenPlay?

OpenPlay is **infrastructure for decentralized gambling**. Think of it like Uniswap for casinos - the protocol provides the smart contracts, and the community builds the games and operates the houses.

### Key Features

- **🏠 House-Based Model**: Each casino operates as an independent House with its own games, fees, and shareholders
- **📈 Share-Based Participation**: Buy and sell shares valued at NAV (Net Asset Value) - no lock-up periods
- **💰 GGR-Based Fees**: All fees calculated from Gross Gaming Revenue (bets - wins) at epoch end
- **🔒 Secure Fund Management**: Players control their funds through Balance Managers; shareholders own shares through Participations
- **🎮 Game Whitelisting**: House operators curate which games to offer, with fee collectors for each game
- **📊 Transparent Accounting**: All transactions, fees, and NAV calculations are on-chain and verifiable

## 🚀 Quick Start

### For Developers

```bash
# Install Sui CLI (if not already installed)
# See: https://docs.sui.io/build/install

# Build the package
cd package
sui move build

# Run tests
sui move test
```

### For Users

- **Players**: Create a Balance Manager, deposit funds, and start playing on any OpenPlay house
- **Shareholders**: Create a Participation, buy shares, and watch your share value grow with the house
- **Operators**: Deploy a House, whitelist games with fee collectors, and start accepting players

See our [Participation Guide](./docs/participation-guide.md) for detailed information on becoming a shareholder.

## 📚 Documentation

### Core Documentation

- **[Vision & Overview](./docs/vision.md)** - What OpenPlay is and how it works
- **[Participation Guide](./docs/participation-guide.md)** - How to become a house shareholder
- **[Balance System](./docs/balances.md)** - Understanding all balance types in the protocol
- **[Balance Manager](./docs/balance-manager.md)** - How player funds are managed securely
- **[Upgrades & Security](./docs/upgrades.md)** - Protocol upgrade process and fund protection
- **[Game Whitelisting](./docs/game-whitelisting.md)** - Security requirements for whitelisting games

### Technical Documentation

- **[Security Audit](./audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md)** - Comprehensive security analysis
- **[Rounding Strategy](./docs/rounding-strategy.md)** - How rounding affects calculations

### Changelog

- **[CHANGELOG.md](./CHANGELOG.md)** - Version history and changes

## 🏗️ Project Structure

```
openplay-core/
├── package/                 # Sui Move package
│   ├── sources/            # Core smart contracts
│   │   ├── house.move      # House contract (main)
│   │   ├── vault.move      # Fund storage and management
│   │   ├── registry.move   # Protocol registry
│   │   ├── participation.move  # Share ownership
│   │   ├── fee_collector.move  # Game fee collection
│   │   ├── balance_manager.move # Player fund management
│   │   └── state/          # State management
│   └── tests/              # Test suite
├── docs/                   # Documentation
├── scripts/                # Deployment and utility scripts
│   ├── core/               # Core package scripts
│   └── utils/              # Utility scripts
└── audit/                  # Security audit reports
```

## 🔧 Core Components

### Registry
Central protocol registry that tracks all houses, manages protocol fees, and handles version control for safe upgrades.

### House
Shared objects that process bet/win transactions, manage whitelisted games with fee collectors, handle GGR-based fee distribution, and manage share purchases/sales.

### Fee Collector
Shared objects that group games for fee collection. Multiple games can share the same fee collector, and fees are calculated from GGR at epoch end.

### Vault
Stores all house funds in a single house balance, plus collected fees (protocol, house, and collector fees).

### Participation
Objects that represent a user's share ownership in a house. Share value is determined by NAV (Net Asset Value).

### Balance Manager
Shared objects that hold player funds for gameplay, with delegatable PlayCaps for secure access control.

## 🎮 How It Works

1. **Operators** create Houses and whitelist game instances with fee collectors
2. **Shareholders** provide liquidity by buying shares (valued at NAV)
3. **Players** deposit funds into Balance Managers and play games
4. **Games** process transactions through whitelisted House contracts
5. **Epochs** end daily, calculating GGR and distributing fees
6. **NAV** adjusts based on house performance (GGR minus fees)

See the [Vision Document](./docs/vision.md) for detailed workflows.

## 🔐 Security

- **Upgradeable Protocol**: Currently upgradeable for rapid development; will become immutable once mature
- **Pause Mechanism**: Can pause gameplay for security without locking user funds
- **Version Control**: Registry tracks allowed package versions for safe upgrades
- **Capability-Based Access**: Fine-grained access control through Sui capabilities
- **Audited**: Comprehensive security audit completed (see [audit report](./audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md))

**Important**: User funds are **never locked**. Players can always withdraw from Balance Managers, and shareholders can sell shares immediately with no lock-up period.

## 📊 Fee Structure

All fees are calculated from **GGR (Gross Gaming Revenue)** at epoch end:

| Fee Type | Range | Description |
|----------|-------|-------------|
| Protocol Fee | 0-20% | Goes to OpenPlay treasury |
| House Fee | Configurable | Goes to house operator |
| Collector Fee | Configurable | Goes to game creators |

**Note**: House + Collector fees cannot exceed 50%, ensuring shareholders receive at least 30% of positive GGR.

See [Participation Guide](./docs/participation-guide.md) for detailed fee breakdown and examples.

## 🛠️ Development

### Prerequisites

- [Sui CLI](https://docs.sui.io/build/install) (latest version)
- Rust (for Sui CLI)
- Basic knowledge of Sui Move

### Building

```bash
cd package
sui move build
```

### Testing

```bash
cd package
sui move test
```

### Deployment Scripts

Scripts are available in the `scripts/` directory:

- `scripts/core/deploy-core.sh` - Deploy the core package
- `scripts/core/upgrade-core.sh` - Upgrade the package
- `scripts/core/manage-registry-version.sh` - Manage version allowlist
- `scripts/utils/create-house.sh` - Create a new house

## 🤝 Contributing

OpenPlay Core is in active development. Contributions are welcome! Please:

1. Review the existing codebase and documentation
2. Check the [CHANGELOG](./CHANGELOG.md) for recent changes
3. Follow Sui Move best practices
4. Ensure all tests pass
5. Update documentation as needed

## 🔗 Links

- **Documentation**: See `docs/` directory
- **Security Audit**: [SECURITY_AUDIT_REPORT_OPUS_4.5.md](./audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md)
- **Sui Documentation**: https://docs.sui.io
- **Move Language**: https://move-language.github.io/move/

## ⚠️ Disclaimer

OpenPlay Core is software for building decentralized gambling infrastructure. Users should:

- Understand the risks of gambling and investing in house shares
- Only invest what they can afford to lose
- Review all smart contracts before interacting
- Be aware that the protocol is currently upgradeable (see [upgrades.md](./docs/upgrades.md))

The protocol is provided "as is" without warranties of any kind.

## 📞 Support

For questions, issues, or contributions, please refer to the project repository.

---

**Built with ❤️ on Sui**
