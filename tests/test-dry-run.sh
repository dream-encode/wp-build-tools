#!/bin/bash

# Tests for wp-release --dry-run and for a real release outside a wp-content path.
# Uses a temp project, a local bare repository as origin and a stub gh. Nothing reaches GitHub.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="$ROOT/bin/release.sh"

WORK="$(mktemp -d)"
GH_LOG="$WORK/gh.log"
UPLOADS="$WORK/uploads"
PASSED=0
FAILED=0

mkdir -p "$WORK/fakebin" "$UPLOADS"

cat > "$WORK/fakebin/gh" <<EOF
#!/bin/bash
echo "gh \$*" >> "$GH_LOG"
case "\$1 \$2" in
    "release upload") cp "\$4" "$UPLOADS/" ;;
    "--version "*) echo "gh version stub" ;;
esac
exit 0
EOF
chmod +x "$WORK/fakebin/gh"

export PATH="$WORK/fakebin:$PATH"

check() {
    local label="$1"
    shift

    if "$@"; then
        PASSED=$((PASSED + 1))
        echo "ok      $label"
    else
        FAILED=$((FAILED + 1))
        echo "FAILED  $label"
    fi
}

# make_project <name> : a plugin in content/plugins, on development, pushed to a bare origin.
make_project() {
    local name="$1"
    local dir="$WORK/$name/content/plugins/demo-plugin"
    local upper="DEMO_PLUGIN"

    git init -q --bare "$WORK/$name/origin.git"
    mkdir -p "$dir/includes"
    cd "$dir" || exit 1

    git init -q -b development
    git remote add origin "$WORK/$name/origin.git"

    printf '<?php\n/**\n * Plugin Name:       Demo\n * Version:           1.0.0\n * Release Asset:     true\n */\n' > demo-plugin.php
    printf "<?php\ndefine( '%s_PLUGIN_VERSION', '1.0.0' );\n" "$upper" > includes/demo-plugin-constants.php
    printf '{\n  "name": "demo-plugin",\n  "version": "1.0.0"\n}\n' > package.json
    printf '# Changelog\n\n## [NEXT_VERSION] - [UNRELEASED]\n* BUG: A real entry.\n' > CHANGELOG.md

    git add .
    git -c user.name=test -c user.email=test@example.test commit -q -m "Initial"
    git push -q -u origin development 2>/dev/null
    git branch main
    git push -q origin main 2>/dev/null
}

snapshot() {
    git rev-parse HEAD
    git status --porcelain
    git tag
    git branch -a
    git ls-remote origin
}

tag_exists() {
    git rev-parse -q --verify "refs/tags/$1" >/dev/null
}

copy_removed() {
    local zip_path

    zip_path="$(sed -n -E 's/^  OK: Built (.*\.zip) .*/\1/p' "$OUT")"

    [ -f "$zip_path" ] && [ ! -d "$(dirname "$zip_path")/demo-plugin-v1.1.0" ]
}

output_has() {
    grep -qF "$1" "$OUT"
}

output_lacks() {
    ! grep -qF "$1" "$OUT"
}

no_gh_writes() {
    ! grep -qE 'gh release (create|upload|edit)' "$GH_LOG" 2>/dev/null
}

# A successful dry run changes nothing.
make_project ok
BEFORE="$(snapshot)"
OUT="$WORK/ok.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
CODE=$?

check "dry run exits 0" [ "$CODE" -eq 0 ]
check "dry run reports the version change" output_has "Version: 1.0.0 -> 1.1.0 (minor)"
check "dry run reports the project as a plugin" output_has "Project: demo-plugin (plugin)"
check "dry run reports the header" output_has "demo-plugin.php header would change to 1.1.0"
check "dry run reports the constant" output_has "includes/demo-plugin-constants.php version constant would change to 1.1.0"
check "dry run finds the main file in the ZIP" output_has "ZIP contains demo-plugin-v1.1.0/demo-plugin.php"
check "dry run reports no failures" output_has "Dry run result: 0 failed"
check "dry run makes no project, git or remote changes" [ "$BEFORE" = "$(snapshot)" ]
check "dry run makes no GitHub writes" no_gh_writes
check "dry run keeps the ZIP and removes its copied folder" copy_removed

