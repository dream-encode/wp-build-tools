#!/bin/bash

# WordPress-specific utility functions for release script

# Source platform utilities if not already loaded
if ! command -v get_platform >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/platform-utils.sh"
fi
# Copied from wp.bashrc
function wp_check_debugging_code() {
    local quiet_mode="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode="true"
                shift
                ;;
            --for-git-updater|--for-install)
                zip_type_param="$1"
                shift
                ;;
            *)
                if [ -z "$zip_type_param" ]; then
                    zip_type_param="$1"
                else
                    echo "❌ Error: Unknown argument '$1' for wp_zip"
                    echo "Usage: wp_zip [--for-git-updater|--for-install] [--quiet]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ "$quiet_mode" != "true" ]; then
        echo "Checking for debugging code..."
    fi

    # Define debugging patterns to search for
    local debug_patterns=(
        "[[:space:]]ray("
        "[[:space:]]var_dump("
        "[[:space:]]error_log("
    )

    local debug_names=(
        "Ray logging"
        "var_dump calls"
        "error_log calls"
    )

    local total_count=0
    local found_issues=false

    # Check each debugging pattern
    for i in "${!debug_patterns[@]}"; do
        local pattern="${debug_patterns[$i]}"
        local name="${debug_names[$i]}"

        local count=$(grep -ro --exclude-dir={.git,node_modules,vendor,tests,action-scheduler,libraries} --exclude=*wc-logger.php "$pattern" . | wc -l)

        if [ "$count" -gt 0 ]; then
            if [ "$found_issues" = false ]; then
                echo "❌"
                echo ""
                echo "Found debugging code in the following files:"
                found_issues=true
            fi
            echo ""
            echo "=== $name ($count occurrences) ==="
            grep -rn --exclude-dir={.git,node_modules,vendor,tests,action-scheduler,libraries} --exclude=*wc-logger.php "$pattern" .
            total_count=$((total_count + count))
        fi
    done

    if [ "$total_count" -lt 1 ]; then
        return 0
    fi

    echo ""
    echo "Total debugging statements found: $total_count"
    return 1
}

# Returns the WordPress root directory by walking up from the given path (or $PWD)
function wp_find_wp_root() {
    local dir="${1:-$(pwd)}"
    while true; do
        if [ -f "$dir/wp-config.php" ]; then
            echo "$dir"
            return 0
        fi
        local parent
        parent="$(dirname "$dir")"
        if [ "$parent" = "$dir" ] || [ -z "$parent" ]; then
            break
        fi
        dir="$parent"
    done
    return 1
}

# Update POT file for WordPress plugins and themes
function wp_plugin_update_pot() {
    local PLUGIN_NAME="$(basename $PWD)"

    if ! command -v wp >/dev/null 2>&1; then
        echo "Warning: WP-CLI not found. Skipping POT file update."
        return 0
    fi

    wp i18n make-pot . languages/$PLUGIN_NAME.pot --exclude=tests,dist/js
}

function is_wp_block_plugin() {
    if [ -d "src" ] && [ -f "package.json" ]; then
        if find . -name "block.json" -not -path "./node_modules/*" -not -path "./vendor/*" | grep -q .; then
            return 0
        fi
    fi

    return 1
}

# Check if this project contains blocks (plugin or theme)
function has_wp_blocks() {
    if find . -name "block.json" -not -path "./node_modules/*" -not -path "./vendor/*" | grep -q .; then
        return 0
    fi

    return 1
}

function wp_plugin_has_release_asset() {
    local MAIN_FILE=""
    local PLUGIN_NAME="$(wp_get_plugin_name)"

    # Determine the main file based on project type
    if is_wp_theme_dir; then
        MAIN_FILE="style.css"
    else
        # Plugin logic
        MAIN_FILE="$(wp_plugin_filename)"
    fi

    if [ ! -f "$MAIN_FILE" ]; then
        return 1
    fi

    if grep -q "Release Asset:.*true" "$MAIN_FILE"; then
        return 0
    fi

    return 1
}

# Update plugin via Git Remote Updater (simplified version)
function wp_update_plugin_via_git_remote_updater() {
    echo "Git Remote Updater functionality would be implemented here."
    echo "This requires site-specific configuration and API keys."
    echo "Skipping remote update for now."
}

