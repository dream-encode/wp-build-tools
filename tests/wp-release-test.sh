#!/bin/bash

# wp-release-test.sh
# Comprehensive test suite for wp-build-tools wp-release functionality
# Tests wp-release on Max Marine plugins/themes in a sandbox environment

set -e  # Exit on any error

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SANDBOX_DIR="$PROJECT_ROOT/wp-build-tools-tests"
MAX_MARINE_SOURCE="F:/MaxMarineAssets/Code/wp-content"

# Source required libraries
source "$PROJECT_ROOT/bin/lib/platform-utils.sh"
source "$PROJECT_ROOT/bin/lib/tool-checker.sh"
source "$SCRIPT_DIR/lib/test-sandbox.sh"
source "$SCRIPT_DIR/lib/test-validation.sh"
source "$SCRIPT_DIR/lib/test-config.sh"
source "$SCRIPT_DIR/lib/test-reporting.sh"

# Test configuration
QUICK_MODE=false
CLEANUP_ONLY=false
KEEP_SANDBOX=false
VERBOSE=false

# Test results tracking
declare -a TEST_RESULTS=()
declare -a FAILED_TESTS=()
declare -a PASSED_TESTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print section header
print_header() {
    echo ""
    print_color "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$CYAN" "$1"
    print_color "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Show help
show_help() {
    cat << EOF
wp-release-test.sh - Test Suite for wp-build-tools

USAGE
    bash tests/wp-release-test.sh [OPTIONS]

DESCRIPTION
    Comprehensive test suite that validates wp-release functionality by:
    1. Creating a sandbox environment (wp-build-tools-tests)
    2. Copying Max Marine plugins/themes to the sandbox
    3. Running wp-release in dry-run mode on each project
    4. Validating version bumps, ZIP contents, changelog updates, etc.
    5. Generating detailed test reports

OPTIONS
    --quick             Run tests on a subset of projects (faster)
    --cleanup-only      Only clean up existing sandbox and exit
    --keep-sandbox      Don't delete sandbox after tests (for debugging)
    --verbose           Show detailed output during tests
    --help, -h          Show this help message

EXAMPLES
    npm test                    # Run full test suite
    npm run test:quick          # Run quick test subset
    npm run test:cleanup        # Clean up test sandbox

REQUIREMENTS
    • All wp-release requirements (git, jq, gh, compression tools)
    • Access to F:/MaxMarineAssets/Code/wp-content
    • Sufficient disk space for sandbox (several GB)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --cleanup-only)
            CLEANUP_ONLY=true
            shift
            ;;
        --keep-sandbox)
            KEEP_SANDBOX=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown option '$1'"
            echo "Use 'bash tests/wp-release-test.sh --help' for usage information"
            exit 1
            ;;
    esac
done

# Handle cleanup-only mode
if [ "$CLEANUP_ONLY" = true ]; then
    print_header "🧹 CLEANUP MODE"
    cleanup_sandbox
    print_color "$GREEN" "✅ Cleanup complete!"
    exit 0
fi

# Main test execution
main() {
    print_header "🧪 WP-BUILD-TOOLS TEST SUITE"

    echo "Starting comprehensive wp-release testing..."
    echo "Sandbox: $SANDBOX_DIR"
    echo "Source: $MAX_MARINE_SOURCE"
    echo "Quick mode: $QUICK_MODE"
    echo "Keep sandbox: $KEEP_SANDBOX"

    # Step 1: Prerequisites check
    print_header "1️⃣  PREREQUISITES CHECK"
    check_prerequisites

    # Step 2: Setup sandbox
    print_header "2️⃣  SANDBOX SETUP"
    setup_sandbox

    # Step 3: Copy test projects
    print_header "3️⃣  PROJECT PREPARATION"
    copy_test_projects

    # Step 4: Run tests
    print_header "4️⃣  RUNNING TESTS"
    run_all_tests

    # Step 5: Generate report
    print_header "5️⃣  TEST RESULTS"
    generate_test_report

    # Step 6: Cleanup (unless keeping sandbox)
    if [ "$KEEP_SANDBOX" != true ]; then
        print_header "6️⃣ CLEANUP"
        cleanup_sandbox
    else
        print_color "$YELLOW" "⚠️  Keeping sandbox for debugging: $SANDBOX_DIR"
    fi

    # Final summary
    print_header "🎯 FINAL SUMMARY"
    show_final_summary
}

# Check prerequisites
check_prerequisites() {
    echo "Checking system requirements..."

    # Check basic tools needed for testing (skip GitHub CLI check since we're in dry-run mode)
    local missing_tools=()

    # Check essential tools for testing
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi

    if ! command -v git >/dev/null 2>&1; then
        missing_tools+=("git")
    fi

    # Check for at least one compression tool
    if ! command -v 7z >/dev/null 2>&1 && ! command -v zip >/dev/null 2>&1 && ! command -v tar >/dev/null 2>&1; then
        missing_tools+=("compression tool (7z, zip, or tar)")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_color "$RED" "❌ Missing required tools for testing:"
        for tool in "${missing_tools[@]}"; do
            echo "  • $tool"
        done
        exit 1
    fi

    # Check if Max Marine source exists
    if [ ! -d "$MAX_MARINE_SOURCE" ]; then
        print_color "$RED" "❌ Max Marine source directory not found: $MAX_MARINE_SOURCE"
        exit 1
    fi

    # Check disk space (rough estimate)
    local available_space
    if command -v df >/dev/null 2>&1; then
        available_space=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
        if [ "$available_space" -lt 5000000 ]; then  # 5GB in KB
            print_color "$YELLOW" "⚠️  Warning: Low disk space. Tests may require several GB."
        fi
    fi

    print_color "$GREEN" "✅ Prerequisites check passed"
}

# Show final summary
show_final_summary() {
    local total_tests=${#TEST_RESULTS[@]}
    local passed_count=${#PASSED_TESTS[@]}
    local failed_count=${#FAILED_TESTS[@]}

    echo "Total tests run: $total_tests"
    echo "Passed: $passed_count"
    echo "Failed: $failed_count"

    if [ $failed_count -eq 0 ]; then
        print_color "$GREEN" "🎉 ALL TESTS PASSED!"
        print_color "$GREEN" "wp-build-tools is ready for release!"
        exit 0
    else
        print_color "$RED" "❌ $failed_count TESTS FAILED"
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            print_color "$RED" "  • $test"
        done
        echo ""
        print_color "$YELLOW" "💡 Check the detailed test report above for more information"
        exit 1
    fi
}

# Execute main function
main
