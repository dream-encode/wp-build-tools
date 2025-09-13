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

        local count=$(grep -ro --exclude-dir={node_modules,vendor,tests} --exclude=*wc-logger.php "$pattern" . | wc -l)

        if [ "$count" -gt 0 ]; then
            if [ "$found_issues" = false ]; then
                echo "Found debugging code in the following files:"
                found_issues=true
            fi
            echo ""
            echo "=== $name ($count occurrences) ==="
            grep -rn --exclude-dir={node_modules,vendor,tests} --exclude=*wc-logger.php "$pattern" .
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
    if [ -d "src" ] && [ -d "build" ] && [ -f "package.json" ]; then
        if jq -e '.dependencies["@wordpress/scripts"] or .devDependencies["@wordpress/scripts"] or .dependencies["@wordpress/blocks"] or .devDependencies["@wordpress/blocks"]' package.json >/dev/null 2>&1; then
            return 0
        fi
    fi

    if find . -name "block.json" -not -path "./node_modules/*" -not -path "./vendor/*" | grep -q .; then
        return 0
    fi

    return 1
}

function wp_plugin_has_release_asset() {
    PLUGIN_FILENAME="$(wp_plugin_filename)"

    if [ "$PLUGIN_NAME" = "max-marine-warehouse-operations-wp-plugin" ];
    then
        PLUGIN_FILENAME="max-marine-electronics-warehouse-operations.php"
    fi

    if [ ! -f "$PLUGIN_FILENAME" ]; then
        return 1
    fi

    if grep -q "Release Asset:.*true" "$PLUGIN_FILENAME"; then
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

# Check if this is a WordPress plugin directory
function is_wp_plugin_dir() {
    if [[ $PWD/ = */wp-content/plugins/* ]]; then
        return 0
    fi
    return 1
}

# Check if this is a WordPress theme directory
function is_wp_theme_dir() {
    if [[ $PWD/ = */wp-content/themes/* ]]; then
        return 0
    fi
    return 1
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

    if [[ $PWD/ = */wp-content/themes/* ]]; then
        IS_THEME=true
    elif [[ $PWD/ = */wp-content/plugins/* ]]; then
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
        CURRENT_VERSION=$(get_version_package_json)
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
        copy_folder "$CURRENT_DIR" "$COPY_DIR" --quiet
    else
        copy_folder "$CURRENT_DIR" "$COPY_DIR"
    fi
    copy_result=$?
    if [ $copy_result -ne 0 ]; then
        echo "❌ Error: Failed to copy files to temporary directory (exit code: $copy_result)"
        return 1
    fi
    if [ "$quiet_mode" != "true" ]; then
        step_done
    fi

    cd "$COPY_DIR"

    # Step 2: Build for production
    if [ "$quiet_mode" != "true" ]; then
        step_start "[2/4] 🏗️  Building for production"
    fi
    if [ "$quiet_mode" = "true" ]; then
        build_for_production --quiet
    else
        build_for_production
    fi
    if [ "$quiet_mode" != "true" ]; then
        step_done
    fi

    # Step 3: Create ZIP file
    if [ "$quiet_mode" != "true" ]; then
        step_start "[3/4] 📦 Creating ZIP archive"
    fi
    if [ "$quiet_mode" = "true" ]; then
        zip_folder "$COPY_DIR" "$ZIP_FILENAME" "$ZIP_NAME" --quiet
    else
        zip_folder "$COPY_DIR" "$ZIP_FILENAME" "$ZIP_NAME"
    fi
    if [ "$quiet_mode" != "true" ]; then
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

# Bump version in WordPress plugin/theme main file
function wp_plugin_bump_version() {
    local NEW_VERSION="$1"
    local PLUGIN_NAME="$(wp_get_plugin_name)"
    local FILENAME="$(wp_plugin_filename)"

    # Check if main plugin file exists
    if [ ! -f "$FILENAME" ]; then
        echo "Warning: Main plugin file $FILENAME not found. Skipping PHP version update."
        return 0
    fi

    # Update version in plugin header
    if grep -q "Version:" "$FILENAME"; then
        sed_inplace "s/Version:.*$/Version: $NEW_VERSION/" "$FILENAME"
        echo "Updated version in $FILENAME header."
    fi

    # Update version constant if it exists
    local PLUGIN_CONSTANT=$(echo "$PLUGIN_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    if grep -q "define.*${PLUGIN_CONSTANT}_VERSION" "$FILENAME"; then
        sed_inplace "s/define.*${PLUGIN_CONSTANT}_VERSION.*$/define( '${PLUGIN_CONSTANT}_VERSION', '$NEW_VERSION' );/" "$FILENAME"
        echo "Updated ${PLUGIN_CONSTANT}_VERSION constant in $FILENAME."
    fi

    # Update version constant in constants files
    local CONSTANTS_FILES=()
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
    local CURRENT_VERSION=$(get_version_package_json)

    # Step 1: Pre-release checks
    step_start "[1/6] 🔍 Running pre-release checks"
    if ! wp_check_debugging_code --quiet; then
        printf "\n❌ Found debugging code in plugin. Please correct before releasing.\n"
        return 1
    fi
    step_done

    # Detect WordPress project types
    local IS_WP_PLUGIN=false
    local IS_WP_THEME=false
    local IS_WP_BLOCK_PLUGIN=false

    if [[ $PWD/ = */wp-content/plugins/* ]]; then
        IS_WP_PLUGIN=true
        # Check if this is specifically a block plugin
        if is_wp_block_plugin; then
            IS_WP_BLOCK_PLUGIN=true
        fi
    fi

    if [[ $PWD/ = */wp-content/themes/* ]]; then
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
        wp_plugin_update_pot >/dev/null 2>&1

        git add languages/* >/dev/null 2>&1
        gc "Updating POT" >/dev/null 2>&1
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
    local RELEASE_VERSION=$(get_version_package_json)

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
        return 0
    fi

    # If this is a theme and a release workflow exists, skip local asset build
    if [ "$IS_WP_THEME" = true ] && github_actions_release_workflow_exists; then
        echo ""
        echo "🔄 Release workflow detected (release.yml). Skipping local release asset build for theme."
        echo "✅ WordPress theme release completed!"
        return 0
    fi

    # Step 5: Create WordPress release asset
    step_start "[5/6] 📦 Creating WordPress release asset"
    local ZIP_FILE_PATH=$(wp_zip --for-git-updater --quiet)
    local ZIP_FILE=$(basename "$ZIP_FILE_PATH")
    step_done

    # Step 6: Upload the asset to the release
    step_start "[6/6] ⬆️  Uploading release asset to GitHub"
    gh release upload "v$RELEASE_VERSION" "$ZIP_FILE_PATH" >/dev/null 2>&1
    step_done

    echo ""
    echo "🎊 SUCCESS: WordPress release v$RELEASE_VERSION created with asset!"
    echo "📋 Zip: $ZIP_FILE"

    # Do we want to trigger Git Remote Updater to force update the plugin/theme now?
    # confirm "Do you want to remote update the plugin/theme to this new version now?"
    # if [ $? == 0 ]; then
    #     wp_update_plugin_via_git_remote_updater
    # fi
}
