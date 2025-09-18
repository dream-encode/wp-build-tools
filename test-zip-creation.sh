#!/bin/bash

# Test script to create a ZIP and verify composer files are included
cd /f/MaxMarineAssets/Code/wp-content/themes/max-marine-block-theme-2025

echo "=== Testing ZIP creation with composer files ==="
echo "Current directory: $(pwd)"
echo ""

# Source all required functions
source /f/DreamEncodeAssets/BuildTools/wp-build-tools/bin/lib/platform-utils.sh
source /f/DreamEncodeAssets/BuildTools/wp-build-tools/bin/lib/general-functions.sh

echo "1. Testing exclusion logic:"
exclusions=$(get_zip_folder_exclusions)
if echo "$exclusions" | grep -q "composer"; then
    echo "   ❌ composer.* IS being excluded"
    echo "$exclusions" | grep composer | sed 's/^/      /'
else
    echo "   ✅ composer.* is NOT being excluded"
fi

echo ""
echo "2. Creating test ZIP manually:"
temp_dir="/tmp/test-theme-zip"
zip_file="/tmp/test-theme.zip"

# Clean up previous test
rm -rf "$temp_dir" "$zip_file" 2>/dev/null

# Create temp directory
mkdir -p "$temp_dir"

# Copy files excluding the standard exclusions
echo "   Copying files..."
rsync -av --exclude-from=<(get_zip_folder_exclusions) . "$temp_dir/" >/dev/null 2>&1

echo ""
echo "3. Checking if composer files are in the temp directory:"
if [ -f "$temp_dir/composer.json" ]; then
    echo "   ✅ composer.json is included"
else
    echo "   ❌ composer.json is missing"
fi

if [ -f "$temp_dir/composer.lock" ]; then
    echo "   ✅ composer.lock is included"
else
    echo "   ❌ composer.lock is missing"
fi

echo ""
echo "4. Creating ZIP file:"
cd "$temp_dir"
zip -r "$zip_file" . >/dev/null 2>&1
cd - >/dev/null

echo ""
echo "5. Checking ZIP contents for composer files:"
if unzip -l "$zip_file" | grep -q "composer.json"; then
    echo "   ✅ composer.json is in the ZIP"
else
    echo "   ❌ composer.json is NOT in the ZIP"
fi

if unzip -l "$zip_file" | grep -q "composer.lock"; then
    echo "   ✅ composer.lock is in the ZIP"
else
    echo "   ❌ composer.lock is NOT in the ZIP"
fi

echo ""
echo "6. ZIP file created at: $zip_file"
echo "   Size: $(ls -lh "$zip_file" | awk '{print $5}')"

echo ""
echo "=== Test complete ==="
