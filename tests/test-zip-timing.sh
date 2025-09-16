#!/bin/bash

# test-zip-timing.sh
# Test ZIP creation timing and file availability

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

# Test ZIP creation and immediate availability
test_zip_timing() {
    print_color "$YELLOW" "🧪 Testing ZIP creation timing..."
    
    cd "$THEME_PATH"
    
    print_color "$YELLOW" "📦 Creating ZIP with wp_zip..."
    local start_time=$(date +%s)
    
    # Create ZIP and capture the path
    local ZIP_FILE_PATH=$(wp_zip --for-git-updater --quiet)
    local zip_exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_color "$GREEN" "✅ wp_zip completed in ${duration}s (exit code: $zip_exit_code)"
    print_color "$YELLOW" "📁 ZIP path: $ZIP_FILE_PATH"
    
    if [ $zip_exit_code -ne 0 ]; then
        print_color "$RED" "❌ wp_zip failed with exit code $zip_exit_code"
        return 1
    fi
    
    if [ -z "$ZIP_FILE_PATH" ]; then
        print_color "$RED" "❌ ZIP path is empty"
        return 1
    fi
    
    # Test immediate availability
    print_color "$YELLOW" "🔍 Testing immediate file availability..."
    
    local check_start=$(date +%s)
    if [ -f "$ZIP_FILE_PATH" ]; then
        local check_end=$(date +%s)
        local check_duration=$((check_end - check_start))
        print_color "$GREEN" "✅ File exists immediately (checked in ${check_duration}s)"
        
        # Check file size
        local file_size
        if command -v stat >/dev/null 2>&1; then
            file_size=$(stat -c%s "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
        else
            file_size=$(wc -c < "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
        fi
        
        print_color "$GREEN" "✅ File size: $file_size bytes"
        
        if [ "$file_size" -gt 1024 ]; then
            print_color "$GREEN" "✅ File size is reasonable (>1KB)"
        else
            print_color "$RED" "❌ File size is too small ($file_size bytes)"
            return 1
        fi
        
        # Test readability
        if [ -r "$ZIP_FILE_PATH" ]; then
            print_color "$GREEN" "✅ File is readable"
        else
            print_color "$RED" "❌ File is not readable"
            return 1
        fi
        
    else
        print_color "$RED" "❌ File does not exist immediately after wp_zip completion"
        
        # Try waiting a bit
        print_color "$YELLOW" "⏳ Waiting 5 seconds and checking again..."
        sleep 5
        
        if [ -f "$ZIP_FILE_PATH" ]; then
            print_color "$YELLOW" "⚠️  File appeared after 5 second delay"
        else
            print_color "$RED" "❌ File still does not exist after 5 second delay"
            return 1
        fi
    fi
    
    print_color "$GREEN" "✅ ZIP timing test completed successfully!"
    return 0
}

# Main test execution
main() {
    print_color "$YELLOW" "🧪 ZIP TIMING TEST"
    echo ""
    
    # Check if theme exists
    if [ ! -d "$THEME_PATH" ]; then
        print_color "$RED" "❌ Theme directory not found: $THEME_PATH"
        return 1
    fi
    
    test_zip_timing
    
    echo ""
    print_color "$GREEN" "🎉 Test completed!"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
