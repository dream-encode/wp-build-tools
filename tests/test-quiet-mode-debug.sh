#!/bin/bash

# test-quiet-mode-debug.sh
# Debug quiet mode issues with wp_zip

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
THEME_PATH="F:/MaxMarineAssets/Code/wp-content/themes/max-marine-block-theme-2025"

# Source required libraries
source "$PROJECT_ROOT/bin/lib/platform-utils.sh"
source "$PROJECT_ROOT/bin/lib/general-functions.sh"
source "$PROJECT_ROOT/bin/lib/wp-functions.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Test build_for_production in quiet mode
test_build_for_production_quiet() {
    print_color "$YELLOW" "🧪 Testing build_for_production in quiet mode..."
    
    cd "$THEME_PATH"
    
    # Create a temp directory for testing
    local temp_dir="/tmp/debug-build-test"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    # Copy files to temp directory
    print_color "$YELLOW" "📁 Copying files to temp directory..."
    copy_folder "$THEME_PATH" "$temp_dir" --quiet
    
    cd "$temp_dir"
    print_color "$GREEN" "✅ Changed to temp directory: $(pwd)"
    
    # Test build_for_production in quiet mode
    print_color "$YELLOW" "🔧 Running build_for_production --quiet..."
    
    if build_for_production --quiet; then
        print_color "$GREEN" "✅ build_for_production --quiet succeeded"
        return 0
    else
        local exit_code=$?
        print_color "$RED" "❌ build_for_production --quiet failed (exit code: $exit_code)"
        return $exit_code
    fi
}

# Main test execution
main() {
    print_color "$YELLOW" "🧪 QUIET MODE DEBUG TEST"
    echo ""
    
    # Check if theme exists
    if [ ! -d "$THEME_PATH" ]; then
        print_color "$RED" "❌ Theme directory not found: $THEME_PATH"
        return 1
    fi
    
    # Test build_for_production in quiet mode
    test_build_for_production_quiet
    
    echo ""
    print_color "$GREEN" "🎉 Test completed!"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
