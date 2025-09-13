#!/usr/bin/env node

/**
 * Setup Command for @dream-encode/wp-build-tools
 * 
 * Can be called via: npx @dream-encode/wp-build-tools setup
 * Provides manual control over project setup
 */

const path = require('path');

// Import the setup functionality
const setupScript = path.join(__dirname, '..', 'scripts', 'setup-project.js');
require(setupScript);
