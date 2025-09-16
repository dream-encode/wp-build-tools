#!/bin/bash

# test-sandbox.sh
# Sandbox management functions for wp-release testing
# Handles creation, setup, and cleanup of the test environment

# Fallback print_color function if not defined
if ! command -v print_color >/dev/null 2>&1; then
    print_color() {
        local color="$1"
        local message="$2"
        echo "$message"
    }
fi

# Setup the test sandbox
setup_sandbox() {
    echo "Setting up test sandbox..."

    # Remove existing sandbox if it exists
    if [ -d "$SANDBOX_DIR" ]; then
        echo "Removing existing sandbox..."
        rm -rf "$SANDBOX_DIR"
    fi

    # Create sandbox directory structure
    mkdir -p "$SANDBOX_DIR"
    mkdir -p "$SANDBOX_DIR/plugins"
    mkdir -p "$SANDBOX_DIR/themes"
    mkdir -p "$SANDBOX_DIR/reports"
    mkdir -p "$SANDBOX_DIR/temp"

    # Copy wp-build-tools to sandbox for testing
    echo "Copying wp-build-tools to sandbox..."
    cp -r "$PROJECT_ROOT/bin" "$SANDBOX_DIR/"
    cp -r "$PROJECT_ROOT/config" "$SANDBOX_DIR/"

    # Make scripts executable
    chmod +x "$SANDBOX_DIR/bin/release.sh"
    chmod +x "$SANDBOX_DIR/bin/wp-release.js"

    print_color "$GREEN" "✅ Sandbox setup complete"
}

# Copy test projects to sandbox
copy_test_projects() {
    echo "Copying test projects to sandbox..."

    local projects_to_test
    if [ "$QUICK_MODE" = true ]; then
        projects_to_test=$(get_quick_test_projects)
    else
        projects_to_test=$(get_all_test_projects)
    fi

    local copied_count=0
    local failed_count=0

    while IFS= read -r project; do
        if [ -n "$project" ]; then
            echo "  Copying $project..."
            copy_single_project "$project"
            local copy_result=$?
            echo "    Copy result: $copy_result"
            if [ $copy_result -eq 0 ]; then
                copied_count=$((copied_count + 1))
                echo "    ✅ Success (count: $copied_count)"
            else
                failed_count=$((failed_count + 1))
                echo "    ❌ Failed (count: $failed_count)"
            fi
            echo "    Moving to next project..."
        fi
    done <<< "$projects_to_test"

    echo "While loop completed"

    echo "Copied $copied_count projects successfully"
    if [ $failed_count -gt 0 ]; then
        print_color "$YELLOW" "⚠️  Failed to copy $failed_count projects"
    fi

    print_color "$GREEN" "✅ Project preparation complete"
}

# Copy a single project to sandbox
copy_single_project() {
    local project_name="$1"
    local source_path=""
    local dest_path=""

    # Determine if it's a plugin or theme
    if [ -d "$MAX_MARINE_SOURCE/plugins/$project_name" ]; then
        source_path="$MAX_MARINE_SOURCE/plugins/$project_name"
        dest_path="$SANDBOX_DIR/plugins/$project_name"
    elif [ -d "$MAX_MARINE_SOURCE/themes/$project_name" ]; then
        source_path="$MAX_MARINE_SOURCE/themes/$project_name"
        dest_path="$SANDBOX_DIR/themes/$project_name"
    else
        print_color "$RED" "❌ Project not found: $project_name"
        return 1
    fi



    # Use tar to copy with exclusions (much faster than cp for large directories)
    if [ "$VERBOSE" = true ]; then
        echo "    Using tar with exclusions..."
    fi

    # Create destination directory
    mkdir -p "$dest_path"

    if [ "$VERBOSE" = true ]; then
        echo "    Source: $source_path"
        echo "    Dest: $dest_path"
        echo "    Starting tar command..."
    fi

    # Use optimized copy method: copy all, then remove excluded items
    if [ "$VERBOSE" = true ]; then
        echo "    Using optimized copy with post-exclusion cleanup..."
    fi

    # First, copy everything quickly
    (
        cd "$source_path" || exit 1
        tar -cf - . | (cd "$dest_path" && tar -xf -)
    )

    # Then remove excluded items (including third-party .git files)
    if [ "$VERBOSE" = true ]; then
        echo "    Cleaning up excluded items..."
    fi

    # Remove .git directories and files (including from third-party libraries)
    find "$dest_path" -name '.git' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$dest_path" -name '.gitignore' -type f -delete 2>/dev/null || true
    find "$dest_path" -name '.gitattributes' -type f -delete 2>/dev/null || true
    find "$dest_path" -name '.github' -type d -exec rm -rf {} + 2>/dev/null || true

    # Remove node_modules and vendor if they exist (but keep them for now as they might be needed)
    # find "$dest_path" -name 'node_modules' -type d -exec rm -rf {} + 2>/dev/null || true
    # find "$dest_path" -name 'vendor' -type d -exec rm -rf {} + 2>/dev/null || true

    # Remove log and temp files
    find "$dest_path" -name '*.log' -type f -delete 2>/dev/null || true
    find "$dest_path" -name '*.tmp' -type f -delete 2>/dev/null || true

    if [ "$VERBOSE" = true ]; then
        echo "    Tar command completed"
    fi

    # Check if copy was successful by verifying package.json exists
    if [ "$VERBOSE" = true ]; then
        echo "    Checking if copy was successful..."
    fi

    if [ -f "$dest_path/package.json" ]; then
        if [ "$VERBOSE" = true ]; then
            echo "    Copy validation successful"
        fi
        return 0
    else
        if [ "$VERBOSE" = true ]; then
            echo "    Copy validation failed - package.json not found"
        fi
        return 1
    fi
}

