# ⭐ **Security Audit Report: OpenPlay Core**

**Project:** OpenPlay Core
**Auditor:** Gemini 3 Pro (AI Assistant)
**Date:** December 4, 2025
**Framework:** Sui Move

---

## **1. Executive Summary**

*   **Risk Assessment:** The protocol is well-structured with a clear separation of concerns between `House`, `Vault`, `State`, and `BalanceManager`. The primary security model relies heavily on the trust placed in "Authorized Games". If a game is malicious or compromised, it can manipulate user and house funds.
*   **Critical Findings:** One potential Denial of Service (DoS) vector was identified regarding long-inactive participation records, which could lead to locked funds due to gas limits.
*   **Architectural Soundness:** The object ownership and capability patterns are generally sound and follow Sui best practices. The use of `Shared` objects for the House and BalanceManager is appropriate for the use case.

---

## **2. Pre-Audit Architecture & Reconnaissance**

### **2.1 Object Ownership Map**

| Object Type | Struct Name | Description | Risks |
| :--- | :--- | :--- | :--- |
| **Shared** | `House` | The main entry point. Holds `Vault` and `State`. | Congestion, sequencing. |
| **Shared** | `BalanceManager` | Holds user funds for gaming. | Authorized games can drain if malicious. |
| **Shared** | `Registry` | Tracks houses and protocol config. | Central point of failure for versioning. |
| **Shared** | `Referral` | Tracks referral fees. | Low risk. |
| **Shared** | `GameStatistics` | Tracks game stats. | Low risk. |
| **Owned** | `HouseAdminCap` | Admin rights for a House. | Can enable/disable games. |
| **Owned** | `OpenPlayAdminCap` | Protocol admin rights. | Can change protocol fees, versions. |
| **Owned** | `Participation` | Represents user's stake in a House. | Loss of object = Loss of Stake. |
| **Owned** | `PlayCap` | Delegated access to BalanceManager. | Risk if transferred to malicious actor. |
| **Wrapped** | `Vault` | Inside `House`. Holds assets. | Protected by House logic. |
| **Wrapped** | `State` | Inside `House`. Tracks logic. | Protected by House logic. |

### **2.2 Capability (Cap) Flow**

1.  **OpenPlayAdminCap:** Created at `registry::init`. Controlled by protocol deployer.
2.  **HouseAdminCap:** Created when `openplay_admin_new_house` is called. Held by House creator.
3.  **HouseTransactionCap:** "Hot Potato" derived from owning a Game's `UID`. Used to authorize transactions.
4.  **PlayCap:** Minted by `BalanceManager` owner. Transferred to player/agent to sign transactions.

### **2.3 Privileged Roles & Centralization Matrix**

| Role | Capability | Can Upgrade? | Move User Funds? | Pause System? |
| :--- | :--- | :--- | :--- | :--- |
| **Protocol Admin** | `OpenPlayAdminCap` | Yes (Versioning) | Yes (Protocol Fees) | Yes (Disable Versions) |
| **House Admin** | `HouseAdminCap` | No | Yes (Game/Ref Fees) | Yes (Revoke Games) |
| **Game Owner** | Game UID | No | Yes (via Game Logic) | No |
| **BM Owner** | `BalanceManagerCap` | No | Yes (Own Funds) | No |

**Centralization Risk:** The **Game Owner** (Authorized Game) has significant power. The protocol assumes authorized games are honest. This is an intended design choice but a critical trust boundary.

---

## **3. Findings & Vulnerabilities (Kill Chain)**

### **[H-01] High: Potential Locked Funds due to Unbounded Loop in Participation Update**

**Description:**
The function `house_state::update_participation` iterates through all epochs from `last_updated_epoch` to `ctx.epoch()` to calculate profit/loss shares.
```move
while (current_participation_epoch < ctx.epoch()) {
    // ... complex calculations ...
}
```
If a user stakes funds and then goes inactive for a prolonged period (e.g., thousands of epochs), the cost to process this loop might exceed the maximum gas limit for a transaction.

**Impact:**
The user would be unable to `unstake`, `add_stake`, or `claim_rewards`. Their funds would be effectively locked in the contract forever.

**Recommendation:**
Implement a mechanism to update participation in chunks. Allow the user to call a `catch_up` function that processes `N` epochs at a time, saving the state (updating `last_updated_epoch`) without requiring a full catch-up in a single transaction.

---

### **[M-01] Medium: Trust Dependence on "Authorized Games"**

**Description:**
The `house::tx_admin_process_transactions_v2` function accepts a `vector<Transaction>` provided by the caller (the Game). The House module blindly processes these results (Win/Loss) to update balances.
```move
public fun tx_admin_process_transactions_v2(...) {
    // ...
    self.state.process_transactions(transactions, ...)
    // ...
}
```
There is no on-chain verification that the game actually occurred or that the result is correct (e.g., via VRF or ZK proof).

**Impact:**
If a game's private key is compromised or the game developer is malicious, they can submit fabricated "Loss" transactions to drain user `BalanceManager` funds, or fabricated "Win" transactions to drain the `House` vault.

**Recommendation:**
While likely intended, this risk should be transparent. Consider adding a "Dealer" signature verification or moving random number generation on-chain (Sui VRF) to verify outcomes if possible.

---

### **[L-01] Low: Precision Errors in Stake/Unstake**

**Description:**
The system allows for a `precision_error_allowance` of 2 units.
```move
if (amount - self.inactive_stake <= precision_error_allowance()) {
    self.inactive_stake = 0;
}
```
While this prevents the system from locking up due to dust, repeated operations could theoretically bleed small amounts of value.

**Recommendation:**
Ensure these error allowances are strictly bounded and monitored. The current implementation seems safe for practical purposes.

---

### **[I-01] Info: Participation Object Loss**

**Description:**
The `Participation` object is an owned object necessary to claim stake.
```move
public struct Participation has key, store { ... }
```
If a user loses access to this object (e.g., sends it to an unrecoverable address), their stake in the House is lost to them. The House keeps the funds as `active_stake` or `inactive_stake` indefinitely.

**Recommendation:**
This is standard Sui behavior, but UI/Client should warn users about the importance of the `Participation` object.

---

## **4. Automated Verification Checks**

### **4.1 Sui Move Linter**
*   **Status:** The code generally follows Sui conventions.
*   **Check:** Ensure no `transfer::public_transfer` is used on objects intended to be soulbound or shared (Checked: usage seems correct).

### **4.2 Kill Chain Checklist**
*   **Coin Smasher:** ✅ Checked. `house::stake` consumes the full coin value.
*   **Function Visibility:** ✅ Checked. Sensitive functions are `private` or `public(package)`.
*   **Object Masquerading:** ✅ Checked. Uses `UID` for identification.
*   **Transfer-to-Object Trap:** ✅ Checked. `Participation` has `store`.

---

## **5. Pre-Flight Final Checklist**

*   [x] **Upgrade Policy:** Controlled via `Registry` allowed versions.
*   [x] **Events:** Emitted for all major actions (`HouseCreated`, `TransactionsProcessed`, `StakeAdded`, `StakeRemoved`).
*   [x] **Slippage:** Not applicable (no swapping).
*   [x] **DoS:** **FLAGGED [H-01]** (Unbounded loop in participation update).
*   [x] **Centralization:** **FLAGGED [M-01]** (Trust in Game logic).

---

**Disclaimer:** This audit validates code logic and security best practices. It does not guarantee protection against economic collapse, private key compromise, or malicious game logic.
