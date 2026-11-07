#!/bin/bash

# Tests for is_wp_plugin_dir and is_wp_theme_dir. Needs no other projects on disk.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/bin/lib/platform-utils.sh"
source "$ROOT/bin/lib/general-functions.sh"
source "$ROOT/bin/lib/wp-functions.sh"

WORK="$(mktemp -d)"
PASSED=0
FAILED=0

# make_dir <relative path> : creates the directory and prints its full path.
make_dir() {
    mkdir -p "$WORK/$1"
    echo "$WORK/$1"
}

# expect <label> <directory> <plugin yes|no> <theme yes|no>
expect() {
    local label="$1" dir="$2" plugin="$3" theme="$4" got_plugin got_theme

    cd "$dir" || exit 1
    got_plugin=$(is_wp_plugin_dir && echo yes || echo no)
    got_theme=$(is_wp_theme_dir && echo yes || echo no)

    if [ "$got_plugin" = "$plugin" ] && [ "$got_theme" = "$theme" ]; then
        PASSED=$((PASSED + 1))
        echo "ok      $label"
    else
        FAILED=$((FAILED + 1))
        echo "FAILED  $label: plugin=$got_plugin (expected $plugin), theme=$got_theme (expected $theme)"
    fi
}

plugin_header() {
    printf '<?php\n/**\n * Plugin Name:       Demo\n * Version:           1.0.0\n */\n' > "$1"
}

theme_header() {
    printf '/*\nTheme Name: Demo\nVersion: 1.0.0\n*/\n' > "$1"
}

expect "wp-content plugin, no header" "$(make_dir wp-content/plugins/a)" yes no
expect "wp-content plugin subfolder" "$(make_dir wp-content/plugins/a/src)" yes no
expect "wp-content theme, no header" "$(make_dir wp-content/themes/a)" no yes

D="$(make_dir content/plugins/demo)"; plugin_header "$D/demo.php"
expect "content/plugins with header" "$D" yes no

D="$(make_dir somewhere/else/demo)"; plugin_header "$D/demo.php"
expect "any path with plugin header" "$D" yes no

D="$(make_dir content/themes/demo)"; theme_header "$D/style.css"
expect "content/themes with header" "$D" no yes

D="$(make_dir both/demo)"; plugin_header "$D/demo.php"; theme_header "$D/style.css"
expect "plugin header wins over a style.css theme header" "$D" yes no

D="$(make_dir wp-content/plugins/styled)"; theme_header "$D/style.css"
expect "wp-content plugin path wins over a theme header" "$D" yes no

D="$(make_dir wp-content/themes/withphp)"; plugin_header "$D/withphp.php"
expect "wp-content theme path wins over a plugin header" "$D" no yes

expect "empty folder" "$(make_dir plain/empty)" no no

D="$(make_dir plain/node)"; echo '{}' > "$D/package.json"
expect "package.json only" "$D" no no

D="$(make_dir plain/script)"; printf '<?php\necho 1;\n' > "$D/script.php"
expect "matching php file with no header" "$D" no no

D="$(make_dir plain/other)"; plugin_header "$D/different-name.php"
expect "plugin header in a file not named after the folder" "$D" no no

D="$(make_dir plain/css)"; printf 'body { color: red; }\n' > "$D/style.css"
expect "style.css with no header" "$D" no no

D="$(make_dir plain/late)"; { head -c 9000 /dev/zero | tr '\0' ' '; printf '\n * Plugin Name: Late\n'; } > "$D/late.php"
expect "header past the first 8KB" "$D" no no

D="$(make_dir plain/prose)"; printf '<?php\n// See the Plugin Name: field in the docs.\n' > "$D/prose.php"
expect "header words inside other text" "$D" no no

D="$(make_dir crlf/demo)"; printf '<?php\r\n/**\r\n * Plugin Name: Demo\r\n */\r\n' > "$D/demo.php"
expect "header with CRLF line endings" "$D" yes no

echo ""
echo "Passed: $PASSED  Failed: $FAILED"

[ "$FAILED" -eq 0 ]
