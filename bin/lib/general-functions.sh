#!/bin/bash

# General utility functions for release script

# Source platform utilities if not already loaded
if ! command -v get_platform >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/platform-utils.sh"
fi
# Copied from general-functions.bashrc.

# Color helper function for better terminal compatibility.
function print_color() {
    local color_code="$1"
    local message="$2"
    if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
        echo -e "\e[${color_code}m${message}\e[0m"
    else
        echo "$message"
    fi
}

# Confirmation prompt function.
function confirm() {
    local message="$1"
    local response

    while true; do
        read -p "$message (y/n): " response
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Simple step display functions
function step_start() {
    local message="$1"
    printf "%s..." "$message"
}

function step_done() {
    printf "Done! ✅\n"
}

# Extract version updates from changelog for a specific version.
function extract_version_updates_from_changelog() {
    local RELEASE_VERSION="$1"
    local CHANGELOG_FILE="CHANGELOG.md"

    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        echo "CHANGELOG.md not found in the current directory."
        return 1
    fi

    # Parse CHANGELOG.md for changes in version (supports both X.X.X and X.X.X.X formats).
    awk -v ver="$RELEASE_VERSION" '
        $0 ~ "^## \\[" ver "\\]" { print; version_found=1; next }
        /^## \[/ && version_found { exit }
        version_found && /^\*/' "$CHANGELOG_FILE"
}

# Check if package.json exists.
function package_json_exists() {
    return file_exists "package.json"
}

# Get version from package.json.
function get_version_package_json() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required but not installed." >&2
        exit 1
    fi

    echo "$(jq -r .version package.json)"
}

# Update version in package.json.
function bump_version_package_json() {
    local VERSION="$1"

    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required but not installed." >&2
        exit 1
    fi

    jq ".version=\"$VERSION\"" package.json > /tmp/package.json
    mv /tmp/package.json package.json
}

# Get package manager for project (yarn or npm).
function get_package_manager_for_project() {
    if [ -f yarn.lock ]; then
        echo "yarn"
    else
        echo "npm"
    fi
}

function replace_dashes_with_underscores() {
    echo $1 | tr "-" "_"
}

function deploy_workflow_exists() {
    return file_exists ".github/workflows/deploy*"
}

function current_project_has_production_composer_dependencies() {
    LENGTH=$(jq '.require | length' composer.json)

    if [[ $LENGTH -gt 0 ]]; then
        echo "Plugin has dependencies.";
        return
    fi

    echo "Plugin does not have dependencies.";
    false
}

function current_dir_has_npm_production_script() {
    LENGTH=$(jq '.scripts.production | length' package.json)

    if [[ $LENGTH -gt 0 ]]; then
        echo "Package has a production build.";
        return
    fi

    echo "Package does not have a production build.";
    false
}

function current_dir_has_npm_build_script() {
    LENGTH=$(jq '.scripts.build | length' package.json)

    if [[ $LENGTH -gt 0 ]]; then
        echo "Package has a build script.";
        return
    fi

    echo "Package does not have a build script.";
    false
}

# Check which build script is available and return the preferred one
function get_available_build_script() {
    if [ ! -f "package.json" ]; then
        return 1
    fi

    # Check for production script first (preferred)
    if jq -e '.scripts.production' package.json >/dev/null 2>&1; then
        echo "production"
        return 0
    fi

    # Check for build script as fallback
    if jq -e '.scripts.build' package.json >/dev/null 2>&1; then
        echo "build"
        return 0
    fi

    return 1
}

#Changelog stuff.
function changelog_exists() {
    if file_exists "CHANGELOG.md"; then
        return 0
    else
        return 1
    fi
}

function changelog_check_next_version() {
    if changelog_exists; then
        # Check if the changelog contains the NEXT_VERSION - UNRELEASED pattern
        if grep -q "## \[NEXT_VERSION\] - \[UNRELEASED\]" CHANGELOG.md; then
            return 0
        fi
    fi

    return 1
}

function changelog_add_next_version_template() {
    local CURRENT_VERSION=$(get_version_package_json)
    local QUIET_MODE="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                QUIET_MODE="true"
                shift
                ;;
            *)
                echo "❌ Error: Unknown argument '$1' for changelog_add_next_version_template"
                echo "Usage: changelog_add_next_version_template [--quiet]"
                return 1
                ;;
        esac
    done

    # Add template changelog entry if changelog file exists.
    if changelog_exists; then
        if [ "$QUIET_MODE" != "true" ]; then
            echo "Adding template changelog entry..."
        fi

        # Only modify CHANGELOG.md, use anchored pattern to avoid .sh files
        sed_inplace "s/^## \[$CURRENT_VERSION\]\(.*\)/## [NEXT_VERSION] - [UNRELEASED]\n* BUG: Example fix description.\n\n## [$CURRENT_VERSION]\1/" "CHANGELOG.md"

        if [ "$QUIET_MODE" != "true" ]; then
            echo "✅ Template changelog entry added to CHANGELOG.md"
        fi
    fi
}

