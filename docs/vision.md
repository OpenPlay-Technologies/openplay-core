# OpenPlay Core: Architecture Summary

## **Current State**

### **What Exists Now**

OpenPlay is a GambleFi protocol on Sui that provides infrastructure for house-based gambling games. The core architecture consists of:

**Core Components:**
- **Registry**: Central protocol registry that tracks all houses, manages protocol fees, and handles version control
- **House**: Shared objects that process bet/win transactions, manage whitelisted games, and handle fee distribution
- **Vault**: Stores all house assets, separates funds into play balance (active gameplay) and reserve balance (staked funds)
- **Participation**: NFT-like objects that represent a user's stake in a house, tracks profit/loss over epochs
- **Balance Manager**: Shared objects that hold player funds, with delegatable PlayCaps for gameplay
- **Game Statistics**: Tracks volume and statistics per game instance

**Key Mechanics:**
- **Epoch-based profit/loss**: Houses operate in epochs (Sui epochs = ~24 hours). At end of epoch, profits/losses are calculated and distributed proportionally to stakers
- **House activation**: Houses must reach minimum stake threshold to activate. When active, funds move from reserve to play balance for gameplay
- **Capability-based security**: Uses Sui capabilities (HouseAdminCap, HouseTransactionCap, PlayCap, etc.) for access control
- **Game whitelisting**: House admins whitelist game instances (identified by UID) to allow them to process transactions

**Current Fee Model:**
- **Protocol fee**: Global fee (in Registry) going to OpenPlay protocol (set to 0% initially)
- **Game fee**: Per-game instance fee going to... someone (currently unclear who owns it)

### **Problems Identified**

1. **Fee attribution is unclear**: Who gets game fees? If you write a package and someone else deploys an instance, how do you get paid?

2. **Referral system is clunky**: Passing `referral_id` on every transaction is:
   - Gas inefficient
   - Easy to bypass (optional)
   - Confusing conceptually (operator vs referral)

3. **Operator model is undefined**: Current code has referral fees, but no clear "operator" concept. How do website operators get rewarded for driving traffic?

4. **Risk of malicious games**: Once whitelisted, a game can send arbitrary transactions and potentially drain the house. No per-game limits or circuit breakers.

5. **Lack of differentiation**: No distinction between:
   - Package developer (writes reusable Move code)
   - Instance creator (deploys a specific instance, might just be making a custom UI/skin)
   - Operator (runs casino website, drives traffic)

6. **Too complex for solo MVP**: As the sole operator, game dev, and house owner initially, the multi-layered fee system feels over-engineered.

---

## **The Vision**

### **What OpenPlay Should Become**

A **permissionless, community-driven protocol** where:

1. **Game developers** can publish reusable game packages and earn fees from any house that uses them
2. **Skin/frontend developers** can create custom UIs for existing games without writing smart contracts
3. **Operators** can launch casinos by creating houses, curating games, and attracting stakers
4. **Stakers** can provide liquidity to houses and earn proportional profits
5. **Protocol** (you) can step back and let the community build games while earning small protocol fees

**Key principles:**
- Open and permissionless (anyone can build)
- Trustless incentives (all fees on-chain, capability-based)
- Composable (games are public goods, reusable across houses)
- Sustainable (aligned incentives for all participants)

---

## **The New Model: 1 House = 1 Operator**

### **Core Architectural Decision**

**Each operator website = one house**

This matches the web2 gambling model:
- Bet365 runs its own bankroll
- Stake.com runs its own bankroll
- They compete for players

In OpenPlay:
- YourCasino.com creates House A
- CompetitorCasino.com creates House B
- They compete for players AND stakers

### **The Four Roles**

**1. Protocol (OpenPlay)**
- Maintains core contracts (Registry, House, Vault, etc.)
- Earns protocol fee from all houses (0-2% of bet volume)
- Eventually can be governed by token holders

