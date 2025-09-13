#!/usr/bin/env node

/**
 * Project Setup Script for @dream-encode/wp-build-tools
 * 
 * Automatically configures the project's package.json with wp-release script
 * Handles existing scripts gracefully and prompts user for permission
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// ANSI color codes for better output
const colors = {
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    red: '\x1b[31m',
    reset: '\x1b[0m',
    bold: '\x1b[1m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function isInteractive() {
    return process.stdout.isTTY && process.stdin.isTTY && !process.env.CI;
}

function findProjectRoot() {
    let currentDir = process.cwd();
    
    // Walk up directory tree to find package.json
    while (currentDir !== path.dirname(currentDir)) {
        const packagePath = path.join(currentDir, 'package.json');
        if (fs.existsSync(packagePath)) {
            return currentDir;
        }
        currentDir = path.dirname(currentDir);
    }
    
    return null;
}

function readPackageJson(projectRoot) {
    const packagePath = path.join(projectRoot, 'package.json');
    
    try {
        const content = fs.readFileSync(packagePath, 'utf8');
        return JSON.parse(content);
    } catch (error) {
        log(`❌ Error reading package.json: ${error.message}`, 'red');
        return null;
    }
}

function writePackageJson(projectRoot, packageData) {
    const packagePath = path.join(projectRoot, 'package.json');
    
    try {
        const content = JSON.stringify(packageData, null, 2) + '\n';
        fs.writeFileSync(packagePath, content, 'utf8');
        return true;
    } catch (error) {
        log(`❌ Error writing package.json: ${error.message}`, 'red');
        return false;
    }
}

function analyzeCurrentSetup(pkg) {
    const analysis = {
        hasScripts: !!pkg.scripts,
        hasReleaseScript: !!(pkg.scripts && pkg.scripts.release),
        currentReleaseScript: pkg.scripts?.release,
        isAlreadyConfigured: pkg.scripts?.release === 'wp-release',
        needsSetup: true
    };
    
    if (analysis.isAlreadyConfigured) {
        analysis.needsSetup = false;
    }
    
    return analysis;
}

function promptUser(question) {
    return new Promise((resolve) => {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
        
        rl.question(question, (answer) => {
            rl.close();
            resolve(answer.toLowerCase().trim());
        });
    });
}

async function setupReleaseScript(projectRoot, pkg, analysis, force = false) {
    log('\n🔧 wp-build-tools Setup', 'bold');
    log('========================', 'blue');
    
    if (analysis.isAlreadyConfigured) {
        log('✅ Release script already configured correctly!', 'green');
        log('   Current: "release": "wp-release"', 'blue');
        return true;
    }
    
    // Show what will be changed
    log('\n📋 Proposed Changes:', 'bold');
    
    if (!analysis.hasScripts) {
        log('   • Add "scripts" section to package.json', 'blue');
    }
    
    if (analysis.hasReleaseScript) {
        log(`   • Backup existing release script: "${analysis.currentReleaseScript}"`, 'yellow');
        log('   • Replace with: "wp-release"', 'blue');
    } else {
        log('   • Add new release script: "wp-release"', 'blue');
    }
    
    // Get user permission (unless forced)
    if (!force && isInteractive()) {
        log('\n❓ Proceed with setup?', 'bold');
        const answer = await promptUser('   Type "yes" to continue, anything else to skip: ');
        
        if (answer !== 'yes' && answer !== 'y') {
            log('\n⏭️  Setup skipped. You can run this later with:', 'yellow');
            log('   npx @dream-encode/wp-build-tools setup', 'blue');
            return false;
        }
    }
    
    // Perform the setup
    log('\n🔄 Updating package.json...', 'blue');
    
    // Initialize scripts if needed
    if (!pkg.scripts) {
        pkg.scripts = {};
    }
    
    // Backup existing release script
    if (analysis.hasReleaseScript) {
        pkg.scripts['release-backup'] = analysis.currentReleaseScript;
        log(`   ✅ Backed up existing script to "release-backup"`, 'green');
    }
    
    // Set the new release script
    pkg.scripts.release = 'wp-release';
    
    // Write the updated package.json
    if (writePackageJson(projectRoot, pkg)) {
        log('   ✅ package.json updated successfully!', 'green');
        
        log('\n🎉 Setup Complete!', 'bold');
        log('==================', 'green');
        log('\n📋 You can now use:', 'bold');
        log('   npm run release     # Interactive release', 'blue');
        log('   yarn release        # Interactive release', 'blue');
        log('   wp-release --help   # See all options', 'blue');
        
        if (analysis.hasReleaseScript) {
            log('\n💡 Your previous release script is saved as "release-backup"', 'yellow');
        }
        
        return true;
    } else {
        return false;
    }
}

async function main() {
    const args = process.argv.slice(2);
    const force = args.includes('--force') || args.includes('-f');
    const quiet = args.includes('--quiet') || args.includes('-q');
    
    if (!quiet) {
        log('🚀 wp-build-tools Project Setup', 'bold');
        log('================================\n', 'blue');
    }
    
    // Find project root
    const projectRoot = findProjectRoot();
    if (!projectRoot) {
        log('❌ No package.json found in current directory or parent directories', 'red');
        log('   Make sure you\'re in a Node.js project directory', 'yellow');
        process.exit(1);
    }
    
    if (!quiet) {
        log(`📁 Project root: ${projectRoot}`, 'blue');
    }
    
    // Read package.json
    const pkg = readPackageJson(projectRoot);
    if (!pkg) {
        process.exit(1);
    }
    
    // Analyze current setup
    const analysis = analyzeCurrentSetup(pkg);
    
    if (!analysis.needsSetup && !force) {
        if (!quiet) {
            log('✅ Project already configured correctly!', 'green');
        }
        process.exit(0);
    }
    
    // Perform setup
    const success = await setupReleaseScript(projectRoot, pkg, analysis, force);
    process.exit(success ? 0 : 1);
}

// Handle errors gracefully
process.on('uncaughtException', (error) => {
    log(`❌ Unexpected error: ${error.message}`, 'red');
    process.exit(1);
});

process.on('unhandledRejection', (error) => {
    log(`❌ Unexpected error: ${error.message}`, 'red');
    process.exit(1);
});

// Run if called directly
if (require.main === module) {
    main().catch((error) => {
        log(`❌ Setup failed: ${error.message}`, 'red');
        process.exit(1);
    });
}

module.exports = { setupReleaseScript, analyzeCurrentSetup, findProjectRoot };
