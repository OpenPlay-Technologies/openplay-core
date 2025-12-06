# Changelog

All notable changes to this project will be documented in this file.

## [v2.1] - In Progress

### Added
- Project context documentation for future development sessions (`.cursor/project-context.md`)
- CHANGELOG.md file to track all changes going forward

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

