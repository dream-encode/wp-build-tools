#!/bin/bash

# Tool availability checker for wp-build-tools
# Validates that all required command-line tools are available

# Source platform utilities if not already loaded
if ! command -v get_platform >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/platform-utils.sh"
fi

# Define tool categories and requirements
declare -A REQUIRED_TOOLS=(
    ["jq"]="JSON processing (required for package.json operations)"
    ["git"]="Version control (required for release workflow)"
    ["gh"]="GitHub CLI (required for creating releases)"
)

declare -A OPTIONAL_TOOLS=(
    ["wp"]="WP-CLI (optional, for POT file generation)"
    ["composer"]="PHP dependency manager (optional, for PHP projects)"
    ["node"]="Node.js runtime (optional, for npm/yarn projects)"
    ["npm"]="Node package manager (optional, for Node.js projects)"
    ["yarn"]="Alternative Node package manager (optional)"
)

declare -A COMPRESSION_TOOLS=(
    ["7z.exe"]="7-Zip for Windows"
    ["7z"]="7-Zip for Unix-like systems"
    ["7za"]="7-Zip standalone for Unix-like systems"
    ["zip"]="Standard ZIP utility"
)

declare -A COPY_TOOLS=(
    ["robocopy"]="Windows robust file copy utility"
    ["rsync"]="Unix file synchronization utility"
    ["tar"]="Archive-based copy with exclusions"
    ["cp"]="Standard copy utility (no exclusions)"
)

# Check if a tool is available and get version if possible
function check_tool() {
    local tool="$1"
    local description="$2"

    if command_exists "$tool"; then
        local version=""
        case "$tool" in
            "jq")
                version=$(jq --version 2>/dev/null || echo "unknown")
                ;;
            "git")
                version=$(git --version 2>/dev/null | head -1 || echo "unknown")
                ;;
            "gh")
                version=$(gh --version 2>/dev/null | head -1 || echo "unknown")
                ;;
            "wp")
                version=$(wp --version 2>/dev/null || echo "unknown")
                ;;
            "composer")
                version=$(composer --version 2>/dev/null | head -1 || echo "unknown")
                ;;
            "node")
                version=$(node --version 2>/dev/null || echo "unknown")
                ;;
            "npm")
                version=$(npm --version 2>/dev/null || echo "unknown")
                ;;
            "yarn")
                version=$(yarn --version 2>/dev/null || echo "unknown")
                ;;
            *)
                version=$($tool --version 2>/dev/null | head -1 || echo "available")
                ;;
        esac
        echo "✅ $tool: $version"
        return 0
    else
        echo "❌ $tool: Not found - $description"
        return 1
    fi
}

# Check GitHub CLI authentication
function check_gh_auth() {
    if command_exists "gh"; then
        if gh auth status >/dev/null 2>&1; then
            echo "✅ GitHub CLI: Authenticated"
            return 0
        else
            echo "⚠️  GitHub CLI: Not authenticated (run 'gh auth login')"
            return 1
        fi
    else
        echo "❌ GitHub CLI: Not installed"
        return 1
    fi
}

# Check for at least one compression tool
function check_compression_tools() {
    local found_tool=""
    local available_tools=()

    for tool in "${!COMPRESSION_TOOLS[@]}"; do
        if command_exists "$tool"; then
            available_tools+=("$tool")
            if [ -z "$found_tool" ]; then
                found_tool="$tool"
            fi
        fi
    done

    if [ -n "$found_tool" ]; then
        echo "✅ Compression: ${available_tools[*]}"
        return 0
    else
        echo "❌ Compression: No compression tools found (need one of: ${!COMPRESSION_TOOLS[*]})"
        return 1
    fi
}

# Check for at least one copy tool
function check_copy_tools() {
    local found_tool=""
    local available_tools=()

    for tool in "${!COPY_TOOLS[@]}"; do
        if command_exists "$tool"; then
            available_tools+=("$tool")
            if [ -z "$found_tool" ]; then
                found_tool="$tool"
            fi
        fi
    done

    if [ -n "$found_tool" ]; then
        echo "✅ File Copy: ${available_tools[*]}"
        return 0
    else
        echo "❌ File Copy: No copy tools found (need one of: ${!COPY_TOOLS[*]})"
        return 1
    fi
}

# Main tool checking function
function check_all_tools() {
    local quiet_mode="${1:-false}"
    local failed_required=0
    local failed_optional=0

    if [ "$quiet_mode" != "true" ]; then
        echo "🔧 Checking required tools..."
    fi

    # Check required tools
    for tool in "${!REQUIRED_TOOLS[@]}"; do
        if ! check_tool "$tool" "${REQUIRED_TOOLS[$tool]}"; then
            failed_required=$((failed_required + 1))
        fi
    done

    # Check GitHub CLI authentication separately
    if ! check_gh_auth; then
        failed_required=$((failed_required + 1))
    fi

    # Check compression tools (at least one required)
    if ! check_compression_tools; then
        failed_required=$((failed_required + 1))
    fi

    # Check copy tools (at least one required)
    if ! check_copy_tools; then
        failed_required=$((failed_required + 1))
    fi

    if [ "$quiet_mode" != "true" ]; then
        echo ""
        echo "🔧 Checking optional tools..."
    fi

    # Check optional tools
    for tool in "${!OPTIONAL_TOOLS[@]}"; do
        if ! check_tool "$tool" "${OPTIONAL_TOOLS[$tool]}"; then
            failed_optional=$((failed_optional + 1))
        fi
    done

    if [ "$quiet_mode" != "true" ]; then
        echo ""
        echo "📋 Platform: $(get_platform)"
        echo ""
    fi

    # Summary
    if [ $failed_required -gt 0 ]; then
        echo "❌ $failed_required required tools are missing or not configured properly."
        echo "   Please install missing tools before proceeding."
        return 1
    else
        if [ "$quiet_mode" != "true" ]; then
            echo "✅ All required tools are available!"
            if [ $failed_optional -gt 0 ]; then
                echo "ℹ️  $failed_optional optional tools are missing (this is okay)."
            fi
        fi
        return 0
    fi
}

# Quick check function for use in scripts
function quick_tool_check() {
    check_all_tools "true" >/dev/null 2>&1
    return $?
}
