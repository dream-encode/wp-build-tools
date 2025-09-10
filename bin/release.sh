#!/bin/bash

# WordPress Plugin Release Script
# Based on git_create_release function from bash includes
# Usage: ./bin/release.sh [patch|minor|major|hotfix]
#   - No argument: Interactive mode with version bump type selection
#   - patch: Bug fixes (1.0.0 → 1.0.1)
#   - minor: New features (1.0.0 → 1.1.0)
#   - major: Breaking changes (1.0.0 → 2.0.0)
#   - hotfix: Critical fixes, adds 4th segment (1.0.0 → 1.0.0.1)

set -e

# Get the directory where this script is located.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source configuration if it exists.
if [ -f "$SCRIPT_DIR/config/release.conf" ]; then
    source "$SCRIPT_DIR/config/release.conf"
fi

# Source helper functions.
source "$SCRIPT_DIR/lib/general-functions.sh"
source "$SCRIPT_DIR/lib/git-functions.sh"
source "$SCRIPT_DIR/lib/wp-functions.sh"

# Change to project root - but if we're in node_modules, use the actual project root.
cd "$PROJECT_ROOT"

# If we're in a node_modules directory, find the actual project root.
if [[ "$PWD" == */node_modules/* ]]; then
    ACTUAL_PROJECT_ROOT="$PWD"

    while [[ "$ACTUAL_PROJECT_ROOT" == */node_modules/* ]]; do
        ACTUAL_PROJECT_ROOT="$(dirname "$ACTUAL_PROJECT_ROOT")"
    done

    # Go up one more level to get out of the node_modules directory itself
    ACTUAL_PROJECT_ROOT="$(dirname "$ACTUAL_PROJECT_ROOT")"

    cd "$ACTUAL_PROJECT_ROOT"
fi

# Set some vars.
CURRENT_DIR=$(pwd)
BASENAME=$(basename "$CURRENT_DIR")

CURRENT_BRANCH=$(git branch --show-current)

# Check if we're on an allowed release branch.
if [ "$CURRENT_BRANCH" != "development" ] && [ "$CURRENT_BRANCH" != "hotfix" ]; then
    echo "❌ Error: Releases can only be created from 'development' or 'hotfix' branches."
    echo "   Current branch: $CURRENT_BRANCH"
    echo "   Please switch to 'development' or 'hotfix' branch before releasing."
    exit 1
fi

PACKAGE_MANAGER=$(get_package_manager_for_project)
CURRENT_VERSION=$(get_version_package_json)

echo ">> Starting release process for $BASENAME"
echo ">> Current branch: $CURRENT_BRANCH"
echo ">> Current version: $CURRENT_VERSION"
echo ">> Package manager: $PACKAGE_MANAGER"
echo ""

# Check for debugging code.
if ! wp_check_debugging_code; then
    echo "❌ Found debugging code in plugin. Please correct before releasing."
    exit 1
fi

# Detect project type.
IS_WP_PLUGIN=false
IS_WP_THEME=false
IS_WP_BLOCK_PLUGIN=false

if [[ $PWD/ = */wp-content/plugins/* ]]; then
    IS_WP_PLUGIN=true

    # Check if this is specifically a block plugin.
    if is_wp_block_plugin; then
        IS_WP_BLOCK_PLUGIN=true
    fi
fi

if [[ $PWD/ = */wp-content/themes/* ]]; then
    IS_WP_THEME=true
fi

echo ">> Project type detection:"
echo "   Plugin: $IS_WP_PLUGIN"
echo "   Theme: $IS_WP_THEME"
echo "   Block Plugin: $IS_WP_BLOCK_PLUGIN"
echo ""

# Maybe update Action Scheduler library for WP plugins.
if [ "$IS_WP_PLUGIN" = true ] && [ -d "libraries/action-scheduler" ]; then
    echo ">> Found Action Scheduler library. Checking for updates..."

    # Check if the Action Scheduler remote exists.
    if ! git remote | grep -q "subtree-action-scheduler"; then
        echo "Adding Action Scheduler remote..."
        git remote add -f subtree-action-scheduler https://github.com/woocommerce/action-scheduler.git
    else
        echo "Fetching latest Action Scheduler updates..."
        git fetch subtree-action-scheduler trunk
    fi

    # Update the Action Scheduler subtree.
    echo "Updating Action Scheduler to latest version..."
    git subtree pull --prefix libraries/action-scheduler subtree-action-scheduler trunk --squash

    # Check if there were any changes.
    if git diff --quiet HEAD~1 HEAD -- libraries/action-scheduler; then
        echo "Action Scheduler is already up to date."
    else
        echo "Action Scheduler updated successfully."
    fi
fi

# Maybe update POT file for WP plugins and themes.
if [ "$IS_WP_PLUGIN" = true ] || [ "$IS_WP_THEME" = true ]; then
    echo ">> Updating translation files..."
    wp_plugin_update_pot

    git add languages/*
    gc "Updating POT"
    echo "Updated languages/$BASENAME.pot."
fi

# Version bump.
echo ">> Version management:"

# Check if a changelog exists.
if changelog_exists; then
    echo ">> Processing changelog..."

    # Check if there's a NEXT_VERSION entry at the top.
    CHANGELOG_TOP_ENTRY=$(grep -m 1 "## \[" CHANGELOG.md | sed -E 's/## \[([^]]*)\].*/\1/')

    if [ "$CHANGELOG_TOP_ENTRY" = "NEXT_VERSION" ]; then
        # Update NEXT_VERSION entry with version and current date.
        CURRENT_DATE=$(date +%Y-%m-%d)

        # Handle both old format [NEXT_VERSION] and new format [NEXT_VERSION] - [UNRELEASED]
        if grep -q "## \\[NEXT_VERSION\\] - \\[UNRELEASED\\]" CHANGELOG.md; then
            sed -i "0,/## \\[NEXT_VERSION\\] - \\[UNRELEASED\\]/ s/## \\[NEXT_VERSION\\] - \\[UNRELEASED\\]/## [$CURRENT_VERSION] - $CURRENT_DATE/" CHANGELOG.md
        else
            sed -i "0,/## \\[NEXT_VERSION\\]/ s/## \\[NEXT_VERSION\\].*$/## [$CURRENT_VERSION] - $CURRENT_DATE/" CHANGELOG.md
        fi
        echo "Updated NEXT_VERSION entry in CHANGELOG.md to [$CURRENT_VERSION] - $CURRENT_DATE."

        # Commit the updated changelog.
        git add CHANGELOG.md
        gc "Update CHANGELOG.md for release $CURRENT_VERSION"
    else
        echo "WARNING: No [NEXT_VERSION] entry found at top of CHANGELOG.md"
        echo "   Top entry is: [$CHANGELOG_TOP_ENTRY]"
        echo "   Expected: [NEXT_VERSION] or [NEXT_VERSION] - [UNRELEASED]"

        if ! confirm "Continue without updating changelog?"; then
            echo "Release cancelled. Please add a [NEXT_VERSION] entry to CHANGELOG.md"
            return 1
        fi
    fi
fi

# Handle version bump - either from command line argument or interactive.
if [ ! -z "$1" ]; then
    # Command line argument provided (patch, minor, major, hotfix).
    case "$1" in
        "patch"|"minor"|"major"|"hotfix")
            echo "Auto-bumping version ($1)..."
            package_version_bump_auto "$1"
            ;;
        *)
            echo "❌ Invalid version bump type: $1"
            echo "Valid options: patch, minor, major, hotfix"
            exit 1
            ;;
    esac