# Cleanup sandbox
cleanup_sandbox() {
    if [ -d "$SANDBOX_DIR" ]; then
        echo "Cleaning up test sandbox..."
        rm -rf "$SANDBOX_DIR"
        print_color "$GREEN" "✅ Sandbox cleanup complete"
    else
        echo "No sandbox to clean up"
    fi
}

# Get list of projects in sandbox
get_sandbox_projects() {
    local projects=()

    # Get plugins
    if [ -d "$SANDBOX_DIR/plugins" ]; then
        for plugin_dir in "$SANDBOX_DIR/plugins"/*; do
            if [ -d "$plugin_dir" ]; then
                projects+=("plugins/$(basename "$plugin_dir")")
            fi
        done
    fi

    # Get themes
    if [ -d "$SANDBOX_DIR/themes" ]; then
        for theme_dir in "$SANDBOX_DIR/themes"/*; do
            if [ -d "$theme_dir" ]; then
                projects+=("themes/$(basename "$theme_dir")")
            fi
        done
    fi

    printf '%s\n' "${projects[@]}"
}

# Check if sandbox is ready
is_sandbox_ready() {
    [ -d "$SANDBOX_DIR" ] && \
    [ -d "$SANDBOX_DIR/bin" ] && \
    [ -f "$SANDBOX_DIR/bin/release.sh" ] && \
    [ -x "$SANDBOX_DIR/bin/release.sh" ]
}

# Get sandbox project path
get_sandbox_project_path() {
    local project="$1"
    echo "$SANDBOX_DIR/$project"
}

# Create a temporary git repo for a project (needed for wp-release)
setup_temp_git_repo() {
    local project_path="$1"

    if [ ! -d "$project_path" ]; then
        return 1
    fi

    cd "$project_path"

    # Initialize git repo if not exists
    if [ ! -d ".git" ]; then
        git init >/dev/null 2>&1
        git config user.email "test@wp-build-tools.test" >/dev/null 2>&1
        git config user.name "WP Build Tools Test" >/dev/null 2>&1

        # Create initial commit
        git add . >/dev/null 2>&1
        git commit -m "Initial test commit" >/dev/null 2>&1

        # Create development branch (required by wp-release)
        git checkout -b development >/dev/null 2>&1
    fi

    return 0
}

# Backup project state before testing
backup_project_state() {
    local project_path="$1"
    local backup_path="$project_path.backup"

    if [ -d "$project_path" ]; then
        cp -r "$project_path" "$backup_path"
        return $?
    fi

    return 1
}

# Restore project state after testing
restore_project_state() {
    local project_path="$1"
    local backup_path="$project_path.backup"

    if [ -d "$backup_path" ]; then
        rm -rf "$project_path"
        mv "$backup_path" "$project_path"
        return $?
    fi

    return 1
}

# Get sandbox disk usage
get_sandbox_size() {
    if [ -d "$SANDBOX_DIR" ] && command -v du >/dev/null 2>&1; then
        du -sh "$SANDBOX_DIR" 2>/dev/null | cut -f1
    else
        echo "unknown"
    fi
}
