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

wp_create_release
