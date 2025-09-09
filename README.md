# WP Build Tools

Some scripts to help handle builds, releases, testing, etc.

## Prerequisites

Before using the release script, ensure you have the following tools installed:

- **Git** - For version control operations
- **GitHub CLI (gh)** - For creating GitHub releases
  - Install: https://cli.github.com/
  - Authenticate: `gh auth login`
- **jq** - For JSON processing
  - Install: `sudo apt-get install jq` (Linux) or `brew install jq` (macOS)
- **WP-CLI** (optional) - For updating translation files
  - Install: https://wp-cli.org/

## Usage

### Using npm/yarn scripts (recommended)

```bash
# Interactive release (prompts for version bump type selection)
npm run release
# or
yarn release
```

### Direct script execution

```bash
# Interactive release (shows version bump type menu)
./bin/release.sh
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
     - `public/manifest.json` (if exists)

4. **Translation updates**
   - Updates POT files using WP-CLI (if available)

5. **Changelog management**
   - Looks for "[NEXT_VERSION]" entry at top of CHANGELOG.md
   - Replaces "[NEXT_VERSION]" with "[X.X.X.X] - YYYY-MM-DD" format

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

### Release Assets

To enable ZIP asset creation, add this line to your main plugin file header:

```php
/**
 * Release Asset: true
 */
```

### Changelog Format

The script expects a `CHANGELOG.md` file in Keep a Changelog format with an "[NEXT_VERSION]" entry at the top:

```markdown
## [NEXT_VERSION]

* Added new feature
* Fixed bug

## [1.0.0] - 2024-01-15

* Initial release
```

During release, "[NEXT_VERSION]" will be automatically replaced with the version and date:

```markdown
## [1.1.0] - 2024-01-20

* Added new feature
* Fixed bug

## [1.0.0] - 2024-01-15

* Initial release
```

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
├── release.sh              # Main release script
├── lib/
│   ├── general-functions.sh # General utility functions
│   ├── git-functions.sh     # Git-related functions
│   └── wp-functions.sh      # WordPress-specific functions
└── README.md               # This file
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
