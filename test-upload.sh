#!/bin/bash

# Test script to verify upload logic
RELEASE_VERSION="1.6.10"
ZIP_FILE_PATH="/tmp/max-marine-block-theme-2025-v1.6.10.zip"

echo "🔍 Testing upload logic..."

# Check if asset already exists first to avoid the upload entirely
asset_name=$(basename "$ZIP_FILE_PATH")
echo "🔍 Debug: Checking if asset already exists before upload..."
echo "🔍 Debug: Asset name: $asset_name"
echo "🔍 Debug: Release version: v$RELEASE_VERSION"

if gh release view "v$RELEASE_VERSION" --json assets --jq ".assets[].name" 2>/dev/null | grep -q "$asset_name"; then
    echo "⚠️  Asset already exists on GitHub release - skipping upload!"
    echo "   The release asset is already available on GitHub."
    exit 0
else
    echo "🔍 Debug: Asset not found, would proceed with upload..."
    echo "🔍 Debug: Would execute: gh release upload \"v$RELEASE_VERSION\" \"$ZIP_FILE_PATH\""
fi

echo "✅ Upload logic test completed!"
