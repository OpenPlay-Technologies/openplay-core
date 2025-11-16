#!/bin/bash

# Print all latest OPENPLAY_* environment variables from outputs/<active-env>/

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

if [ ! -f "packages/openplay_core/Move.toml" ]; then
    print_error "This script must be run from the openplay-framework root directory"
    exit 1
fi

if ! command -v sui &> /dev/null; then
    print_error "sui client is not available. Please ensure Sui is installed and in your PATH."
    exit 1
fi

ACTIVE_ENV=$(get_active_env)
OUTPUT_DIR="outputs/$ACTIVE_ENV"

print_status "Active environment: $ACTIVE_ENV"

if [ ! -d "$OUTPUT_DIR" ]; then
    print_error "Output directory not found: $OUTPUT_DIR"
    exit 1
fi

# Collect candidate env files to source
declare -a candidate_files=(
    "$OUTPUT_DIR/latest.env"
    "$OUTPUT_DIR/latest_balance_manager.env"
    "$OUTPUT_DIR/latest_coin_flip.env"
    "$OUTPUT_DIR/latest_piggy_bank.env"
)

# Most recent play_cap_*.env if present
latest_play_cap_file=$(ls -t "$OUTPUT_DIR"/play_cap_*.env 2>/dev/null | head -n 1 || true)
if [ -n "${latest_play_cap_file:-}" ]; then
    candidate_files+=("$latest_play_cap_file")
fi

loaded_any=false
echo ""
print_status "Sourcing env files (if they exist):"
for f in "${candidate_files[@]}"; do
    if [ -f "$f" ]; then
        # shellcheck disable=SC1090
        source "$f"
        echo "  - $f"
        loaded_any=true
    fi
done

if [ "$loaded_any" = false ]; then
    print_warning "No env files found to load in $OUTPUT_DIR"
fi

echo ""
print_status "OPENPLAY_* variables (after sourcing):"
vars=$(env | grep '^OPENPLAY_' | sort || true)
if [ -z "$vars" ]; then
    print_warning "No OPENPLAY_* variables are currently set."
else
    echo "$vars"
    print_success "Printed $(echo "$vars" | wc -l | tr -d ' ') variables."
fi




