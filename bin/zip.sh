#!/bin/bash

# WordPress ZIP Creation Tool
# Part of wp-build-tools package
# Creates ZIP files for WordPress plugins and themes

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all required functions
source "$SCRIPT_DIR/lib/platform-utils.sh"
source "$SCRIPT_DIR/lib/general-functions.sh"
source "$SCRIPT_DIR/lib/wp-functions.sh"

# Help text
show_help() {
    cat << EOF
WordPress ZIP Creation Tool

USAGE
    wp-zip [OPTIONS]

DESCRIPTION
    Creates ZIP files for WordPress plugins and themes with proper exclusions.
    Automatically detects project type and prompts for ZIP type selection.

OPTIONS
    --for-install         Create ZIP for installation (files at root)
    --for-git-updater     Create versioned ZIP for Git Updater
    --quiet               Suppress output (returns only ZIP file path)
    --help                Show this help message

EXAMPLES
    wp-zip                        # Interactive mode with type selection
    wp-zip --for-install          # Create installation ZIP
    wp-zip --for-git-updater      # Create versioned ZIP for Git Updater
    wp-zip --quiet                # Silent mode

WORKFLOW
    1. Detects WordPress plugin/theme directory
    2. Prompts for ZIP type (install vs Git Updater)
    3. Copies files to temporary directory with exclusions
    4. Creates ZIP file in temp directory
    5. Opens file location for easy access

REQUIREMENTS
    • Compression tool (7z, zip)
    • Copy tool (robocopy, rsync, tar, cp)

EOF
}

# Parse command line arguments
HELP_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            HELP_MODE=true
            shift
            ;;
        *)
            # Pass all other arguments to wp_zip function
            break
            ;;
    esac
done

# Show help if requested
if [ "$HELP_MODE" = true ]; then
    show_help
    exit 0
fi

# Check if we're in a WordPress plugin or theme directory
if ! is_wp_plugin_dir && ! is_wp_theme_dir; then
    echo "❌ Error: This command must be run from within a WordPress plugin or theme directory."
    echo ""
    echo "Expected directory structure:"
    echo "  • Plugin: */wp-content/plugins/your-plugin/"
    echo "  • Theme:  */wp-content/themes/your-theme/"
    echo ""
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check if we're in quiet mode first
if [[ "$*" == *"--quiet"* ]]; then
    # In quiet mode, just call wp_zip and let it handle everything
    wp_zip "$@"
    exit $?
fi

# Call the wp_zip function with all arguments
echo "🚀 WordPress ZIP Creation Tool"
echo "=============================="
echo ""

# In non-quiet mode, we need to capture the ZIP file path
# Create a temporary file to capture the output
TEMP_OUTPUT_FILE="/tmp/wp-zip-output-$$"

# Call wp_zip and capture both stdout and the exit code
wp_zip "$@" > "$TEMP_OUTPUT_FILE" 2>&1
zip_exit_code=$?

# Display the output
cat "$TEMP_OUTPUT_FILE"

# Check if ZIP creation was successful
if [ $zip_exit_code -ne 0 ]; then
    rm -f "$TEMP_OUTPUT_FILE"
    echo ""
    echo "❌ ZIP creation failed."
    exit 1
fi

# Extract the ZIP file path from the last line that contains "Zip:"
ZIP_FILE_PATH=$(grep "Zip:" "$TEMP_OUTPUT_FILE" | tail -1 | sed 's/.*Zip: //')
rm -f "$TEMP_OUTPUT_FILE"

if [ -z "$ZIP_FILE_PATH" ]; then
    echo ""
    echo "❌ Could not determine ZIP file location."
    exit 1
fi

echo ""
echo "🎉 ZIP creation completed successfully!"
echo ""
echo "📁 ZIP Location: $ZIP_FILE_PATH"

# Try to open the file location in the system file manager
TEMP_DIR=$(dirname "$ZIP_FILE_PATH")

echo ""
echo "🔗 Opening file location..."

# Cross-platform file manager opening
case "$(get_platform)" in
    "windows")
        if command -v explorer.exe >/dev/null 2>&1; then
            # Convert path to Windows format for explorer
            WINDOWS_PATH=$(convert_path_for_windows_tools "$TEMP_DIR")
            explorer.exe "$WINDOWS_PATH" 2>/dev/null || echo "   ℹ️  Could not open file manager automatically"
        else
            echo "   ℹ️  File manager not available"
        fi
        ;;
    "macos")
        if command -v open >/dev/null 2>&1; then
            open "$TEMP_DIR" 2>/dev/null || echo "   ℹ️  Could not open Finder automatically"
        else
            echo "   ℹ️  Finder not available"
        fi
        ;;
    "linux")
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$TEMP_DIR" 2>/dev/null || echo "   ℹ️  Could not open file manager automatically"
        elif command -v nautilus >/dev/null 2>&1; then
            nautilus "$TEMP_DIR" 2>/dev/null || echo "   ℹ️  Could not open file manager automatically"
        else
            echo "   ℹ️  File manager not available"
        fi
        ;;
    *)
        echo "   ℹ️  File manager opening not supported on this platform"
        ;;
esac

echo ""
echo "✅ Ready to use! The ZIP file is available at the location above."
