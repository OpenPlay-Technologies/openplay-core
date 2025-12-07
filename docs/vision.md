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
   - Fees are collected from each transaction

2. **End of Epoch**:
   - Total profits or losses are calculated
   - House performance fees are deducted (if profitable)
   - Remaining profits are distributed proportionally to all stakers
   - New stakes become active for the next epoch

This epoch-based system ensures fair profit/loss sharing - everyone who stakes during an epoch shares proportionally in that epoch's results.

## Key Participants

### Players

Players enjoy provably fair games on any OpenPlay house. They:
- Create a **Balance Manager** to hold their gameplay funds
- Connect to any house's frontend
- Play whitelisted games with instant settlement
- Never need to trust a centralized operator

**Security**: Players maintain full control of their funds through the Balance Manager system. They can deposit, play, and withdraw at any time - even if a house is paused or upgrading.

### Stakers (Liquidity Providers)

Stakers provide liquidity to houses and earn proportional returns. They:
- Create a **Participation** NFT for each house they want to stake in
- Stake SUI tokens into the house
- Earn a proportional share of house profits each epoch
- Can unstake at any time (processed at end of epoch)

**Returns**: Stakers earn based on:
- House performance (profits from games)
- Their stake size (proportional distribution)
- House fee structure (performance fees reduce returns)

**Risk**: Stakers bear losses if the house loses money during an epoch. Losses are shared proportionally, just like profits.

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

OpenPlay uses a multi-tier fee system that aligns incentives across all participants:

### Transaction Fees (Per Bet)

When a player places a bet, fees are deducted from the house edge:

1. **Protocol Fee** (0-2%): Goes to OpenPlay protocol treasury
2. **Game Fee** (configurable per game): Goes to the game instance owner
3. **Remaining**: Goes to the house profit pool

### House Performance Fee (Per Epoch)

At the end of each profitable epoch:
- A percentage of profits (configurable, default 20%) goes to the house operator
- Remaining profits are distributed proportionally to all stakers

**Example**:
- House makes 1000 SUI profit in an epoch
- House fee: 20% = 200 SUI → House operator
- Remaining: 800 SUI → Distributed to stakers proportionally

## Security & Trust

### For Players

- **Fund Control**: Players control their funds through Balance Managers - no one can access them without your permission
- **Provably Fair**: Games use Sui's on-chain randomness - results are verifiable
- **No Lock-in**: You can withdraw funds at any time, even if a house is paused
- **Transparent**: All transactions are on-chain and auditable

### For Stakers

- **Proportional Sharing**: Profits and losses are shared proportionally - no preferential treatment
- **Transparent Accounting**: All stake, profit, and loss calculations are on-chain
- **No Lock-in**: You can unstake at any time (processed at end of epoch)
- **House Control**: You choose which houses to stake in based on their game selection, fees, and track record

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

### For Stakers

- **Passive Income**: Earn returns by providing liquidity to houses
- **Diversification**: Stake in multiple houses to spread risk
- **Transparent Returns**: See exactly how profits are calculated and distributed
- **Flexible**: Stake and unstake based on house performance

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

**House**: Shared objects that process bet/win transactions, manage whitelisted games, handle fee distribution, and manage staking.

**Vault**: Stores all house assets, separating funds into:
- **Reserve Balance**: Staked funds not currently in play
- **Play Balance**: Funds actively used for game payouts
- **Fee Balances**: Collected protocol, game, and house fees

**Participation**: NFT-like objects that represent a user's stake in a house, tracking profit/loss over epochs.

**Balance Manager**: Shared objects that hold player funds for gameplay, with delegatable PlayCaps for secure access control.

**State**: Tracks house-level stake management, activation status, and epoch history.

### Key Mechanics

**Epoch-Based Profit/Loss**: Houses operate in epochs (~24 hours). At end of epoch, profits/losses are calculated and distributed proportionally to stakers.

**House Activation**: Houses must reach minimum stake threshold to activate. When active, funds move from reserve to play balance for gameplay.

**Capability-Based Security**: Uses Sui capabilities (HouseAdminCap, HouseTransactionCap, PlayCap, etc.) for fine-grained access control.

**Game Whitelisting**: House admins whitelist game instances (identified by UID) to allow them to process transactions.

**Balance Separation**: Player funds (Balance Manager) are separate from house funds (Vault), ensuring players can always access their funds.

## Getting Started

### As a Player

1. Create a Balance Manager to hold your gameplay funds
2. Deposit SUI into your Balance Manager
3. Visit any OpenPlay house frontend
4. Connect your wallet and start playing

### As a Staker

1. Browse available houses (check game selection, fees, historical returns)
2. Create a Participation for the house you want to stake in
3. Stake SUI tokens
4. Monitor your returns each epoch
5. Claim profits or unstake when ready

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
- **Stakers** to earn returns by providing liquidity to houses
- **Operators** to launch and operate their own casinos
- **Developers** to create and monetize games

All built on Sui blockchain with transparency, security, and permissionless access at its core.
