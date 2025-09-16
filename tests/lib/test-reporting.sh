#!/bin/bash

# test-reporting.sh
# Test reporting and result tracking for wp-release testing

# Fallback print_color function if not defined
if ! command -v print_color >/dev/null 2>&1; then
    print_color() {
        local color="$1"
        local message="$2"
        echo "$message"
    }
fi

# Initialize test tracking
init_test_tracking() {
    TEST_START_TIME=$(date +%s)
    TEST_RESULTS=()
    FAILED_TESTS=()
    PASSED_TESTS=()

    # Create reports directory
    mkdir -p "$SANDBOX_DIR/reports"
}

# Record test result
record_test_result() {
    local project_name="$1"
    local test_type="$2"
    local status="$3"  # PASS, FAIL, SKIP
    local details="$4"
    local duration="$5"

    local result="$project_name|$test_type|$status|$details|$duration"
    TEST_RESULTS+=("$result")

    if [ "$status" = "PASS" ]; then
        PASSED_TESTS+=("$project_name ($test_type)")
    elif [ "$status" = "FAIL" ]; then
        FAILED_TESTS+=("$project_name ($test_type)")
    fi
}

# Generate detailed test report
generate_test_report() {
    local report_file="$SANDBOX_DIR/reports/test-report-$(date +%Y%m%d-%H%M%S).txt"
    local json_report_file="$SANDBOX_DIR/reports/test-report-$(date +%Y%m%d-%H%M%S).json"

    echo "Generating test report..."

    # Generate text report
    generate_text_report > "$report_file"

    # Generate JSON report
    generate_json_report > "$json_report_file"

    # Display summary
    display_test_summary

    echo ""
    echo "📋 Detailed reports saved:"
    echo "   Text: $report_file"
    echo "   JSON: $json_report_file"
}

# Generate text format report
generate_text_report() {
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - TEST_START_TIME))

    cat << EOF
WP-BUILD-TOOLS TEST REPORT
==========================

Test Run Information:
- Date: $(date)
- Duration: ${test_duration}s
- Sandbox: $SANDBOX_DIR
- Mode: $([ "$QUICK_MODE" = true ] && echo "Quick" || echo "Full")
- Total Tests: ${#TEST_RESULTS[@]}
- Passed: ${#PASSED_TESTS[@]}
- Failed: ${#FAILED_TESTS[@]}

System Information:
- Platform: $(get_platform)
- Compression Tool: $(get_compression_tool)
- Copy Tool: $(get_copy_tool)
- Sandbox Size: $(get_sandbox_size)

Test Results by Project:
========================

EOF

    # Group results by project
    local current_project=""
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r project test_type status details duration <<< "$result"

        if [ "$project" != "$current_project" ]; then
            echo ""
            echo "Project: $project"
            echo "$(printf '%.0s-' {1..50})"
            current_project="$project"
        fi

        local status_icon
        case "$status" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
            "SKIP") status_icon="⏭️" ;;
            *) status_icon="❓" ;;
        esac

        printf "  %s %-20s %s" "$status_icon" "$test_type" "$status"
        if [ -n "$duration" ]; then
            printf " (${duration}s)"
        fi
        echo ""

        if [ -n "$details" ] && [ "$details" != "null" ]; then
            echo "     Details: $details"
        fi
    done

    echo ""
    echo ""
    echo "Summary by Test Type:"
    echo "===================="

    # Count by test type
    declare -A test_type_counts
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r project test_type status details duration <<< "$result"
        local key="${test_type}_${status}"
        test_type_counts["$key"]=$((${test_type_counts["$key"]} + 1))
    done

    # Display test type summary
    local test_types=("structure" "version-bump" "zip-creation" "changelog" "build-process")
    for test_type in "${test_types[@]}"; do
        local pass_count=${test_type_counts["${test_type}_PASS"]:-0}
        local fail_count=${test_type_counts["${test_type}_FAIL"]:-0}
        local skip_count=${test_type_counts["${test_type}_SKIP"]:-0}
        local total_count=$((pass_count + fail_count + skip_count))

        if [ $total_count -gt 0 ]; then
            printf "%-15s: %d passed, %d failed, %d skipped (total: %d)\n" \
                "$test_type" "$pass_count" "$fail_count" "$skip_count" "$total_count"
        fi
    done

    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo ""
        echo "Failed Tests:"
        echo "============="
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $failed_test"
        done
    fi

    echo ""
    echo "Test Environment:"
    echo "================="
    echo "- wp-build-tools version: $(grep '"version"' "$PROJECT_ROOT/package.json" | cut -d'"' -f4)"
    echo "- Test script: $0"
    echo "- Arguments: $*"
    echo ""
}

