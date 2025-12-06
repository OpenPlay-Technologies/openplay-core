# Changelog

All notable changes to this project will be documented in this file.

## [v2.1] - In Progress

### Added
- Epoch limit parameter to `update_participation` to prevent DoS attacks (H-01 security fix)
  - Added `max_epochs` parameter to `house_state::update_participation()` function
  - Added `refresh_with_limit()` function in `house_state` module for chunked epoch processing
  - Added `update_participation_with_limit()` public function in `house` module
  - Default behavior unchanged: `update_participation()` still processes all epochs (uses `u64::MAX`)
  - New function returns `true` if all epochs were processed, `false` if more epochs remain
  - Added test `update_participation_with_epoch_limit` to verify chunked processing works correctly
- Project context documentation for future development sessions (`.cursor/project-context.md`)
- CHANGELOG.md file to track all changes going forward
- House fee (performance fee) system that takes a percentage of profits from each epoch
  - Added `house_fee_bps` field to House struct (default 20% = 2000 bps)
  - Added `collected_house_fees` balance to Vault
  - Added `admin_claim_house_fees()` function for house admin to claim collected fees
  - Added `house_fee_factor()` and `house_fee_bps()` getter functions
  - House fee is calculated and deducted from profits during end-of-day processing
  - Remaining profits (after house fee) are distributed to stakers
  - Added test case for claiming house fees

### Changed

### Fixed

### Removed
- Referral system completely removed from the codebase
  - Removed `referral.move` module
  - Removed referral fee tracking from `vault.move`
  - Removed referral fee parameters and logic from `house.move` and `house_state.move`
  - Removed `referral_fee_factor` parameter from `process_transactions` function
  - Removed referral-related test cases
  - Removed `referral_fee_bps` parameter from `openplay_admin_new_house` and `new_for_testing` functions
  - Removed `referral_id` parameter from transaction processing functions
  - Updated `create-house.sh` script to remove referral fee parameters
  - Updated documentation in `docs/vision.md` and `.cursor/project-context.md` to reflect referral system removal
  - Cleaned up all remaining referral references in code, tests, and documentation

---

## [v1.1] - Previous Version

Initial stable version of OpenPlay Core protocol.