function changelog_update_current_version() {
    local CURRENT_VERSION=$(get_version_package_json)

    # Update changelog in development branch before release
    if changelog_exists; then
        local CURRENT_DATE=$(date +%Y-%m-%d)

        # Replace [NEXT_VERSION] with the actual version and today's date
        if grep -q "## \[NEXT_VERSION\]" "CHANGELOG.md"; then
            sed_inplace "s/^## \[NEXT_VERSION\] - \[UNRELEASED\]/## [$CURRENT_VERSION] - $CURRENT_DATE/" "CHANGELOG.md"
            git add CHANGELOG.md >/dev/null 2>&1
            git commit -m "Update changelog for v$CURRENT_VERSION" >/dev/null 2>&1
        fi
    fi
}

# Interactive menu selection with cursor support
function interactive_menu_select() {
    local prompt="$1"
    shift
    local options=("$@")

    # Try fzf first (modern, best UX)
    if command -v fzf >/dev/null 2>&1; then
        local result=$(printf '%s\n' "${options[@]}" | fzf --height=10 --layout=reverse --border --prompt="Select: " --header="$prompt")
        local fzf_exit=$?
        if [ $fzf_exit -eq 0 ] && [ -n "$result" ]; then
            echo "$result"
            return 0
        else
            return 1
        fi
    fi

    # Try whiptail (good TUI)
    if command -v whiptail >/dev/null 2>&1; then
        local menu_items=()
        for i in "${!options[@]}"; do
            menu_items+=("$((i+1))" "${options[i]}")
        done

        local choice=$(whiptail --title "Version Bump" --menu "$prompt" 15 80 5 "${menu_items[@]}" 3>&1 1>&2 2>&3)
        local whiptail_exit=$?
        if [ $whiptail_exit -eq 0 ] && [ -n "$choice" ]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            return 1
        fi
    fi

    # Fallback to numbered menu (most compatible)
    echo "$prompt" >&2
    echo "" >&2
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[i]}" >&2
    done
    echo "" >&2

    while true; do
        read -p "Enter your choice (1-${#options[@]}): " choice >&2
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            local selected_option="${options[$((choice-1))]}"
            echo "$selected_option"
            return 0
        else
            echo "Invalid choice. Please enter a number between 1 and ${#options[@]}." >&2
        fi
    done
}

