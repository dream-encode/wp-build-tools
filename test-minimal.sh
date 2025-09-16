#!/bin/bash

echo "Starting minimal test..."

# Test path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "PROJECT_ROOT: $PROJECT_ROOT"

# Test sourcing files one by one
echo "Testing platform-utils.sh..."
source "$PROJECT_ROOT/bin/lib/platform-utils.sh"
echo "✅ platform-utils.sh loaded"

echo "Testing tool-checker.sh..."
source "$PROJECT_ROOT/bin/lib/tool-checker.sh"
echo "✅ tool-checker.sh loaded"

echo "Testing test-sandbox.sh..."
source "$SCRIPT_DIR/tests/lib/test-sandbox.sh"
echo "✅ test-sandbox.sh loaded"

echo "Testing test-validation.sh..."
source "$SCRIPT_DIR/tests/lib/test-validation.sh"
echo "✅ test-validation.sh loaded"

echo "Testing test-config.sh..."
source "$SCRIPT_DIR/tests/lib/test-config.sh"
echo "✅ test-config.sh loaded"

echo "Testing test-reporting.sh..."
source "$SCRIPT_DIR/tests/lib/test-reporting.sh"
echo "✅ test-reporting.sh loaded"

echo "All files loaded successfully!"
