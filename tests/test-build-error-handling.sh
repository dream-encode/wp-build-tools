#!/bin/bash

# test-build-error-handling.sh
# Test that build errors are properly caught and reported during wp_zip creation

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source required libraries
source "$PROJECT_ROOT/bin/lib/platform-utils.sh"
source "$PROJECT_ROOT/bin/lib/general-functions.sh"
source "$PROJECT_ROOT/bin/lib/wp-functions.sh"

# Test configuration
TEST_DIR="$PROJECT_ROOT/test-build-error-temp"
FAILED_TESTS=0
PASSED_TESTS=0

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

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    if [ "$result" = "PASS" ]; then
        print_color "$GREEN" "✅ $test_name: $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        print_color "$RED" "❌ $test_name: $message"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Setup test environment
setup_test_env() {
    print_color "$YELLOW" "🔧 Setting up test environment..."
    
    # Clean up any existing test directory
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Create a minimal package.json with a failing build script
    cat > package.json << 'EOF'
{
  "name": "test-build-error",
  "version": "1.0.0",
  "scripts": {
    "build": "exit 1"
  }
}
EOF
    
    # Create a minimal style.css for theme detection
    cat > style.css << 'EOF'
/*
Theme Name: Test Build Error Theme
Version: 1.0.0
*/
EOF
    
    print_color "$GREEN" "✅ Test environment created at: $TEST_DIR"
}

# Test build_for_production error handling
test_build_for_production_error_handling() {
    print_color "$YELLOW" "🧪 Testing build_for_production error handling..."
    
    cd "$TEST_DIR"
    
    # Test quiet mode error handling
    if build_for_production --quiet; then
        test_result "build_for_production_quiet" "FAIL" "Should have failed but returned success"
    else
        test_result "build_for_production_quiet" "PASS" "Properly caught build failure in quiet mode"
    fi
    
    # Test non-quiet mode error handling
    local build_output
    if build_output=$(build_for_production 2>&1); then
        test_result "build_for_production_verbose" "FAIL" "Should have failed but returned success"
    else
        if echo "$build_output" | grep -q "build failed"; then
            test_result "build_for_production_verbose" "PASS" "Properly caught and reported build failure"
        else
            test_result "build_for_production_verbose" "FAIL" "Failed but didn't show proper error message"
        fi
    fi
}

# Test wp_zip error handling
test_wp_zip_error_handling() {
    print_color "$YELLOW" "🧪 Testing wp_zip error handling..."
    
    cd "$TEST_DIR"
    
    # Create a fake wp-content/themes structure for theme detection
    mkdir -p wp-content/themes/test-theme
    cd wp-content/themes/test-theme
    
    # Copy our test files
    cp "$TEST_DIR/package.json" .
    cp "$TEST_DIR/style.css" .
    
    # Test wp_zip with failing build
    local zip_output
    if zip_output=$(wp_zip --for-git-updater --quiet 2>&1); then
        test_result "wp_zip_build_error" "FAIL" "wp_zip should have failed due to build error"
    else
        test_result "wp_zip_build_error" "PASS" "wp_zip properly failed when build failed"
    fi
}

# Cleanup test environment
cleanup_test_env() {
    print_color "$YELLOW" "🧹 Cleaning up test environment..."
    
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
        print_color "$GREEN" "✅ Test environment cleaned up"
    fi
}

# Main test execution
main() {
    print_color "$YELLOW" "🧪 BUILD ERROR HANDLING TEST SUITE"
    echo ""
    
    # Setup
    setup_test_env
    
    # Run tests
    test_build_for_production_error_handling
    test_wp_zip_error_handling
    
    # Cleanup
    cleanup_test_env
    
    # Report results
    echo ""
    print_color "$YELLOW" "📊 TEST RESULTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Total: $((PASSED_TESTS + FAILED_TESTS))"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_color "$GREEN" "🎉 All tests passed!"
        exit 0
    else
        print_color "$RED" "💥 Some tests failed!"
        exit 1
    fi
}

# Handle cleanup on script exit
trap cleanup_test_env EXIT

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
