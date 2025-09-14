#!/usr/bin/env node

/**
 * Setup Command for @dream-encode/wp-build-tools
 *
 * Can be called via: npx @dream-encode/wp-build-tools setup
 * Provides manual control over project setup
 */

// Just run the setup-project script directly by spawning it as a separate process
const { spawn } = require('child_process');
const path = require('path');

const setupScript = path.join(__dirname, '..', 'scripts', 'setup-project.js');

// Pass through all arguments
const args = process.argv.slice(2);

// Spawn the setup script as a separate process
const child = spawn('node', [setupScript, ...args], {
    stdio: 'inherit',
    cwd: process.cwd()
});

// Exit with the same code as the child process
child.on('exit', (code) => {
    process.exit(code || 0);
});