# Read the first 8KB of a file, as WordPress does, and look for a header field.
function wp_file_has_header() {
    local file="$1"
    local header="$2"

    [ -f "$file" ] || return 1

    head -c 8192 "$file" | grep -qiE "^[[:space:]/*#@]*${header}:"
}

# Check if this is a WordPress plugin directory.
# Matches a standard wp-content path, or a main plugin file with a "Plugin Name" header
# so custom content directories such as content/plugins also work.
function is_wp_plugin_dir() {
    if [[ $PWD/ = */wp-content/plugins/* ]]; then
        return 0
    fi

    if [[ $PWD/ = */wp-content/themes/* ]]; then
        return 1
    fi

    wp_file_has_header "$(basename "$PWD").php" "Plugin Name"
}

# Check if this is a WordPress theme directory.
# Matches a standard wp-content path, or a style.css with a "Theme Name" header.
function is_wp_theme_dir() {
    if [[ $PWD/ = */wp-content/themes/* ]]; then
        return 0
    fi

    if [[ $PWD/ = */wp-content/plugins/* ]]; then
        return 1
    fi

    if wp_file_has_header "$(basename "$PWD").php" "Plugin Name"; then
        return 1
    fi

    wp_file_has_header "style.css" "Theme Name"
}

# Get WordPress plugin name
function wp_get_plugin_name() {
    echo "$(basename $PWD)"
}

# Get WordPress plugin filename
function wp_plugin_filename() {
    echo "$(wp_get_plugin_name).php"
}

# Get current plugin version from main PHP file
function wp_plugin_current_version() {
    local PLUGIN_FILE="$(wp_plugin_filename)"

    if [ -f "$PLUGIN_FILE" ]; then
        grep "Version:" "$PLUGIN_FILE" | head -1 | sed 's/.*Version: *\([0-9.]*\).*/\1/'
    else
        echo "0.0.0"
    fi
}

# Validate WordPress plugin structure
function validate_wp_plugin_structure() {
    local PLUGIN_FILE="$(wp_plugin_filename)"

    echo "🔍 Validating WordPress plugin structure..."

    # Check if main plugin file exists
    if [ ! -f "$PLUGIN_FILE" ]; then
        echo "❌ Error: Main plugin file $PLUGIN_FILE not found."
        return 1
    fi

    # Check if plugin header exists
    if ! grep -q "Plugin Name:" "$PLUGIN_FILE"; then
        echo "❌ Error: Plugin header not found in $PLUGIN_FILE."
        return 1
    fi

    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        echo "❌ Error: package.json not found."
        return 1
    fi

    echo "✅ WordPress plugin structure validation passed."
    return 0
}

# Smart zip dispatcher that detects context and prompts for zip type
function wp_zip() {
    CURRENT_DIR="$(pwd)"
    local TEMP_DIR=$(get_temp_dir)
    local quiet_mode="false"
    local zip_type_param=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode="true"
                shift
                ;;
            --for-install)
                zip_type_param="--for-install"
                shift
                ;;
            --for-git-updater)
                zip_type_param="--for-git-updater"
                shift
                ;;
            *)
                echo "Invalid parameter: $1"
                echo "Usage: wp_zip [--for-install|--for-git-updater] [--quiet]"
                return 1
                ;;
        esac
    done

    # Detect type
    IS_PLUGIN=false
    IS_THEME=false

    if is_wp_theme_dir; then
        IS_THEME=true
    elif is_wp_plugin_dir; then
        IS_PLUGIN=true
    fi

    if [ "$IS_PLUGIN" = false ] && [ "$IS_THEME" = false ]; then
        echo "Not inside a WordPress plugin or theme directory."
        return 1
    fi

    # Determine zip type from parameter or prompt user
    local CHOICE=""
    local selected_option=""

    case "$zip_type_param" in
        "--for-install")
            CHOICE="1"
            ;;
        "--for-git-updater")
            CHOICE="2"
            ;;
        "")
            # No parameter provided, show interactive menu
            local options=(
                "For install (files at root)"
                "Versioned for Git Updater (with versioned folder)"
            )

            selected_option=$(interactive_menu_select "Choose zip type:" "${options[@]}")
            if [ $? -ne 0 ] || [ -z "$selected_option" ]; then
                echo "No selection made. Exiting."
                return 1
            fi

            # Map selection back to choice number
            case "$selected_option" in
                "For install (files at root)")
                    CHOICE="1"
                    ;;
                "Versioned for Git Updater (with versioned folder)")
                    CHOICE="2"
                    ;;
                *)
                    echo "Invalid selection. Exiting."
                    return 1
                    ;;
            esac
            ;;
    esac

    # Compute default zip name (folder name)
    ZIP_NAME="$(basename "$CURRENT_DIR")"

    if [ "$CHOICE" = "2" ]; then
        CURRENT_VERSION=${WP_ZIP_VERSION:-$(get_package_json_version)}
        ZIP_NAME="$(basename "$CURRENT_DIR")-v$CURRENT_VERSION"
    fi

    COPY_DIR="$TEMP_DIR/${ZIP_NAME}"
    CURRENT_DIR_POSIX=$(convert_path_for_windows_tools "$CURRENT_DIR")
    ZIP_FILENAME="$TEMP_DIR/$ZIP_NAME.zip"

    TYPE="Plugin"

    if [ "$IS_THEME" = true ]; then
        TYPE="Theme"
    fi

    if [ "$quiet_mode" != "true" ]; then
        echo "🚀 Starting WordPress $TYPE zip creation..."
    fi

    # Step 1: Copy files
    if [ "$quiet_mode" != "true" ]; then
        step_start "[1/4] 📁 Copying files to temporary directory"
    fi
    if [ "$quiet_mode" = "true" ]; then
        if ! copy_folder "$CURRENT_DIR" "$COPY_DIR" --quiet; then
            echo "❌ Error: Failed to copy files to temporary directory" >&2
            return 1
        fi
    else
        copy_folder "$CURRENT_DIR" "$COPY_DIR"
        copy_result=$?
        if [ $copy_result -ne 0 ]; then
            echo "❌ Error: Failed to copy files to temporary directory (exit code: $copy_result)"
            return 1
        fi
        step_done
    fi

    cd "$COPY_DIR"

    # Step 2: Build for production
    if [ "$quiet_mode" != "true" ]; then
        step_start "[2/4] 🏗️  Building for production"
    fi
    if [ "$quiet_mode" = "true" ]; then
        if ! build_for_production --quiet; then
            echo "❌ Error: Build for production failed" >&2
            return 1
        fi
    else
        build_for_production
        build_result=$?
        if [ $build_result -ne 0 ]; then
            echo "❌ Error: Build for production failed (exit code: $build_result)"
            return 1
        fi
        step_done
    fi

    # Step 3: Create ZIP file
    if [ "$quiet_mode" != "true" ]; then
        step_start "[3/4] 📦 Creating ZIP archive"
    fi
    if [ "$quiet_mode" = "true" ]; then
        if ! zip_folder "$COPY_DIR" "$ZIP_FILENAME" "$ZIP_NAME" --quiet; then
            echo "❌ Error: ZIP file creation failed" >&2
            return 1
        fi
    else
        zip_folder "$COPY_DIR" "$ZIP_FILENAME" "$ZIP_NAME"
        zip_result=$?
        if [ $zip_result -ne 0 ]; then
            echo "❌ Error: ZIP file creation failed (exit code: $zip_result)"
            return 1
        fi
        step_done
    fi

    cd "$CURRENT_DIR"

    # Step 4: Complete
    if [ "$quiet_mode" != "true" ]; then
        step_start "[4/4] 🎉 Finalizing"
        sleep 0.5  # Brief pause for effect
        step_done

        echo ""
        echo "✅ WordPress $TYPE zip created successfully!"
        echo "📋 Zip: $ZIP_FILENAME"
    else
        echo $ZIP_FILENAME
    fi

}