# The example entry warning only looks at the [NEXT_VERSION] section.
make_project oldexample
printf '# Changelog\n\n## [NEXT_VERSION] - [UNRELEASED]\n* BUG: A real entry.\n\n## [0.9.0] - 2026-01-01\n* BUG: Example fix description.\n' > CHANGELOG.md
OUT="$WORK/oldexample.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "example entry in a released section is not reported" output_lacks "still has the example entry"

make_project newexample
printf '# Changelog\n\n## [NEXT_VERSION] - [UNRELEASED]\n* BUG: Example fix description.\n' > CHANGELOG.md
OUT="$WORK/newexample.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "example entry in the next version section is reported" output_has "still has the example entry"

# Each problem makes the dry run fail.
make_project wrongbranch
git checkout -q main
OUT="$WORK/wrongbranch.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "wrong branch exits non-zero" [ $? -ne 0 ]
check "wrong branch is reported" output_has "Releases only run from development or hotfix"

make_project noupstream
git branch --unset-upstream
OUT="$WORK/noupstream.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "missing upstream exits non-zero" [ $? -ne 0 ]
check "missing upstream is reported" output_has "Branch has no upstream"

make_project nomain
git branch -q -D main
git update-ref -d refs/remotes/origin/main
OUT="$WORK/nomain.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "missing main exits non-zero" [ $? -ne 0 ]
check "missing main is reported" output_has "Branch main does not exist"

make_project nochangelog
printf '# Changelog\n' > CHANGELOG.md
OUT="$WORK/nochangelog.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "missing changelog section exits non-zero" [ $? -ne 0 ]
check "missing changelog section is reported" output_has "has no [NEXT_VERSION]"
check "uncommitted change is reported" output_has "Working tree has changes"

make_project debugcode
printf '<?php\n\tvar_dump( 1 );\n' > debug.php
OUT="$WORK/debugcode.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "debugging code exits non-zero" [ $? -ne 0 ]
check "debugging code is reported" output_has "Debugging code found"

make_project tagged
git tag v1.1.0
OUT="$WORK/tagged.out"
bash "$RELEASE" --dry-run minor > "$OUT" 2>&1 < /dev/null
check "existing tag exits non-zero" [ $? -ne 0 ]
check "existing tag is reported" output_has "Tag v1.1.0 already exists"

make_project notype
OUT="$WORK/notype.out"
bash "$RELEASE" --dry-run > "$OUT" 2>&1 < /dev/null
check "no version type exits non-zero" [ $? -ne 0 ]
check "no version type is reported" output_has "requires a version type"

# A real release outside wp-content bumps the version files and uploads a ZIP.
make_project real
git config user.name test
git config user.email test@example.test
: > "$GH_LOG"
export TMPDIR="$WORK/real-tmp"
mkdir -p "$TMPDIR"
OUT="$WORK/real.out"
bash "$RELEASE" minor > "$OUT" 2>&1 < /dev/null
CODE=$?
unset TMPDIR

check "real release exits 0" [ "$CODE" -eq 0 ]
check "real release bumps the header" grep -q ' \* Version:           1.1.0' demo-plugin.php
check "real release bumps the constant" grep -q "DEMO_PLUGIN_PLUGIN_VERSION', '1.1.0'" includes/demo-plugin-constants.php
check "real release bumps package.json" grep -q '"version": "1.1.0"' package.json
check "real release creates the tag" tag_exists v1.1.0
check "real release merges into main" git merge-base --is-ancestor v1.1.0 main
check "real release returns to development" [ "$(git branch --show-current)" = "development" ]
check "real release uploads the ZIP" test -f "$UPLOADS/demo-plugin-v1.1.0.zip"

echo ""
echo "Passed: $PASSED  Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    echo "Output files are in $WORK"
fi

[ "$FAILED" -eq 0 ]