**2. Package Developers**
- Write reusable game logic (e.g., CoinFlip, Dice, Roulette packages)
- Publish packages to Sui
- Anyone can create instances from their packages
- Earn fee from ALL instances of their package across ALL houses
- Example: You write CoinFlip.move, publish it. Every house that uses any CoinFlip instance pays you a fee.

**3. Instance Creators (Skin Developers)**
- Deploy specific instances of game packages
- Customize parameters (min/max bet, house edge, etc.)
- Create custom UI/graphics for their instance
- Earn fee from THEIR instance only
- Example: Someone creates a "cyberpunk-themed CoinFlip" instance using your package, builds fancy UI, earns fees when their instance is played

**4. House Admins (Operators)**
- Create a house with minimum stake
- Whitelist game instances they trust
- Set fee splits when whitelisting
- Run operator website (frontend)
- Drive traffic and curate game selection
- Earn through:
  - Staking their own capital
  - House admin fee (% of house profits before distribution)

### **How Fees Work**

**Fee hierarchy per bet:**
```
Player bets 100 SUI on a game with 2% house edge
→ House edge = 2 SUI goes to the house vault

Fee distribution from that 2 SUI:
1. Protocol fee (0-2%): 0.04 SUI → OpenPlay treasury
2. Package dev fee (5-10%): 0.20 SUI → Package developer
3. Instance creator fee (2-5%): 0.10 SUI → Instance creator/skin dev
4. Remaining: 1.66 SUI → House profit pool

House profit pool (1.66 SUI):
5. House admin fee (5-10%): 0.17 SUI → House admin (operator)
6. Stakers: 1.49 SUI → Distributed proportionally to all stakers

If operator staked 50% of house:
- Their total: 0.17 (admin fee) + 0.745 (50% of staker pool) = 0.915 SUI
```

**Fee caps are tracked in Vault:**
- `collected_protocol_fees`: By house, claimed by OpenPlay admin
- `collected_package_dev_fees`: By package developer address, claimed by that address
- `collected_instance_creator_fees`: By instance creator address, claimed by that address
- House admin fee: Taken before staker distribution each epoch

---

## **Functional Flows**

### **Flow 1: Package Developer Publishes Game**

```
1. Developer writes CoinFlip.move
   - Includes: create_instance() function (anyone can call)
   - Hardcodes: package_developer address in the package

2. Deploys to Sui
   - Gets package ID: 0xPKG...

3. Anyone can now create instances:
   - Call: coin_flip::create_instance(min_bet, max_bet, house_edge)
   - Returns: Game instance with UID
   - Instance stores: package_developer address + instance_creator address

4. Package dev earns automatically:
   - When ANY instance from their package is played
   - Fees accumulate in vault by developer address
   - They claim anytime: house.claim_package_dev_fees()
```

**Key: Permissionless and automatic - no coordination needed.**

### **Flow 2: Skin Developer Creates Custom Instance**

```
1. Skin dev finds CoinFlip package they like

2. Creates instance:
   - Calls: coin_flip::create_instance(params)
   - Gets: Instance ID 0xINST...
   - Instance records: instance_creator = skin_dev_address

3. Builds custom UI:
   - Pixel art theme, custom animations, etc.
   - Frontend calls their specific instance 0xINST...

4. Submits to operators:
   - Contacts house admins: "Whitelist my instance 0xINST..."
   - Operators review and decide

5. If whitelisted, earns automatically:
   - Fees accumulate when their instance is played
   - They claim: house.claim_instance_creator_fees()
```

**Key: No smart contract knowledge needed - just call existing functions and build UI.**

### **Flow 3: Operator Launches Casino**

```
1. Operator creates house:
   - Calls: openplay_admin_new_house(private=false, min_activation=X, fees)
   - Gets: House object + HouseAdminCap
   - Shares house publicly

2. Stakes initial liquidity:
   - Calls: house.stake(participation, coins)
   - House activates once minimum reached

3. Whitelists games:
   - Reviews game instances (code audit, testing)
   - Whitelists each: house.admin_add_tx_allowed_with_fees(
       game_id,
       package_dev_fee_bps: 500,
       instance_creator_fee_bps: 200,
     )
   - Sets house admin fee: 500 bps (5%)

4. Builds operator frontend:
   - Lists all whitelisted games
   - Players connect wallets, create balance managers
   - Gameplay flows through house

5. Earns as operator:
   - House admin fee from profits each epoch
   - Plus returns from their own stake
```