# Report what a release would do, without changing the project, git or GitHub.
# The ZIP is built from a copy in its own temp directory, so it cannot affect a later real release.
function wp_release_dry_run() {
    local version_type="$1"
    local failures=0
    local warnings=0

    dry_run_ok() { echo "  OK: $1"; }
    dry_run_warn() { echo "  Warning: $1"; warnings=$((warnings + 1)); }
    dry_run_fail() { echo "  Failed: $1"; failures=$((failures + 1)); }

    echo "Dry run: no commits, tags, pushes, GitHub releases or project file changes."
    echo ""

    if ! is_git_repo; then
        dry_run_fail "Not a git repository."
        echo ""
        echo "Dry run result: $failures failed, $warnings warning(s)."
        return 1
    fi

    local current_version new_version
    current_version=$(get_package_json_version)
    new_version=$(calculate_new_version "$current_version" "$version_type")

    local project_name project_type main_file
    project_name=$(basename "$PWD")
    project_type="other"
    main_file=""

    if is_wp_plugin_dir; then
        project_type="plugin"
        main_file="$(wp_plugin_filename)"
    elif is_wp_theme_dir; then
        project_type="theme"
        main_file="style.css"
    fi

    echo "Project: $project_name ($project_type)"
    echo "Version: $current_version -> $new_version ($version_type)"
    echo ""
    echo "Git:"

    local branch
    branch=$(git branch --show-current)

    if [ "$branch" = "development" ] || [ "$branch" = "hotfix" ]; then
        dry_run_ok "Branch is $branch."
    else
        dry_run_fail "Releases only run from development or hotfix. Current branch: ${branch:-detached HEAD}."
    fi

    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        dry_run_ok "Branch has an upstream."
    else
        dry_run_fail "Branch has no upstream. The release would stop at its first push, after the version commit."
    fi

    if git_main_branch_exists; then
        dry_run_ok "Branch main exists."
    else
        dry_run_fail "Branch main does not exist. The release would stop at its merge step, after the tag and GitHub release."
    fi

    if is_working_directory_clean; then
        dry_run_ok "Working tree is clean."
    else
        dry_run_warn "Working tree has changes. The release runs git add . and would include them."
    fi

    if git rev-parse -q --verify "refs/tags/v$new_version" >/dev/null 2>&1 || [ -n "$(git ls-remote --tags origin "v$new_version" 2>/dev/null)" ]; then
        dry_run_fail "Tag v$new_version already exists. The release would overwrite it."
    else
        dry_run_ok "Tag v$new_version is available."
    fi

    echo ""
    echo "Changelog:"

    if changelog_check_next_version; then
        dry_run_ok "CHANGELOG.md has a [NEXT_VERSION] section."

        if awk '/^## \[NEXT_VERSION\]/ { found = 1; next } /^## / { found = 0 } found' CHANGELOG.md | grep -q "Example fix description"; then
            dry_run_warn "CHANGELOG.md still has the example entry."
        fi
    else
        dry_run_fail "CHANGELOG.md has no [NEXT_VERSION] - [UNRELEASED] section."
    fi

    if [ "$project_type" = "other" ]; then
        echo ""
        echo "Not a WordPress plugin or theme. No version headers or release asset."
        echo ""
        echo "Dry run result: $failures failed, $warnings warning(s)."
        [ "$failures" -eq 0 ]
        return
    fi

    echo ""
    echo "Debugging code:"

    if wp_check_debugging_code --quiet; then
        dry_run_ok "None found."
    else
        dry_run_fail "Debugging code found. See the list above."
    fi

    echo ""
    echo "Version files:"

    if [ ! -f "$main_file" ]; then
        dry_run_fail "$main_file not found."
    elif [ "$project_type" = "plugin" ] && ! grep -q '^ \* Version:' "$main_file"; then
        dry_run_fail "$main_file has no ' * Version:' header line to update."
    elif [ "$project_type" = "theme" ] && ! grep -qE '^Version:' "$main_file"; then
        dry_run_fail "$main_file has no 'Version:' header line to update."
    else
        dry_run_ok "$main_file header would change to $new_version."
    fi

    local constant_prefix constant_file
    constant_prefix=$(echo "$project_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    for constant_file in "$main_file" "includes/${project_name}-constants.php" "inc/constants.php"; do
        if [ -f "$constant_file" ] && grep -qE "define.*${constant_prefix}_(PLUGIN|THEME)_VERSION" "$constant_file"; then
            dry_run_ok "$constant_file version constant would change to $new_version."
        fi
    done

    local next_version_files
    next_version_files=$(get_next_version_replacement_files)

    if [ -n "$next_version_files" ]; then
        dry_run_ok "[NEXT_VERSION] would be replaced in $(echo "$next_version_files" | wc -l | tr -d ' ') file(s)."
    fi

    echo ""
    echo "Release asset:"

    if ! wp_plugin_has_release_asset; then
        echo "  Header has no 'Release Asset: true'. No ZIP would be built."
    elif github_actions_release_workflow_exists; then
        echo "  .github/workflows/release.yml exists. The workflow would build the ZIP."
    else
        local dry_run_temp zip_path
        dry_run_temp=$(mktemp -d)

        if zip_path=$(TMPDIR="$dry_run_temp" WP_ZIP_VERSION="$new_version" wp_zip --for-git-updater --quiet) && [ -f "$zip_path" ]; then
            dry_run_ok "Built $zip_path ($(wc -c < "$zip_path" | tr -d ' ') bytes)."

            local entries
            entries=$(wp_list_zip_entries "$zip_path")

            if [ -z "$entries" ]; then
                dry_run_warn "No tool available to list the ZIP contents."
            else
                local root_main="${project_name}-v${new_version}/${main_file}"

                if echo "$entries" | grep -qF "$root_main"; then
                    dry_run_ok "ZIP contains $root_main."
                else
                    dry_run_fail "ZIP does not contain $root_main."
                fi

                local unwanted
                unwanted=$(echo "$entries" | grep -E "/(tests|vendor|node_modules)(/|\$)" | head -5)

                if [ -n "$unwanted" ]; then
                    dry_run_warn "ZIP contains tests, vendor or node_modules, for example $(echo "$unwanted" | head -1). This is expected only for production dependencies."
                fi
            fi

            echo "  Version files inside this ZIP still show $current_version, because the project was not changed."

            rm -rf "${dry_run_temp:?}/${project_name}-v${new_version}"
        else
            dry_run_fail "ZIP build failed."
        fi
    fi

    echo ""
    echo "Skipped: version bump, commits, pushes, release branch, tag, GitHub release, asset upload, merge to main."
    echo ""
    echo "Dry run result: $failures failed, $warnings warning(s)."

    [ "$failures" -eq 0 ]
}

# List ZIP entries with forward slashes, one per line. Empty if no listing tool is available.
function wp_list_zip_entries() {
    local zip_path="$1"
    local tool

    for tool in 7z.exe 7z 7za; do
        if command -v "$tool" >/dev/null 2>&1; then
            "$tool" l -ba "$zip_path" 2>/dev/null | sed -E 's/^.{53}//' | tr '\\' '/'
            return 0
        fi
    done

    if command -v unzip >/dev/null 2>&1; then
        unzip -Z1 "$zip_path" 2>/dev/null
    fi
}

# Bump version in WordPress plugin/theme main file
function wp_bump_version() {
    local NEW_VERSION="$1"
    local PLUGIN_NAME="$(wp_get_plugin_name)"
    local FILENAME=""

    # Determine the main file based on project type
    if is_wp_theme_dir; then
        FILENAME="style.css"

        # Check if theme style.css exists
        if [ ! -f "$FILENAME" ]; then
            echo "Warning: Theme style.css not found. Skipping theme version update."
            return 0
        fi

        # Update version in theme header (style.css format)
        if grep -q "Version:" "$FILENAME"; then
            sed_inplace "s/^\(Version:[ \t]*\)[0-9.]\+/\1$NEW_VERSION/" "$FILENAME"
            echo "Updated version in $FILENAME header."
        fi
    else
        # Plugin logic
        FILENAME="$(wp_plugin_filename)"

        # Check if main plugin file exists
        if [ ! -f "$FILENAME" ]; then
            echo "Warning: Main plugin file $FILENAME not found. Skipping PHP version update."
            return 0
        fi

        # Update version in plugin header (PHP format)
        if grep -q "Version:" "$FILENAME"; then
            sed_inplace "s/^\( \* Version:[ \t]*\)[0-9.]\+/\1$NEW_VERSION/" "$FILENAME"
            echo "Updated version in $FILENAME header."
        fi
    fi

    # Update version constant in the main plugin file and any constants files.
    local CONSTANTS_FILES=("$FILENAME")
    if [ -f "includes/${PLUGIN_NAME}-constants.php" ]; then
        CONSTANTS_FILES+=("includes/${PLUGIN_NAME}-constants.php")
    fi
    if [ -f "inc/constants.php" ]; then
        CONSTANTS_FILES+=("inc/constants.php")
    fi

    for CONSTANTS_FILE in "${CONSTANTS_FILES[@]}"; do
        if [ -f "$CONSTANTS_FILE" ]; then
            local PLUGIN_CONSTANT=$(echo "$PLUGIN_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
            if grep -q "define.*${PLUGIN_CONSTANT}_PLUGIN_VERSION" "$CONSTANTS_FILE"; then
                sed_inplace "s/define.*${PLUGIN_CONSTANT}_PLUGIN_VERSION.*$/define( '${PLUGIN_CONSTANT}_PLUGIN_VERSION', '$NEW_VERSION' );/" "$CONSTANTS_FILE"
                echo "Updated ${PLUGIN_CONSTANT}_PLUGIN_VERSION constant in $CONSTANTS_FILE."
            fi
            if grep -q "define.*${PLUGIN_CONSTANT}_THEME_VERSION" "$CONSTANTS_FILE"; then
                sed_inplace "s/define.*${PLUGIN_CONSTANT}_THEME_VERSION.*$/define( '${PLUGIN_CONSTANT}_THEME_VERSION', '$NEW_VERSION' );/" "$CONSTANTS_FILE"
                echo "Updated ${PLUGIN_CONSTANT}_THEME_VERSION constant in $CONSTANTS_FILE."
            fi
        fi
    done

    # Update block.json files (for block plugins/themes).
    local BLOCK_JSON_FILES=$(find . -type f -name "block.json" -not -path "./node_modules/*" -not -path "./vendor/*")

    if [ -n "$BLOCK_JSON_FILES" ]; then
        echo "Updating version in block.json files..."

        while IFS= read -r BLOCK_FILE; do
            if [ -f "$BLOCK_FILE" ]; then
                jq --arg v "$NEW_VERSION" '.version = $v' "$BLOCK_FILE" > "$BLOCK_FILE.tmp" && mv "$BLOCK_FILE.tmp" "$BLOCK_FILE"
                echo "Updated version in $BLOCK_FILE."
            fi
        done <<< "$BLOCK_JSON_FILES"
    fi
}

# WordPress-specific release function - extends git_create_release with WP functionality
function wp_create_release() {
    local version_type="$1"
    echo "🚀 Starting WordPress release process..."

    # Set some vars for WP detection
    local CURRENT_DIR=$(pwd)
    local TEMP_DIR=$(get_temp_dir)
    local BASENAME=$(basename "$CURRENT_DIR")
    local PACKAGE_MANAGER=$(get_package_manager_for_project)
    local CURRENT_VERSION=$(get_package_json_version)

    # Read custom ZIP exclusions early (before release branch creation)
    # This ensures .wp-build-exclusions is available when we need it
    local temp_exclusions_file="/tmp/wp-build-exclusions-$$"
    if [ -f ".wp-build-exclusions" ]; then
        # Copy custom exclusions to temp file, adding .wp-build-exclusions itself
        grep -v '^[[:space:]]*#' .wp-build-exclusions | grep -v '^[[:space:]]*$' > "$temp_exclusions_file"
        echo ".wp-build-exclusions" >> "$temp_exclusions_file"
    else
        # Just exclude .wp-build-exclusions file itself
        echo ".wp-build-exclusions" > "$temp_exclusions_file"
    fi

    # Export temp file path for use during ZIP creation
    export WP_BUILD_EXCLUSIONS_FILE="$temp_exclusions_file"

    # Step 1: Pre-release checks
    step_start "[1/6] 🔍 Running pre-release checks"

    local release_branch
    release_branch=$(git branch --show-current)

    if [ "$release_branch" != "development" ] && [ "$release_branch" != "hotfix" ]; then
        printf "\n❌ Releases can only be created from the development or hotfix branch. Current branch: %s\n" "$release_branch"
        return 1
    fi

    if ! git_main_branch_exists; then
        printf "\n❌ Branch main does not exist. A release merges into main after it creates the tag and GitHub release. Create main before releasing.\n"
        return 1
    fi

    if ! wp_check_debugging_code --quiet; then
        printf "\n❌ Found debugging code in plugin. Please correct before releasing.\n"
        return 1
    fi

    # Test build scripts in a sandbox copy (if they exist)
    if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
        local package_manager=$(get_package_manager_for_project)
        local has_build_script=false
        local build_script=""

        # Check for production or build scripts
        if jq -e '.scripts.production' package.json >/dev/null 2>&1; then
            has_build_script=true
            build_script="production"
        elif jq -e '.scripts.build' package.json >/dev/null 2>&1; then
            has_build_script=true
            build_script="build"
        fi

        if [ "$has_build_script" = true ]; then
            printf "\n  🔨 Build script detected: $build_script"
            printf "\n  ⚠️  Skipping build test due to timeout issues on Windows"
            printf "\n  💡 Build will be tested during ZIP creation step"
            echo "  ✅ Pre-release checks complete!"
        else
            step_done
        fi
    else
        step_done
    fi

    # Detect WordPress project types
    local IS_WP_PLUGIN=false
    local IS_WP_THEME=false
    local IS_WP_BLOCK_PLUGIN=false

    if is_wp_plugin_dir; then
        IS_WP_PLUGIN=true
        # Check if this is specifically a block plugin
        if is_wp_block_plugin; then
            IS_WP_BLOCK_PLUGIN=true
        fi
    fi

    if is_wp_theme_dir; then
        IS_WP_THEME=true
    fi

    # Step 2: Maybe update Action Scheduler library for WP plugins
    if [ "$IS_WP_PLUGIN" = true ] && [ -d "libraries/action-scheduler" ]; then
        step_start "[2/6] 📚 Updating Action Scheduler library"

        # Check if the Action Scheduler remote exists
        if ! git remote | grep -q "subtree-action-scheduler"; then
            git remote add -f subtree-action-scheduler https://github.com/woocommerce/action-scheduler.git >/dev/null 2>&1
        else
            git fetch subtree-action-scheduler trunk >/dev/null 2>&1
        fi

        # Update the Action Scheduler subtree
        git subtree pull --prefix libraries/action-scheduler subtree-action-scheduler trunk --squash >/dev/null 2>&1

        step_done
    else
        step_start "[2/6] 📚 Checking Action Scheduler library"
        # No Action Scheduler found, skip
        step_done
    fi

    # Step 3: Maybe update POT file for WP plugins and themes
    if [ "$IS_WP_PLUGIN" = true ] || [ "$IS_WP_THEME" = true ]; then
        step_start "[3/6] 🌐 Updating translation files"
        wp_plugin_update_pot >/dev/null 2>&1 || true

        git add languages/* >/dev/null 2>&1 || true
        gc "Updating POT" >/dev/null 2>&1 || true
        step_done
    else
        step_start "[3/6] 🌐 Checking translation files"
        # Not a WP plugin/theme, skip
        step_done
    fi

    # Step 4: Call the core git release function
    step_start "[4/6] 🔄 Running core release process"
    if [ -n "$version_type" ]; then
        git_create_release_quiet "$version_type" --quiet
    else
        git_create_release_quiet --quiet
    fi
    local git_exit_code=$?

    # If core release failed, exit
    if [ $git_exit_code -ne 0 ]; then
        printf "\n❌ Core release process failed.\n"
        return 1
    fi

    # Get the current version after the release process
    local RELEASE_VERSION=$(get_package_json_version)

    # Exit now if not a WP plugin or theme with a release asset
    if ! [ "$IS_WP_PLUGIN" = true ] && ! [ "$IS_WP_THEME" = true ]; then
        echo ""
        echo "✅ Non-WordPress project release completed!"
        return 0
    fi

    # Ask if we want to create a zip to deploy WP plugins and themes
    if ! wp_plugin_has_release_asset; then
        echo ""
        echo "ℹ️  This plugin/theme does not use a release asset. Exiting."
        wp_post_create_release
        return 0
    fi

    # If this is a theme and a release workflow exists, skip local asset build
    if github_actions_release_workflow_exists; then
        echo ""
        echo "🔄 Release workflow detected (release.yml). Skipping local release asset build."
        echo "✅ WordPress release completed!"
        wp_post_create_release
        return 0
    fi

    # Step 5: Create WordPress release asset
    step_start "[5/6] 📦 Creating WordPress release asset"
    local ZIP_FILE_PATH
    ZIP_FILE_PATH=$(wp_zip --for-git-updater --quiet)
    local zip_exit_code=$?

    # Check if ZIP creation was successful
    if [ $zip_exit_code -ne 0 ]; then
        printf "\n❌ Error: WordPress release asset creation failed (exit code: $zip_exit_code)\n"
        printf "   This may be due to build process issues or dependency conflicts.\n"
        return 1
    fi

    # Verify ZIP file was actually created and wait for it to be available
    if [ -z "$ZIP_FILE_PATH" ]; then
        printf "\n❌ Error: ZIP file path is empty\n"
        return 1
    fi

    # Wait for ZIP file to be fully written to disk (with retry logic)
    local max_attempts=10
    local attempt=1
    local wait_seconds=1

    while [ $attempt -le $max_attempts ]; do
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

            if [ "$file_size" -gt 1024 ]; then  # At least 1KB
                break
            fi
        fi

        if [ $attempt -eq $max_attempts ]; then
            printf "\n❌ Error: ZIP file was not created or is not accessible after $max_attempts attempts\n"
            printf "   Expected path: $ZIP_FILE_PATH\n"
            return 1
        fi

        sleep $wait_seconds
        attempt=$((attempt + 1))
        wait_seconds=$((wait_seconds + 1))  # Increase wait time with each attempt
    done

    local ZIP_FILE=$(basename "$ZIP_FILE_PATH")
    step_done

    # Step 6: Upload the asset to the release
    step_start "[6/6] ⬆️  Uploading release asset to GitHub"

    # Double-check ZIP file accessibility before upload
    if [ ! -f "$ZIP_FILE_PATH" ] || [ ! -r "$ZIP_FILE_PATH" ]; then
        printf "\n❌ Error: ZIP file not found or not readable at $ZIP_FILE_PATH\n"
        printf "   ZIP creation may have failed or file system latency issue.\n"
        return 1
    fi

    # Verify file size is reasonable
    local file_size
    if command -v stat >/dev/null 2>&1; then
        file_size=$(stat -c%s "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
    else
        # Fallback for systems without stat
        file_size=$(wc -c < "$ZIP_FILE_PATH" 2>/dev/null || echo "0")
    fi

    if [ "$file_size" -lt 1024 ]; then
        printf "\n❌ Error: ZIP file appears to be too small ($file_size bytes)\n"
        printf "   This may indicate an incomplete or corrupted file.\n"
        return 1
    fi

    # Upload the asset to GitHub
    if gh release upload "v$RELEASE_VERSION" "$ZIP_FILE_PATH" >/dev/null 2>&1; then
        step_done
    else
        printf "\n❌ Error: Failed to upload release asset to GitHub\n"
        return 1
    fi

    wp_post_create_release

    echo ""
    echo "🎊 SUCCESS: WordPress release $RELEASE_VERSION created with asset!"
    echo "📋 Zip: $ZIP_FILE"

    # Clean up temporary exclusions file
    if [ -n "$WP_BUILD_EXCLUSIONS_FILE" ] && [ -f "$WP_BUILD_EXCLUSIONS_FILE" ]; then
        rm -f "$WP_BUILD_EXCLUSIONS_FILE"
        unset WP_BUILD_EXCLUSIONS_FILE
    fi

    # Do we want to trigger Git Remote Updater to force update the plugin/theme now?
    # confirm "Do you want to remote update the plugin/theme to this new version now?"
    # if [ $? == 0 ]; then
    #     wp_update_plugin_via_git_remote_updater
    # fi
}

function wp_post_create_release() {
    git checkout development >/dev/null 2>&1

    # Add new [NEXT_VERSION] template when back on development branch.
    changelog_add_next_version_template --quiet
}
