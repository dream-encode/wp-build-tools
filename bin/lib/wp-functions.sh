#!/bin/bash

# WordPress-specific utility functions for release script
# Copied from wp.bashrc

# Check for debugging code in the plugin
function wp_check_debugging_code() {
    echo "Checking for debugging code..."

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

# Update POT file for WordPress plugins and themes
function wp_plugin_update_pot() {
    local PLUGIN_NAME="$(basename $PWD)"

    if ! command -v wp >/dev/null 2>&1; then
        echo "Warning: WP-CLI not found. Skipping POT file update."
        return 0
    fi

    wp i18n make-pot . languages/$PLUGIN_NAME.pot --exclude=tests,dist/js
}

# Check if this is a WordPress block plugin
function is_wp_block_plugin() {
    # Check if this is a block plugin by looking for common block plugin indicators
    if [ -d "src" ] && [ -d "build" ] && [ -f "package.json" ]; then
        # Check if package.json has @wordpress/scripts or block-related dependencies
        if jq -e '.dependencies["@wordpress/scripts"] or .devDependencies["@wordpress/scripts"] or .dependencies["@wordpress/blocks"] or .devDependencies["@wordpress/blocks"]' package.json >/dev/null 2>&1; then
            echo "This appears to be a WordPress block plugin."
            return 0
        fi
    fi

    # Check for block.json files which are definitive indicators of block plugins
    if find . -name "block.json" -not -path "./node_modules/*" -not -path "./vendor/*" | grep -q .; then
        echo "This appears to be a WordPress block plugin (found block.json)."
        return 0
    fi

    echo "This does not appear to be a WordPress block plugin."
    return 1
}

# Check if plugin has release asset
function wp_plugin_has_release_asset() {
    local PLUGIN_NAME="$(basename $PWD)"
    local PLUGIN_FILENAME="$PLUGIN_NAME.php"

    # Special case for specific plugin
    if [ "$PLUGIN_NAME" = "max-marine-warehouse-operations-wp-plugin" ]; then
        PLUGIN_FILENAME="max-marine-electronics-warehouse-operations.php"
    fi

    if [ -f "$PLUGIN_FILENAME" ] && grep -q "Release Asset:     true" "$PLUGIN_FILENAME"; then
        echo "Plugin uses a release asset."
        return 0
    fi

    echo "Plugin does not use a release asset."
    return 1
}

# Get WordPress plugin filename
function wp_plugin_filename() {
    local PLUGIN_NAME="$(basename $PWD)"
    echo "$PLUGIN_NAME.php"
}

# Bump version in WordPress plugin/theme main file
function wp_plugin_bump_version() {
    local NEW_VERSION="$1"
    local PLUGIN_NAME="$(basename $PWD)"
    local FILENAME="$PLUGIN_NAME.php"

    # Main plugin file.
    if [ ! -f "$FILENAME" ]; then
        echo "Warning: Main plugin file $FILENAME not found. Skipping PHP version update."
        return 0
    fi

    # Plugin header.
    if grep -q "Version:" "$FILENAME"; then
        sed -i "s/Version:.*$/Version: $NEW_VERSION/" "$FILENAME"
        echo "Updated version in $FILENAME header."
    fi

    # Version constant.
    local PLUGIN_CONSTANT=$(echo "$PLUGIN_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    if grep -q "define.*${PLUGIN_CONSTANT}_VERSION" "$FILENAME"; then
        sed -i "s/define.*${PLUGIN_CONSTANT}_VERSION.*$/define( '${PLUGIN_CONSTANT}_VERSION', '$NEW_VERSION' );/" "$FILENAME"
        echo "Updated ${PLUGIN_CONSTANT}_VERSION constant in $FILENAME."
    fi

    # Constants files.
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
                sed -i "s/define.*${PLUGIN_CONSTANT}_PLUGIN_VERSION.*$/define( '${PLUGIN_CONSTANT}_PLUGIN_VERSION', '$NEW_VERSION' );/" "$CONSTANTS_FILE"
                echo "Updated ${PLUGIN_CONSTANT}_PLUGIN_VERSION constant in $CONSTANTS_FILE."
            fi
        fi
    done

    # Block.json files.
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

# Create ZIP file for WordPress plugin (Windows-compatible version)
function wp_zip_plugin() {
    local CURRENT_DIR="$(pwd)"
    local ZIP_NAME="$1"

    # Use provided filename or default to current directory name
    if [ -z "$ZIP_NAME" ]; then
        ZIP_NAME="$(basename "$CURRENT_DIR")"
    fi

    local COPY_DIR="$HOME/tmp/$ZIP_NAME"
    local CURRENT_DIR_POSIX
    local COPY_DIR_POSIX
    local ZIP_FILENAME="$HOME/tmp/$ZIP_NAME.zip"

    # Convert to Windows paths if cygpath is available
    if command -v cygpath >/dev/null 2>&1; then
        CURRENT_DIR_POSIX=$(cygpath -w "$CURRENT_DIR")
        COPY_DIR_POSIX=$(cygpath -w "$COPY_DIR")
    else
        CURRENT_DIR_POSIX="$CURRENT_DIR"
        COPY_DIR_POSIX="$COPY_DIR"
    fi

    echo "Creating plugin ZIP: $ZIP_NAME.zip"
    echo "Plugin Dir is $CURRENT_DIR"
    echo "Copy Dir is $COPY_DIR"
    echo "Zip is $ZIP_FILENAME"

    # Clean up previous files
    rm -rf "$COPY_DIR"
    rm -f "$ZIP_FILENAME"
    mkdir -p "$COPY_DIR"

    # Copy files excluding development directories
    echo "Copying plugin files..."
    if command -v robocopy >/dev/null 2>&1; then
        echo "DEBUG: About to run robocopy..."
        echo "DEBUG: Source: $CURRENT_DIR_POSIX"
        echo "DEBUG: Dest: $COPY_DIR_POSIX"

        # Windows robocopy (handle exit codes properly)
        set +e  # Temporarily disable exit on error for robocopy
        robocopy "$CURRENT_DIR_POSIX" "$COPY_DIR_POSIX" //MIR //NS //NC //NFL //NDL //NP //XD "$CURRENT_DIR_POSIX\.git" //XD "$CURRENT_DIR_POSIX\vendor" //XD "$CURRENT_DIR_POSIX\node_modules" //XD "$CURRENT_DIR_POSIX\tests" //XD "$CURRENT_DIR_POSIX\bin"
        local robocopy_exit=$?
        set -e  # Re-enable exit on error

        echo "DEBUG: robocopy completed with exit code: $robocopy_exit"
        # robocopy exit codes: 0=no files, 1=files copied, 2=extra files, 4=mismatched, 8+=errors
        if [ $robocopy_exit -ge 8 ]; then
            echo "Error: robocopy failed with exit code $robocopy_exit"
            return 1
        else
            echo "DEBUG: robocopy completed successfully (exit code $robocopy_exit)"
        fi
    else
        # Fallback to rsync for non-Windows systems
        rsync -av \
            --exclude='node_modules' \
            --exclude='.git' \
            --exclude='vendor' \
            --exclude='tests' \
            --exclude='.github' \
            --exclude='*.log' \
            --exclude='.DS_Store' \
            --exclude='Thumbs.db' \
            --exclude='*.tmp' \
            --exclude='*.bak' \
            --exclude='bin' \
            ./ "$COPY_DIR/"
    fi

    # Ensure copy directory exists and change to it
    if [ ! -d "$COPY_DIR" ]; then
        echo "Error: Copy directory $COPY_DIR was not created properly"
        return 1
    fi

    echo "Changing to copy directory: $COPY_DIR"
    cd "$COPY_DIR" || {
        echo "Error: Failed to change to copy directory $COPY_DIR"
        return 1
    }

    # Get package manager for build process
    local PACKAGE_MANAGER
    if [ -f "package.json" ]; then
        if [ -f "yarn.lock" ]; then
            PACKAGE_MANAGER="yarn"
        else
            PACKAGE_MANAGER="npm"
        fi
    fi

    # Run production build if needed
    if [ -n "$PACKAGE_MANAGER" ] && [ -f "package.json" ]; then
        if grep -q '"production"' package.json; then
            echo "Running production build..."
            "$PACKAGE_MANAGER" run production
        elif grep -q '"build"' package.json; then
            echo "Running build..."
            "$PACKAGE_MANAGER" run build
        fi
    fi

    # Install production dependencies if composer.json exists
    if [ -f "composer.json" ]; then
        echo "Installing production dependencies..."
        composer install --no-dev --optimize-autoloader
    fi

    # Create ZIP file
    if command -v 7z.exe >/dev/null 2>&1; then
        # Use 7-Zip on Windows
        7z.exe a "$ZIP_FILENAME" "$COPY_DIR" -xr!node_modules -xr!*.git* -xr!*.dist -xr!.env* -xr!composer.* -xr!package.json -xr!*.lock -xr!webpack.config.js -xr!*.map -xr!.babelrc -xr!postcss.config.js -xr!.cache -xr!./tests -xr!.husky -xr!playwright* -xr!.wakatime* -xr!.eslint* -xr!eslint* -xr!.dist* -xr!.nvmrc -xr!.editorconfig -xr!./codecov -xr!"*\assets\src" -xr!"test-results" -xr!./vendor -xr!./bin
    else
        # Fallback to zip command
        cd "$HOME/tmp"
        zip -r -q "$ZIP_NAME.zip" "$ZIP_NAME" -x "*/node_modules/*" "*/.git/*" "*/vendor/*" "*/tests/*" "*/bin/*"
    fi

    # Return to original directory
    cd "$CURRENT_DIR"

    echo "Plugin ZIP created: $ZIP_FILENAME"
}

# Create ZIP file for WordPress block plugin
function wp_zip_block_plugin() {
    local CURRENT_DIR="$(pwd)"
    local ZIP_NAME="$1"

    # Use provided filename or default to current directory name
    if [ -z "$ZIP_NAME" ]; then
        ZIP_NAME="$(basename "$CURRENT_DIR")"
    fi

    local ZIP_FILENAME="$ZIP_NAME.zip"
    local COPY_DIR="$HOME/tmp/$ZIP_NAME"

    echo "Creating block plugin ZIP: $ZIP_FILENAME"

    # Create temporary directory
    mkdir -p "$HOME/tmp"
    rm -rf "$COPY_DIR"
    mkdir -p "$COPY_DIR"

    # Copy files excluding development directories
    echo "Copying block plugin files..."
    rsync -av \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='vendor' \
        --exclude='tests' \
        --exclude='.github' \
        --exclude='src' \
        --exclude='*.log' \
        --exclude='.DS_Store' \
        --exclude='Thumbs.db' \
        --exclude='*.tmp' \
        --exclude='*.bak' \
        --exclude='bin' \
        ./ "$COPY_DIR/"

    # Create ZIP file
    cd "$HOME/tmp"
    zip -r -q "$ZIP_FILENAME" "$ZIP_NAME"

    # Return to original directory
    cd "$CURRENT_DIR"

    echo "Block plugin ZIP created: $HOME/tmp/$ZIP_FILENAME"
}

# Create ZIP file for WordPress theme
function wp_zip_theme() {
    local CURRENT_DIR="$(pwd)"
    local ZIP_NAME="$1"

    # Use provided filename or default to current directory name
    if [ -z "$ZIP_NAME" ]; then
        ZIP_NAME="$(basename "$CURRENT_DIR")"
    fi

    local ZIP_FILENAME="$ZIP_NAME.zip"
    local COPY_DIR="$HOME/tmp/$ZIP_NAME"

    echo "Creating theme ZIP: $ZIP_FILENAME"

    # Create temporary directory
    mkdir -p "$HOME/tmp"
    rm -rf "$COPY_DIR"
    mkdir -p "$COPY_DIR"

    # Copy files excluding development directories
    echo "Copying theme files..."
    rsync -av \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='vendor' \
        --exclude='tests' \
        --exclude='.github' \
        --exclude='*.log' \
        --exclude='.DS_Store' \
        --exclude='Thumbs.db' \
        --exclude='*.tmp' \
        --exclude='*.bak' \
        --exclude='bin' \
        ./ "$COPY_DIR/"

    # Create ZIP file
    cd "$HOME/tmp"
    zip -r -q "$ZIP_FILENAME" "$ZIP_NAME"

    # Return to original directory
    cd "$CURRENT_DIR"

    echo "Theme ZIP created: $HOME/tmp/$ZIP_FILENAME"
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

# Get current plugin version from main PHP file
function wp_plugin_current_version() {
    local PLUGIN_NAME="$(basename $PWD)"
    local PLUGIN_FILE="$PLUGIN_NAME.php"

    if [ -f "$PLUGIN_FILE" ]; then
        grep "Version:" "$PLUGIN_FILE" | head -1 | sed 's/.*Version: *\([0-9.]*\).*/\1/'
    else
        echo "0.0.0"
    fi
}

# Validate WordPress plugin structure
function validate_wp_plugin_structure() {
    local PLUGIN_NAME="$(basename $PWD)"
    local PLUGIN_FILE="$PLUGIN_NAME.php"

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
