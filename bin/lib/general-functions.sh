#!/bin/bash

# General utility functions for release script.
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

# File existence check.
function file_exists() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    return 0
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

# Check if changelog exists.
function changelog_exists() {
    if file_exists "CHANGELOG.md"; then
        return 0
    else
        return 1
    fi
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

# Check if current directory has production script.
function current_dir_has_production_script() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required but not installed." >&2
        return 1
    fi

    local LENGTH=$(jq '.scripts.production | length' package.json 2>/dev/null || echo "0")

    if [[ $LENGTH -gt 0 ]]; then
        echo "Package has a production build."
        return 0
    fi

    echo "Package does not have a production build."
    return 1
}

# Check if current directory has build script.
function current_dir_has_build_script() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required but not installed." >&2
        return 1
    fi

    local LENGTH=$(jq '.scripts.build | length' package.json 2>/dev/null || echo "0")

    if [[ $LENGTH -gt 0 ]]; then
        echo "Package has a build script."
        return 0
    fi

    echo "Package does not have a build script."
    return 1
}

# Check if release workflow exists.
function release_workflow_exists() {
    if [ -f .github/workflows/release.yml ] || [ -f .github/workflows/release.yaml ]; then
        return 0
    fi

    if ls .github/workflows/release-*.yml >/dev/null 2>&1 || ls .github/workflows/release-*.yaml >/dev/null 2>&1; then
        return 0
    fi

    return 1
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

    echo "Current package version is $CURRENT_VERSION"
    echo ""
    echo "Select version bump type:"
    echo "  1) patch   - Bug fixes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "patch"))"
    echo "  2) minor   - New features (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "minor"))"
    echo "  3) major   - Breaking changes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "major"))"
    echo "  4) hotfix  - Critical fixes, adds 4th segment (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "hotfix"))"
    echo "  5) custom  - Enter custom version"
    echo ""

    local choice
    while true; do
        read -p "Enter your choice (1-5): " choice
        case $choice in
            1) local bump_type="patch"; break;;
            2) local bump_type="minor"; break;;
            3) local bump_type="major"; break;;
            4) local bump_type="hotfix"; break;;
            5) local bump_type="custom"; break;;
            *) echo "Invalid choice. Please enter 1-5.";;
        esac
    done

    local NEW_VERSION
    if [ "$bump_type" = "custom" ]; then
        # Custom version input.
        read -e -p "Enter custom version: " -i "$CURRENT_VERSION" NEW_VERSION
        if [ -z "$NEW_VERSION" ]; then
            echo "No version supplied. Exiting!"
            exit 1
        fi
    else
        # Calculate new version based on bump type.
        NEW_VERSION=$(calculate_new_version "$CURRENT_VERSION" "$bump_type")
    fi

    echo ""
    echo "Version will be updated from $CURRENT_VERSION to $NEW_VERSION ($bump_type)"
    confirm "Continue with this version bump?"
    if [ $? == 1 ]; then
        echo "Version bump cancelled."
        exit 1
    fi

    # Update package.json.
    bump_version_package_json "$NEW_VERSION"
    echo "Updated version in package.json."

    # Update composer.json if it exists.
    local COMPOSER_JSON_FILENAME='composer.json'
    if [ -f "$COMPOSER_JSON_FILENAME" ]; then
        jq ".version = \"$NEW_VERSION\"" composer.json > composer.json.tmp && mv composer.json.tmp composer.json
        echo "Updated version in $COMPOSER_JSON_FILENAME."
    fi

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

    # Update WordPress plugin/theme main file.
    if [ "$IS_WP_PLUGIN" = true ] || [ "$IS_WP_THEME" = true ]; then
        wp_plugin_bump_version "$NEW_VERSION"
    fi

    # Update public/manifest.json if it exists.
    local MANIFEST_JSON_FILENAME='public/manifest.json'

    if [ -f "$MANIFEST_JSON_FILENAME" ]; then
        jq ".version = \"$NEW_VERSION\"" $MANIFEST_JSON_FILENAME > $MANIFEST_JSON_FILENAME.tmp && mv $MANIFEST_JSON_FILENAME.tmp $MANIFEST_JSON_FILENAME
        echo "Updated version in $MANIFEST_JSON_FILENAME."
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
                        sed -i "s/\[NEXT_VERSION\]/$NEW_VERSION/g" "$file"
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
    gc "Version $NEW_VERSION bump."

    echo "Version bump to $NEW_VERSION complete."
}

# Calculate new version based on bump type.
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

# Calculate new version based on bump type.
function package_version_bump_auto() {
    local bump_type="$1"
    local current_version=$(get_version_package_json)

    local new_version=$(calculate_new_version "$current_version" "$bump_type")

    echo "Auto-bumping version from $current_version to $new_version ($bump_type)"

    # Update package.json.
    bump_version_package_json "$new_version"
    echo "Updated version in package.json."

    # Commit changes.
    git add .
    gc "Version $new_version bump."

    echo "Version bump to $new_version complete."
}