else
    # Interactive mode - ask if they want to bump version.
    if confirm "Current version in package.json is $CURRENT_VERSION. Do you want to bump the version now?"; then
        package_version_bump_interactive
    else
        echo "Staying at version $CURRENT_VERSION."
    fi
fi

# Refresh the version, as it may have changed.
CURRENT_VERSION=$(get_version_package_json)

echo ">> Pushing latest code to $CURRENT_BRANCH..."
gpu

echo ">> Creating release branch...."
git checkout -b "release/$CURRENT_VERSION"

echo ">> Pushing release branch to origin..."
git push --set-upstream origin "release/$CURRENT_VERSION"

# Tag the version.
echo ">> Creating release tag..."
git_tag_release "$CURRENT_VERSION"

git_post_create_release "$CURRENT_VERSION" "$CURRENT_BRANCH"

# Check if a changelog exists for release notes.
CHANGELOG_EXISTS=$(changelog_exists)

# Create GitHub release.
echo ">> Creating GitHub release..."
if $CHANGELOG_EXISTS; then
    RELEASE_NOTES=$(extract_version_updates_from_changelog "$CURRENT_VERSION")
    gh release create "v$CURRENT_VERSION" -n "$RELEASE_NOTES" -t "v$CURRENT_VERSION"
else
    gh release create "v$CURRENT_VERSION"
fi

# Exit now if not a WP plugin or theme with a release asset.
if ! [ "$IS_WP_PLUGIN" = true ] && ! [ "$IS_WP_THEME" = true ]; then
    echo "SUCCESS: Version $CURRENT_VERSION release created!"
    exit 0
fi

# Ask if we want to create a zip to deploy WP plugins and themes.
if ! wp_plugin_has_release_asset; then
    echo "INFO: This plugin/theme does not use a release asset. Exiting."
    exit 0
fi

# If this is a theme and a release workflow exists, skip local asset build.
if [ "$IS_WP_THEME" = true ] && release_workflow_exists; then
    echo ">> Release workflow detected (release.yml). Skipping local release asset build for theme."
    echo "SUCCESS: Version $CURRENT_VERSION release created!"
    exit 0
fi

echo ">> Building release assets..."

# Check if the current repo has a production workflow.
if current_dir_has_production_script; then
    echo "This repo has a production script. Creating production build..."
    "$PACKAGE_MANAGER" run production
    echo "Production build complete."
elif current_dir_has_build_script; then
    echo "This repo has a build script. Creating build..."
    "$PACKAGE_MANAGER" run build
    echo "Build complete."
fi

ZIP_NAME="$BASENAME-v$CURRENT_VERSION"
ZIP_FILE="$ZIP_NAME.zip"

echo ">> Creating release ZIP..."
if [ "$IS_WP_BLOCK_PLUGIN" = true ]; then
    wp_zip_block_plugin "$ZIP_NAME"
elif [ "$IS_WP_PLUGIN" = true ]; then
    wp_zip_plugin "$ZIP_NAME"
else
    wp_zip_theme "$ZIP_NAME"
fi

echo ">> Release asset details:"
echo "   Zip Name: $ZIP_NAME"
echo "   Zip Filename: $ZIP_FILE"
echo "   Zip Path: $HOME/tmp/$ZIP_FILE"

# Upload the asset to the release.
echo ">> Uploading release asset to GitHub..."
gh release upload "v$CURRENT_VERSION" "$HOME/tmp/$ZIP_FILE"

echo "SUCCESS: Version $CURRENT_VERSION release created!"

# Do we want to trigger Git Remote Updater to force update the plugin/theme now?
if confirm "Do you want to remote update the plugin/theme to this new version now?"; then
    wp_update_plugin_via_git_remote_updater
fi

echo ""
echo "SUCCESS: Release process completed successfully!"
echo "GitHub Release: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/releases/tag/v$CURRENT_VERSION"






