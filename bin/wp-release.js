#!/usr/bin/env node

const { spawn } = require( 'child_process' )
const path      = require( 'path' )

const scriptDir     = __dirname
const releaseScript = path.join( scriptDir, 'release.sh' )

// Detect if we're running under yarn (which has emoji display issues on Windows)
const isYarn = process.env.npm_config_user_agent && process.env.npm_config_user_agent.includes('yarn')
const isWindows = process.platform === 'win32'

// Show warning for yarn users on Windows about emoji display
if (isYarn && isWindows) {
	console.log('⚠️  Note: Running via yarn may cause emoji display issues on Windows.')
	console.log('   For best results, use: npm run release')
	console.log('')
}

const child = spawn( 'bash', [ releaseScript, ...process.argv.slice(2) ], {
	stdio: 'inherit',
	cwd: process.cwd(),
	env: {
		...process.env,
		// Ensure proper encoding for emoji support
		LANG: process.env.LANG || 'en_US.UTF-8',
		LC_ALL: process.env.LC_ALL || 'en_US.UTF-8',
		// Force UTF-8 encoding in various contexts
		PYTHONIOENCODING: 'utf-8',
		// Ensure terminal supports color and unicode (fixes yarn emoji issue)
		// yarn doesn't set TERM while npm does, causing emoji display problems
		TERM: process.env.TERM || 'xterm-256color',
		// Let the bash script know if we're running under yarn
		WP_RELEASE_VIA_YARN: isYarn ? '1' : '0'
	}
} )

child.on( 'exit', ( code ) => {
	process.exit( code )
} )