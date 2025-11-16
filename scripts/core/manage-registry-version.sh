#!/bin/bash

# Manage Registry Version Allow/Disallow
# This script allows or disallows a specific version in the OpenPlay Core Registry

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

# Function to get active environment
get_active_env() {
    sui client active-env 2>/dev/null || echo "unknown"
}

# Function to show usage
show_usage() {
    echo ""
    echo "Usage: $0 <action> <version>"
    echo ""
    echo "Arguments:"
    echo "  action    - 'allow' or 'disallow'"
    echo "  version   - Version number (u64) to allow or disallow"
    echo ""
    echo "Examples:"
    echo "  $0 allow 2"
    echo "  $0 disallow 1"
    echo ""
}

# Check if we're in the right directory
if [ ! -f "packages/openplay_core/Move.toml" ]; then
    print_error "This script must be run from the openplay-framework root directory"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    exit 1
fi

# Check if sui client is available
if ! command -v sui &> /dev/null; then
    print_error "sui client is not available. Please ensure Sui is installed and in your PATH."
    exit 1
fi

# Validate arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    show_usage
    exit 1
fi

ACTION="$1"
VERSION="$2"

# Validate action
if [ "$ACTION" != "allow" ] && [ "$ACTION" != "disallow" ]; then
    print_error "Invalid action: $ACTION"
    print_error "Action must be either 'allow' or 'disallow'"
    show_usage
    exit 1
fi

# Validate version is a positive integer
if ! [[ "$VERSION" =~ ^[0-9]+$ ]] || [ "$VERSION" -le 0 ]; then
    print_error "Version must be a positive integer"
    exit 1
fi

# Get active environment
ACTIVE_ENV=$(get_active_env)

print_status "Active environment: $ACTIVE_ENV"
print_status "Action: $ACTION"
print_status "Version: $VERSION"

# Load latest state to get registry and admin cap
if [ -f "outputs/$ACTIVE_ENV/latest.env" ]; then
    print_status "Loading latest deployment state..."
    source "outputs/$ACTIVE_ENV/latest.env"
    print_success "Loaded core package environment variables"
else
    print_error "Core package not deployed. Run ./scripts/deploy-core.sh first."
    exit 1
fi

# Validate that we have the required variables
if [ -z "$CURRENT_OPENPLAY_CORE_PACKAGE_ID" ] || [ "$CURRENT_OPENPLAY_CORE_PACKAGE_ID" = "null" ]; then
    print_error "Core package ID not found. Cannot proceed."
    exit 1
fi

if [ -z "$OPENPLAY_CORE_REGISTRY_ID" ] || [ "$OPENPLAY_CORE_REGISTRY_ID" = "null" ]; then
    print_error "Registry ID not found. Cannot proceed."
    exit 1
fi

if [ -z "$OPENPLAY_CORE_ADMIN_CAP" ] || [ "$OPENPLAY_CORE_ADMIN_CAP" = "null" ]; then
    print_error "Admin cap not found. Cannot proceed."
    exit 1
fi

# Set package variables for convenience
CORE_PACKAGE_ID="$CURRENT_OPENPLAY_CORE_PACKAGE_ID"
REGISTRY_ID="$OPENPLAY_CORE_REGISTRY_ID"
ADMIN_CAP="$OPENPLAY_CORE_ADMIN_CAP"

print_status "Using Core Package: $CORE_PACKAGE_ID"
print_status "Using Registry: $REGISTRY_ID"
print_status "Using Admin Cap: $ADMIN_CAP"

# Determine the function to call based on action
if [ "$ACTION" = "allow" ]; then
    FUNCTION_NAME="admin_allow_version"
    ACTION_DESCRIPTION="allowing"
    ACTION_DESCRIPTION_CAP="Allowing"
else
    FUNCTION_NAME="admin_disallow_version"
    ACTION_DESCRIPTION="disallowing"
    ACTION_DESCRIPTION_CAP="Disallowing"
fi

print_status "$ACTION_DESCRIPTION_CAP version $VERSION in registry..."

# Call the appropriate function
TRANSACTION_OUTPUT=$(sui client ptb \
    --move-call "$CORE_PACKAGE_ID::registry::$FUNCTION_NAME" @$REGISTRY_ID @$ADMIN_CAP $VERSION \
    --json)

# Check if transaction was successful
if echo "$TRANSACTION_OUTPUT" | jq -e '.effects.status.status == "success"' > /dev/null; then
    print_success "Version $VERSION ${ACTION}ed successfully!"
else
    print_error "Failed to $ACTION version $VERSION"
    echo "$TRANSACTION_OUTPUT" | jq '.effects.status'
    exit 1
fi

# Print summary
echo ""
print_success "Registry version management completed successfully!"
echo ""
print_status "Summary:"
echo "  Action: $ACTION"
echo "  Version: $VERSION"
echo "  Registry ID: $REGISTRY_ID"
echo "  Core Package ID: $CORE_PACKAGE_ID"
echo ""

