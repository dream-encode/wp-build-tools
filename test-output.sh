#!/bin/bash

# Test script that writes output to a file
cd /f/MaxMarineAssets/Code/wp-content/themes/max-marine-block-theme-2025

output_file="/tmp/test-results.txt"
echo "=== Testing composer exclusion logic ===" > "$output_file"
echo "Current directory: $(pwd)" >> "$output_file"
echo "" >> "$output_file"

echo "1. Checking if composer.json exists:" >> "$output_file"
if [ -f "composer.json" ]; then
    echo "   ✅ composer.json exists" >> "$output_file"
else
    echo "   ❌ composer.json does not exist" >> "$output_file"
fi

echo "" >> "$output_file"
echo "2. Checking if jq is available:" >> "$output_file"
if command -v jq >/dev/null 2>&1; then
    echo "   ✅ jq is available" >> "$output_file"
else
    echo "   ❌ jq is not available" >> "$output_file"
fi

echo "" >> "$output_file"
echo "3. Checking if composer.json has autoload section:" >> "$output_file"
if jq -e '.autoload' composer.json >/dev/null 2>&1; then
    echo "   ✅ composer.json HAS autoload section" >> "$output_file"
else
    echo "   ❌ composer.json does NOT have autoload section" >> "$output_file"
fi

echo "" >> "$output_file"
echo "4. Testing exclusion function:" >> "$output_file"
source /f/DreamEncodeAssets/BuildTools/wp-build-tools/bin/lib/general-functions.sh

exclusions=$(get_zip_folder_exclusions)
if echo "$exclusions" | grep -q "composer"; then
    echo "   ❌ composer.* IS being excluded (BAD)" >> "$output_file"
    echo "   Exclusions containing 'composer':" >> "$output_file"
    echo "$exclusions" | grep composer | sed 's/^/      /' >> "$output_file"
else
    echo "   ✅ composer.* is NOT being excluded (GOOD)" >> "$output_file"
fi

echo "" >> "$output_file"
echo "=== Test complete ===" >> "$output_file"

# Also output to stdout
cat "$output_file"