**Key: Full control over which games to offer and risk management.**

### **Flow 4: Player Gameplay**

```
1. Player visits operator website (e.g., YourCasino.com)

2. Creates/connects balance manager:
   - Creates: balance_manager::new()
   - Deposits funds: balance_manager.deposit(coins)

3. Selects game and plays:
   - UI shows: "CoinFlip Cyberpunk" (instance 0xINST...)
   - Player: Bets 1 SUI on Heads
   - Frontend calls: coin_flip::play(game, house, balance_manager, ...)

4. Game processes:
   - Game borrows HouseTransactionCap from house
   - Generates random result (Sui VRF)
   - Creates transactions: [bet(1 SUI), win(1.96 SUI)] or [bet(1 SUI)]
   - Calls: house.process_transactions(transactions, ...)

5. House processes:
   - Reads attribution from game instance (package_dev, instance_creator)
   - Calculates all fees
   - Settles balance manager (debit bet, credit win)
   - Distributes fees to correct buckets
   - Updates statistics

6. Player sees result immediately
```

**Key: Seamless UX - player doesn't think about fees or backend complexity.**

### **Flow 5: Staker Provides Liquidity**

```
1. User evaluates houses:
   - Looks at Registry: lists all houses
   - Compares: game selection, historical returns, operator reputation

2. Chooses a house (e.g., House A)

3. Creates participation:
   - Calls: house.new_participation()
   - Gets: Participation NFT (owned object)

4. Stakes funds:
   - Calls: house.stake(participation, coins)
   - Funds go to reserve balance
   - If house active: stake is "pending" until next epoch
   - If house inactive: stake is immediate

5. Earns profits automatically:
   - At end of each epoch: house calculates profits/losses
   - Profits distributed proportionally to active stake
   - Participation object updates with new balance

6. Can unstake:
   - Calls: house.unstake(participation, amount)
   - Unstake is "pending" until next epoch
   - Next epoch: can claim coins

7. Claims rewards:
   - Calls: house.claim_all(participation)
   - Receives coins proportional to profits earned
```

**Key: Simple staking mechanism, automatic profit distribution.**

### **Flow 6: End of Epoch Processing**

```
Happens automatically when new epoch starts:

1. Vault processes end of day:
   - Records play_balance at epoch end
   - Moves play_balance back to reserve_balance
   - Returns: end_of_day_balance

2. House calculates profit/loss:
   - If eod_balance > active_stake: profits = difference
   - If eod_balance < active_stake: losses = difference

3. Take house admin fee:
   - Admin fee = profits * admin_fee_bps / 10000
   - Transfer to house admin address
   - Remaining profits go to stakers

4. State processes end of day:
   - Actualizes pending unstakes (with profit/loss)
   - Processes pending stakes (become active)
   - Saves historical data
   - Resets for new epoch

5. House attempts reactivation:
   - If sufficient inactive stake exists: reactivate
   - Moves funds from reserve to play balance
   - House is ready for new epoch
```

**Key: Fully automated, no manual intervention needed.**

---

## **Changes Needed**

### **What to Add**


1. **House admin fee mechanism:**
   - Add `admin_fee_bps` to House config
   - At epoch end: take admin fee before distributing to stakers
   - Transfer admin fee to house admin (or accumulate in vault)

2. **Package developer fee tracking:**
   - Vault tracks: `collected_package_dev_fees` by address
   - When processing transactions: read package_developer from game instance
   - Accumulate fees by developer address
   - Claim function: `claim_package_dev_fees()` (checks ctx.sender())

