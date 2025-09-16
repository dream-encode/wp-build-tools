#!/bin/bash

# test-release-asset-timing.sh
# Test the release asset creation timing and retry logic

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

# Simulate the retry logic from wp_create_release
test_file_retry_logic() {
    local ZIP_FILE_PATH="$1"
    
    print_color "$YELLOW" "🔍 Testing file retry logic for: $ZIP_FILE_PATH"
    
    # Verify ZIP file was actually created and wait for it to be available
    if [ -z "$ZIP_FILE_PATH" ]; then
        print_color "$RED" "❌ Error: ZIP file path is empty"
        return 1
    fi
    
    # Wait for ZIP file to be fully written to disk (with retry logic)
    local max_attempts=10
    local attempt=1
    local wait_seconds=1
    
    while [ $attempt -le $max_attempts ]; do
        print_color "$YELLOW" "  Attempt $attempt/$max_attempts (waiting ${wait_seconds}s)..."
        
        if [ -f "$ZIP_FILE_PATH" ] && [ -r "$ZIP_FILE_PATH" ]; then
            # File exists and is readable, check if it has a reasonable size
            # Use cross-platform method to get file size
            local file_size
            if command -v stat >/dev/null 2>&1; then
                file_size=$(stat -c%s "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
            else
                # Fallback for systems without stat
                file_size=$(wc -c < "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
            fi
            
            print_color "$GREEN" "  ✅ File found! Size: $file_size bytes"
            
            if [ "$file_size" -gt 1024 ]; then  # At least 1KB
                print_color "$GREEN" "✅ File is ready for upload!"
                return 0
            else
                print_color "$YELLOW" "  ⚠️  File too small ($file_size bytes), continuing..."
            fi
        else
            print_color "$YELLOW" "  ⏳ File not yet available..."
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_color "$RED" "❌ Error: ZIP file was not created or is not accessible after $max_attempts attempts"
            print_color "$RED" "   Expected path: $ZIP_FILE_PATH"
            return 1
        fi
        
        sleep $wait_seconds
        attempt=$((attempt + 1))
        wait_seconds=$((wait_seconds + 1))  # Increase wait time with each attempt
    done
}

# Test with actual ZIP creation
test_actual_zip_creation() {
    print_color "$YELLOW" "🧪 Testing actual ZIP creation and retry logic..."
    
    cd "$THEME_PATH"
    
    # Create ZIP in verbose mode to get the path
    print_color "$YELLOW" "📦 Creating ZIP in verbose mode..."
    local zip_output=$(wp_zip --for-git-updater 2>/dev/null | grep "📋 Zip:" | sed 's/📋 Zip: //')
    
    if [ -z "$zip_output" ]; then
        print_color "$RED" "❌ Could not extract ZIP path from verbose output"
        return 1
    fi
    
    print_color "$GREEN" "✅ ZIP created: $zip_output"
    
    # Test the retry logic
    test_file_retry_logic "$zip_output"
    
    return $?
}

# Main test execution
main() {
    print_color "$YELLOW" "🧪 RELEASE ASSET TIMING TEST"
    echo ""
    
    # Check if theme exists
    if [ ! -d "$THEME_PATH" ]; then
        print_color "$RED" "❌ Theme directory not found: $THEME_PATH"
        return 1
    fi
    
    test_actual_zip_creation
    
    echo ""
    print_color "$GREEN" "🎉 Test completed!"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
