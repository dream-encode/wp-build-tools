#!/usr/bin/env node

const { spawn } = require( 'child_process' )
const path      = require( 'path' )

const scriptDir     = __dirname
const releaseScript = path.join( scriptDir, 'release.sh' )

const child = spawn( 'bash', [ releaseScript ], {
	stdio: 'inherit',
	cwd: process.cwd()
} )

child.on( 'exit', ( code ) => {
	process.exit( code )
} )