#!/bin/bash

# Test script to validate release script functionality
# This script tests the helper functions without actually creating a release

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source helper functions
source "$SCRIPT_DIR/lib/general-functions.sh"
source "$SCRIPT_DIR/lib/git-functions.sh"
source "$SCRIPT_DIR/lib/wp-functions.sh"

# Change to project root
cd "$PROJECT_ROOT"

echo "🧪 Testing release script functionality..."
echo ""

# Test 1: Check if we can read package.json version
echo "📦 Testing package.json version reading..."
if command -v jq >/dev/null 2>&1; then
    VERSION=$(get_version_package_json)
    echo "✅ Current version: $VERSION"
else
    echo "❌ jq not found - required for JSON processing"
fi
echo ""

# Test 2: Check package manager detection
echo "🔧 Testing package manager detection..."
PACKAGE_MANAGER=$(get_package_manager_for_project)
echo "✅ Detected package manager: $PACKAGE_MANAGER"
echo ""

# Test 3: Check if this is a WordPress plugin
echo "🔍 Testing WordPress plugin detection..."
if is_wp_plugin_dir; then
    echo "✅ This is a WordPress plugin directory"
else
    echo "ℹ️  This is not in a WordPress plugin directory"
fi
echo ""

# Test 4: Check for block plugin indicators
echo "🧱 Testing block plugin detection..."
if is_wp_block_plugin; then
    echo "✅ This appears to be a block plugin"
else
    echo "ℹ️  This does not appear to be a block plugin"
fi
echo ""

# Test 5: Check for debugging code
echo "🔍 Testing debugging code detection..."
if wp_check_debugging_code; then
    echo "✅ No debugging code found"
else
    echo "⚠️  Debugging code detected"
fi
echo ""

# Test 6: Check for release asset configuration
echo "📦 Testing release asset configuration..."
if wp_plugin_has_release_asset; then
    echo "✅ Plugin is configured for release assets"
else
    echo "ℹ️  Plugin is not configured for release assets"
fi
echo ""

# Test 7: Check for production/build scripts
echo "🔨 Testing build script detection..."
if current_dir_has_npm_production_script; then
    echo "✅ Production script found"
elif current_dir_has_npm_build_script; then
    echo "✅ Build script found"
else
    echo "ℹ️  No production or build script found"
fi
echo ""

# Test 8: Check changelog
echo "📝 Testing changelog detection..."
if changelog_exists; then
    echo "✅ CHANGELOG.md found"
else
    echo "ℹ️  No CHANGELOG.md found"
fi
echo ""

# Test 9: Check git repository
echo "📂 Testing git repository..."
if is_git_repo; then
    echo "✅ This is a git repository"
    CURRENT_BRANCH=$(get_current_branch)
    echo "   Current branch: $CURRENT_BRANCH"

    if is_working_directory_clean; then
        echo "✅ Working directory is clean"
    else
        echo "⚠️  Working directory has uncommitted changes"
    fi
else
    echo "❌ This is not a git repository"
fi
echo ""

# Test 10: Check GitHub CLI
echo "🐙 Testing GitHub CLI..."
if check_gh_cli; then
    echo "✅ GitHub CLI is installed and authenticated"
else
    echo "❌ GitHub CLI is not available or not authenticated"
fi
echo ""

# Test 11: Check WP-CLI
echo "🔧 Testing WP-CLI..."
if command -v wp >/dev/null 2>&1; then
    echo "✅ WP-CLI is available"
else
    echo "ℹ️  WP-CLI not found (optional for POT file updates)"
fi
echo ""

# Test 12: Version calculation
echo "🔢 Testing version calculation..."
if command -v jq >/dev/null 2>&1; then
    VERSION=$(get_version_package_json)
    echo "✅ Current version: $VERSION"
    echo "   Patch bump: $VERSION → $(calculate_new_version "$VERSION" "patch")"
    echo "   Minor bump: $VERSION → $(calculate_new_version "$VERSION" "minor")"
    echo "   Major bump: $VERSION → $(calculate_new_version "$VERSION" "major")"
    echo "   Hotfix bump: $VERSION → $(calculate_new_version "$VERSION" "hotfix")"
else
    echo "❌ jq not found - cannot test version calculation"
fi
echo ""

echo "🎉 Release script functionality test completed!"
echo ""
echo "📋 Summary:"
echo "   - All required functions are available"
echo "   - Check any ❌ or ⚠️  items above before running a release"
echo ""
echo "🚀 Usage options:"
echo "   - Interactive: './bin/release.sh' (shows version bump menu)"
echo "   - Auto patch: './bin/release.sh patch'"
echo "   - Auto minor: './bin/release.sh minor'"
echo "   - Auto major: './bin/release.sh major'"
echo "   - Auto hotfix: './bin/release.sh hotfix'"
