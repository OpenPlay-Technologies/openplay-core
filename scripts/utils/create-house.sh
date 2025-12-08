#!/bin/bash

# Create OpenPlay House Instances
# This script creates house instances with predefined parameter sets

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_active_env() { sui client active-env 2>/dev/null || echo "unknown"; }
get_timestamp() { date +"%Y%m%d_%H%M%S"; }

# Function to show available parameter sets
show_parameter_sets() {
    echo ""
    print_status "Available House Parameter Sets:"
    echo ""
    for set_num in 1 2 3 4; do
        get_parameter_set "$set_num" >/dev/null 2>&1

        local min_activation_sui
        if command -v bc >/dev/null 2>&1; then
            min_activation_sui=$(echo "scale=2; $MIN_ACTIVATION_BALANCE/1000000000" | bc)
        else
            min_activation_sui="$MIN_ACTIVATION_BALANCE (raw)"
        fi

        echo "------------------------------------------------------------"
        echo "Parameter Set $set_num: $HOUSE_TYPE"
        echo "    Private              : $PRIVATE"
        echo "    Min Activation       : $min_activation_sui SUI"
        echo "------------------------------------------------------------"
        echo ""
    done
}

# Function to get parameter set
get_parameter_set() {
    local set_num="$1"
    
    case $set_num in
        1)
            PRIVATE=false
            MIN_ACTIVATION_BALANCE=1000000000
            HOUSE_TYPE="PUBLIC_1_SUI"
            ;;
        2)
            PRIVATE=false
            MIN_ACTIVATION_BALANCE=50000000000
            HOUSE_TYPE="PUBLIC_50_SUI"
            ;;
        3)
            PRIVATE=true
            MIN_ACTIVATION_BALANCE=10000000000
            HOUSE_TYPE="PRIVATE_10_SUI"
            ;;
        4)
            PRIVATE=true
            MIN_ACTIVATION_BALANCE=1000000000
            HOUSE_TYPE="PRIVATE_1_SUI"
            ;;
        *)
            print_error "Invalid parameter set: $set_num"
            show_parameter_sets
            exit 1
            ;;
    esac
}

# Function to save house creation output to files
save_house_output() {
    local env="$1"
    local timestamp="$2"
    local param_set="$3"
    local output_dir="outputs/$env"
    local base_filename="house_${param_set}_${timestamp}"
    
    # Create environment-specific directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Save env file with house id and admin cap id
    local env_file="$output_dir/${base_filename}.env"
    > "$env_file"
    echo "export OPENPLAY_HOUSE_ID=\"$HOUSE_ID\"" >> "$env_file"
    echo "export OPENPLAY_HOUSE_ADMIN_CAP_ID=\"$HOUSE_ADMIN_CAP_ID\"" >> "$env_file"
    print_success "House environment saved to $env_file"
}

if [ $# -ne 2 ]; then
    show_parameter_sets
    echo ""
    print_status "Usage: $0 <parameter_set_number> <recipient_address>"
    print_status "Example: $0 1 0xabc123..."
    exit 1
fi

PARAM_SET="$1"
RECIPIENT_ADDRESS="$2"

if [ -z "$RECIPIENT_ADDRESS" ]; then
    print_error "Recipient address is required"
    exit 1
fi

if [ ! -f "package/Move.toml" ]; then
    print_error "This script must be run from the openplay-core root directory"
    exit 1
fi

if ! command -v sui &> /dev/null; then
    print_error "sui client is not available. Please ensure Sui is installed and in your PATH."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    exit 1
fi

ACTIVE_ENV=$(get_active_env)
TIMESTAMP=$(get_timestamp)
print_status "Active environment: $ACTIVE_ENV"
print_status "Creation timestamp: $TIMESTAMP"

# Load core environment variables
if [ -f "outputs/$ACTIVE_ENV/latest.env" ]; then
    # shellcheck disable=SC1090
    source "outputs/$ACTIVE_ENV/latest.env"
    print_success "Loaded core package environment variables"
else
    print_error "Core package not deployed. Run ./scripts/core/deploy-core.sh first."
    exit 1
fi

# Check if package variables are loaded
if [ -z "$CURRENT_OPENPLAY_CORE_PACKAGE_ID" ] || [ -z "$OPENPLAY_CORE_REGISTRY_ID" ] || [ -z "$OPENPLAY_CORE_ADMIN_CAP" ]; then
    print_error "Required package variables not loaded. Ensure core package is deployed."
    exit 1
fi

CORE_PACKAGE_ID="$CURRENT_OPENPLAY_CORE_PACKAGE_ID"
REGISTRY_ID="$OPENPLAY_CORE_REGISTRY_ID"
ADMIN_CAP_ID="$OPENPLAY_CORE_ADMIN_CAP"

# Get parameter set
get_parameter_set "$PARAM_SET"

print_status "Creating house with parameter set $PARAM_SET ($HOUSE_TYPE)"
print_status "Parameters: Private=$PRIVATE, Min Activation=$MIN_ACTIVATION_BALANCE"
print_status "Recipient: $RECIPIENT_ADDRESS"

# Create the house
print_status "Creating house instance..."
HOUSE_OUTPUT=$(sui client ptb \
    --assign min_activation_balance $MIN_ACTIVATION_BALANCE \
    --move-call $CORE_PACKAGE_ID::house::openplay_admin_new_house @$ADMIN_CAP_ID $PRIVATE min_activation_balance 2000 \
    --assign createHouseOutput \
    --move-call $CORE_PACKAGE_ID::house::share @$REGISTRY_ID createHouseOutput.0 \
    --transfer-objects [createHouseOutput.1] @$RECIPIENT_ADDRESS \
    --json)

# Check if house creation was successful
if echo "$HOUSE_OUTPUT" | jq -e '.effects.status.status == "success"' > /dev/null; then
    print_success "House created successfully!"
else
    print_error "House creation failed!"
    echo "$HOUSE_OUTPUT" | jq '.effects.status'
    exit 1
fi

# Extract house ID (get first match only)
HOUSE_ID=$(echo "$HOUSE_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("::house::House"))) | .objectId' | head -n1)

if [ -z "$HOUSE_ID" ] || [ "$HOUSE_ID" = "null" ]; then
    print_error "Failed to extract house ID"
    exit 1
fi

# Extract house admin cap ID (check both created and transferred since it's transferred in the same transaction, get first match only)
HOUSE_ADMIN_CAP_ID=$(echo "$HOUSE_OUTPUT" | jq -r '.objectChanges[] | select((.type == "created" or .type == "transferred") and (.objectType | contains("::house::HouseAdminCap"))) | .objectId' | head -n1)

if [ -z "$HOUSE_ADMIN_CAP_ID" ] || [ "$HOUSE_ADMIN_CAP_ID" = "null" ]; then
    print_error "Failed to extract house admin cap ID"
    exit 1
fi

# Save outputs to files
save_house_output "$ACTIVE_ENV" "$TIMESTAMP" "$PARAM_SET"

# Print summary
echo ""
print_success "House creation completed successfully!"
echo ""
print_status "House Summary:"
echo "  House ID: $HOUSE_ID"
echo "  House Admin Cap ID: $HOUSE_ADMIN_CAP_ID"
echo "  Parameter Set: $PARAM_SET ($HOUSE_TYPE)"
echo "  Private: $PRIVATE"
echo "  Min Activation Balance: $MIN_ACTIVATION_BALANCE"
echo "  House Performance Fee: 20% (2000 bps)"
echo "  Admin Cap Recipient: $RECIPIENT_ADDRESS"
echo ""

