# Changelog

## [NEXT_VERSION] - [UNRELEASED]
* ENH: Add more tests.
* ENH: Abstract some more.

## [0.7.7] - 2025-09-15
* BUG: Fix MMWOP release asset detection.

## [0.7.6] - 2025-09-15
* BUG: Only omit step_done if no build script.
* BUG: More formatting during pre-release checks.

## [0.7.5] - 2025-09-15
* TWK: Format output during pre-release checks a bit nicer.

## [0.7.4] - 2025-09-15
* TSK: Bump release to resolve npmcr error.

## [0.7.3] - 2025-09-15
* BUG: Fix a local error.

## [0.7.2] - 2025-09-15
* BUG: Add pre-release check for missing dependencies that might cause errors during the production build.

## [0.7.1] - 2025-09-14
* ENH: Add early exclusion reading to wp_create_release.

## [0.7.0] - 2025-09-14
* ENH: Add custom ZIP exclusions support.

## [0.6.20] - 2025-09-14
* BUG: Exclude action-scheduler and libraries from debugging code check.

## [0.6.19] - 2025-09-14
* ENH: Add more output to the version bump.
* BUG: Maybe fix postinstall.

## [0.6.18] - 2025-09-14
* BUG: Remove extra output during next version replacement.

## [0.6.17] - 2025-09-14
* BUG: Revert back to the inline implementation.

## [0.6.16] - 2025-09-14
* BUG: Fix dependencies.

## [0.6.15] - 2025-09-14
* BUG: Fix package_version_bump_interactive.

## [0.6.14] - 2025-09-14
* BUG: Use package_version_bump_interactive instead of inline implementation in git_create_release.

## [0.6.13] - 2025-09-14
* BUG: Fix zips not being created due to composer dependency conflicts.

## [0.6.12] - 2025-09-14
* BUG: Fix emoji rendering in yarn.

## [0.6.11] - 2025-09-13
* BUG: Only replace the version string in the WP plugin file, not other @since references.

## [0.6.10] - 2025-09-13
* BUG: Exclude /src in block plugin release assets.
* BUG: Make wp_is_block_plugin more robust.

## [0.6.9] - 2025-09-13
* BUG: Fix changelog next version template included in release assets.

## [0.6.8] - 2025-09-13
* BUG: Fix double changelog updates.

## [0.6.7] - 2025-09-13
* BUG: Don't add the NEXT_VERSION template until after the release asset is built.

## [0.6.6.2] - 2025-09-13
* BUG: Example fix description.

## [0.6.6.1] - 2025-09-13
* BUG: Example fix description.

## [0.6.6] - 2025-09-13
* BUG: Fix spacing in version replacement.

## [0.6.5] - 2025-09-13
* BUG: Don't include node_modules in release assets if there are no production dependencies.

## [0.6.4] - 2025-09-13
* BUG: Maybe fix copy_folder.

## [0.6.3] - 2025-09-13
* BUG: NPM doesn't like hotfix versions.

## [0.6.2.1] - 2025-09-13
* BUG: Make release asset header detection more robust.

## [0.6.2] - 2025-09-13
* BUG: Fix version bump and GitHub release issues with empty version variables.

## [0.6.1] - 2025-09-13
* ENH: Add automatic package.json setup functionality.
* BUG: Fix changelog version replacement bug.

## [0.6.0] - 2025-09-13
* ENH: Add optional flags for --check-tools and --test.
* ENH: Add postinstall.js to automatically configure projects.
* ENH: Add copy_folder fallbacks.

## [0.5.2] - 2025-09-12
* BUG: Fix PROJECT_ROOT detection when in a WP plugin or theme.

## [0.5.1] - 2025-09-12
* BUG: Bring everything in line with bash.

## [0.5.0] - 2025-09-12
* BUG: Fix some bugs.  Ready for more testing in a plugin.

## [0.4.2.1] - 2025-09-12
* BUG: Fix version bump and GitHub release issues with empty version variables.

## [0.4.2] - 2025-09-12
* BUG: Fix version bump and GitHub release issues with empty version variables.

## [0.4.1] - 2025-09-12
* ENH: More changes from bash.

## [0.4.0] - 2025-09-12
* ENH: Import latest updates from bash_includes.

## [0.3.0] - 2025-09-10
* ENH: Try interactive_menu_select function.

## [0.2.8] - 2025-09-10
* BUG: Only validate the changelog formatting before the version bump, don't update the version yet.

## [0.2.7] - 2025-09-10
* BUG: FIx .sh files exclusion.

## [0.2.6] - 2025-09-10
* BUG: Fix placeholders.
* BUG: Add constants file support.

## [0.2.5] - 2025-09-10
* BUG: Don't replace version in .sh files.

## [0.2.4] - 2025-09-10
* BUG: Use interactive version bumping.
* BUG: Handle both old format of NEXT_VERSION replacement.

## [0.2.3] - 2025-09-09
* BUG: Go up one more level.

## [0.2.2] - 2025-09-09
* BUG: Distinguish between the script root and the project root.
* BUG: cd to the project root before running the script.

## [0.2.1] - 2025-09-09
* Bump version.

## [0.2.0] - 2025-09-09
* Bump version.

## [0.1.1] - 2025-09-08
* More abstraction.

## [0.1.0] - 2025-09-08
* Initial release.