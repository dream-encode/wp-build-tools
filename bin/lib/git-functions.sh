#!/bin/bash

# Git utility functions for release script
# Copied from git.bashrc

# Git commit with message
function gc() {
    git commit -m "$1"
}

# Git push
function gpu() {
    git push
}

# Create and push git tag for release
function git_tag_release() {
    if [ -z "$1" ]; then
        echo "No tag name supplied. Exiting!"
        return 1
    else
        git tag -a "v$1" -m "Version $1"
        git push -u origin "v$1"
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
        git push --delete origin "v$tag"
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
        local CHANGELOG_TOP_VERSION=$(grep -m 1 "## \[" CHANGELOG.md | sed -E 's/## \[(.*)\].*/\1/')

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

    # Check if a changelog exists
    local CHANGELOG_EXISTS=$(changelog_exists)

    # Check if changelog is present
    if $CHANGELOG_EXISTS; then
        local RELEASE_NOTES=$(extract_version_updates_from_changelog "$CURRENT_VERSION")
        gh release create "v$CURRENT_VERSION" -n "$RELEASE_NOTES" -t "v$CURRENT_VERSION"
    else
        gh release create "v$CURRENT_VERSION"
    fi

    echo "Version $CURRENT_VERSION release created!"
}

# Re-create a release (delete and recreate)
function git_create_rerelease() {
    local CURRENT_VERSION=$(get_version_package_json)

    git tag -d "v$CURRENT_VERSION"
    git push --delete origin "v$CURRENT_VERSION"
    gh release delete "v$CURRENT_VERSION" --cleanup-tag
    git push
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
    git push origin main

    # Return to original branch.
    echo "Returning to original branch: $original_branch"
    git checkout "$original_branch"

    # Add template changelog entry if changelog file exists.
    if changelog_exists; then
        echo "Adding template changelog entry..."
        sed -i "s/## \[$current_version\]/## 0.2.4 - [UNRELEASED]\n* BUG: Example fix description.\n\n## [$current_version]/" "CHANGELOG.md"
        echo "✅ Template changelog entry added to CHANGELOG.md"
    fi

    echo "✅ Post-release cleanup completed."
}