# Interactive version bump with type selection.
function package_version_bump_interactive() {
    local CURRENT_DIR=$(pwd)
    local CURRENT_DIR_BASENAME=$(basename "$CURRENT_DIR")
    local CURRENT_VERSION=$(get_version_package_json)

    local IS_WP_PLUGIN=false
    local IS_WP_THEME=false

    if [[ $PWD/ = */wp-content/plugins/* ]]; then
        IS_WP_PLUGIN=true
    fi

    if [[ $PWD/ = */wp-content/themes/* ]]; then
        IS_WP_THEME=true
    fi

    # Create menu options with version previews
    local options=(
        "major - Breaking changes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "major"))"
        "minor - New features (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "minor"))"
        "patch - Bug fixes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "patch"))"
        "hotfix - Critical fixes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "hotfix"))"
        "custom - Enter custom version"
    )

    # Use interactive menu with current version in heading
    local selected=$(interactive_menu_select "Current version is $CURRENT_VERSION. Choose the version for this release:" "${options[@]}")
    local menu_exit_code=$?

    if [ $menu_exit_code -ne 0 ] || [ -z "$selected" ]; then
        echo "Version bump cancelled."
        return 1
    fi

    # Extract bump type from selection
    local bump_type=$(echo "$selected" | cut -d' ' -f1)

    local NEW_VERSION
    if [ "$bump_type" = "custom" ]; then
        # Custom version input
        read -e -p "Enter custom version: " -i "$CURRENT_VERSION" NEW_VERSION
        if [ -z "$NEW_VERSION" ]; then
            echo "No version supplied. Exiting!"
            return 1
        fi
    else
        # Calculate new version based on bump type
        NEW_VERSION=$(calculate_new_version "$CURRENT_VERSION" "$bump_type")
    fi

    echo ""
    echo "Version will be updated from $CURRENT_VERSION to $NEW_VERSION ($bump_type)" >&2
    confirm "Continue with this version bump?"
    if [ $? == 1 ]; then
        echo "Version bump cancelled."
        return 1
    fi

    # Check if a changelog exists.
    if changelog_exists; then
        echo ">> Processing changelog..."

        # Check if there's a NEXT_VERSION entry at the top.
        CHANGELOG_TOP_ENTRY=$(grep -m 1 "## \[" CHANGELOG.md | sed -E 's/## \[([^]]*)\].*/\1/')

        if [ "$CHANGELOG_TOP_ENTRY" = "NEXT_VERSION" ]; then
            # NEXT_VERSION template found - this is good, changelog will be updated later in the release process
            echo "✅ Found [NEXT_VERSION] template in CHANGELOG.md - ready for release"
        else
            echo "WARNING: No [NEXT_VERSION] entry found at top of CHANGELOG.md"
            echo "   Top entry is: [$CHANGELOG_TOP_ENTRY]"
            echo "   Expected: [NEXT_VERSION] - [UNRELEASED]"

            if ! confirm "Continue without updating changelog?"; then
                echo "Release cancelled. Please add a [NEXT_VERSION] entry to CHANGELOG.md"
                return 1
            fi
        fi
    fi

    # Update package.json
    bump_version_package_json "$NEW_VERSION"
    echo "Updated version in package.json."

    # Update composer.json if it exists.
    local COMPOSER_JSON_FILENAME='composer.json'

    if [ -f "$COMPOSER_JSON_FILENAME" ]; then
        jq ".version = \"$NEW_VERSION\"" composer.json > composer.json.tmp && mv composer.json.tmp composer.json
        echo "Updated version in $COMPOSER_JSON_FILENAME."
    fi

    # Update public/manifest.json if it exists.
    local MANIFEST_JSON_FILENAME='public/manifest.json'

    if [ -f "$MANIFEST_JSON_FILENAME" ]; then
        jq ".version = \"$NEW_VERSION\"" $MANIFEST_JSON_FILENAME > $MANIFEST_JSON_FILENAME.tmp && mv $MANIFEST_JSON_FILENAME.tmp $MANIFEST_JSON_FILENAME
        echo "Updated version in $MANIFEST_JSON_FILENAME."
    fi

    # Update WordPress plugin/theme main file.
    if [ "$IS_WP_PLUGIN" = true ] || [ "$IS_WP_THEME" = true ]; then
        if command -v wp_plugin_bump_version >/dev/null 2>&1; then
            wp_plugin_bump_version "$NEW_VERSION"
        else
            echo "Warning: wp_plugin_bump_version function not available. Skipping WordPress file updates."
        fi
    fi

    # Replace [NEXT_VERSION] placeholders in all files.
    echo "Searching for [NEXT_VERSION] placeholders to replace with $NEW_VERSION..."
    local NEXT_VERSION_FILES

    # Find all files containing [NEXT_VERSION] (excluding binary files, node_modules, vendor, .git).
    if command -v grep >/dev/null 2>&1; then
        NEXT_VERSION_FILES=$(grep -r -l "\[NEXT_VERSION\]" . \
            --exclude-dir=node_modules \
            --exclude-dir=vendor \
            --exclude-dir=.git \
            --exclude-dir=tests \
            --exclude="*.zip" \
            --exclude="*.tar.gz" \
            --exclude="*.jpg" \
            --exclude="*.jpeg" \
            --exclude="*.png" \
            --exclude="*.gif" \
            --exclude="*.ico" \
            --exclude="*.pdf" \
            --exclude="*.woff" \
            --exclude="*.woff2" \
            --exclude="*.ttf" \
            --exclude="*.eot" \
            --exclude="*.svg" \
            --exclude="*.mp4" \
            --exclude="*.mp3" \
            --exclude="*.wav" \
            --exclude="*.lock" \
            --exclude="*.sh" \
            2>/dev/null || true)

        if [ -n "$NEXT_VERSION_FILES" ]; then
            echo "Found [NEXT_VERSION] placeholders in the following files:"
            echo "$NEXT_VERSION_FILES" | while IFS= read -r file; do
                echo "  - $file"
            done
            echo ""

            # Replace [NEXT_VERSION] with the actual version in each file.
            echo "$NEXT_VERSION_FILES" | while IFS= read -r file; do
                if [ -f "$file" ]; then
                    # Use sed to replace [NEXT_VERSION] with the new version.
                    if command -v sed >/dev/null 2>&1; then
                        sed_inplace "s/\[NEXT_VERSION\]/$NEW_VERSION/g" "$file"
                        echo "Updated [NEXT_VERSION] → $NEW_VERSION in $file"
                    fi
                fi
            done
        else
            echo "No [NEXT_VERSION] placeholders found."
        fi
    else
        echo "grep command not available, skipping [NEXT_VERSION] replacement."
    fi

    # Commit changes.
    git add .
    if command -v gc >/dev/null 2>&1; then
        gc "Version $NEW_VERSION bump."
    else
        git commit -m "Version $NEW_VERSION bump."
    fi

    echo "Version bump to $NEW_VERSION complete."
}

function package_version_bump_auto() {
    local bump_type="$1"
    local current_version=$(get_version_package_json)

    local new_version=$(calculate_new_version "$current_version" "$bump_type")

    echo "Auto-bumping version from $current_version to $new_version ($bump_type)"

    local IS_WP_PLUGIN=false
    local IS_WP_THEME=false

    if [[ $PWD/ = */wp-content/plugins/* ]]; then
        IS_WP_PLUGIN=true
    fi

    if [[ $PWD/ = */wp-content/themes/* ]]; then
        IS_WP_THEME=true
    fi

    # Check if a changelog exists and update it
    if changelog_exists; then
        # Check if there's a NEXT_VERSION entry at the top
        CHANGELOG_TOP_ENTRY=$(grep -m 1 "## \[" CHANGELOG.md | sed -E 's/## \[([^]]*)\].*/\1/')

        if [ "$CHANGELOG_TOP_ENTRY" = "NEXT_VERSION" ]; then
            # Update NEXT_VERSION entry with version and current date
            CURRENT_DATE=$(date +%Y-%m-%d)

            # Handle both old format [NEXT_VERSION] and new format [NEXT_VERSION] - [UNRELEASED]
            if grep -q "## \\[NEXT_VERSION\\] - \\[UNRELEASED\\]" CHANGELOG.md; then
                sed_inplace "0,/^## \\[NEXT_VERSION\\] - \\[UNRELEASED\\]/ s/^## \\[NEXT_VERSION\\] - \\[UNRELEASED\\]/## [$new_version] - $CURRENT_DATE/" CHANGELOG.md
            else
                sed_inplace "0,/^## \\[NEXT_VERSION\\]/ s/^## \\[NEXT_VERSION\\].*$/## [$new_version] - $CURRENT_DATE/" CHANGELOG.md
            fi
            echo "Updated NEXT_VERSION entry in CHANGELOG.md to [$new_version] - $CURRENT_DATE."
        fi
    fi

    # Update package.json
    bump_version_package_json "$new_version"
    echo "Updated version in package.json."

    # Update composer.json if it exists
    if [ -f "composer.json" ]; then
        jq ".version = \"$new_version\"" composer.json > composer.json.tmp && mv composer.json.tmp composer.json
        echo "Updated version in composer.json."
    fi

    # Update public/manifest.json if it exists
    if [ -f "public/manifest.json" ]; then
        jq ".version = \"$new_version\"" public/manifest.json > public/manifest.json.tmp && mv public/manifest.json.tmp public/manifest.json
        echo "Updated version in public/manifest.json."
    fi

    # Update WordPress plugin/theme main file
    if [ "$IS_WP_PLUGIN" = true ] || [ "$IS_WP_THEME" = true ]; then
        if command -v wp_plugin_bump_version >/dev/null 2>&1; then
            wp_plugin_bump_version "$new_version"
        else
            echo "Warning: wp_plugin_bump_version function not available. Skipping WordPress file updates."
        fi
    fi

    # Replace [NEXT_VERSION] placeholders in all files
    if command -v grep >/dev/null 2>&1; then
        NEXT_VERSION_FILES=$(grep -r -l "\[NEXT_VERSION\]" . \
            --exclude-dir=node_modules \
            --exclude-dir=vendor \
            --exclude-dir=.git \
            --exclude-dir=tests \
            --exclude="*.zip" \
            --exclude="*.tar.gz" \
            --exclude="*.jpg" \
            --exclude="*.jpeg" \
            --exclude="*.png" \
            --exclude="*.gif" \
            --exclude="*.ico" \
            --exclude="*.pdf" \
            --exclude="*.woff" \
            --exclude="*.woff2" \
            --exclude="*.ttf" \
            --exclude="*.eot" \
            --exclude="*.svg" \
            --exclude="*.mp4" \
            --exclude="*.mp3" \
            --exclude="*.wav" \
            --exclude="*.lock" \
            --exclude="*.sh" \
            --exclude="CHANGELOG.md" \
            2>/dev/null || true)

        if [ -n "$NEXT_VERSION_FILES" ]; then
            echo "$NEXT_VERSION_FILES" | while IFS= read -r file; do
                if [ -f "$file" ]; then
                    sed_inplace "s/\[NEXT_VERSION\]/$new_version/g" "$file"
                    echo "Updated [NEXT_VERSION] → $new_version in $file"
                fi
            done
        fi
    fi

    # Commit changes
    git add .
    if command -v gc >/dev/null 2>&1; then
        gc "Version $new_version bump."
    else
        git commit -m "Version $new_version bump."
    fi

    echo "Version bump to $new_version complete."
}

# Copy folder with configurable exclusions using robocopy or rsync
function copy_folder() {
    local source_dir=""
    local dest_dir=""
    local quiet_mode="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode="true"
                shift
                ;;
            *)
                if [ -z "$source_dir" ]; then
                    source_dir="$1"
                elif [ -z "$dest_dir" ]; then
                    dest_dir="$1"
                else
                    echo "Error: Too many arguments for copy_folder"
                    echo "Usage: copy_folder <source_dir> <dest_dir> [--quiet]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then
        echo "Error: Missing required arguments for copy_folder"
        echo "Usage: copy_folder <source_dir> <dest_dir> [--quiet]"
        return 1
    fi

    # Default exclusions list
    local default_exclusions=(
        "node_modules"
        ".git"
        ".github"
        ".gitignore"
        "vendor"
        "tests"
        ".github"
        "*.log"
        ".DS_Store"
        "Thumbs.db"
        "*.tmp"
        ".vscode"
        "*.bak"
        ".wakatime-project"
        "bin"
    )

    # Use custom exclusions if provided, otherwise use defaults
    local exclusions=("${COPY_EXCLUSIONS[@]:-${default_exclusions[@]}}")

    if [ "$quiet_mode" != "true" ]; then
        echo "Copying files from $source_dir to $dest_dir"
    fi

    # Get the best available copy tool
    local copy_tool=$(get_copy_tool)

    if [ -z "$copy_tool" ]; then
        echo "❌ Error: No copy utility found (robocopy, rsync, tar, or cp required)"
        return 1
    fi

    # Ensure destination directory exists
    create_directory "$dest_dir"

    case "$copy_tool" in
        "robocopy")
            if [ "$quiet_mode" != "true" ]; then
                echo "Using robocopy..."
            fi

            # Convert to Windows paths for robocopy
            local source_dir_posix=$(convert_path_for_windows_tools "$source_dir")
            local dest_dir_posix=$(convert_path_for_windows_tools "$dest_dir")

            # Build exclusion arguments for robocopy using helper function
            local robocopy_exclusions=($(get_robocopy_exclusions "${exclusions[@]}"))

            # Windows robocopy (handle exit codes properly)
            set +e  # Temporarily disable exit on error for robocopy
            if [ "$quiet_mode" = "true" ]; then
                robocopy "$source_dir_posix" "$dest_dir_posix" //MIR //NS //NC //NFL //NDL //NJH //NJS //NP "${robocopy_exclusions[@]}" >/dev/null 2>&1
            else
                robocopy "$source_dir_posix" "$dest_dir_posix" //MIR //NS //NC //NFL //NDL //NJH //NJS //NP "${robocopy_exclusions[@]}"
            fi
            local robocopy_exit=$?
            set -e  # Re-enable exit on error

            # robocopy exit codes: 0=no files, 1=files copied, 2=extra files, 4=mismatched, 8+=errors
            if [ $robocopy_exit -ge 8 ]; then
                echo "❌ Error: robocopy failed with exit code $robocopy_exit"
                return 1
            fi
            ;;
        "rsync")
            if [ "$quiet_mode" != "true" ]; then
                echo "Using rsync..."
            fi

            # Build exclusion arguments for rsync using helper function
            local rsync_exclusions=($(get_rsync_exclusions "${exclusions[@]}"))

            if [ "$quiet_mode" = "true" ]; then
                rsync -aq "${rsync_exclusions[@]}" "$source_dir/" "$dest_dir/"
            else
                rsync -aqv "${rsync_exclusions[@]}" "$source_dir/" "$dest_dir/"
            fi
            ;;
        "tar")
            if [ "$quiet_mode" != "true" ]; then
                echo "Using tar with exclusions..."
            fi

            # Build exclusion arguments for tar using helper function
            local tar_exclusions=($(get_tar_exclusions "${exclusions[@]}"))

            # Use tar to copy with exclusions via pipe
            if [ "$quiet_mode" = "true" ]; then
                (cd "$source_dir" && tar cf - "${tar_exclusions[@]}" .) | (cd "$dest_dir" && tar xf -) 2>/dev/null
            else
                (cd "$source_dir" && tar cf - "${tar_exclusions[@]}" .) | (cd "$dest_dir" && tar xf -)
            fi
            ;;
        "cp")
            if [ "$quiet_mode" != "true" ]; then
                echo "Using cp (basic copy, no exclusions)..."
            fi

            # Note: cp doesn't support exclusions, so we do a basic copy
            cp -r "$source_dir/." "$dest_dir/"
            ;;
        *)
            echo "❌ Error: Unknown copy tool: $copy_tool"
            return 1
            ;;
    esac

    if [ "$quiet_mode" != "true" ]; then
        echo "✅ Folder copied successfully from $source_dir to $dest_dir"
    fi
}

