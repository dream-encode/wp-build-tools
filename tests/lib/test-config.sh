#!/bin/bash

# test-config.sh
# Configuration and project selection for wp-release testing

# Load configuration file
load_test_config() {
    local config_file="${BASH_SOURCE[0]%/*}/../config/test-config.conf"
    if [ -f "$config_file" ]; then
        # Source the config file, ignoring comments and empty lines
        while IFS= read -r line; do
            # Skip comments and empty lines
            if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// }" ]]; then
                # Export the variable
                export "$line"
            fi
        done < "$config_file"
    fi
}

# Load configuration when this file is sourced
load_test_config

# Get all available Max Marine projects for testing
get_all_test_projects() {
    # Check if FULL_MODE_PROJECTS is set in config
    if [ -n "$FULL_MODE_PROJECTS" ]; then
        # Use configured projects
        echo "$FULL_MODE_PROJECTS" | tr ' ' '\n'
    else
        # Use default full project list
        cat << 'EOF'
max-marine-alphabetized-brands-block
max-marine-background-processor
max-marine-block-data-store
max-marine-international-shipping-enhancements
max-marine-jpeg-quality
max-marine-block-theme-2025
EOF
    fi
}

# Get a subset of projects for quick testing
get_quick_test_projects() {
    # Check if QUICK_MODE_PROJECTS is set in config
    if [ -n "$QUICK_MODE_PROJECTS" ]; then
        # Use configured projects
        echo "$QUICK_MODE_PROJECTS" | tr ' ' '\n'
    else
        # Use default quick project list
        cat << 'EOF'
max-marine-alphabetized-brands-block
max-marine-brand-carousel-block
max-marine-popular-brands-block
max-marine-block-theme-2025
max-marine-background-processor
max-marine-performance-optimizations
EOF
    fi
}

# Get projects that are known to have specific features for targeted testing
get_block_plugins() {
    cat << 'EOF'
max-marine-alphabetized-brands-block
max-marine-brand-carousel-block
max-marine-brand-image-block
max-marine-popular-brands-block
EOF
}

get_standard_plugins() {
    cat << 'EOF'
max-marine-background-processor
max-marine-performance-optimizations
max-marine-custom-product-export
max-marine-data-migrations
EOF
}

get_themes() {
    cat << 'EOF'
max-marine-block-theme-2025
EOF
}

# Test configuration settings
get_test_config() {
    cat << 'EOF'
# Test Configuration for wp-release-test.sh

# Version bump type to test (patch, minor, major, hotfix)
TEST_VERSION_TYPE="patch"

# Whether to test build processes
TEST_BUILD_PROCESS=true

# Whether to test ZIP creation
TEST_ZIP_CREATION=true

# Whether to test version bumping
TEST_VERSION_BUMPING=true

# Whether to test changelog updates
TEST_CHANGELOG_UPDATES=true

# Whether to test exclusion compliance
TEST_EXCLUSIONS=true

# Whether to test WordPress-specific features
TEST_WP_FEATURES=true

# Timeout for individual tests (in seconds)
TEST_TIMEOUT=300

# Maximum number of parallel tests
MAX_PARALLEL_TESTS=3

# Whether to keep failed test artifacts
KEEP_FAILED_ARTIFACTS=true

# Test report format (text, json, both)
REPORT_FORMAT="both"
EOF
}

# Load test configuration
load_test_config() {
    # Set defaults
    TEST_VERSION_TYPE="patch"
    TEST_BUILD_PROCESS=true
    TEST_ZIP_CREATION=true
    TEST_VERSION_BUMPING=true
    TEST_CHANGELOG_UPDATES=true
    TEST_EXCLUSIONS=true
    TEST_WP_FEATURES=true
    TEST_TIMEOUT=300
    MAX_PARALLEL_TESTS=3
    KEEP_FAILED_ARTIFACTS=true
    REPORT_FORMAT="both"

    # Load from config file if it exists
    local config_file="$SCRIPT_DIR/config/test-config.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
}

# Get project type (plugin, theme, block-plugin)
get_project_type() {
    local project_path="$1"

    if [[ "$project_path" == *"/themes/"* ]]; then
        echo "theme"
        return 0
    fi

    if [[ "$project_path" == *"/plugins/"* ]]; then
        # Check if it's a block plugin
        if [ -d "$project_path/src" ] && find "$project_path" -name "block.json" -not -path "*/node_modules/*" -not -path "*/vendor/*" | grep -q .; then
            echo "block-plugin"
        else
            echo "plugin"
        fi
        return 0
    fi

    echo "unknown"
}

# Check if project has specific features
project_has_package_json() {
    local project_path="$1"
    [ -f "$project_path/package.json" ]
}

project_has_composer_json() {
    local project_path="$1"
    [ -f "$project_path/composer.json" ]
}

project_has_changelog() {
    local project_path="$1"
    [ -f "$project_path/CHANGELOG.md" ]
}

project_has_build_script() {
    local project_path="$1"
    if [ -f "$project_path/package.json" ] && command -v jq >/dev/null 2>&1; then
        jq -e '.scripts.build // .scripts.production' "$project_path/package.json" >/dev/null 2>&1
    else
        return 1
    fi
}

project_has_wp_build_exclusions() {
    local project_path="$1"
    [ -f "$project_path/.wp-build-exclusions" ]
}

# Get expected main file for project
get_project_main_file() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    local project_type=$(get_project_type "$project_path")

    case "$project_type" in
        "theme")
            echo "style.css"
            ;;
        "plugin"|"block-plugin")
            # Handle special case for warehouse operations plugin
            if [ "$project_name" = "max-marine-warehouse-operations-wp-plugin" ]; then
                echo "max-marine-electronics-warehouse-operations.php"
            else
                echo "$project_name.php"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get test categories for a project
get_project_test_categories() {
    local project_path="$1"
    local categories=()

    # Basic tests for all projects
    categories+=("structure")
    categories+=("version-detection")

    # Package.json tests
    if project_has_package_json "$project_path"; then
        categories+=("package-json")
    fi

    # Build tests
    if project_has_build_script "$project_path"; then
        categories+=("build-process")
    fi

    # Changelog tests
    if project_has_changelog "$project_path"; then
        categories+=("changelog")
    fi

    # WordPress-specific tests
    categories+=("wp-structure")
    categories+=("version-bumping")
    categories+=("zip-creation")

    # Exclusion tests
    if project_has_wp_build_exclusions "$project_path"; then
        categories+=("custom-exclusions")
    else
        categories+=("default-exclusions")
    fi

    printf '%s\n' "${categories[@]}"
}

# Check if project should be skipped
should_skip_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")

    # Skip if project doesn't exist
    if [ ! -d "$project_path" ]; then
        return 0  # Skip
    fi

    # Skip if no main file exists
    local main_file=$(get_project_main_file "$project_path")
    if [ -n "$main_file" ] && [ ! -f "$project_path/$main_file" ]; then
        return 0  # Skip
    fi

    # Skip if no package.json (required for version bumping)
    if ! project_has_package_json "$project_path"; then
        return 0  # Skip
    fi

    return 1  # Don't skip
}
