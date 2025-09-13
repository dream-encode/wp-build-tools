#!/bin/bash

# Cross-platform utility functions for wp-build-tools
# Handles platform-specific differences for Windows, macOS, and Linux

# File existence check.
function file_exists() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    return 0
}

# Get cross-platform temporary directory.
function get_temp_dir() {
    get_cross_platform_temp_dir
}

# Detect the current platform
function get_platform() {
    case "$OSTYPE" in
        msys*|cygwin*|mingw*)
            echo "windows"
            ;;
        darwin*)
            echo "macos"
            ;;
        linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get cross-platform temporary directory.
function get_cross_platform_temp_dir() {
    if [ -n "${TMPDIR:-}" ]; then
        echo "$TMPDIR"
    elif [ -n "${TMP:-}" ]; then
        echo "$TMP"
    elif [ -n "${TEMP:-}" ]; then
        echo "$TEMP"
    elif [ -d "/tmp" ]; then
        echo "/tmp"
    else
        echo "$HOME/tmp"
    fi
}

# Cross-platform sed in-place editing
function sed_inplace() {
    local pattern="$1"
    local file="$2"

    if [[ "$(get_platform)" == "macos" ]]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

# Convert path to Windows format if needed (for tools that require it)
function convert_path_for_windows_tools() {
    local path="$1"

    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$path"
    else
        echo "$path"
    fi
}

# Get the best available compression tool
function get_compression_tool() {
    # Check for 7-Zip variants
    if command -v 7z.exe >/dev/null 2>&1; then
        echo "7z.exe"
    elif command -v 7z >/dev/null 2>&1; then
        echo "7z"
    elif command -v 7za >/dev/null 2>&1; then
        echo "7za"
    elif command -v zip >/dev/null 2>&1; then
        echo "zip"
    else
        echo ""
    fi
}

# Get the best available copy tool
function get_copy_tool() {
    if command -v robocopy >/dev/null 2>&1; then
        echo "robocopy"
    elif command -v rsync >/dev/null 2>&1; then
        echo "rsync"
    elif command -v tar >/dev/null 2>&1; then
        echo "tar"
    elif command -v cp >/dev/null 2>&1; then
        echo "cp"
    else
        echo ""
    fi
}

# Check if a command exists and is executable
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get platform-specific file exclusion patterns for robocopy
function get_robocopy_exclusions() {
    local exclusions=("$@")
    local robocopy_dir_excludes=()
    local robocopy_file_excludes=()

    for exclusion in "${exclusions[@]}"; do
        if [[ "$exclusion" == *.* ]] && [[ "$exclusion" != .* ]]; then
            # File pattern exclusion (but not dot-prefixed directories)
            robocopy_file_excludes+=("/XF" "$exclusion")
        else
            # Directory exclusion - robocopy needs just the directory name, not full path
            robocopy_dir_excludes+=("/XD" "$exclusion")
        fi
    done

    echo "${robocopy_dir_excludes[@]} ${robocopy_file_excludes[@]}"
}

# Get platform-specific file exclusion patterns for rsync
function get_rsync_exclusions() {
    local exclusions=("$@")
    local rsync_excludes=()

    for exclusion in "${exclusions[@]}"; do
        rsync_excludes+=("--exclude=$exclusion")
    done

    echo "${rsync_excludes[@]}"
}

# Get platform-specific file exclusion patterns for 7z
function get_7z_exclusions() {
    local exclusions=("$@")
    local sevenz_excludes=()

    for exclusion in "${exclusions[@]}"; do
        sevenz_excludes+=("-xr!${exclusion}")
    done

    echo "${sevenz_excludes[@]}"
}

# Cross-platform directory creation
function create_directory() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || true
}

# Cross-platform file removal
function remove_file() {
    local file="$1"
    rm -f "$file" 2>/dev/null || true
}

# Cross-platform directory removal
function remove_directory() {
    local dir="$1"
    rm -rf "$dir" 2>/dev/null || true
}

# Get platform-specific file exclusion patterns for tar
function get_tar_exclusions() {
    local exclusions=("$@")
    local tar_excludes=()

    for exclusion in "${exclusions[@]}"; do
        tar_excludes+=("--exclude=$exclusion")
    done

    echo "${tar_excludes[@]}"
}


