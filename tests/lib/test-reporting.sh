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

        print_color "$CYAN" "  📦 ZIP: $zip_file"

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
}

# Extract version from wp-release output
extract_version_from_output() {
    local output="$1"
    echo "$output" | grep -o "Version [0-9.]*" | head -1 | cut -d' ' -f2
}

# Extract ZIP file path from wp-release output
extract_zip_file_from_output() {
    local output="$1"
    echo "$output" | grep -o "Created release asset: .*\.zip" | head -1 | sed 's/Created release asset: //'
}

# Run the real production git release function against the sandbox project.
run_wp_release_sandbox() {
    local project_path="$1"

    cd "$project_path"

    local project_name
    project_name=$(basename "$(pwd)")

    local sandbox_bin="$SANDBOX_DIR/bin"

    # Run the actual production git_create_release_quiet in an isolated subshell.
    # Production libs are sourced here and external-service functions are overridden
    # so no network or GitHub activity occurs. set -e is active to match production.
    (
        set -e
        cd "$project_path"

        source "$sandbox_bin/lib/platform-utils.sh"
        source "$sandbox_bin/lib/general-functions.sh"
        source "$sandbox_bin/lib/git-functions.sh"
        source "$sandbox_bin/lib/wp-functions.sh"

        github_create_release() { return 0; }
        wp_plugin_update_pot() { return 0; }

        git_create_release_quiet "patch"
    )

    if [ $? -ne 0 ]; then
        echo "❌ git_create_release_quiet failed"
        cd - >/dev/null 2>&1
        return 1
    fi

    # Read the version that was written by git_create_release_quiet.
    local new_version
    new_version=$(jq -r '.version' package.json 2>/dev/null || echo "unknown")

    # Run build script if present (mirrors real wp_create_release -> build_for_production).
    local build_script=""
    if jq -e '.scripts.production' package.json >/dev/null 2>&1; then
        build_script="production"
    elif jq -e '.scripts.build' package.json >/dev/null 2>&1; then
        build_script="build"
    fi

    local package_manager
    package_manager=$(get_package_manager_for_project)

    if [ -n "$build_script" ]; then
        if [ "$package_manager" = "yarn" ]; then
            yarn --silent install --frozen-lockfile >/dev/null 2>&1 || true
        else
            npm --silent install >/dev/null 2>&1 || true
        fi
        "$package_manager" --silent run "$build_script" >/dev/null 2>&1 || true
    fi

    # Prune to production-only deps after building.
    if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
        local npm_prod_deps
        npm_prod_deps=$(jq '.dependencies | length' package.json 2>/dev/null || echo "0")
        if [ "$npm_prod_deps" -gt 0 ]; then
            if [ "$package_manager" = "yarn" ]; then
                yarn --silent install --production=true >/dev/null 2>&1 || true
            else
                npm --silent prune --omit=dev >/dev/null 2>&1 || true
            fi
        else
            rm -rf node_modules
        fi
    fi

    # Install composer production deps if applicable.
    if [ -f "composer.json" ] && command -v composer >/dev/null 2>&1; then
        local composer_prod_deps
        composer_prod_deps=$(jq '.require | length' composer.json 2>/dev/null || echo "0")
        local composer_php_only
        composer_php_only=$(jq '.require | keys | length == 1 and .[0] == "php"' composer.json 2>/dev/null || echo "false")
        if [ "$composer_prod_deps" -gt 0 ] && [ "$composer_php_only" != "true" ]; then
            composer install --no-dev --optimize-autoloader --quiet 2>/dev/null || true
        fi
    fi

    # Create ZIP with the same exclusion logic as the real release.
    local zip_dir
    zip_dir="$(get_cross_platform_temp_dir)/wp-build-tools-tests"
    mkdir -p "$zip_dir"
    local zip_file="${zip_dir}/${project_name}-${new_version}.zip"

    [ -f "$zip_file" ] && rm -f "$zip_file"

    local exclusions=($(get_zip_folder_exclusions))
    local sevenz_exclusions=($(get_7z_exclusions "${exclusions[@]}"))

    if command -v 7z >/dev/null 2>&1; then
        7z a "$zip_file" . "${sevenz_exclusions[@]}" >/dev/null 2>&1
    elif command -v zip >/dev/null 2>&1; then
        local zip_excludes=()
        for exclusion in "${exclusions[@]}"; do
            local clean="${exclusion#./}"
            zip_excludes+=("-x" "${clean}" "${clean}/*" "*/${clean}" "*/${clean}/*")
        done
        zip -r -q "$zip_file" . "${zip_excludes[@]}" >/dev/null 2>&1
    else
        local tar_exclusions=($(get_tar_exclusions "${exclusions[@]}"))
        tar -czf "${zip_file%.zip}.tar.gz" "${tar_exclusions[@]}" . >/dev/null 2>&1
        mv "${zip_file%.zip}.tar.gz" "$zip_file"
    fi

    echo "Simulated wp-release output:"
    echo "Version $new_version"
    echo "Created release asset: $zip_file"

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
