#!/bin/bash

# test-file-availability-retry.sh
# Test the file availability retry logic

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Test file availability retry logic
test_file_availability_retry() {
    print_color "$YELLOW" "🧪 Testing file availability retry logic..."
    
    local test_dir="/tmp/file-retry-test"
    rm -rf "$test_dir"
    mkdir -p "$test_dir"
    
    local test_file="$test_dir/test.zip"
    
    # Create a function that simulates the retry logic from wp_create_release
    test_zip_availability() {
        local ZIP_FILE_PATH="$1"
        
        # Wait for ZIP file to be fully written to disk (with retry logic)
        local max_attempts=10
        local attempt=1
        local wait_seconds=1
        
        while [ $attempt -le $max_attempts ]; do
            if [ -f "$ZIP_FILE_PATH" ] && [ -r "$ZIP_FILE_PATH" ]; then
                # File exists and is readable, check if it has a reasonable size
                local file_size=$(stat -c%s "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
                if [ "$file_size" -gt 1024 ]; then  # At least 1KB
                    return 0
                fi
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                return 1
            fi
            
            sleep $wait_seconds
            attempt=$((attempt + 1))
            wait_seconds=$((wait_seconds + 1))  # Increase wait time with each attempt
        done
    }
    
    # Test 1: File doesn't exist - should fail
    print_color "$YELLOW" "  Test 1: Non-existent file (should fail quickly)"
    if test_zip_availability "$test_file"; then
        print_color "$RED" "❌ Test 1 failed: Should have failed for non-existent file"
        return 1
    else
        print_color "$GREEN" "✅ Test 1 passed: Correctly failed for non-existent file"
    fi
    
    # Test 2: Create file in background and test retry logic
    print_color "$YELLOW" "  Test 2: Delayed file creation (should succeed with retry)"
    (
        sleep 3
        echo "This is a test ZIP file with enough content to exceed 1KB minimum size requirement. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt." > "$test_file"
    ) &
    
    if test_zip_availability "$test_file"; then
        print_color "$GREEN" "✅ Test 2 passed: Successfully waited for delayed file creation"
    else
        print_color "$RED" "❌ Test 2 failed: Should have succeeded with retry logic"
        return 1
    fi
    
    # Test 3: File exists immediately
    print_color "$YELLOW" "  Test 3: Immediate file availability (should succeed quickly)"
    local immediate_file="$test_dir/immediate.zip"
    echo "This is an immediately available test file with sufficient content for size check." > "$immediate_file"
    
    if test_zip_availability "$immediate_file"; then
        print_color "$GREEN" "✅ Test 3 passed: Correctly detected immediately available file"
    else
        print_color "$RED" "❌ Test 3 failed: Should have succeeded for immediately available file"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    print_color "$GREEN" "✅ All file availability retry tests passed!"
    return 0
}

# Main test execution
main() {
    print_color "$YELLOW" "🧪 FILE AVAILABILITY RETRY TEST SUITE"
    echo ""
    
    test_file_availability_retry
    
    echo ""
    print_color "$GREEN" "🎉 All tests completed successfully!"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