3. **Instance creator fee tracking:**
   - Vault tracks: `collected_instance_creator_fees` by address
   - When processing transactions: read instance_creator from game instance
   - Accumulate fees by creator address
   - Claim function: `claim_instance_creator_fees()` (checks ctx.sender())

4. **Per-game fee configuration:**
   - Instead of: `games_fee_bps: VecMap<ID, u64>`
   - Use: `game_fee_configs: VecMap<ID, GameFeeConfig>`
   - Where GameFeeConfig has: package_dev_fee_bps, instance_creator_fee_bps

5. **Game instance attribution standard:**
   - Game contracts should expose: package_developer and instance_creator addresses
   - House reads these when processing transactions
   - (Convention, not enforced by protocol)

### **What to Remove**

1. **Current referral system:**
   - Remove: `referral_id: Option<ID>` parameter from transaction processing
   - Remove: referral fee calculation and distribution
   - Keep: referral module in codebase (for future player-to-player referrals)

2. **Unclear operator concept:**
   - Remove: any operator-specific code that's not the house admin
   - Simplify: operator = house admin

### **What to Keep**

✅ All core mechanics (staking, profit/loss, epoch processing)
✅ Registry and protocol fee structure
✅ Capability-based security model
✅ Vault separation (play vs reserve balance)
✅ Game whitelisting mechanism
✅ Balance manager system
✅ Game statistics tracking

---

## **MVP Path Forward**

### **Phase 1: You Do Everything (Months 1-3)**

**Setup:**
- You create House A
- You stake your capital
- You write 2-3 game packages (CoinFlip, Dice, Crash)
- You create instances from your packages
- You whitelist on your house
- You run operator website

**Fee config:**
- Protocol: 0%
- Package dev: 10% (goes to you)
- Instance creator: 2% (goes to you)
- House admin: 5% (goes to you)
- Stakers: 83% (including you)

**Goal:** Prove the system works, generate volume, build reputation

### **Phase 2: External Game Devs (Months 3-6)**

**Onboarding:**
- External devs publish game packages
- You review and whitelist instances on YOUR house
- Set fee splits: package_dev (them), instance_creator (them or you), admin (you)

**Two approaches:**
1. **Full package**: They write and deploy complete game contract
2. **Frontend-only**: You write contract, they build custom UI/skin

**Goal:** Prove incentive model works, grow game library

### **Phase 3: Multiple Houses (Months 6-12)**

**Expansion:**
- Other operators create their houses
- They whitelist games from community packages
- Multiple houses compete for stakers and players

**Ecosystem emerges:**
- Game packages become valuable (earn from all houses)
- Houses differentiate (conservative vs degen, different game selections)
- Stakers choose houses based on returns and risk

**Your role:**
- Enable protocol fee (1-2%)
- Focus on protocol maintenance
- Let community build games

### **Phase 4: Token Launch (Month 12+)**

**Tokenomics:**
- Launch $OPENPLAY token
- Stakers earn protocol fees (from all houses)
- Governance over protocol parameters
- You transition to protocol development only

---

## **Key Success Metrics**

**MVP Success:**
- 3+ games live and playable
- 10+ active players
- $10K+ total volume
- 0 security incidents
- 1+ external game developer onboarded

**Ecosystem Success:**
- 3+ external houses created
- 10+ game packages published
- 100+ active players across all houses
- $100K+ total volume
- Sustainable fees for all participants

---

## **The Mental Model**

Think of OpenPlay as:
- **The protocol**: Like Uniswap (provides infrastructure)
- **Houses**: Like liquidity pools (provide capital)
- **Game packages**: Like trading pairs (provide functionality)
- **Operators**: Like Uniswap front-ends (provide UX)

**Everyone wins:**
- Protocol earns from all houses
- Package devs earn from all houses using their games
- Instance creators earn from their specific instances
- House admins earn from their house's success
- Stakers earn from their chosen house

**Result:** Self-sustaining ecosystem where incentives are aligned and value flows to contributors automatically.