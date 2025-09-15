# WP Build Tools

Some scripts to help handle builds, releases, testing, etc.

## Prerequisites

The release script automatically detects and uses the best available tools on your platform (Windows, macOS, Linux).

### Required Tools
- **Git** - Version control operations
- **GitHub CLI (gh)** - Creating GitHub releases ([install](https://cli.github.com/) & authenticate: `gh auth login`)
- **jq** - JSON processing
- **Compression tool** - One of: 7z, zip

### Optional Tools
- **WP-CLI** - Translation file updates ([install](https://wp-cli.org/))
- **Node.js/npm/yarn** - For block plugins
- **Composer** - For PHP dependencies

### Quick Install Commands
```bash
# Windows (via Chocolatey)
choco install git jq 7zip gh

# macOS (via Homebrew)
brew install git jq p7zip gh

# Linux (Ubuntu/Debian)
sudo apt install git jq p7zip-full
# Install GitHub CLI: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
```

### Automatic Setup
After installing wp-build-tools, it will automatically offer to configure your project:

```bash
npm install --save-dev @dream-encode/wp-build-tools
# Automatically prompts to add "release": "wp-release" to package.json
```

### Manual Setup
```bash
npx @dream-encode/wp-build-tools setup    # Interactive setup
npx @dream-encode/wp-build-tools setup --force    # Automatic setup
```

### Check Tool Availability
```bash
wp-release --check-tools    # Verify all tools are installed
wp-release --test           # Run comprehensive tests
```

## Usage

### Basic Commands

```bash
# Interactive release (prompts for version bump type selection)
wp-release

# Specific version bumps
wp-release patch    # 1.0.0 → 1.0.1 (bug fixes)
wp-release minor    # 1.0.0 → 1.1.0 (new features)
wp-release major    # 1.0.0 → 2.0.0 (breaking changes)
wp-release hotfix   # 1.0.0 → 1.0.0.1 (critical fixes)

# Tool management
wp-release --check-tools    # Check if all required tools are installed
wp-release --test           # Run comprehensive compatibility and readiness tests
wp-release --help           # Show detailed help
wp-release --version        # Show version info
```

### Using npm/yarn scripts (alternative)

```bash
# If you have npm scripts configured
npm run release
yarn release
```

## What the release script does

1. **Pre-release validation**
   - Checks for Ray debugging code
   - Validates git repository state
   - Ensures working directory is clean

2. **Project type detection**
   - Detects if this is a regular plugin, theme, or block plugin
   - Applies appropriate build and packaging logic

3. **Version management**
   - Interactive mode: Shows menu with version bump options (patch/minor/major/hotfix/custom)
   - Command line mode: Uses specified bump type (patch/minor/major/hotfix)
   - Calculates and displays new version before confirmation
   - Updates version in multiple files:
     - `package.json`
     - `composer.json` (if exists)
     - `block.json` files (if exists)
     - Main plugin PHP file
     - Constants files (if exists)
     - `public/manifest.json` (if exists)

4. **Translation updates**
   - Updates POT files using WP-CLI (if available)

5. **Changelog management**
   - Looks for "[NEXT_VERSION] - [UNRELEASED]" entry at top of CHANGELOG.md
   - Replaces "[NEXT_VERSION] - [UNRELEASED]" with "[X.X.X.X] - YYYY-MM-DD" format

6. **Git operations**
   - Commits version bump changes
   - Pushes to main branch
   - Creates and pushes git tag

7. **GitHub release**
   - Creates GitHub release with changelog notes
   - Uploads release ZIP asset (if plugin uses release assets)

8. **Build process**
   - Runs production build if `production` script exists
   - Falls back to `build` script if available
   - Creates optimized ZIP file for distribution

## Configuration

### Automatic Project Setup

When you install `@dream-encode/wp-build-tools` in a project, it will automatically:

1. **Detect your project** - Finds your package.json
2. **Analyze existing scripts** - Checks for existing release scripts
3. **Prompt for setup** - Asks permission before making changes (in interactive mode)
4. **Backup existing scripts** - Saves any existing release script as "release-backup"
5. **Add release script** - Adds `"release": "wp-release"` to your package.json

#### Setup Options

```bash
# Interactive setup (prompts for confirmation)
npx @dream-encode/wp-build-tools setup

# Automatic setup (no prompts)
npx @dream-encode/wp-build-tools setup --force

# Skip setup entirely
NO_SETUP=1 npm install @dream-encode/wp-build-tools
```

#### What Gets Added

```json
{
  "scripts": {
    "release": "wp-release"
  }
}
```

If you already have a release script, it will be backed up:

```json
{
  "scripts": {
    "release": "wp-release",
    "release-backup": "your-previous-command"
  }
}
```

### Release Assets

To enable ZIP asset creation, add this line to your main plugin file header:

```php
/**
 * Release Asset: true
 */
```

### Custom ZIP Exclusions

You can customize which files and directories are excluded from ZIP files by creating a `.wp-build-exclusions` file in your project root:

```bash
# .wp-build-exclusions
# Custom exclusions for ZIP files (one per line)
# Lines starting with # are comments

# Exclude custom directories
development
local-config
temp-files

# Exclude file patterns
*.dev
*.local
*.backup

# Exclude documentation
docs
examples
```

These exclusions are **added to** the default exclusions (like `node_modules`, `vendor`, `.git`, etc.). The custom exclusions work with all compression tools (zip, 7z).

**Note:** The `.wp-build-exclusions` file itself is automatically excluded from ZIP files. The exclusions are read early in the release process to ensure the configuration file is available when needed.

### Changelog Format

The script expects a `CHANGELOG.md` file in Keep a Changelog format with an "0.6.1 - [UNRELEASED]" entry at the top:

```markdown
## 0.6.1 - [UNRELEASED]
* Added new feature
* Fixed bug

## [1.0.0] - 2024-01-15
* Initial release
```

During release, "0.6.1 - [UNRELEASED]" will be automatically replaced with the version and date:

```markdown
## [1.1.0] - 2024-01-20
* Added new feature
* Fixed bug

## [1.0.0] - 2024-01-15
* Initial release
```

Then, a new "0.6.1 - [UNRELEASED]" entry will be added at the top for the next release.

## Troubleshooting

### Common Issues

1. **"jq not found"** - Install jq JSON processor
2. **"gh not authenticated"** - Run `gh auth login`
3. **"Working directory not clean"** - Commit or stash changes
4. **"Changelog version mismatch"** - Update CHANGELOG.md with correct version

### Debug Mode

To see more detailed output, you can modify the script to add debug flags:

```bash
# Add to the top of release.sh after the shebang
set -x  # Enable debug output
```

## File Structure

```
bin/
├── release.sh                      # Main release script with CLI flags
├── wp-release.js                   # Node.js wrapper script
├── setup.js                        # Setup command (npx @dream-encode/wp-build-tools setup)
└── lib/
    ├── platform-utils.sh           # Cross-platform utilities
    ├── tool-checker.sh             # Tool availability checking
    ├── general-functions.sh        # General utility functions
    ├── git-functions.sh            # Git-related functions
    └── wp-functions.sh             # WordPress-specific functions

scripts/
├── setup-project.js                # Project setup logic
└── postinstall.js                  # Automatic setup after npm install
```

## Customization

You can customize the release process by modifying the functions in the `lib/` directory:

- **general-functions.sh** - Version bumping, file operations
- **git-functions.sh** - Git operations, GitHub releases
- **wp-functions.sh** - WordPress-specific operations, ZIP creation

## Support

If you encounter issues with the release script, check:

1. All prerequisites are installed and configured
2. You're in the correct directory (plugin root)
3. Git working directory is clean
4. GitHub CLI is authenticated
5. CHANGELOG.md format is correct
