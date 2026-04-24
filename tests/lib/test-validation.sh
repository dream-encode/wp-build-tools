#!/bin/bash

# test-validation.sh
# Validation functions for wp-release testing
# Validates version bumps, ZIP contents, changelog updates, etc.

# Validate version was bumped correctly
validate_version_bump() {
    local project_path="$1"
    local expected_version="$2"
    local validation_results=()

    echo "  Validating version bump to $expected_version..."

    # Check package.json version
    if [ -f "$project_path/package.json" ]; then
        local package_version=$(jq -r '.version' "$project_path/package.json" 2>/dev/null)
        if [ "$package_version" = "$expected_version" ]; then
            validation_results+=("✅ package.json version: $package_version")
        else
            validation_results+=("❌ package.json version: expected $expected_version, got $package_version")
        fi
    fi

    # Check main file version (PHP header)
    local main_file=$(get_project_main_file "$project_path")
    if [ -n "$main_file" ] && [ -f "$project_path/$main_file" ]; then
        local header_version=$(grep "Version:" "$project_path/$main_file" | head -1 | sed 's/.*Version: *\([0-9.]*\).*/\1/')
        if [ "$header_version" = "$expected_version" ]; then
            validation_results+=("✅ $main_file header version: $header_version")
        else
            validation_results+=("❌ $main_file header version: expected $expected_version, got $header_version")
        fi
    fi

    # Check block.json files (for block plugins)
    local block_files=$(find "$project_path" -name "block.json" -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/build/*" 2>/dev/null)
    if [ -n "$block_files" ]; then
        while IFS= read -r block_file; do
            if [ -f "$block_file" ]; then
                local block_version=$(jq -r '.version // "none"' "$block_file" 2>/dev/null)
                if [ "$block_version" = "$expected_version" ]; then
                    validation_results+=("✅ $(basename "$block_file") version: $block_version")
                else
                    validation_results+=("❌ $(basename "$block_file") version: expected $expected_version, got $block_version")
                fi
            fi
        done <<< "$block_files"
    fi

    # Check constants files
    local constants_files=()
    local project_name=$(basename "$project_path")
    local basename_upper=$(echo "$project_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Common constants file locations
    [ -f "$project_path/includes/${project_name}-constants.php" ] && constants_files+=("includes/${project_name}-constants.php")
    [ -f "$project_path/includes/mmewoa-constants.php" ] && constants_files+=("includes/mmewoa-constants.php")
    [ -f "$project_path/inc/constants.php" ] && constants_files+=("inc/constants.php")

    for constants_file in "${constants_files[@]}"; do
        if [ -f "$project_path/$constants_file" ]; then
            if grep -q "define.*${basename_upper}_\(PLUGIN\|THEME\)_VERSION.*$expected_version" "$project_path/$constants_file"; then
                validation_results+=("✅ $constants_file constant version: $expected_version")
            else
                validation_results+=("❌ $constants_file constant version: not found or incorrect")
            fi
        fi
    done

    # Print results
    for result in "${validation_results[@]}"; do
        echo "    $result"
        if [[ "$result" == *"⚠️"* ]]; then
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    done

    # Return success if no failures
    for result in "${validation_results[@]}"; do
        if [[ "$result" == *"❌"* ]]; then
            return 1
        fi
    done

    return 0
}

# Validate ZIP file contents
validate_zip_contents() {
    local zip_file="$1"
    local project_path="$2"
    local validation_results=()

    echo "  Validating ZIP contents..."

    if [ ! -f "$zip_file" ]; then
        echo "    ❌ ZIP file not found: $zip_file"
        return 1
    fi

    # Get ZIP contents - use a more reliable method
    local zip_contents
    if command -v unzip >/dev/null 2>&1; then
        # Use unzip -Z to get just filenames
        zip_contents=$(unzip -Z1 "$zip_file" 2>/dev/null | sed 's/\r//g')
    elif command -v 7z >/dev/null 2>&1; then
        # Use 7z with simpler parsing
        zip_contents=$(7z l "$zip_file" 2>/dev/null | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {print $NF}' | sed 's/\r//g')
    else
        echo "    ❌ No ZIP extraction tool available"
        return 1
    fi

    # Check for required files
    local main_file=$(get_project_main_file "$project_path")
    if [ -n "$main_file" ]; then
        if echo "$zip_contents" | grep -q "$main_file"; then
            validation_results+=("✅ Main file included: $main_file")
        else
            validation_results+=("❌ Main file missing: $main_file")
        fi
    fi

    # Check for unconditional exclusions.
    local excluded_items=(".git" "tests" ".gitignore" ".wp-build-exclusions" "assets/src" "webpack.config.js" "yarn.lock")
    for item in "${excluded_items[@]}"; do
        local item_regex=$(echo "$item" | sed 's/\./\\./g')
        if echo "$zip_contents" | grep -q -E "(^|/)$item_regex(/|$)"; then
            if [[ "$item" == "tests" ]] && ! echo "$zip_contents" | grep -q -E "^tests/|^[^/]+/tests/"; then
                validation_results+=("✅ Excluded item properly excluded: $item")
            else
                local matching_files=$(echo "$zip_contents" | grep -E "(^|/)$item_regex(/|$)" | head -n 1)
                validation_results+=("❌ Excluded item found in ZIP: $item (Matched: $matching_files)")
            fi
        else
            validation_results+=("✅ Excluded item properly excluded: $item")
        fi
    done

    # Dynamically validate node_modules based on whether project has production npm deps.
    if [ -f "$project_path/package.json" ] && command -v jq >/dev/null 2>&1; then
        local npm_prod_count=$(jq '.dependencies | length' "$project_path/package.json" 2>/dev/null || echo "0")
        if [ "$npm_prod_count" -gt 0 ]; then
            if echo "$zip_contents" | grep -q -E "(^|/)node_modules(/|$)"; then
                validation_results+=("✅ node_modules included (project has production npm deps)")
            else
                validation_results+=("⚠️  node_modules missing but project has production npm deps")
            fi
        else
            if echo "$zip_contents" | grep -q -E "(^|/)node_modules(/|$)"; then
                local match=$(echo "$zip_contents" | grep -E "(^|/)node_modules(/|$)" | head -n 1)
                validation_results+=("❌ node_modules found in ZIP but project has no production npm deps (Matched: $match)")
            else
                validation_results+=("✅ node_modules excluded (no production npm deps)")
            fi
        fi
    fi

    # Dynamically validate vendor based on whether project has production composer deps.
    if [ -f "$project_path/composer.json" ] && command -v jq >/dev/null 2>&1; then
        local composer_prod_count=$(jq '.require | length' "$project_path/composer.json" 2>/dev/null || echo "0")
        local composer_php_only=$(jq '.require | keys | length == 1 and .[0] == "php"' "$project_path/composer.json" 2>/dev/null || echo "false")
        if [ "$composer_prod_count" -gt 0 ] && [ "$composer_php_only" != "true" ]; then
            if echo "$zip_contents" | grep -q -E "(^|/)vendor(/|$)"; then
                validation_results+=("✅ vendor included (project has production composer deps)")
            else
                validation_results+=("⚠️  vendor missing but project has production composer deps")
            fi
        else
            if echo "$zip_contents" | grep -q -E "(^|/)vendor(/|$)"; then
                local match=$(echo "$zip_contents" | grep -E "(^|/)vendor(/|$)" | head -n 1)
                validation_results+=("❌ vendor found in ZIP but project has no production composer deps (Matched: $match)")
            else
                validation_results+=("✅ vendor excluded (no production composer deps)")
            fi
        fi
    fi

    # Check for build artifacts (if build script exists)
    if project_has_build_script "$project_path"; then
        if echo "$zip_contents" | grep -qE "build/|assets/dist/"; then
            validation_results+=("✅ Build artifacts included")
        else
            validation_results+=("⚠️  No build artifacts found (may be expected)")
        fi
    fi

    # Print results
    for result in "${validation_results[@]}"; do
        echo "    $result"
        if [[ "$result" == *"⚠️"* ]]; then
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    done

    # Return success if no failures
    for result in "${validation_results[@]}"; do
        if [[ "$result" == *"❌"* ]]; then
            return 1
        fi
    done

    return 0
}

# Validate changelog updates
validate_changelog_updates() {
    local project_path="$1"
    local expected_version="$2"
    local validation_results=()

    echo "  Validating changelog updates..."

    local changelog_file="$project_path/CHANGELOG.md"
    if [ ! -f "$changelog_file" ]; then
        echo "    ℹ️  No CHANGELOG.md found (optional)"
        return 0
    fi

    # Check if version exists in changelog
    if grep -q "## \[$expected_version\]" "$changelog_file"; then
        validation_results+=("✅ Version $expected_version found in changelog")
    else
        validation_results+=("⚠️  Version $expected_version not found in changelog (may be missing [NEXT_VERSION] template)")
    fi

    # Check if version has a date
    local version_line=$(grep "## \[$expected_version\]" "$changelog_file" | head -1)
    if [[ "$version_line" == *"$(date +%Y-%m-%d)"* ]]; then
        validation_results+=("✅ Version has today's date")
    else
        validation_results+=("⚠️  Version date may not be current")
    fi

    # Verify the [NEXT_VERSION] template was replaced (should not be present in a final release).
    if grep -q "\[NEXT_VERSION\]" "$changelog_file"; then
        validation_results+=("❌ [NEXT_VERSION] template was not replaced in changelog")
    fi

    # Print results
    for result in "${validation_results[@]}"; do
        echo "    $result"
        if [[ "$result" == *"⚠️"* ]]; then
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    done

    # Return success if no failures
    for result in "${validation_results[@]}"; do
        if [[ "$result" == *"❌"* ]]; then
            return 1
        fi
    done

    return 0
}

# Validate project structure
validate_project_structure() {
    local project_path="$1"
    local validation_results=()

    echo "  Validating project structure..."

    # Check for required files
    local main_file=$(get_project_main_file "$project_path")
    if [ -n "$main_file" ] && [ -f "$project_path/$main_file" ]; then
        validation_results+=("✅ Main file exists: $main_file")
    else
        validation_results+=("❌ Main file missing: $main_file")
    fi

    if [ -f "$project_path/package.json" ]; then
        validation_results+=("✅ package.json exists")
    else
        validation_results+=("❌ package.json missing")
    fi

    # Check WordPress headers
    if [ -n "$main_file" ] && [ -f "$project_path/$main_file" ]; then
        if grep -q "Plugin Name:\|Theme Name:" "$project_path/$main_file"; then
            validation_results+=("✅ WordPress headers found")
        else
            validation_results+=("❌ WordPress headers missing")
        fi

        if grep -q "Version:" "$project_path/$main_file"; then
            validation_results+=("✅ Version header found")
        else
            validation_results+=("❌ Version header missing")
        fi
    fi

    # Print results
    for result in "${validation_results[@]}"; do
        echo "    $result"
        if [[ "$result" == *"⚠️"* ]]; then
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    done

    # Return success if no failures
    for result in "${validation_results[@]}"; do
        if [[ "$result" == *"❌"* ]]; then
            return 1
        fi
    done

    return 0
}

# Validate build process
validate_build_process() {
    local project_path="$1"
    local validation_results=()

    echo "  Validating build process..."

    if ! project_has_build_script "$project_path"; then
        echo "    ℹ️  No build script found (optional)"
        return 0
    fi

    # Check if build artifacts exist
    local build_dirs=("build" "assets/dist" "assets/dist/js" "assets/dist/css" "admin/assets/dist" "public/assets/dist")
    local found_artifacts=false

    for build_dir in "${build_dirs[@]}"; do
        if [ -d "$project_path/$build_dir" ] && [ "$(ls -A "$project_path/$build_dir" 2>/dev/null)" ]; then
            validation_results+=("✅ Build artifacts found: $build_dir")
            found_artifacts=true
        fi
    done

    if [ "$found_artifacts" = false ]; then
        validation_results+=("⚠️  No build artifacts found")
    fi

    # Print results
    for result in "${validation_results[@]}"; do
        echo "    $result"
        if [[ "$result" == *"⚠️"* ]]; then
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    done

    return 0
}

# Run all validations for a project
validate_project() {
    local project_path="$1"
    local expected_version="$2"
    local zip_file="$3"
    local overall_success=true

    echo "Validating project: $(basename "$project_path")"

    # Structure validation
    if ! validate_project_structure "$project_path"; then
        overall_success=false
    fi

    # Version bump validation
    if ! validate_version_bump "$project_path" "$expected_version"; then
        overall_success=false
    fi

    # ZIP validation
    if [ -n "$zip_file" ] && [ -f "$zip_file" ]; then
        if ! validate_zip_contents "$zip_file" "$project_path"; then
            overall_success=false
        fi
    fi

    # Changelog validation
    if ! validate_changelog_updates "$project_path" "$expected_version"; then
        overall_success=false
    fi

    # Build validation
    validate_build_process "$project_path"

    if [ "$overall_success" = true ]; then
        echo "  ✅ All validations passed"
        return 0
    else
        echo "  ❌ Some validations failed"
        return 1
    fi
}
