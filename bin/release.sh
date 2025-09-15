#!/bin/bash

# WordPress Plugin Release Script
# Based on git_create_release function from bash includes

set -e

# Ensure proper Unicode/emoji support in terminal output
# This fixes emoji display issues when running via yarn vs npm
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export TERM="${TERM:-xterm-256color}"

# Get the directory where this script is located.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Store the current working directory (where the user ran the command)
USER_PROJECT_DIR="$(pwd)"

# Function to display help/man page
function show_help() {
    cat << 'EOF'
NAME
    wp-release - WordPress Plugin/Theme Release Tool

SYNOPSIS
    wp-release [OPTIONS] [VERSION_TYPE]

DESCRIPTION
    A comprehensive release tool for WordPress plugins and themes that handles
    version bumping, changelog updates, git tagging, GitHub releases, and
    WordPress-specific asset creation.

OPTIONS
    --check-tools      Check if all required tools are installed and configured
    --test             Run comprehensive compatibility and readiness tests
    --help, -h         Show this help message
    --version, -v      Show version information

VERSION_TYPE
    patch              Bug fixes (1.0.0 → 1.0.1)
    minor              New features (1.0.0 → 1.1.0)
    major              Breaking changes (1.0.0 → 2.0.0)
    hotfix             Critical fixes (1.0.0 → 1.0.0.1)

    If no VERSION_TYPE is specified, interactive mode will prompt for selection.

EXAMPLES
    wp-release                    # Interactive mode
    wp-release patch              # Create patch release
    wp-release --check-tools      # Check tool availability
    wp-release --test             # Run comprehensive tests

WORKFLOW
    1. Pre-release checks (debugging code detection)
    2. Action Scheduler library updates (if applicable)
    3. Translation file updates (POT generation)
    4. Version bumping in all relevant files
    5. Changelog updates
    6. Git commit and tag creation
    7. GitHub release creation
    8. WordPress release asset generation and upload

REQUIREMENTS
    • git - Version control
    • jq - JSON processing
    • gh - GitHub CLI (authenticated)
    • Compression tool (7z, zip)
    • Copy tool (robocopy, rsync, tar, cp)

OPTIONAL TOOLS
    • wp - WP-CLI (for POT file generation)
    • composer - PHP dependency manager
    • node/npm/yarn - Node.js ecosystem

FILES
    The tool operates on these files in your project:
    • package.json - Version and metadata
    • CHANGELOG.md - Release notes
    • *.php - WordPress plugin/theme headers
    • block.json - Block plugin metadata

ENVIRONMENT
    Works on Windows (Git Bash/MSYS2), macOS, and Linux with automatic
    platform detection and tool selection.

SEE ALSO
    GitHub: https://github.com/your-org/wp-build-tools
    Documentation: README.md

EOF
}

# Parse command line arguments
SHOW_HELP=false
CHECK_TOOLS=false
RUN_TESTS=false
VERSION_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        --version|-v)
            echo "wp-release version 0.5.1"
            echo "WordPress Plugin/Theme Release Tool"
            exit 0
            ;;
        --check-tools)
            CHECK_TOOLS=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        patch|minor|major|hotfix)
            if [ -n "$VERSION_TYPE" ]; then
                echo "❌ Error: Multiple version types specified"
                exit 1
            fi
            VERSION_TYPE="$1"
            shift
            ;;
        -*)
            echo "❌ Error: Unknown option '$1'"
            echo "Use 'wp-release --help' for usage information"
            exit 1
            ;;
        *)
            if [ -n "$VERSION_TYPE" ]; then
                echo "❌ Error: Multiple arguments specified"
                echo "Use 'wp-release --help' for usage information"
                exit 1
            fi
            VERSION_TYPE="$1"
            shift
            ;;
    esac
done

# Handle help flag
if [ "$SHOW_HELP" = true ]; then
    show_help
    exit 0
fi

# Source configuration if it exists.
if [ -f "$SCRIPT_DIR/config/release.conf" ]; then
    source "$SCRIPT_DIR/config/release.conf"
fi

# Source helper functions.
source "$SCRIPT_DIR/lib/platform-utils.sh"
source "$SCRIPT_DIR/lib/tool-checker.sh"
source "$SCRIPT_DIR/lib/general-functions.sh"
source "$SCRIPT_DIR/lib/git-functions.sh"
source "$SCRIPT_DIR/lib/wp-functions.sh"

# Stay in the user's project directory (don't change to wp-build-tools directory)
cd "$USER_PROJECT_DIR"