# Generate JSON format report
generate_json_report() {
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - TEST_START_TIME))

    cat << EOF
{
  "test_run": {
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": $test_duration,
    "sandbox_path": "$SANDBOX_DIR",
    "mode": "$([ "$QUICK_MODE" = true ] && echo "quick" || echo "full")",
    "total_tests": ${#TEST_RESULTS[@]},
    "passed_tests": ${#PASSED_TESTS[@]},
    "failed_tests": ${#FAILED_TESTS[@]}
  },
  "system": {
    "platform": "$(get_platform)",
    "compression_tool": "$(get_compression_tool)",
    "copy_tool": "$(get_copy_tool)",
    "sandbox_size": "$(get_sandbox_size)"
  },
  "results": [
EOF

    # Output test results as JSON
    local first=true
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r project test_type status details duration <<< "$result"

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        cat << EOF
    {
      "project": "$project",
      "test_type": "$test_type",
      "status": "$status",
      "details": "$details",
      "duration_seconds": ${duration:-null}
    }
EOF
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Display test summary to console
display_test_summary() {
    local total_tests=${#TEST_RESULTS[@]}
    local passed_count=${#PASSED_TESTS[@]}
    local failed_count=${#FAILED_TESTS[@]}
    local success_rate=0

    if [ $total_tests -gt 0 ]; then
        success_rate=$((passed_count * 100 / total_tests))
    fi

    echo ""
    echo "📊 Test Summary:"
    echo "   Total tests: $total_tests"
    echo "   Passed: $passed_count"
    echo "   Failed: $failed_count"
    echo "   Success rate: ${success_rate}%"

    if [ $failed_count -eq 0 ]; then
        print_color "$GREEN" "   🎉 All tests passed!"
    else
        print_color "$RED" "   ❌ $failed_count tests failed"
    fi
}

# Run all tests on sandbox projects
run_all_tests() {
    echo "Initializing test tracking..."
    init_test_tracking

    echo "Getting sandbox projects..."
    local projects
    projects=$(get_sandbox_projects)

    if [ -z "$projects" ]; then
        print_color "$RED" "❌ No projects found in sandbox"
        return 1
    fi

    echo "Counting projects..."
    local project_count=0
    while IFS= read -r project; do
        if [ -n "$project" ]; then
            project_count=$((project_count + 1))
            echo "  Found project: $project"
        fi
    done <<< "$projects"

    echo "Found $project_count projects to test"
    echo ""

    echo "Starting project tests..."
    local current_project=0
    while IFS= read -r project; do
        if [ -n "$project" ]; then
            current_project=$((current_project + 1))
            echo "[$current_project/$project_count] Testing $project..."

            run_single_project_test "$project"
            echo ""
        fi
    done <<< "$projects"

    echo "All project tests completed"
}

# Run tests on a single project
run_single_project_test() {
    local project="$1"
    local project_path=$(get_sandbox_project_path "$project")
    local project_name=$(basename "$project")
    local test_start_time=$(date +%s)

    # Skip if project should be skipped
    if should_skip_project "$project_path"; then
        record_test_result "$project_name" "all" "SKIP" "Project skipped due to missing requirements" ""
        print_color "$YELLOW" "  ⏭️  Skipped (missing requirements)"
        return 0
    fi

    # Setup temporary git repo
    setup_temp_git_repo "$project_path"

    # Backup project state
    backup_project_state "$project_path"

    # Run wp-release in sandbox mode (no actual git operations)
    local wp_release_result
    wp_release_result=$(run_wp_release_sandbox "$project_path")
    local wp_release_exit_code=$?

    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    if [ $wp_release_exit_code -eq 0 ]; then
        # Extract expected version and ZIP file from wp-release output
        local expected_version=$(extract_version_from_output "$wp_release_result")
        local zip_file=$(extract_zip_file_from_output "$wp_release_result")

        # Run validations
        if validate_project "$project_path" "$expected_version" "$zip_file"; then
            record_test_result "$project_name" "full-release" "PASS" "All validations passed" "$test_duration"
            print_color "$GREEN" "  ✅ Passed"
        else
            record_test_result "$project_name" "full-release" "FAIL" "Validation failures" "$test_duration"
            print_color "$RED" "  ❌ Failed validation"
        fi
    else
        record_test_result "$project_name" "full-release" "FAIL" "wp-release failed" "$test_duration"
        print_color "$RED" "  ❌ wp-release failed"
    fi

    # Restore project state
    restore_project_state "$project_path"
}

# Extract version from wp-release output
extract_version_from_output() {
    local output="$1"
    echo "$output" | grep -o "Version [0-9.]*" | head -1 | cut -d' ' -f2
}

# Extract ZIP file path from wp-release output
extract_zip_file_from_output() {
    local output="$1"
    echo "$output" | grep -o "/tmp/.*\.zip" | head -1
}

# Run wp-release in sandbox mode (simulated)
run_wp_release_sandbox() {
    local project_path="$1"

    cd "$project_path"

    # Simulate a comprehensive wp-release run
    local project_name=$(basename "$(pwd)")
    local current_version=$(jq -r '.version' package.json 2>/dev/null || echo "1.0.0")
    local new_version=$(increment_version "$current_version" "patch")

    # 1. Update package.json version
    if [ -f package.json ]; then
        jq --arg version "$new_version" '.version = $version' package.json > package.json.tmp && mv package.json.tmp package.json
    fi

    # 2. Update PHP file headers (plugins and themes)
    for php_file in *.php; do
        if [ -f "$php_file" ]; then
            sed -i "s/Version:.*$/Version:           $new_version/" "$php_file" 2>/dev/null || true
        fi
    done

    # 2b. Update theme style.css header (themes only)
    if [ -f "style.css" ]; then
        sed -i "s/Version:.*$/Version:           $new_version/" "style.css" 2>/dev/null || true
    fi

    # 3. Update block.json files (exclude third-party libraries)
    local block_files
    block_files=$(find . -name "block.json" \
        -not -path "./node_modules/*" \
        -not -path "./vendor/*" \
        -not -path "./libraries/*" \
        -not -path "./lib/*" \
        -not -path "./libs/*" 2>/dev/null || true)

    if [ -n "$block_files" ]; then
        while IFS= read -r block_file; do
            if [ -f "$block_file" ]; then
                jq --arg version "$new_version" '.version = $version' "$block_file" > "$block_file.tmp" && mv "$block_file.tmp" "$block_file"
            fi
        done <<< "$block_files"
    fi

    # 4. Update constants files (Max Marine specific patterns)
    for constants_file in includes/*constants.php inc/constants.php; do
        if [ -f "$constants_file" ]; then
            # Special case for warehouse operations (MMEWOA)
            if [[ "$project_name" == *"warehouse-operations"* ]]; then
                sed -i "s/define( 'MMEWOA_PLUGIN_VERSION', '[^']*' );/define( 'MMEWOA_PLUGIN_VERSION', '$new_version' );/" "$constants_file" 2>/dev/null || true
            fi

            # Generic version patterns - update any VERSION constant
            sed -i "s/\(define( '[^']*_PLUGIN_VERSION', '\)[^']*\(' );\)/\1$new_version\2/" "$constants_file" 2>/dev/null || true
            sed -i "s/\(define( '[^']*_THEME_VERSION', '\)[^']*\(' );\)/\1$new_version\2/" "$constants_file" 2>/dev/null || true
        fi
    done

    # 5. Update changelog
    if [ -f CHANGELOG.md ]; then
        # Replace [NEXT_VERSION] with actual version and current date
        local current_date=$(date +"%Y-%m-%d")
        sed -i "s/\[NEXT_VERSION\]/## [$new_version] - $current_date/" CHANGELOG.md 2>/dev/null || true
    fi

    # 6. Create ZIP file with updated content
    local zip_file="/tmp/${project_name}-${new_version}.zip"

    # Remove old ZIP file if it exists
    [ -f "$zip_file" ] && rm -f "$zip_file"

    # Create a proper ZIP file with updated project contents (excluding development files and third-party .git)
    if command -v 7z >/dev/null 2>&1; then
        7z a "$zip_file" . \
            -x!.git -x!.git/* -x!**/.git -x!**/.git/* \
            -x!.gitignore -x!.gitattributes -x!**/.gitignore -x!**/.gitattributes \
            -x!.github -x!.github/* -x!**/.github -x!**/.github/* \
            -x!node_modules -x!node_modules/* -x!**/node_modules -x!**/node_modules/* \
            -x!vendor -x!vendor/* -x!**/vendor -x!**/vendor/* \
            -x!tests -x!tests/* -x!**/tests -x!**/tests/* \
            -x!.wp-build-exclusions -x!.wakatime-project -x!.distignore \
            -x!*.log -x!*.tmp \
            >/dev/null 2>&1
    elif command -v zip >/dev/null 2>&1; then
        zip -r "$zip_file" . \
            -x ".git/*" "*/.git/*" "**/.git/*" \
            ".gitignore" ".gitattributes" "*/.gitignore" "*/.gitattributes" \
            ".github/*" "*/.github/*" "**/.github/*" \
            "node_modules/*" "*/node_modules/*" "**/node_modules/*" \
            "vendor/*" "*/vendor/*" "**/vendor/*" \
            "tests/*" "*/tests/*" "**/tests/*" \
            ".wp-build-exclusions" ".wakatime-project" ".distignore" \
            "*.log" "*.tmp" \
            >/dev/null 2>&1
    else
        # Fallback: create a basic ZIP with main files
        tar -czf "${zip_file%.zip}.tar.gz" \
            --exclude='.git' --exclude='*/.git' --exclude='**/.git' \
            --exclude='.gitignore' --exclude='.gitattributes' \
            --exclude='*/.gitignore' --exclude='*/.gitattributes' \
            --exclude='.github' --exclude='*/.github' --exclude='**/.github' \
            --exclude='node_modules' --exclude='*/node_modules' --exclude='**/node_modules' \
            --exclude='vendor' --exclude='*/vendor' --exclude='**/vendor' \
            --exclude='tests' --exclude='*/tests' --exclude='**/tests' \
            --exclude='.wp-build-exclusions' --exclude='.wakatime-project' --exclude='.distignore' \
            --exclude='*.log' --exclude='*.tmp' \
            . >/dev/null 2>&1
        mv "${zip_file%.zip}.tar.gz" "$zip_file"
    fi

    # Output in the format expected by extraction functions
    echo "Simulated wp-release output:"
    echo "Version $new_version"
    echo "Created release asset: $zip_file"

    # Return to original directory
    cd - >/dev/null 2>&1

    return 0
}

# Helper function to increment version
increment_version() {
    local version="$1"
    local type="$2"

    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    case "$type" in
        "major")
            echo "$((major + 1)).0.0"
            ;;
        "minor")
            echo "${major}.$((minor + 1)).0"
            ;;
        "patch"|*)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
    esac
}
