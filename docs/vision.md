# OpenPlay: Decentralized Casino Infrastructure

## What is OpenPlay?

OpenPlay is a **permissionless, decentralized casino infrastructure protocol** built on Sui blockchain. It enables anyone to create, operate, and participate in transparent, on-chain gambling houses where players can enjoy provably fair games and stakers can earn returns by providing liquidity.

Unlike traditional online casinos that operate as centralized entities, OpenPlay is a **protocol** - a set of smart contracts that anyone can use to build their own casino. Think of it like Uniswap for gambling: the protocol provides the infrastructure, and the community builds the games and operates the houses.

## Core Philosophy

OpenPlay is built on three fundamental principles:

1. **Permissionless**: Anyone can create a house, deploy games, or stake funds - no approval needed
2. **Transparent**: All transactions, fees, and profit/loss distributions are on-chain and verifiable
3. **Decentralized**: No single entity controls the protocol; houses compete for players and stakers

## How It Works

### The House Model

In OpenPlay, each casino operates as a **House** - a shared smart contract object that manages:
- **Staked funds** from liquidity providers
- **Game transactions** (bets and wins)
- **Profit/loss distribution** to stakers
- **Fee collection** for protocol, games, and house operators

**Key Concept**: Each house is independent. Multiple houses can exist simultaneously, each with their own:
- Game selection (whitelisted games)
- Fee structure
- Minimum stake requirements
- Risk profile and strategy

This creates a competitive market where houses differentiate themselves through game selection, fees, returns, and reputation.

### Epoch-Based Operations

Houses operate in **epochs** (approximately 24 hours, aligned with Sui epochs):

1. **During the Epoch**: 
   - Players place bets using whitelisted games
   - Wins and losses are settled in real-time
   - GGR (Gross Gaming Revenue) is tracked per fee collector
   - Users can buy/sell shares at any time based on current NAV

2. **End of Epoch**:
   - GGR is calculated (total bets - total wins)
   - Fees are calculated from GGR and deducted from house balance:
     - Protocol fee (to OpenPlay)
     - House fee (to house admin)
     - Collector fees (to game creators based on their GGR contribution)
   - NAV per share is updated to reflect new house balance

This epoch-based system ensures fair fee calculation - fees are taken from actual house profits (GGR), and share value (NAV) reflects true house performance.

## Key Participants

### Players

Players enjoy provably fair games on any OpenPlay house. They:
- Create a **Balance Manager** to hold their gameplay funds
- Connect to any house's frontend
- Play whitelisted games with instant settlement
- Never need to trust a centralized operator

**Security**: Players maintain full control of their funds through the Balance Manager system. They can deposit, play, and withdraw at any time - even if a house is paused or upgrading.

### Shareholders (Liquidity Providers)

Shareholders provide liquidity to houses by purchasing shares. They:
- Create a **Participation** for each house they want to invest in
- Buy shares with SUI tokens - shares are valued at NAV (Net Asset Value)
- Share value increases/decreases based on house performance (GGR)
- Can sell shares at any time and receive proceeds immediately

**Returns**: Shareholders earn based on:
- House performance (GGR = bets - wins)
- Their share count (proportional to total shares)
- Fees are deducted from GGR (protocol, house, and collector fees)

**Risk**: Shareholders bear losses if the house loses money. The NAV per share decreases proportionally when players win more than they bet.

### House Operators

House operators create and manage casinos. They:
- Create a House with minimum stake requirements
- Whitelist game instances they trust
- Set fee structures (game fees, house performance fees)
- Build frontends to attract players
- Earn through house performance fees and their own stake

**Control**: Operators have full control over:
- Which games to offer (whitelisting)
- Fee structures (within protocol limits)
- House branding and user experience

**Responsibility**: Operators must:
- Maintain sufficient liquidity (or attract stakers)
- Curate safe, fair games
- Build trust with players and stakers

### Game Developers

Game developers create the games that run on OpenPlay houses. They:
- Write game logic in Sui Move
- Deploy game packages to Sui
- Create game instances with specific parameters
- Submit instances to house operators for whitelisting
- Earn fees when their games are played

