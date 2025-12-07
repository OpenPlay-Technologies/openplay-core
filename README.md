# OpenPlay Core

[![Sui](https://img.shields.io/badge/Built%20on-Sui-6fbcf0)](https://sui.io)
[![Move](https://img.shields.io/badge/Language-Move-00d4ff)](https://move-language.github.io/move/)

**Decentralized casino infrastructure protocol on Sui blockchain**

OpenPlay Core is a permissionless smart contract protocol that enables anyone to create, operate, and participate in transparent, on-chain gambling houses. Players enjoy provably fair games, stakers earn returns by providing liquidity, and operators can launch their own casinos - all built on Sui with full transparency and security.

## 🎯 What is OpenPlay?

OpenPlay is **infrastructure for decentralized gambling**. Think of it like Uniswap for casinos - the protocol provides the smart contracts, and the community builds the games and operates the houses.

### Key Features

- **🏠 House-Based Model**: Each casino operates as an independent House with its own games, fees, and stakers
- **⏱️ Epoch-Based Operations**: 24-hour epochs ensure fair profit/loss distribution to all stakers
- **💰 Multi-Tier Fee System**: Protocol, game, and house fees align incentives across all participants
- **🔒 Secure Fund Management**: Players control their funds through Balance Managers; stakers participate through Participation NFTs
- **🎮 Game Whitelisting**: House operators curate which games to offer, ensuring quality and security
- **📊 Transparent Accounting**: All transactions, fees, and distributions are on-chain and verifiable

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
- **Stakers**: Create a Participation, stake SUI, and earn proportional returns each epoch
- **Operators**: Deploy a House, whitelist games, and start accepting players

See our [Vision Document](./docs/vision.md) for detailed information on how to participate.

## 📚 Documentation

### Core Documentation

- **[Vision & Overview](./docs/vision.md)** - What OpenPlay is and how it works
- **[Balance System](./docs/balances.md)** - Understanding all balance types in the protocol
- **[Balance Manager](./docs/balance-manager.md)** - How player funds are managed securely
- **[Upgrades & Security](./docs/upgrades.md)** - Protocol upgrade process and fund protection
- **[Game Whitelisting](./docs/game-whitelisting.md)** - Security requirements for whitelisting games

### Technical Documentation

- **[Security Audit](./audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md)** - Comprehensive security analysis
- **[Rounding Strategy](./docs/rounding-strategy.md)** - How rounding affects calculations
- **[Mathematical Proofs](./docs/mathematical_proof_complete.md)** - Formal proofs of protocol correctness

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
│   │   ├── participation.move  # Staking participation
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
Shared objects that process bet/win transactions, manage whitelisted games, handle fee distribution, and manage staking.

### Vault
Stores all house assets, separating funds into reserve balance (staked funds) and play balance (active gameplay).

### Participation
NFT-like objects that represent a user's stake in a house, tracking profit/loss over epochs.

### Balance Manager
Shared objects that hold player funds for gameplay, with delegatable PlayCaps for secure access control.

## 🎮 How It Works

1. **Operators** create Houses and whitelist game instances
2. **Stakers** provide liquidity by staking SUI tokens
3. **Players** deposit funds into Balance Managers and play games
4. **Games** process transactions through whitelisted House contracts
5. **Epochs** end daily, calculating profits/losses and distributing to stakers

See the [Vision Document](./docs/vision.md) for detailed workflows.

## 🔐 Security

- **Upgradeable Protocol**: Currently upgradeable for rapid development; will become immutable once mature
- **Pause Mechanism**: Can pause gameplay for security without locking user funds
- **Version Control**: Registry tracks allowed package versions for safe upgrades
- **Capability-Based Access**: Fine-grained access control through Sui capabilities
- **Audited**: Comprehensive security audit completed (see [audit report](./audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md))

**Important**: User funds are **never locked**. Players can always withdraw from Balance Managers, and stakers can unstake (processed at end of epoch).

## 📊 Fee Structure

- **Protocol Fee**: 0-2% of bet volume (currently 0%, configurable)
- **Game Fee**: Configurable per game instance
- **House Performance Fee**: Percentage of profits each epoch (default 20%)

See [Vision Document](./docs/vision.md) for detailed fee breakdown.

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

- Understand the risks of gambling and staking
- Only stake what they can afford to lose
- Review all smart contracts before interacting
- Be aware that the protocol is currently upgradeable (see [upgrades.md](./docs/upgrades.md))

The protocol is provided "as is" without warranties of any kind.

## 📞 Support

For questions, issues, or contributions, please refer to the project repository.

---

**Built with ❤️ on Sui**
