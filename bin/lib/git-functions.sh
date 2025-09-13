#!/bin/bash

# Git utility functions for release script

# Source platform utilities if not already loaded
if ! command -v get_platform >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/platform-utils.sh"
fi
# Copied from git.bashrc

# Git commit with message
function gc() {
    git commit -m "$1"
}

# Git push
function gpu() {
    git push -q
}

# Create and push git tag for release
function git_tag_release() {
    if [ -z "$1" ]; then
        echo "No tag name supplied. Exiting!"
        return 1
    else
        git tag -a "v$1" -m "Version $1"
        git push -q -u origin "v$1"
    fi
}

# Delete git tag (local and remote)
function git_delete_tag() {
    local tag="$1"
    if [ -z "$tag" ]; then
        read -p "Tag: " tag
    fi

    if [ -z "$tag" ]; then
        echo "Missing tag name"
        return 1
    else
        git tag -d "v$tag"
        git push -q --delete origin "v$tag"
    fi
}

# Check if we're in a git repository
function is_git_repo() {
    git rev-parse --git-dir > /dev/null 2>&1
}

# Get current branch name
function get_current_branch() {
    git branch --show-current
}

# Check if working directory is clean
function is_working_directory_clean() {
    if [ -z "$(git status --porcelain)" ]; then
        return 0
    else
        return 1
    fi
}

# Get remote origin URL
function get_remote_origin_url() {
    git config --get remote.origin.url
}

# Extract GitHub repo info from remote URL
function get_github_repo_info() {
    local url=$(get_remote_origin_url)
    echo "$url" | sed 's/.*github.com[:/]\([^.]*\).*/\1/'
}

# Check if GitHub CLI is available and authenticated
function check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is required but not installed." >&2
        echo "Please install it from: https://cli.github.com/" >&2
        return 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated." >&2
        echo "Please run: gh auth login" >&2
        return 1
    fi

    return 0
}