**Flexibility**: Games can be:
- Simple (coin flip, dice) or complex (slots, poker variants)
- Provably fair using Sui's randomness
- Customized with different parameters per instance

**Note**: Currently, game fees go to the game instance owner (whoever deployed/whitelisted it). Future versions may support more granular fee attribution between package developers and instance creators.

### Protocol (OpenPlay)

The OpenPlay protocol provides the core infrastructure:
- **Registry**: Tracks all houses, manages protocol fees, handles version control
- **House Contracts**: Process transactions, manage stakes, distribute profits
- **Vault System**: Securely stores and separates funds
- **Balance Managers**: Enable secure player fund management

**Protocol Fees**: A small fee (currently 0%, configurable up to 2%) is collected from all transactions to support protocol development and maintenance.

## Fee Structure

OpenPlay uses a GGR-based (Gross Gaming Revenue) fee system that aligns incentives across all participants:

### GGR Calculation

At the end of each epoch, GGR is calculated:
```
GGR = Total Bets - Total Wins
```

All fees are calculated as a percentage of GGR, not per-transaction.

### Fee Types (All from GGR)

When the epoch ends with positive GGR (house profit):

1. **Protocol Fee** (0-20%): Goes to OpenPlay protocol treasury
2. **Collector Fees** (configurable): Goes to fee collectors based on their games' GGR contribution
3. **House Fee** (configurable): Goes to the house operator
4. **Remaining GGR**: Reflected in increased NAV for shareholders

**Note**: House fee + Collector share cannot exceed 50% to ensure shareholders receive at least 30% of GGR.

### Example Fee Distribution

- Epoch GGR: 1000 SUI
- Protocol fee: 10% = 100 SUI → OpenPlay treasury
- House fee: 20% = 200 SUI → House operator
- Collector share: 20% = 200 SUI → Distributed to fee collectors by their GGR
- Remaining: 500 SUI → Increases house balance (NAV for shareholders)

## Security & Trust

### For Players

- **Fund Control**: Players control their funds through Balance Managers - no one can access them without your permission
- **Provably Fair**: Games use Sui's on-chain randomness - results are verifiable
- **No Lock-in**: You can withdraw funds at any time, even if a house is paused
- **Transparent**: All transactions are on-chain and auditable

### For Shareholders

- **Proportional Ownership**: Share value (NAV) reflects proportional ownership of house balance
- **Transparent Accounting**: All share counts, balances, and GGR calculations are on-chain
- **Instant Liquidity**: You can sell shares at any time and receive proceeds immediately
- **House Control**: You choose which houses to invest in based on their game selection, fees, and track record

### For Operators

- **Full Control**: You control which games to whitelist and your fee structure
- **No Fund Access**: You cannot directly access user funds - they're in shared objects with proper access controls
- **Version Control**: The protocol can pause gameplay if needed, but user funds are never locked

### Protocol-Level Protections

- **Upgradeable During Development**: The protocol is upgradeable to fix bugs and add features quickly
- **Pause Mechanism**: Can pause gameplay for security without locking user funds
- **Version Control**: Registry tracks allowed package versions for safe upgrades
- **Capability-Based Security**: All operations require proper capabilities - no single point of failure

See [Upgrade Documentation](./upgrades.md) for details on how upgrades work and how user funds are protected.

## Use Cases

### For Players

- **Provably Fair Gaming**: Play games where results are verifiable on-chain
- **No KYC**: Participate without identity verification
- **Instant Settlement**: Wins and losses are settled immediately
- **Multiple Houses**: Choose from different houses with different game selections

### For Shareholders

- **Passive Income**: Earn returns by providing liquidity to houses
- **Diversification**: Buy shares in multiple houses to spread risk
- **Transparent Returns**: See exactly how NAV is calculated from GGR
- **Instant Liquidity**: Buy and sell shares anytime with immediate settlement

### For Operators

- **Launch Your Casino**: Create a house and start accepting players
- **Full Control**: Choose games, set fees, build your brand
- **Competitive**: Compete with other houses for players and stakers
- **Scalable**: As your house grows, attract more stakers and players

### For Game Developers

