#!/usr/bin/env node

/**
 * Postinstall Script for @dream-encode/wp-build-tools
 *
 * Runs automatically after npm install
 * Detects if setup is needed and prompts user appropriately
 */

const fs = require('fs');
const path = require('path');
const { setupReleaseScript, analyzeCurrentSetup, findProjectRoot } = require('./setup-project');

// ANSI color codes
const colors = {
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    red: '\x1b[31m',
    reset: '\x1b[0m',
    bold: '\x1b[1m',
    dim: '\x1b[2m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function isInteractive() {
    return process.stdout.isTTY && process.stdin.isTTY && !process.env.CI;
}

function isInWpBuildToolsDirectory() {
    // Check if we're installing wp-build-tools itself (not in a project using it)
    const currentPkg = path.join(process.cwd(), 'package.json');

    if (fs.existsSync(currentPkg)) {
        try {
            const pkg = JSON.parse(fs.readFileSync(currentPkg, 'utf8'));
            return pkg.name === '@dream-encode/wp-build-tools' || pkg.name === 'wp-build-tools';
        } catch {
            return false;
        }
    }

    return false;
}

function shouldSkipSetup() {
    // Skip in CI environments
    if (process.env.CI) return true;

    // Skip if NO_SETUP environment variable is set
    if (process.env.NO_SETUP) return true;

    // Skip if we're installing wp-build-tools itself
    if (isInWpBuildToolsDirectory()) return true;

    return false;
}

async function main() {
    // Early exit conditions
    if (shouldSkipSetup()) {
        return;
    }

    try {
        // Find project root
        const projectRoot = findProjectRoot();
        if (!projectRoot) {
            // No package.json found, probably not a Node.js project
            return;
        }

        // Read package.json
        const packagePath = path.join(projectRoot, 'package.json');
        let pkg;
        try {
            pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
        } catch {
            return; // Can't read package.json
        }

        // Analyze current setup
        const analysis = analyzeCurrentSetup(pkg);

        if (!analysis.needsSetup) {
            // Already configured, nothing to do
            return;
        }

        // Show setup notification
        log('\n' + '='.repeat(60), 'blue');
        log('🚀 wp-build-tools installed successfully!', 'bold');
        log('='.repeat(60), 'blue');

        if (isInteractive()) {
            log('\n💡 Quick Setup Available:', 'bold');
            log('   wp-build-tools can add "release" and "zip" scripts to your package.json', 'blue');
            log('   This enables: npm run release and npm run zip', 'dim');

            if (analysis.hasReleaseScript && !analysis.isReleaseConfigured) {
                log(`\n⚠️  Existing release script detected: "${analysis.currentReleaseScript}"`, 'yellow');
                log('   (will be backed up as "release-backup")', 'dim');
            }

            if (analysis.hasZipScript && !analysis.isZipConfigured) {
                log(`⚠️  Existing zip script detected: "${analysis.currentZipScript}"`, 'yellow');
                log('   (will be backed up as "zip-backup")', 'dim');
            }

            log('\n🔧 Setup Options:', 'bold');
            log('   • Interactive: npx @dream-encode/wp-build-tools setup', 'blue');
            log('   • Automatic:   npx @dream-encode/wp-build-tools setup --force', 'blue');
            log('   • Skip:        Set NO_SETUP=1 environment variable', 'dim');

            log('\n📖 Usage after setup:', 'bold');
            log('   npm run release        # Interactive release', 'blue');
            log('   npm run zip            # Create ZIP files', 'blue');
            log('   wp-release patch       # Patch release', 'blue');
            log('   wp-zip --help          # See ZIP options', 'blue');
            log('   wp-release --help      # See all release options', 'blue');
        } else {
            // Non-interactive environment
            log('\n💡 Setup required:', 'yellow');
            log('   Run: npx @dream-encode/wp-build-tools setup', 'blue');
        }

        log('\n' + '='.repeat(60), 'blue');

    } catch (error) {
        // Silently fail - postinstall scripts shouldn't break installation
        if (process.env.DEBUG) {
            console.error('wp-build-tools postinstall error:', error);
        }
    }
}

// Run the postinstall logic
main().catch(() => {
    // Silently fail - postinstall scripts shouldn't break installation
});
