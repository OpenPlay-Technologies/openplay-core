# SECURITY_AUDIT_REPORT_GEMINI_3_PRO.md

## 1. Executive Summary

*   **Project Name:** OpenPlay Core
*   **Audit Date:** December 10, 2025
*   **Auditor:** Gemini-3-Pro (AI Assistant)
*   **Target Framework:** Sui Move
*   **Scope:** `package/sources` directory

### Risk Assessment

The OpenPlay Core protocol implements a "House" and "Vault" system for gambling applications on Sui. The architecture relies on a shared object model with specific capabilities for access control.

**Overall Security Score:** **High Risk**

While the core Move logic (coin handling, object ownership) follows many best practices, the system has **Critical** availability risks and **High** economic loopholes that could allow users to play risk-free or houses to bleed funds. The protocol is designed as a "Platform" where the House Admin and Game Providers are trusted entities, but the interaction between asynchronous game processing and user custody creates significant vulnerabilities.

**Key Strengths:**
*   **Hot Potato Pattern:** `HouseTransactionCap` correctly enforces transaction processing flow.
*   **Anti-Rug Mechanisms:** Explicit design choices to prevent admins from locking user funds via version control.
*   **Rounding Strategy:** Robust implementation of `mul_floor` and `mul_ceil` to strictly favor the protocol in all math operations.

**Key Weaknesses:**
*   **Quadratic Gas Usage:** The fee collection logic contains an O(N^2) loop that can permanently lock the contract.
*   **"Free Roll" Vulnerability:** Users can withdraw funds from their `BalanceManager` while a game is pending, causing the settlement transaction to fail.
*   **Financial Inefficiency:** Lack of "Carry Forward Loss" means houses pay fees on volatility, even if net profitable is zero.

---

## 2. Findings

### [C-01] Critical: Denial of Service via Quadratic Gas Usage in Fee Collection

**Severity:** Fixed
**Location:** `package/sources/state/house_state.move`: `process_collector_end_of_day`

**Description:**
The function `process_collector_end_of_day` previously iterated through the keys of `current_collector_ggr` (a `VecMap`) and called `vec_map::get` inside the loop, resulting in O(N^2) complexity. This presented a significant DoS risk if `MAX_GAMES` (500) was reached.

**Resolution:**
The logic has been refactored to use `vec_map::get_entry_by_idx` and `vec_map::get_entry_by_idx_mut`, which provides O(1) access per entry. The total complexity is now O(N) (linear), effectively mitigating the gas exhaustion risk.

---

### [H-01] High: Game Settlement Front-Running ("Free Roll" Attack)

**Severity:** Mitigated / Acknowledged
**Location:** `package/sources/vault.move`, `package/sources/balance_manager.move`

**Description:**
The protocol uses a `BalanceManager` to hold user funds, allowing instant withdrawals. This creates a "Free Roll" vulnerability if games do not lock funds before generating outcomes.

**Mitigation:**
The `game-whitelisting.md` documentation has been updated to explicitly require **Atomic Transaction Flow**. Games must enforce that the bet transaction (fund locking) occurs in the same Programmable Transaction Block (PTB) as the game initiation or outcome generation. This shifts the responsibility to the Game implementation, which is verified during the whitelisting process.

---

### [H-02] High: Centralization Risk - Trusted Game Execution & Replay

**Severity:** Mitigated / Acknowledged
**Location:** `package/sources/house.move`, `package/sources/transaction.move`

**Description:**
The protocol relies on the `HouseTransactionCap` holder (Game Backend) to submit honest results.

**Mitigation:**
This risk is inherent to the "Platform" model and is managed via the rigorous **Game Whitelisting Process** defined in `docs/game-whitelisting.md`. Only verified games are authorized to submit transactions.

---

### [M-01] Medium: Unpausable Fund Operations (Security Trade-off)

**Severity:** Acknowledged
**Location:** `package/sources/house.move`: `buy_shares`, `sell_shares`

**Description:**
`buy_shares` and `sell_shares` bypass `registry.check_version()` to prevent admin-driven rug pulls via pausing. This is a deliberate design choice prioritizing user fund access over admin control.

---

### [M-02] Medium: Financial Risk - No Carry-Forward of Losses

**Severity:** Acknowledged
**Location:** `package/sources/state/house_state.move`: `process_end_of_day`

**Description:**
GGR is calculated per epoch without carrying forward losses. This may result in higher effective fees during volatile periods. This is a known economic parameter of the current version.

---

### [M-03] Medium: Lack of Slippage Protection in Share Operations

**Severity:** Invalid / By Design
**Location:** `package/sources/house.move`: `buy_shares`, `sell_shares`

**Description:**
The report previously flagged a lack of slippage parameters. However, share operations are executed based on the strictly calculated NAV at the end of the day. Since the system uses a forward-pricing model (NAV is determined *after* the epoch closes/processes), "slippage" in the traditional DEX sense does not apply. Rounding strictly favors the protocol to prevent arbitrage.

**Resolution:**
Marked as invalid. The NAV-based model coupled with protocol-favoring rounding provides sufficient economic deterministic behavior.

---

## 3. Architecture & Capabilities

### 3.1 Object Ownership Map

| Object | Type | Description | Risks |
| :--- | :--- | :--- | :--- |
| `Registry` | Shared | Central directory. | Single point of failure. |
| `House` | Shared | Main logic, holds Vault. | Locked by DoS (C-01 - **FIXED**). |
| `BalanceManager` | Shared | User funds escrow. | "Free Roll" Vulnerable (H-01 - **MITIGATED**). |
| `HouseTransactionCap`| Hot Potato | Auth for processing txs. | No replay protection (H-02 - **MITIGATED**). |

### 3.2 Privileged Roles

| Role | Capability | Powers | Risk |
| :--- | :--- | :--- | :--- |
| **OpenPlay Admin** | `OpenPlayAdminCap` | Create Houses, Set Protocol Fees. | **Critical Centralization.** |
| **House Admin** | `HouseAdminCap` | Whitelist Games, Set House Fees. | **High Centralization.** |

---

## 4. Pre-Flight Checklist

*   [x] **Build & Test:** Passing.
*   [x] **Rounding:** Strategy strictly enforced.
*   [x] **DoS Protection:** **FIXED** (O(N) Refactor).
*   [x] **Front-Running Protection:** **MITIGATED** (Via Whitelisting Requirements).
