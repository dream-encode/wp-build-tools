#!/bin/bash

# test-block-theme-zip.sh
# Test wp_zip functionality specifically on the max-marine-block-theme-2025

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

# Test wp_zip on the actual block theme
test_block_theme_zip() {
    print_color "$YELLOW" "🧪 Testing wp_zip on max-marine-block-theme-2025..."
    
    # Check if theme exists
    if [ ! -d "$THEME_PATH" ]; then
        print_color "$RED" "❌ Theme directory not found: $THEME_PATH"
        return 1
    fi
    
    cd "$THEME_PATH"
    print_color "$GREEN" "✅ Changed to theme directory: $(pwd)"
    
    # Check package.json
    if [ ! -f "package.json" ]; then
        print_color "$RED" "❌ package.json not found"
        return 1
    fi
    
    print_color "$GREEN" "✅ package.json found"
    
    # Show current version
    local current_version=$(jq -r '.version' package.json 2>/dev/null || echo "unknown")
    print_color "$YELLOW" "📋 Current version: $current_version"
    
    # Test wp_zip in verbose mode first
    print_color "$YELLOW" "🔧 Testing wp_zip in verbose mode..."
    echo ""
    
    local zip_output
    local zip_exit_code
    
    if zip_output=$(wp_zip --for-git-updater 2>&1); then
        zip_exit_code=0
        print_color "$GREEN" "✅ wp_zip verbose mode succeeded"
        echo "Output: $zip_output"
    else
        zip_exit_code=$?
        print_color "$RED" "❌ wp_zip verbose mode failed (exit code: $zip_exit_code)"
        echo "Output: $zip_output"
        return 1
    fi
    
    echo ""
    print_color "$YELLOW" "🔧 Testing wp_zip in quiet mode..."
    
    if zip_output=$(wp_zip --for-git-updater --quiet 2>&1); then
        zip_exit_code=0
        print_color "$GREEN" "✅ wp_zip quiet mode succeeded"
        echo "ZIP file path: $zip_output"
        
        # Check if the ZIP file actually exists
        if [ -f "$zip_output" ]; then
            print_color "$GREEN" "✅ ZIP file exists at: $zip_output"
            local zip_size=$(stat -c%s "$zip_output" 2>/dev/null || echo "unknown")
            print_color "$YELLOW" "📋 ZIP file size: $zip_size bytes"
        else
            print_color "$RED" "❌ ZIP file does not exist at: $zip_output"
            return 1
        fi
    else
        zip_exit_code=$?
        print_color "$RED" "❌ wp_zip quiet mode failed (exit code: $zip_exit_code)"
        echo "Output: $zip_output"
        return 1
    fi
}

# Test build_for_production directly
test_build_for_production() {
    print_color "$YELLOW" "🧪 Testing build_for_production on max-marine-block-theme-2025..."
    
    cd "$THEME_PATH"
    
    # Test in verbose mode
    print_color "$YELLOW" "🔧 Testing build_for_production in verbose mode..."
    if build_for_production; then
        print_color "$GREEN" "✅ build_for_production verbose mode succeeded"
    else
        print_color "$RED" "❌ build_for_production verbose mode failed"
        return 1
    fi
    
    echo ""
    print_color "$YELLOW" "🔧 Testing build_for_production in quiet mode..."
    if build_for_production --quiet; then
        print_color "$GREEN" "✅ build_for_production quiet mode succeeded"
    else
        print_color "$RED" "❌ build_for_production quiet mode failed"
        return 1
    fi
}

# Main test execution
main() {
    print_color "$YELLOW" "🧪 BLOCK THEME ZIP CREATION TEST"
    echo ""
    
    # Test build process first
    test_build_for_production
    
    echo ""
    
    # Test ZIP creation
    test_block_theme_zip
    
    echo ""
    print_color "$GREEN" "🎉 All tests completed!"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