function github_actions_github_actions_release_workflow_exists() {
    # Consider common release workflow names
    if [ -f .github/workflows/release.yml ] || [ -f .github/workflows/release.yaml ]; then
        return 0
    fi
    # Also match common alternate naming patterns
    if ls .github/workflows/release-*.yml >/dev/null 2>&1 || ls .github/workflows/release-*.yaml >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

function github_create_release() {
    VERSION=$1

    if changelog_exists; then
        local RELEASE_NOTES=$(extract_version_updates_from_changelog "$VERSION")
        gh release create "v$VERSION" -n "$RELEASE_NOTES" -t "v$VERSION" >/dev/null 2>&1
    else
        gh release create "v$VERSION" >/dev/null 2>&1
    fi
}

# Validate git setup before release
function validate_git_setup() {
    echo "🔍 Validating git setup..."

    if ! is_git_repo; then
        echo "❌ Error: Not in a git repository."
        return 1
    fi

    if ! is_working_directory_clean; then
        echo "❌ Error: Working directory is not clean. Please commit or stash changes."
        git status --short
        return 1
    fi

    # Check current branch
    local current_branch=$(get_current_branch)

    if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
        echo "⚠️  Warning: You're not on main/master branch (current: $current_branch)"
        confirm "Continue with release from $current_branch branch?"
        if [ $? == 1 ]; then
            echo "Release cancelled."
            return 1
        fi
    fi

    if ! check_gh_cli; then
        return 1
    fi

    echo "✅ Git setup validation passed."
    return 0
}

# Create a simple release (without assets)
function git_create_simple_release() {
    local CURRENT_VERSION=$(get_version_package_json)

    # Version bump
    confirm "Current version in package.json is $CURRENT_VERSION. Do you want to bump the version now?"

    if [ $? == 1 ]; then
        echo "Staying at version $CURRENT_VERSION."
    else
        package_version_bump_interactive
    fi

    # Refresh the version, as it may have changed
    CURRENT_VERSION=$(get_version_package_json)

    # Check if a changelog exists
    if changelog_exists; then
        # Changelog exists, proceed with version check
        local CHANGELOG_TOP_VERSION=$(grep -m 1 "## \[" CHANGELOG.md | sed -E 's/## \[([^]]*)\].*/\1/')

        if [ "$CHANGELOG_TOP_VERSION" != "$CURRENT_VERSION" ]; then
            echo "Error: Latest entry in CHANGELOG.md is for version $CHANGELOG_TOP_VERSION, but you're releasing version $CURRENT_VERSION."
            echo "Please update CHANGELOG.md with the correct version before releasing."
            return 1
        fi

        # Update the date in the changelog to today's date
        local CURRENT_DATE=$(date +%Y-%m-%d)

        # Check if the entry contains "UNRELEASED" or already has a date
        if grep -q "## \[$CURRENT_VERSION\] - UNRELEASED" CHANGELOG.md; then
            sed -i "0,/## \[$CURRENT_VERSION\] - UNRELEASED/ s/## \[$CURRENT_VERSION\] - UNRELEASED/## [$CURRENT_VERSION] - $CURRENT_DATE/" CHANGELOG.md
            echo "Updated UNRELEASED date in CHANGELOG.md to $CURRENT_DATE."
        else
            # Replace existing date with current date
            sed -i "0,/## \[$CURRENT_VERSION\]/ s/## \[$CURRENT_VERSION\].*$/## [$CURRENT_VERSION] - $CURRENT_DATE/" CHANGELOG.md
            echo "Updated release date in CHANGELOG.md to $CURRENT_DATE."
        fi

        # Commit the updated changelog
        git add CHANGELOG.md
        gc "Update release date in CHANGELOG.md"
    fi

    echo "Pushing latest code to main..."
    gpu

    # Tag the version
    git_tag_release "$CURRENT_VERSION"

    # Create GitHub release
    github_create_release "$CURRENT_VERSION"

    echo "Version $CURRENT_VERSION release created!"
}

# Re-create a release (delete and recreate)
function git_create_rerelease() {
    local CURRENT_VERSION=$(get_version_package_json)

    git tag -d "v$CURRENT_VERSION"
    git push -q --delete origin "v$CURRENT_VERSION"
    gh release delete "v$CURRENT_VERSION" --cleanup-tag
    git push -q
}

# Delete a specific release
function git_delete_release() {
    local version="$1"

    if [ -z "$version" ]; then
        read -p "Version: " version
    fi

    if [ -z "$version" ]; then
        echo "No version supplied. Exiting!"
        return 1
    else
        git tag -d "v$version"
        gh release delete "v$version" --cleanup-tag
    fi
}

# Get the latest tag
function get_latest_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Check if a tag exists
function tag_exists() {
    local tag="$1"

    git tag -l | grep -q "^$tag$"
}

# Get commit hash for a specific tag
function get_commit_for_tag() {
    local tag="$1"

    git rev-list -n 1 "$tag" 2>/dev/null
}

function git_create_rerelease() {
    CURRENT_VERSION=$(get_version_package_json)

    git tag -d "v$CURRENT_VERSION"
    git push -q --delete origin "v$CURRENT_VERSION"
    gh release delete "v$CURRENT_VERSION" --cleanup-tag
    git push -q
}

function git_delete_release() {
    read -p "Version: " version
    if [ -z "$version" ]
    then
        echo "No version supplied.  Exiting!"
        return
    else
        git tag -d "v$version"
        gh release delete "v$version" --cleanup-tag
    fi
}

function git_sync_upstream() {
    git checkout trunk
    git fetch upstream
    git merge upstream/trunk
}

# Core git release function - handles generic git/GitHub release workflow
function git_create_release() {
    # Set some vars
    local CURRENT_DIR=$(pwd)
    local BASENAME=$(basename "$CURRENT_DIR")
    local PACKAGE_MANAGER=$(get_package_manager_for_project)
    local CURRENT_VERSION=$(get_version_package_json)

    CURRENT_BRANCH=$(git branch --show-current)

    # Check if we're on an allowed release branch.
    if [ "$CURRENT_BRANCH" != "development" ] && [ "$CURRENT_BRANCH" != "hotfix" ]; then
        echo "❌ Error: Releases can only be created from 'development' or 'hotfix' branches."
        echo "   Current branch: $CURRENT_BRANCH"
        echo "   Please switch to 'development' or 'hotfix' branch before releasing."
        exit 1
    fi

    echo "🚀 Starting release process for $BASENAME"
    echo "📦 Package manager: $PACKAGE_MANAGER"
    echo "📋 Current version: $CURRENT_VERSION"
    echo ""

    # Version bump.
    echo ">> Version management:"

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
            if ! package_version_bump_interactive; then
                echo "❌ Version bump failed or was cancelled. Aborting release."
                return 1
            fi
        else
            echo "Staying at version $CURRENT_VERSION."
        fi
    fi

    # Refresh the version, as it may have changed.
    CURRENT_VERSION=$(get_version_package_json)

    echo "📤 Pushing latest code to main..."
    git push -q

    # Create the release branch.
    echo ">> Creating release branch...."
    git checkout -b "release/$CURRENT_VERSION"

    echo ">> Pushing release branch to origin..."
    git push -q --set-upstream origin "release/$CURRENT_VERSION"

    # Tag the version.
    echo "🏷️  Creating release tag..."
    git_tag_release "$CURRENT_VERSION"

    # Create GitHub release.
    echo "🎉 Creating GitHub release..."
    github_create_release "$CURRENT_VERSION"

    git_post_create_release "$CURRENT_VERSION" "$CURRENT_BRANCH"

    echo "🎊 SUCCESS: Version $CURRENT_VERSION release created!"
}

# Quiet version of git_create_release for use in wp_create_release
function git_create_release_quiet() {
    # Parse arguments
    local quiet_mode="false"
    local version_bump=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode="true"
                shift
                ;;
            patch|minor|major|hotfix)
                version_bump="$1"
                shift
                ;;
            *)
                echo "❌ Invalid argument: $1"
                echo "Usage: git_create_release_quiet [--quiet] [patch|minor|major|hotfix]"
                exit 1
                ;;
        esac
    done

    # Set some vars
    local CURRENT_DIR=$(pwd)
    local BASENAME=$(basename "$CURRENT_DIR")
    local PACKAGE_MANAGER=$(get_package_manager_for_project)
    local CURRENT_VERSION=$(get_version_package_json)

    CURRENT_BRANCH=$(git branch --show-current)

    # Check if we're on an allowed release branch.
    if [ "$CURRENT_BRANCH" != "development" ] && [ "$CURRENT_BRANCH" != "hotfix" ]; then
        echo "❌ Error: Releases can only be created from 'development' or 'hotfix' branches."
        echo "   Current branch: $CURRENT_BRANCH"
        echo "   Please switch to 'development' or 'hotfix' branch before releasing."
        exit 1
    fi

    if ! changelog_check_next_version; then
        echo "❌ Error: Latest entry in CHANGELOG.md is not for NEXT_VERSION.  Please update CHANGELOG.md before releasing."
        exit 1
    fi

    # Handle version bump - either from command line argument or interactive.
    if [ ! -z "$version_bump" ]; then
        # Command line argument provided (patch, minor, major, hotfix).
        package_version_bump_auto "$version_bump" >/dev/null
    else
        # Interactive mode with version bump options including "stay at current"
        echo ""
        printf "  🔢 Version Selection Required\n"
        local options=(
            "━━━ Current version: $CURRENT_VERSION - Choose action: ━━━"
            "patch - Bug fixes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "patch"))"
            "minor - New features (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "minor"))"
            "major - Breaking changes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "major"))"
            "hotfix - Critical fixes (${CURRENT_VERSION} → $(calculate_new_version "$CURRENT_VERSION" "hotfix"))"
            "custom - Enter custom version"
            "Stay at current version ($CURRENT_VERSION)"
        )

        local selected=$(interactive_menu_select "" "${options[@]}")

        # If they selected the header line, show error
        if [[ "$selected" == "━━━"* ]]; then
            echo "❌ Please select a valid option, not the header."
            return 1
        fi
        local menu_exit_code=$?

        if [ $menu_exit_code -ne 0 ] || [ -z "$selected" ]; then
            echo "❌ Version selection cancelled. Aborting release."
            return 1
        fi

        # Extract action from selection
        local action=$(echo "$selected" | cut -d' ' -f1)
        printf "  ✅ Selected: %s\n" "$selected"

        if [ "$action" != "Stay" ]; then
            # User chose to bump version
            local bump_type="$action"

            local NEW_VERSION
            if [ "$bump_type" = "custom" ]; then
                # Custom version input
                read -e -p "Enter custom version: " -i "$CURRENT_VERSION" NEW_VERSION
                if [ -z "$NEW_VERSION" ]; then
                    echo "❌ No version supplied. Aborting release."
                    return 1
                fi
            else
                # Calculate new version based on bump type
                NEW_VERSION=$(calculate_new_version "$CURRENT_VERSION" "$bump_type")
            fi

            # Update package.json
            bump_version_package_json "$NEW_VERSION" >/dev/null

            # Update WordPress plugin/theme files if applicable
            if [[ $PWD/ = */wp-content/plugins/* ]] || [[ $PWD/ = */wp-content/themes/* ]]; then
                wp_plugin_bump_version "$NEW_VERSION" >/dev/null 2>&1
            fi

            # Commit changes
            git add . >/dev/null 2>&1
            git commit -m "Version $NEW_VERSION bump." >/dev/null 2>&1
        fi
    fi

    # Refresh the version, as it may have changed.
    CURRENT_VERSION=$(get_version_package_json)

    changelog_update_current_version

    echo "    - Updated changelog."

    # Push latest code to main (quietly)
    git push -q >/dev/null 2>&1

    # Create the release branch (quietly)
    git checkout -b "release/$CURRENT_VERSION" >/dev/null 2>&1
    git push -q --set-upstream origin "release/$CURRENT_VERSION" >/dev/null 2>&1

    echo "    - Release branch created."

    # Tag the version (quietly)
    git tag -a "v$CURRENT_VERSION" -m "Version $CURRENT_VERSION" >/dev/null 2>&1
    git push -q -u origin "v$CURRENT_VERSION" >/dev/null 2>&1

    echo "    - Version v$CURRENT_VERSION tagged."

    # Create GitHub release (quietly)
    github_create_release "$CURRENT_VERSION" >/dev/null 2>&1

    echo "    - GitHub release created."

    # Post-release cleanup (quietly)
    git checkout main >/dev/null 2>&1
    git merge "release/$CURRENT_VERSION" --no-ff -m "Merge release/$CURRENT_VERSION into main" >/dev/null 2>&1
    git push -q origin main >/dev/null 2>&1

    echo "    - Release branch merged into main."

    git checkout "$CURRENT_BRANCH" >/dev/null 2>&1

    echo "  ✅ Release version $NEW_VERSION created."
}

function git_create_simple_release() {
    CURRENT_VERSION=$(get_version_package_json)

    CURRENT_BRANCH=$(git branch --show-current)

    # Check if we're on an allowed release branch.
    if [ "$CURRENT_BRANCH" != "development" ] && [ "$CURRENT_BRANCH" != "hotfix" ]; then
        echo "❌ Error: Releases can only be created from 'development' or 'hotfix' branches."
        echo "   Current branch: $CURRENT_BRANCH"
        echo "   Please switch to 'development' or 'hotfix' branch before releasing."
        exit 1
    fi

    # Version bump.
    confirm "Current version in package.json is $CURRENT_VERSION. Do you want to bump the version now?"
    if ([ $? == 1 ])
    then
        echo "Staying at version $CURRENT_VERSION."
    else
        if ! package_version_bump_interactive; then
            echo "❌ Version bump failed or was cancelled. Aborting release."
            return 1
        fi
    fi

    # Refresh the version, as it may have changed.
    CURRENT_VERSION=$(get_version_package_json)

    # Check if a changelog exists.
    if changelog_exists; then
        # Changelog exists, proceed with version check
        CHANGELOG_TOP_VERSION=$(grep -m 1 "## \[" CHANGELOG.md | sed -E 's/## \[([^]]*)\].*/\1/')

        # Check if the top entry is NEXT_VERSION - UNRELEASED format
        if [ "$CHANGELOG_TOP_VERSION" = "NEXT_VERSION" ]; then
            # Update NEXT_VERSION to actual version and UNRELEASED to current date
            # Only modify CHANGELOG.md, exclude .sh files
            CURRENT_DATE=$(date +%Y-%m-%d)
            sed -i "0,/^## \[NEXT_VERSION\] - \[UNRELEASED\]/ s/^## \[NEXT_VERSION\] - \[UNRELEASED\]/## [$CURRENT_VERSION] - $CURRENT_DATE/" CHANGELOG.md
            echo "✅ Updated NEXT_VERSION entry in CHANGELOG.md to [$CURRENT_VERSION] - $CURRENT_DATE."
        elif [ "$CHANGELOG_TOP_VERSION" != "$CURRENT_VERSION" ]; then
            echo "Error: Latest entry in CHANGELOG.md is for version $CHANGELOG_TOP_VERSION, but you're releasing version $CURRENT_VERSION."
            echo "Please update CHANGELOG.md with the correct version before releasing."
            return 1
        else
            # Update the date in the changelog to today's date
            CURRENT_DATE=$(date +%Y-%m-%d)

            # Update the changelog entry to have the correct date (replace any existing content after the version)
            # This handles cases like:
            # ## [0.2.0] - UNRELEASED
            # ## [0.2.0] - 2025-09-09
            # ## [0.2.0] - 2025-09-09 - 2025-09-08 (double dates)
            # ## [0.2.0]
            if grep -q "## \\[$CURRENT_VERSION\\]" CHANGELOG.md; then
                sed -i "0,/## \\[$CURRENT_VERSION\\]/ s/## \\[$CURRENT_VERSION\\].*$/## [$CURRENT_VERSION] - $CURRENT_DATE/" CHANGELOG.md
                echo "✅ Updated release date in CHANGELOG.md to $CURRENT_DATE."
            else
                echo "⚠️  Warning: Could not find version $CURRENT_VERSION in CHANGELOG.md"
            fi
        fi

        # Commit the updated changelog
        git add CHANGELOG.md
        gc "Update release date in CHANGELOG.md"
    fi

    git push -q origin "$CURRENT_BRANCH"

    echo ">> Creating release branch...."
    git checkout -b "release/$CURRENT_VERSION"

    echo ">> Pushing release branch to origin..."
    git push -q --set-upstream origin "release/$CURRENT_VERSION"

    # Tag the version.
    git_tag_release "$CURRENT_VERSION"

    # Create release on GitHub.
    github_create_release "$CURRENT_VERSION"

    git_post_create_release "$CURRENT_VERSION" "$CURRENT_BRANCH"
}

# Post-release cleanup: merge release branch to main and return to original branch.
function git_post_create_release() {
    local current_version="$1"
    local original_branch="$2"

    echo ">> Post-release cleanup..."

    # Switch to main branch.
    echo "Switching to main branch..."
    git checkout main

    # Merge the release branch.
    echo "Merging release/$current_version into main..."
    git merge "release/$current_version" --no-ff -m "Merge release/$current_version into main"

    # Push main branch.
    echo "Pushing main branch..."
    git push -q origin main

    # Return to original branch.
    echo "Returning to original branch: $original_branch"
    git checkout "$original_branch"

    # Add template changelog entry if changelog file exists.
    if changelog_exists; then
        echo "Adding template changelog entry..."
        # Only modify CHANGELOG.md, use anchored pattern to avoid .sh files
        sed -i "s/^## \[$current_version\]/## [NEXT_VERSION] - [UNRELEASED]\n* BUG: Example fix description.\n\n## [$current_version]/" "CHANGELOG.md"
        echo "✅ Template changelog entry added to CHANGELOG.md"
    fi

    echo "✅ Post-release cleanup completed."
}