- **Publish Once, Earn Everywhere**: Deploy a game package that can be used by any house
- **No Gatekeeping**: Submit your games to any house operator
- **Fair Compensation**: Earn fees when your games are played
- **Innovation**: Build new game types and mechanics

## Technical Architecture

### Core Components

**Registry**: Central protocol registry that tracks all houses, manages protocol fees, and handles version control for safe upgrades.

**House**: Shared objects that process bet/win transactions, manage whitelisted games with fee collectors, handle GGR-based fee distribution, and manage shares.

**Fee Collector**: Shared objects that group games for fee collection. Multiple games can share the same fee collector, and fees are calculated from GGR at epoch end.

**Vault**: Stores all house assets:
- **House Balance**: All funds available for the house (single balance, always active)
- **Fee Balances**: Collected protocol, collector, and house fees

**Participation**: Objects that represent a user's share ownership in a house, tracking share count.

**Balance Manager**: Shared objects that hold player funds for gameplay, with delegatable PlayCaps for secure access control.

**State**: Tracks house-level share management, GGR volumes, and epoch-captured fee rates.

### Key Mechanics

**Share-Based Participation**: Users buy/sell shares valued at NAV (Net Asset Value). Houses are always active - no activation cycles.

**GGR-Based Fees**: All fees (protocol, house, collector) are calculated from Gross Gaming Revenue (bets - wins) at epoch end.

**Epoch Fee Capture**: Fee rates are captured at epoch start to ensure predictable calculations throughout the epoch.

**Capability-Based Security**: Uses Sui capabilities (HouseAdminCap, HouseTransactionCap, FeeCollectorCap, PlayCap, etc.) for fine-grained access control.

**Game Whitelisting with Fee Collectors**: House admins whitelist game instances AND assign them to fee collectors in a single operation.

**Balance Separation**: Player funds (Balance Manager) are separate from house funds (Vault), ensuring players can always access their funds.

## Getting Started

### As a Player

1. Create a Balance Manager to hold your gameplay funds
2. Deposit SUI into your Balance Manager
3. Visit any OpenPlay house frontend
4. Connect your wallet and start playing

### As a Shareholder

1. Browse available houses (check game selection, fees, historical NAV performance)
2. Create a Participation for the house you want to invest in
3. Buy shares with SUI tokens (shares valued at current NAV)
4. Monitor your share value as NAV changes
5. Sell shares anytime to receive SUI immediately

### As an Operator

1. Create a House with your desired configuration
2. Whitelist game instances you trust
3. Set your fee structure
4. Build or use a frontend to attract players
5. Monitor house performance and adjust as needed

### As a Game Developer

1. Write your game logic in Sui Move
2. Deploy your game package to Sui
3. Create game instances with your desired parameters
4. Submit instances to house operators for whitelisting
5. Earn fees when your games are played

## The Future of OpenPlay

OpenPlay is designed to evolve into a fully decentralized, community-driven ecosystem:

- **Multiple Houses**: Competition between houses drives innovation and better returns
- **Rich Game Library**: Community-developed games create diverse offerings
- **Proven Track Records**: Houses build reputation through transparent performance
- **Sustainable Economics**: Aligned incentives ensure long-term viability

The protocol is currently in active development. Some features discussed (like granular fee attribution between package developers and instance creators) may be implemented in future versions based on community needs and feedback.

## Learn More

- [Balance System Documentation](./balances.md) - Understand how funds flow through the system
- [Balance Manager Documentation](./balance-manager.md) - Learn about player fund management
- [Upgrade Documentation](./upgrades.md) - Understand protocol upgrades and security
- [Security Audit Report](../audit/SECURITY_AUDIT_REPORT_OPUS_4.5.md) - Detailed security analysis

## Summary

OpenPlay is **infrastructure for decentralized gambling**. It enables:

- **Players** to enjoy provably fair games with full control of their funds
- **Shareholders** to earn returns by providing liquidity to houses through share ownership
- **Operators** to launch and operate their own casinos with GGR-based performance fees
- **Developers** to create and monetize games through fee collectors

All built on Sui blockchain with transparency, security, and permissionless access at its core. The v3.1 share-based model provides instant liquidity and simplified participation with NAV-based valuation.