# Create ZIP file with configurable exclusions
function zip_folder() {
    local source_dir=""
    local zip_filename=""
    local zip_name=""
    local quiet_mode="false"
    local arg_count=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode="true"
                shift
                ;;
            *)
                arg_count=$((arg_count + 1))
                case $arg_count in
                    1)
                        source_dir="$1"
                        ;;
                    2)
                        zip_filename="$1"
                        ;;
                    3)
                        zip_name="$1"
                        ;;
                    *)
                        echo "Error: Too many arguments for zip_folder"
                        echo "Usage: zip_folder <source_dir> <zip_filename> <zip_name> [--quiet]"
                        return 1
                        ;;
                esac
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$source_dir" ] || [ -z "$zip_filename" ] || [ -z "$zip_name" ]; then
        echo "Error: Missing required arguments for zip_folder"
        echo "Usage: zip_folder <source_dir> <zip_filename> <zip_name> [--quiet]"
        return 1
    fi

    # Check if either zip or 7z is available
    if ! command -v zip >/dev/null 2>&1 && ! command -v 7z.exe >/dev/null 2>&1; then
        echo "❌ Error: Neither zip nor 7zip found. One is required for folder compression."
        return 1
    fi

    # Default exclusions list
    local default_exclusions=(
        "*.git*"
        "*.dist"
        ".env*"
        "composer.*"
        "package.json"
        "package-lock.json"
        "*.lock"
        "webpack.config.js"
        "*.map"
        ".babelrc"
        "postcss.config.js"
        ".cache"
        "./tests"
        ".husky"
        "playwright*"
        ".wakatime*"
        ".eslint*"
        "eslint*"
        ".dist*"
        ".nvmrc"
        ".vscode"
        ".editorconfig"
        "./codecov"
        "assets/src"
        "*/assets/src"
        "*/*/assets/src"
        "*/*/*/assets/src"
        "assets/*/src"
        "*/assets/*/src"
        "test-results"
        "./bin"
        ".distignore"
        "vite.config.js"
    )

    # Check if we should exclude node_modules directory based on dependencies.
    if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
        local dependencies_length=$(jq '.dependencies | length' package.json 2>/dev/null || echo "0")

        if [[ $dependencies_length -eq 0 ]]; then
            default_exclusions+=("./node_modules")
        fi
    else
        # No package.json or jq not available, exclude node_modules directory by default.
        default_exclusions+=("./node_modules")
    fi

    # Check if we should exclude vendor directory based on dependencies.
    # Only exclude vendor if the project has no production dependencies (or only PHP requirement).
    if [ -f "composer.json" ] && command -v jq >/dev/null 2>&1; then
        local require_length=$(jq '.require | length' composer.json 2>/dev/null || echo "0")
        local has_php_only=$(jq '.require | keys | length == 1 and .[0] == "php"' composer.json 2>/dev/null || echo "false")

        if [[ $require_length -eq 0 ]] || [[ "$has_php_only" == "true" ]]; then
            # No production dependencies or only PHP requirement, exclude vendor directory.
            default_exclusions+=("./vendor")
        fi
    else
        # No composer.json or jq not available, exclude vendor directory by default.
        default_exclusions+=("./vendor")
    fi

    # Check if is_wp_block_plugin function exists and call it if available
    if command -v is_wp_block_plugin >/dev/null 2>&1 && is_wp_block_plugin; then
        default_exclusions+=("src" "./src" "*/src")
    fi

    # Load custom exclusions - prioritize early-read exclusions from wp_create_release
    local custom_exclusions=()
    if [ -n "${WP_BUILD_CUSTOM_EXCLUSIONS[*]}" ]; then
        # Use exclusions read early in wp_create_release (includes .wp-build-exclusions file itself)
        custom_exclusions=("${WP_BUILD_CUSTOM_EXCLUSIONS[@]}")
    elif [ -f ".wp-build-exclusions" ]; then
        # Fallback: read .wp-build-exclusions file if it exists (for direct zip_folder calls)
        while IFS= read -r line; do
            # Skip empty lines and comments (lines starting with #)
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                custom_exclusions+=("$line")
            fi
        done < ".wp-build-exclusions"
        # Add .wp-build-exclusions itself to exclusions
        custom_exclusions+=(".wp-build-exclusions")
    fi

    # Combine default exclusions with custom exclusions
    local all_exclusions=("${default_exclusions[@]}" "${custom_exclusions[@]}")

    # Use ZIP_EXCLUSIONS environment variable if set, otherwise use combined exclusions
    local exclusions=("${ZIP_EXCLUSIONS[@]:-${all_exclusions[@]}}")

    if [ "$quiet_mode" != "true" ]; then
        echo "Creating ZIP file: $zip_filename"
    fi

    # Get the best available compression tool
    local compression_tool=$(get_compression_tool)

    if [ -z "$compression_tool" ]; then
        echo "❌ Error: No compression utility found (zip, 7z.exe, 7z, or 7za required)"
        return 1
    fi

    case "$compression_tool" in
        "zip")
            if [ "$quiet_mode" != "true" ]; then
                echo "Using zip command..."
            fi

            # Get the parent directory of the source directory
            local source_parent=$(dirname "$source_dir")
            cd "$source_parent"

            local zip_excludes=()
            for exclusion in "${exclusions[@]}"; do
                # Handle different exclusion patterns for zip command
                if [[ "$exclusion" == ./* ]]; then
                    # Remove ./ prefix for zip command
                    local clean_exclusion="${exclusion#./}"
                    zip_excludes+=("-x" "${zip_name}/${clean_exclusion}" "${zip_name}/${clean_exclusion}/*")
                elif [[ "$exclusion" == */* ]]; then
                    # Path with subdirectories
                    zip_excludes+=("-x" "${zip_name}/${exclusion}" "${zip_name}/${exclusion}/*")
                else
                    # Simple file/directory name
                    zip_excludes+=("-x" "${zip_name}/${exclusion}" "${zip_name}/${exclusion}/*" "*/${exclusion}" "*/${exclusion}/*")
                fi
            done

            zip -r -q "$zip_filename" "$zip_name" "${zip_excludes[@]}"
            ;;
        "7z.exe"|"7z"|"7za")
            if [ "$quiet_mode" != "true" ]; then
                echo "Using $compression_tool..."
            fi

            # Build exclusion arguments for 7z using helper function
            local sevenz_exclusions=($(get_7z_exclusions "${exclusions[@]}"))

            if [ "$quiet_mode" = "true" ]; then
                "$compression_tool" a "$zip_filename" "$source_dir" "${sevenz_exclusions[@]}" >/dev/null 2>&1
            else
                "$compression_tool" a "$zip_filename" "$source_dir" "${sevenz_exclusions[@]}"
            fi
            ;;
        *)
            echo "❌ Error: Unknown compression tool: $compression_tool"
            return 1
            ;;
    esac

    if [ "$quiet_mode" != "true" ]; then
        echo "✅ ZIP file created successfully: $zip_filename"
    fi
}

