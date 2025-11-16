#!/bin/bash

# Setup OpenPlay Balance Manager
# This script creates, funds, and sets up a balance manager with play capabilities

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Require deposit amount argument (in MIST)
if [ $# -ne 1 ]; then
    echo ""
    echo "Usage: $0 <deposit_amount_in_MIST>"
    echo "Example: $0 5000000000   # deposits 5 SUI (since 1 SUI = 1e9 MIST)"
    exit 1
fi

DEPOSIT_AMOUNT_MIST="$1"

# Validate deposit amount is a positive integer
if ! [[ "$DEPOSIT_AMOUNT_MIST" =~ ^[0-9]+$ ]] || [ "$DEPOSIT_AMOUNT_MIST" -le 0 ]; then
    print_error "Deposit amount must be a positive integer (in MIST)."
    exit 1
fi

# Function to get active environment
get_active_env() {
    sui client active-env 2>/dev/null || echo "unknown"
}

# Function to generate timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Function to save balance manager setup output to files
save_balance_manager_output() {
    local env="$1"
    local timestamp="$2"
    local output_dir="outputs/$env"
    local base_filename="balance_manager_setup_${timestamp}"
    
    # Create environment-specific directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Save environment variables
    local env_file="$output_dir/${base_filename}.env"
    save_env_vars "$env_file" \
        "OPENPLAY_BALANCE_MANAGER_ID" \
        "OPENPLAY_BALANCE_MANAGER_CAP_ID"
    
    # Create latest symlink for easy access
    local latest_env="$output_dir/latest_balance_manager.env"
    
    ln -sf "${base_filename}.env" "$latest_env"
    
    print_success "Latest symlinks created for easy access"
    
    # Do not write any root-level files; env files live only under outputs
}

# Function to save environment variables to a file
save_env_vars() {
    local env_file="$1"
    shift
    local vars=("$@")
    
    print_status "Saving environment variables to $env_file"
    
    # Create or overwrite the env file
    > "$env_file"
    
    for var in "${vars[@]}"; do
        if [ -n "${!var}" ]; then
            echo "export $var=\"${!var}\"" >> "$env_file"
            print_success "Saved $var=${!var}"
        else
            print_warning "Variable $var is empty, skipping"
        fi
    done
    
    print_success "Environment variables saved to $env_file"
    print_status "To load these variables in your shell, run: source $env_file"
}

# Check if we're in the right directory
if [ ! -f "packages/openplay_core/Move.toml" ]; then
    print_error "This script must be run from the openplay-framework root directory"
    exit 1
fi

# Check if sui client is available
if ! command -v sui &> /dev/null; then
    print_error "sui client is not available. Please ensure Sui is installed and in your PATH."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    exit 1
fi

# Get active environment and timestamp
ACTIVE_ENV=$(get_active_env)
TIMESTAMP=$(get_timestamp)

print_status "Active environment: $ACTIVE_ENV"
print_status "Setup timestamp: $TIMESTAMP"

# Load environment variables from outputs
if [ -f "outputs/$ACTIVE_ENV/latest.env" ]; then
    source "outputs/$ACTIVE_ENV/latest.env"
    print_success "Loaded core package environment variables"
else
    print_error "Core package not deployed. Run ./scripts/deploy-core.sh first."
    exit 1
fi

# Check if package variables are loaded
if [ -z "$CURRENT_OPENPLAY_CORE_PACKAGE_ID" ]; then
    print_error "Core package variables not loaded. Run ./scripts/deploy-core.sh first."
    exit 1
fi

# Set package variables for convenience (use CURRENT_* to always use latest version)
CORE_PACKAGE_ID="$CURRENT_OPENPLAY_CORE_PACKAGE_ID"

print_status "Setting up Balance Manager with Core Package: $CORE_PACKAGE_ID"

# Step 1: Get available coins
print_status "Step 1: Getting available coins..."
GAS_OUTPUT=$(sui client gas --json)
COIN_ID=$(echo "$GAS_OUTPUT" | jq -r '.[0].gasCoinId')
COIN_BALANCE=$(echo "$GAS_OUTPUT" | jq -r '.[0].mistBalance')

if [ -z "$COIN_ID" ] || [ "$COIN_ID" = "null" ]; then
    print_error "No coins available. Please ensure you have SUI coins in your wallet."
    exit 1
fi

print_success "Found coin: $COIN_ID with balance: $COIN_BALANCE"

# Check if we have a valid balance
if [ "$COIN_BALANCE" = "null" ] || [ -z "$COIN_BALANCE" ]; then
    print_error "No valid coin balance found. Please ensure you have SUI coins in your wallet."
    exit 1
fi

# Ensure requested deposit does not exceed available balance
if [ "$DEPOSIT_AMOUNT_MIST" -ge "$COIN_BALANCE" ]; then
    print_error "Requested deposit ($DEPOSIT_AMOUNT_MIST MIST) is >= available balance ($COIN_BALANCE MIST)."
    exit 1
fi

if command -v bc >/dev/null 2>&1; then
    DEPOSIT_AMOUNT_SUI=$(echo "scale=9; $DEPOSIT_AMOUNT_MIST/1000000000" | bc)
    print_status "Will fund balance manager with: $DEPOSIT_AMOUNT_MIST MIST (~${DEPOSIT_AMOUNT_SUI} SUI)"
else
    print_status "Will fund balance manager with: $DEPOSIT_AMOUNT_MIST MIST"
fi

# Step 2: Create the balance manager
print_status "Step 2: Creating balance manager..."
BALANCE_MANAGER_CREATE_OUTPUT=$(sui client ptb \
    --move-call sui::tx_context::sender \
    --assign sender \
    --move-call $CORE_PACKAGE_ID::balance_manager::new \
    --assign bmOutput \
    --move-call $CORE_PACKAGE_ID::balance_manager::share bmOutput.0 \
    --transfer-objects [bmOutput.1] sender \
    --json)

# Extract balance manager ID and cap ID from the event data
BALANCE_MANAGER_CAP_ID=$(echo "$BALANCE_MANAGER_CREATE_OUTPUT" | jq -r '.events[] | select(.type | contains("::balance_manager::BalanceManagerCreatedEvent")) | .parsedJson.balance_manager_cap_id')
BALANCE_MANAGER_ID=$(echo "$BALANCE_MANAGER_CREATE_OUTPUT" | jq -r '.events[] | select(.type | contains("::balance_manager::BalanceManagerCreatedEvent")) | .parsedJson.balance_manager_id')


if [ -z "$BALANCE_MANAGER_ID" ] || [ "$BALANCE_MANAGER_ID" = "null" ]; then
    print_error "Failed to extract balance manager ID"
    exit 1
fi

if [ -z "$BALANCE_MANAGER_CAP_ID" ] || [ "$BALANCE_MANAGER_CAP_ID" = "null" ]; then
    print_error "Failed to extract balance manager cap ID"
    exit 1
fi

print_success "Balance manager created: $BALANCE_MANAGER_ID"
print_success "Balance manager cap created: $BALANCE_MANAGER_CAP_ID"

# Step 3: Split a coin to the exact deposit amount and fund the balance manager
print_status "Step 3: Splitting coin and funding balance manager..."
FUND_OUTPUT=$(sui client ptb \
    --split-coins @$COIN_ID [$DEPOSIT_AMOUNT_MIST] \
    --assign depositCoins \
    --move-call $CORE_PACKAGE_ID::balance_manager::deposit @$BALANCE_MANAGER_ID @$BALANCE_MANAGER_CAP_ID depositCoins.0 \
    --json)

print_success "Balance manager funded successfully with $DEPOSIT_AMOUNT_MIST MIST"

# Export variables for current session
export OPENPLAY_BALANCE_MANAGER_ID="$BALANCE_MANAGER_ID"
export OPENPLAY_BALANCE_MANAGER_CAP_ID="$BALANCE_MANAGER_CAP_ID"

# Combine all outputs for final JSON
BALANCE_MANAGER_OUTPUT=$(jq -n \
    --argjson create "$BALANCE_MANAGER_CREATE_OUTPUT" \
    --argjson fund "$FUND_OUTPUT" \
    '{
        balance_manager_create: $create,
        funding: $fund
    }')

# Save all outputs to files
save_balance_manager_output "$ACTIVE_ENV" "$TIMESTAMP"

# Print summary
echo ""
print_success "Balance Manager setup completed successfully!"
echo ""
print_status "Setup Summary:"
echo "  Balance Manager ID: $BALANCE_MANAGER_ID"
echo "  Balance Manager Cap ID: $BALANCE_MANAGER_CAP_ID"
if command -v bc >/dev/null 2>&1; then
    echo "  Funding Amount: ${DEPOSIT_AMOUNT_MIST} MIST (~$(echo "scale=9; ${DEPOSIT_AMOUNT_MIST}/1000000000" | bc) SUI)"
else
    echo "  Funding Amount: ${DEPOSIT_AMOUNT_MIST} MIST"
fi
echo ""