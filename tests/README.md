# WP-Build-Tools Test Suite

Comprehensive test suite for validating wp-release functionality before publishing new versions to npm.

## Overview

This test suite creates a sandbox environment where it:

1. **Copies Max Marine plugins/themes** to a temporary directory (`wp-build-tools-tests`)
2. **Runs wp-release in dry-run mode** on each project (no git operations)
3. **Validates all expected changes** (version bumps, ZIP contents, changelog updates, etc.)
4. **Generates detailed reports** showing what was tested and results
5. **Makes zero changes** to the original Max Marine directory

## Quick Start

```bash
# Run full test suite
npm test

# Run quick test (subset of projects)
npm run test:quick

# Clean up test sandbox only
npm run test:cleanup
```

## Test Structure

```
tests/
├── wp-release-test.sh              # Main test runner
├── lib/
│   ├── test-sandbox.sh             # Sandbox management
│   ├── test-validation.sh          # Validation functions
│   ├── test-config.sh              # Test configuration
│   └── test-reporting.sh           # Test reporting
├── config/
│   └── test-config.conf            # Test settings
└── README.md                       # This file
```

## What Gets Tested

### ✅ **Validated Features:**

- **Project Structure** - WordPress headers, required files
- **Version Bumping** - package.json, PHP headers, block.json, constants
- **ZIP Creation** - Release asset generation with proper exclusions
- **Build Process** - npm/yarn build scripts (if present)
- **Changelog Updates** - Version entries and date formatting
- **Exclusion Compliance** - node_modules, .git, vendor, etc. properly excluded
- **WordPress Features** - Plugin/theme detection, POT file generation

### ❌ **Skipped Operations (Dry-Run Mode):**

- Git commits and pushes
- Git tag creation
- GitHub release creation
- Release asset upload
- Branch creation/switching

## Test Projects

### Full Test Suite (28 plugins + 1 theme):
- All max-marine-* plugins from F:/MaxMarineAssets/Code/wp-content/plugins
- max-marine-block-theme-2025 from F:/MaxMarineAssets/Code/wp-content/themes

### Quick Test Suite (6 projects):
- max-marine-alphabetized-brands-block
- max-marine-brand-carousel-block
- max-marine-popular-brands-block
- max-marine-block-theme-2025
- max-marine-background-processor
- max-marine-performance-optimizations

## Configuration

Edit `tests/config/test-config.conf` to customize:

```bash
# Version bump type to test
TEST_VERSION_TYPE="patch"

# Enable/disable specific test categories
TEST_BUILD_PROCESS=true
TEST_ZIP_CREATION=true
TEST_VERSION_BUMPING=true
TEST_CHANGELOG_UPDATES=true
TEST_EXCLUSIONS=true

# Test execution settings
TEST_TIMEOUT=300
MAX_PARALLEL_TESTS=3
KEEP_FAILED_ARTIFACTS=true

# Project Selection (NEW!)
# Quick mode projects (space-separated list)
QUICK_MODE_PROJECTS="max-marine-alphabetized-brands-block max-marine-brand-carousel-block max-marine-popular-brands-block max-marine-block-theme-2025 max-marine-background-processor max-marine-performance-optimizations"

# Full mode projects (if not set, tests all max-marine-* projects)
# FULL_MODE_PROJECTS="max-marine-alphabetized-brands-block max-marine-automated-product-image-processing max-marine-background-processor"

# Skip projects matching these patterns
# SKIP_PATTERNS="*-test-* *-deprecated-*"
REPORT_FORMAT="both"
```

## Command Line Options

```bash
# Test runner options
bash tests/wp-release-test.sh [OPTIONS]

--quick             Run tests on subset of projects (faster)
--cleanup-only      Only clean up existing sandbox and exit
--keep-sandbox      Don't delete sandbox after tests (for debugging)
--verbose           Show detailed output during tests
--help, -h          Show help message
```

## Test Reports

Reports are generated in `wp-build-tools-tests/reports/`:

- **Text Report** - Human-readable summary with detailed results
- **JSON Report** - Machine-readable data for CI/CD integration

### Sample Report Output:

```
📊 Test Summary:
   Total tests: 29
   Passed: 27
   Failed: 2
   Success rate: 93%
```

## Prerequisites

- All wp-release requirements (git, jq, gh, compression tools)
- Access to F:/MaxMarineAssets/Code/wp-content
- Sufficient disk space (several GB for sandbox)

## Troubleshooting

### Common Issues:

1. **"Max Marine source directory not found"**
   - Ensure F:/MaxMarineAssets/Code/wp-content exists and is accessible

2. **"Missing required tools"**
   - Run `wp-release --check-tools` to see what's missing

3. **"Low disk space warning"**
   - Free up space or use `--quick` mode for smaller test set

4. **Tests fail with build errors**
   - Check individual project build scripts and dependencies

### Debug Mode:

```bash
# Keep sandbox for inspection
npm test -- --keep-sandbox --verbose

# Check sandbox contents
ls -la wp-build-tools-tests/

# Manually test a single project
cd wp-build-tools-tests/plugins/max-marine-alphabetized-brands-block
bash ../../bin/release.sh --dry-run patch
```

## Integration with CI/CD

The test suite is designed to be run before releasing new versions of wp-build-tools:

```bash
# In your release workflow
npm test                    # Run full test suite
npm run build              # Build the package
npm publish                # Publish to npm
```

## Safety Features

- **Read-only operations** on original Max Marine files
- **Sandbox isolation** - all changes happen in temporary directory
- **Dry-run mode** - no git operations or external API calls
- **Automatic cleanup** - sandbox removed after tests (unless --keep-sandbox)
- **Validation-only** - tests verify expected changes without applying them

## Contributing

When adding new features to wp-build-tools:

1. Add corresponding validation functions to `test-validation.sh`
2. Update test configuration in `test-config.sh` if needed
3. Run the test suite to ensure compatibility
4. Update this README if new test categories are added