# Handle --check-tools flag
if [ "$CHECK_TOOLS" = true ]; then
    echo "🔧 Checking tool availability..."
    echo ""
    if check_all_tools; then
        echo ""
        echo "✅ All required tools are available and properly configured!"
        echo "🚀 Ready to run wp-release"
    else
        echo ""
        echo "❌ Some required tools are missing or not configured properly."
        echo ""
        echo "💡 Common installation commands:"
        echo "   • jq: apt install jq (Linux) | brew install jq (macOS) | choco install jq (Windows)"
        echo "   • gh: https://cli.github.com/manual/installation"
        echo "   • 7z: apt install p7zip-full (Linux) | brew install p7zip (macOS) | choco install 7zip (Windows)"
        echo ""
        echo "📖 See README.md for detailed installation instructions"
        exit 1
    fi
    exit 0
fi

# Handle --test flag
if [ "$RUN_TESTS" = true ]; then
    echo "🧪 Running release compatibility tests..."
    echo ""

    # Run inline compatibility tests
    source "$SCRIPT_DIR/lib/platform-utils.sh"
    source "$SCRIPT_DIR/lib/tool-checker.sh"

    echo "1️⃣  Testing platform detection..."
    PLATFORM=$(get_platform)
    echo "   ✅ Detected platform: $PLATFORM"
    echo ""

    echo "2️⃣  Testing tool detection..."
    COMPRESSION_TOOL=$(get_compression_tool)
    COPY_TOOL=$(get_copy_tool)
    echo "   ✅ Compression tool: $COMPRESSION_TOOL"
    echo "   ✅ Copy tool: $COPY_TOOL"
    echo ""

    echo "3️⃣  Testing comprehensive tool check..."
    if check_all_tools; then
        echo "   ✅ All required tools are available"
    else
        echo "   ❌ Some required tools are missing"
        echo ""
        echo "🔧 Run 'wp-release --check-tools' for detailed tool status"
        exit 1
    fi
    echo ""

    echo "4️⃣  Testing release readiness..."

    # Test version reading
    if command -v jq >/dev/null 2>&1; then
        VERSION=$(get_version_package_json)
        echo "   ✅ Current version: $VERSION"
    else
        echo "   ❌ Cannot read version (jq required)"
    fi

    # Test WordPress plugin detection
    if is_wp_plugin_dir; then
        echo "   ✅ WordPress plugin directory detected"
    elif is_wp_theme_dir; then
        echo "   ✅ WordPress theme directory detected"
    else
        echo "   ℹ️  Not in WordPress plugin/theme directory"
    fi

    # Test git repository
    if is_git_repo; then
        echo "   ✅ Git repository detected"
        if is_working_directory_clean; then
            echo "   ✅ Working directory is clean"
        else
            echo "   ⚠️  Working directory has uncommitted changes"
        fi
    else
        echo "   ❌ Not a git repository"
    fi

    # Test changelog
    if changelog_exists; then
        echo "   ✅ CHANGELOG.md found"
    else
        echo "   ℹ️  No CHANGELOG.md found"
    fi

    # Test build process (for WordPress plugins/themes with build scripts)
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
            echo "   🔨 Testing build process..."

            # Quick build test - run actual build and capture output
            local build_output
            local build_exit_code

            build_output=$($package_manager run $build_script 2>&1)
            build_exit_code=$?

            if [ $build_exit_code -eq 0 ]; then
                echo "   ✅ Build process successful"
            else
                echo "   ❌ Build process failed"
                echo "   💡 Run '$package_manager run $build_script' to see detailed errors"
                echo "   ⚠️  Release will fail during asset creation step"

                # Show first few lines of error for quick diagnosis
                echo "   📋 Build error preview:"
                echo "$build_output" | tail -5 | sed 's/^/      /'
            fi
        else
            echo "   ℹ️  No build script detected"
        fi
    fi

    echo ""
    echo "🎉 Comprehensive test complete!"
    echo ""
    echo "📋 Summary:"
    echo "   • Platform: $PLATFORM"
    echo "   • Compression: $COMPRESSION_TOOL"
    echo "   • Copy Tool: $COPY_TOOL"
    if command -v jq >/dev/null 2>&1; then
        echo "   • Current Version: $(get_version_package_json)"
    fi
    echo ""
    echo "✅ System ready for wp-release!"
    exit 0
fi

# Normal release workflow - check tools first
echo "🔧 Checking system requirements..."
if ! check_all_tools; then
    echo ""
    echo "❌ Missing required tools. Please install them before running wp-release."
    echo ""
    echo "💡 Common installation commands:"
    echo "   • jq: apt install jq (Linux) | brew install jq (macOS) | choco install jq (Windows)"
    echo "   • gh: https://cli.github.com/manual/installation"
    echo "   • 7z: apt install p7zip-full (Linux) | brew install p7zip (macOS) | choco install 7zip (Windows)"
    echo ""
    echo "📖 See README.md for detailed installation instructions"
    echo "🔧 Run 'wp-release --check-tools' for detailed tool status"
    exit 1
fi

# Call the WordPress release function with the version type
echo ""
if [ -n "$VERSION_TYPE" ]; then
    wp_create_release "$VERSION_TYPE"
else
    wp_create_release
fi