# Build project for production with package manager detection and dependency management
function build_for_production() {
    local quiet_mode="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode="true"
                shift
                ;;
            *)
                echo "Error: Unknown argument '$1' for build_for_production"
                echo "Usage: build_for_production [--quiet]"
                return 1
                ;;
        esac
    done

    if [ "$quiet_mode" != "true" ]; then
        echo "🏗️  Building project for production..."
    fi

    # Detect package manager
    local PACKAGE_MANAGER
    if [ -f "yarn.lock" ]; then
        PACKAGE_MANAGER="yarn"
    elif [ -f "package.json" ]; then
        PACKAGE_MANAGER="npm"
    else
        if [ "$quiet_mode" != "true" ]; then
            echo "⚠️  No package.json found, skipping Node.js build steps"
        fi
        PACKAGE_MANAGER=""
    fi

    # Check if we have build scripts that need to run
    local has_build_script=false
    local build_script=""
    if [ -n "$PACKAGE_MANAGER" ]; then
        if jq -e '.scripts.production' package.json >/dev/null 2>&1; then
            has_build_script=true
            build_script="production"
        elif jq -e '.scripts.build' package.json >/dev/null 2>&1; then
            has_build_script=true
            build_script="build"
        fi
    fi

    # Check if we have production dependencies
    local has_production_deps=false
    if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
        local deps_length=$(jq '.dependencies | length' package.json 2>/dev/null || echo "0")
        if [[ $deps_length -gt 0 ]]; then
            has_production_deps=true
        fi
    fi

    # Install dependencies and build if needed
    if [ -n "$PACKAGE_MANAGER" ] && [ "$has_build_script" = true ]; then
        if [ "$quiet_mode" != "true" ]; then
            echo "📦 Using package manager: $PACKAGE_MANAGER"
            echo "🔨 Build script detected: $build_script"
        fi

        if [ "$PACKAGE_MANAGER" = "yarn" ]; then
            if [ "$quiet_mode" != "true" ]; then
                echo "🧹 Installing dependencies with yarn..."
                yarn --silent install --frozen-lockfile
            else
                yarn --silent install --frozen-lockfile >/dev/null 2>&1
            fi

            if [ "$quiet_mode" != "true" ]; then
                echo "🔨 Running $build_script build with yarn..."
            fi
            if [ "$quiet_mode" = "true" ]; then
                yarn --silent run "$build_script" >/dev/null 2>&1
            else
                if yarn --silent run "$build_script" >/dev/null 2>&1; then
                    echo "✅ Yarn $build_script build completed successfully"
                else
                    echo "❌ Yarn $build_script build failed"
                    return 1
                fi
            fi
        else
            if [ "$quiet_mode" != "true" ]; then
                echo "🧹 Installing dependencies with npm..."
                npm --silent ci
            else
                npm --silent ci >/dev/null 2>&1
            fi

            if [ "$quiet_mode" != "true" ]; then
                echo "🔨 Running $build_script build with npm..."
            fi
            if [ "$quiet_mode" = "true" ]; then
                npm run --silent "$build_script" >/dev/null 2>&1
            else
                if npm run --silent "$build_script" >/dev/null 2>&1; then
                    echo "✅ NPM $build_script build completed successfully"
                else
                    echo "❌ NPM $build_script build failed"
                    return 1
                fi
            fi
        fi

        # Clean up node_modules if no production dependencies
        if [ "$has_production_deps" = false ]; then
            if [ "$quiet_mode" != "true" ]; then
                echo "🧹 No production dependencies found, removing node_modules..."
            fi
            rm -rf node_modules
        else
            # Prune dev dependencies after build
            if [ "$quiet_mode" != "true" ]; then
                echo "🧹 Pruning development dependencies..."
            fi
            if [ "$PACKAGE_MANAGER" = "yarn" ]; then
                if [ "$quiet_mode" = "true" ]; then
                    yarn --silent install --production=true >/dev/null 2>&1 || true
                else
                    yarn --silent install --production=true || true
                fi
            else
                if [ "$quiet_mode" = "true" ]; then
                    npm --silent prune --omit=dev >/dev/null 2>&1
                else
                    npm --silent prune --omit=dev
                fi
            fi
        fi
    elif [ -n "$PACKAGE_MANAGER" ]; then
        if [ "$quiet_mode" != "true" ]; then
            echo "⚠️  No build scripts found in package.json, skipping npm build"
        fi
    fi

    # Handle Composer dependencies if they exist
    if [ -f "composer.json" ] && command -v composer >/dev/null 2>&1; then
        if command -v jq >/dev/null 2>&1; then
            local require_length=$(jq '.require | length' composer.json 2>/dev/null || echo "0")
            local has_php_only=$(jq '.require | keys | length == 1 and .[0] == "php"' composer.json 2>/dev/null || echo "false")

            if [[ $require_length -gt 0 ]] && [[ "$has_php_only" != "true" ]]; then
                if [ "$quiet_mode" != "true" ]; then
                    echo "📦 Project has Composer production dependencies"
                    # Use install instead of update to avoid dependency conflicts
                    if composer install --quiet --no-dev --optimize-autoloader --no-interaction; then
                        echo "✅ Composer dependencies installed for production"
                    else
                        echo "❌ Composer install failed, trying update as fallback"
                        composer update --quiet --no-dev --optimize-autoloader --no-interaction
                        echo "✅ Composer dependencies updated for production"
                    fi
                else
                    # Try install first, fallback to update if it fails
                    if ! composer install --quiet --no-dev --optimize-autoloader --no-interaction >/dev/null 2>&1; then
                        composer update --quiet --no-dev --optimize-autoloader --no-interaction >/dev/null 2>&1
                    fi
                fi
            else
                if [ "$quiet_mode" != "true" ]; then
                    echo "ℹ️  Project has no Composer production dependencies, skipping composer update"
                fi
            fi
        else
            if [ "$quiet_mode" != "true" ]; then
                echo "⚠️  jq not available, cannot check Composer dependencies"
            fi
        fi
    elif [ -f "composer.json" ]; then
        if [ "$quiet_mode" != "true" ]; then
            echo "⚠️  composer.json found but Composer not available"
        fi
    fi

    if [ "$quiet_mode" != "true" ]; then
        echo "✅ Production build completed successfully"
    fi
}

# Compare two versions (returns 0 if v1 < v2, 1 if v1 >= v2)
function version_lt() {
    local v1="$1"
    local v2="$2"

    # Remove 'v' prefix if present
    v1=${v1#v}
    v2=${v2#v}

    # Use sort -V for version comparison
    if [ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" = "$v1" ] && [ "$v1" != "$v2" ]; then
        return 0
    else
        return 1
    fi
}

# Calculate new version based on bump type
function calculate_new_version() {
    local current_version="$1"
    local bump_type="$2"

    IFS='.' read -ra VERSION_PARTS <<< "$current_version"

    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}
    local hotfix=${VERSION_PARTS[3]:-}

    case $bump_type in
        "patch")
            patch=$((patch + 1))
            hotfix=""
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            hotfix=""
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            hotfix=""
            ;;
        "hotfix")
            if [ -z "$hotfix" ]; then
                hotfix=1
            else
                hotfix=$((hotfix + 1))
            fi
            ;;
        *)
            echo "Invalid bump type: $bump_type. Use patch, minor, major, or hotfix."
            return 1
            ;;
    esac

    if [ -n "$hotfix" ]; then
        echo "$major.$minor.$patch.$hotfix"
    else
        echo "$major.$minor.$patch"
    fi
}