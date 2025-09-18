#!/bin/bash

# Test script to verify composer exclusion logic
cd /f/MaxMarineAssets/Code/wp-content/themes/max-marine-block-theme-2025

echo "=== Testing composer exclusion logic ==="
echo "Current directory: $(pwd)"
echo ""

echo "1. Checking if composer.json exists:"
if [ -f "composer.json" ]; then
    echo "   ✅ composer.json exists"
else
    echo "   ❌ composer.json does not exist"
    exit 1
fi

echo ""
echo "2. Checking if jq is available:"
if command -v jq >/dev/null 2>&1; then
    echo "   ✅ jq is available"
else
    echo "   ❌ jq is not available"
    exit 1
fi

echo ""
echo "3. Checking if composer.json has autoload section:"
if jq -e '.autoload' composer.json >/dev/null 2>&1; then
    echo "   ✅ composer.json HAS autoload section"
    has_autoload="true"
else
    echo "   ❌ composer.json does NOT have autoload section"
    has_autoload="false"
fi

echo ""
echo "4. Testing exclusion function:"
source /f/DreamEncodeAssets/BuildTools/wp-build-tools/bin/lib/general-functions.sh

exclusions=$(get_zip_folder_exclusions)
if echo "$exclusions" | grep -q "composer"; then
    echo "   ❌ composer.* IS being excluded (BAD)"
    echo "   Exclusions containing 'composer':"
    echo "$exclusions" | grep composer | sed 's/^/      /'
else
    echo "   ✅ composer.* is NOT being excluded (GOOD)"
fi

echo ""
echo "5. All exclusions:"
echo "$exclusions" | head -10 | sed 's/^/   /'
echo "   ... (showing first 10)"

echo ""
echo "=== Test complete ==="
