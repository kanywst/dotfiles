#!/usr/bin/env bash
# Regression suite for bin/.local/bin/bump.
#
# Every assertion here corresponds to a bug that actually shipped. The script
# drives package managers that take tens of minutes and need root, so none of
# it can be exercised by hand — each run is stubbed: a temp dir of fake `brew`,
# `npm`, `sudo` &c is put at the front of PATH, and XDG_CACHE_HOME / DOTFILES_DIR
# / RUSTUP_HOME are redirected so nothing touches the real machine.
#
# Usage:
#   tests/bump.test.sh              # run under the default bash
#   BUMP_TEST_SHELL=/bin/bash \
#     tests/bump.test.sh            # and again under macOS's bash 3.2
#
# `gum` is deliberately kept off the stub PATH: the plain renderer prints the
# same facts in a form that is assertable, and CI has no gum. The one gum-shaped
# bug (its terminal probe leaking into the next shell prompt) is covered by the
# pty test at the end, which needs no gum either.

set -uo pipefail

ROOT="$(cd -P "$(dirname "$0")/.." && pwd)"
# Overridable so the suite can be pointed at an older revision to confirm it
# actually catches the regressions it claims to (see the mutation check in the
# commit that added it): BUMP_UNDER_TEST=<path> tests/bump.test.sh
BUMP="${BUMP_UNDER_TEST:-$ROOT/bin/.local/bin/bump}"
SHELL_UNDER_TEST="${BUMP_TEST_SHELL:-bash}"

PASS=0; FAIL=0
red=$'\e[38;5;203m'; grn=$'\e[38;5;84m'; dim=$'\e[38;5;244m'; off=$'\e[0m'

ok()   { PASS=$((PASS + 1)); printf '%s  ✓%s %s\n' "$grn" "$off" "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '%s  ✗ %s%s\n' "$red" "$1" "$off"
         [[ -n "${2:-}" ]] && printf '%s%s%s\n' "$dim" "$(printf '%s' "$2" | sed 's/^/      /')" "$off"; }

# assert_contains <name> <haystack> <needle>
assert_contains() {
    case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain: $3
--- got ---
$2" ;; esac
}
assert_missing() {
    case "$2" in *"$3"*) bad "$1" "expected NOT to contain: $3
--- got ---
$2" ;; *) ok "$1" ;; esac
}
assert_eq() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "expected [$3], got [$2]"; fi; }
# For shapes that padding makes brittle to match literally.
assert_matches() {
    if printf '%s' "$2" | grep -qE "$3"; then ok "$1"; else bad "$1" "expected to match: $3
--- got ---
$2"; fi
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/bump-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/bin"
mkdir -p "$STUB" "$TMP/dotfiles" "$TMP/cache" "$TMP/data" "$TMP/rustup"
touch "$TMP/dotfiles/flake.nix"

stub() { printf '%s\n' "#!/bin/sh" "$2" >"$STUB/$1"; chmod +x "$STUB/$1"; }

# Every managed tool, so "nothing is installed" can actually mean that.
MANAGED="nix rustup mise npm kubectl gh atuin cargo cargo-install-update gup uv brew darwin-rebuild"

# A system PATH with those filtered out. `$STUB:/usr/bin:/bin` is NOT a clean
# room: a GitHub runner ships a real `gh` in /usr/bin, so the tests that remove
# every stub still found it, the guard passed, and the suite ran a live
# `gh extension upgrade` that failed with exit 4. CI caught that; macOS could
# not, because none of these live in /usr/bin there. Mirroring the system dirs
# minus the managed names keeps the script's own coreutils working while making
# the absence real.
SYSBIN="$TMP/sysbin"
mkdir -p "$SYSBIN"
# Overridable so the filter itself can be tested by pointing it at a directory
# that does contain a managed tool — the runner's /usr/bin/gh cannot be
# reproduced on macOS any other way.
for _d in ${BUMP_TEST_SYSDIRS:-/usr/bin /bin /usr/sbin /sbin}; do
    [ -d "$_d" ] || continue
    for _f in "$_d"/*; do
        _b=${_f##*/}
        case " $MANAGED " in *" $_b "*) continue ;; esac
        [ -e "$SYSBIN/$_b" ] || ln -s "$_f" "$SYSBIN/$_b" 2>/dev/null
    done
done

# The stub PATH is deliberately minimal, which would leave the watchdog tests
# vacuous on macOS (no timeout(1) in /usr/bin — it comes from brew's coreutils).
# Link whatever the outer PATH has into the stub dir so they mean something.
HAVE_TIMEOUT=false
for _t in timeout gtimeout; do
    _p=$(command -v "$_t" 2>/dev/null) && { ln -sf "$_p" "$STUB/timeout"; HAVE_TIMEOUT=true; break; }
done

PY3=$(command -v python3 2>/dev/null || :)

# Defaults: every manager present and succeeding. Individual tests override.
reset_stubs() {
    rm -f "$STUB"/*
    $HAVE_TIMEOUT && ln -sf "$(command -v timeout || command -v gtimeout)" "$STUB/timeout"
    # The cask planner is python. /usr/bin/python3 on macOS is an xcrun shim that
    # needs TMPDIR, which `env -i` drops, so hand the stub PATH the real one.
    [[ -n "$PY3" ]] && ln -sf "$PY3" "$STUB/python3"
    local t
    for t in nix rustup mise kubectl gh cargo cargo-install-update gup uv darwin-rebuild brew npm atuin; do
        stub "$t" 'exit 0'
    done
    stub whoami 'echo tester'
    # Records that it was called, so "did bump ask for a password?" is testable.
    stub sudo "touch \"$TMP/sudo-called\"; exit 0"
    rm -f "$TMP/sudo-called"
    mkdir -p "$TMP/rustup/toolchains"
    # No atuin session file is seeded: nothing reads one any more, and having it
    # here is what made the wrong guard look correct in the first place.
}

# run [env assignments...] -- <bump args...>; sets $OUT and $RC.
run() {
    local -a env_extra=()
    while [[ $# -gt 0 && "$1" != "--" ]]; do env_extra+=("$1"); shift; done
    shift || true
    OUT=$(env -i \
        PATH="$STUB:$SYSBIN" \
        HOME="$TMP" \
        TERM=dumb \
        XDG_CACHE_HOME="$TMP/cache" \
        XDG_DATA_HOME="$TMP/data" \
        RUSTUP_HOME="$TMP/rustup" \
        DOTFILES_DIR="$TMP/dotfiles" \
        BUMP_TIMEOUT=5 \
        "${env_extra[@]}" \
        "$SHELL_UNDER_TEST" "$BUMP" "$@" </dev/null 2>&1 \
        | sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g')
    RC=${PIPESTATUS[0]}
}

# shellcheck disable=SC2016  # $BASH_VERSION must expand in the child, not here.
printf '%s▸ bump regression suite — %s (%s)%s\n\n' "$dim" \
    "$SHELL_UNDER_TEST" "$("$SHELL_UNDER_TEST" -c 'echo $BASH_VERSION')" "$off"

# --- the environment ------------------------------------------------------
# Several assertions need a pty (the box-width and terminal-probe checks) and a
# controlling terminal (/dev/tty, for the drain and the sudo branches). Inside a
# restrictive sandbox those fail in a way that looks exactly like the code being
# broken — 33 of 87 here, identically on every run, on a tree whose suite passes
# 87 of 87 outside it. Diagnosing that as a bug in bump cost two wrong
# explanations before the real variable turned up, so the suite says it itself.
if command -v python3 >/dev/null 2>&1 && ! python3 - <<'PTYCHECK' 2>/dev/null
import os, pty, sys
try:
    pid, fd = pty.fork()
except OSError:
    sys.exit(1)
if pid == 0:
    os._exit(0)
os.waitpid(pid, 0)
PTYCHECK
then
    printf '%s  !! this environment cannot allocate a pty. The terminal-dependent\n' "$red"
    printf '     assertions below will fail for that reason, not because bump is\n'
    printf '     broken. Run outside the sandbox.%s\n\n' "$off"
fi

# --- the harness itself ---------------------------------------------------
# If this ever regresses, every "not installed" assertion below silently starts
# testing the runner's real tools instead of the guard.
_leaked=
for _m in $MANAGED; do [ -e "$SYSBIN/$_m" ] && _leaked="$_leaked $_m"; done
if [[ -z "$_leaked" ]]; then
    ok "the system PATH mirror hides every managed tool"
else
    bad "managed tools leaked into the test PATH:$_leaked"
fi
assert_eq "the system PATH mirror still has the coreutils bump needs" \
    "$([ -e "$SYSBIN/date" ] && [ -e "$SYSBIN/sed" ] && [ -e "$SYSBIN/stty" ] && echo yes)" "yes"

# --- CLI surface ----------------------------------------------------------
reset_stubs

run -- --list
assert_eq "--list prints every step, one per line" "$(printf '%s' "$OUT" | grep -c .)" "13"
assert_contains "--list includes the cask step" "$OUT" "brew-cask"

run -- --help
assert_eq "--help exits 0" "$RC" "0"
assert_contains "--help shows usage" "$OUT" "Usage:"

# A typo used to select nothing and run nothing, silently.
run -- --only typo
assert_eq "unknown --only name exits 2" "$RC" "2"
assert_contains "unknown --only name is named" "$OUT" "unknown step in --only: typo"

# `--only=` with no value read as "no filter" and quietly ran everything.
run -- --only=
assert_eq "--only= with no value exits 2" "$RC" "2"

# Names are matched literally. The exit code cannot show this — a regex that
# validates still selects nothing, and "nothing selected" is also exit 2 — so
# the message is the only discriminator: `np.` must be rejected as an unknown
# NAME, not accepted as a pattern and then quietly matched against nothing.
run -- --only 'np.'
assert_eq "--only regex is not a pattern" "$RC" "2"
assert_contains "--only regex is rejected as an unknown name" "$OUT" "unknown step in --only: np."
assert_missing "--only regex is not silently accepted then matched" "$OUT" "no steps selected"

# Splitting the list also globbed it against $PWD, so run this from a directory
# holding files named after real steps: with globbing on, `*` becomes `gh npm`
# and those get silently skipped; with it off, `*` stays an unknown name. The
# exit code is the same either way in an empty directory, which is why the
# first version of this test passed against the broken code.
mkdir -p "$TMP/globtrap" && : >"$TMP/globtrap/gh" && : >"$TMP/globtrap/npm"
(
    cd "$TMP/globtrap" || exit 1
    env -i PATH="$STUB:$SYSBIN" HOME="$TMP" TERM=dumb \
        XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data" \
        RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=5 \
        "$SHELL_UNDER_TEST" "$BUMP" --skip '*' </dev/null 2>&1
) >"$TMP/globout" 2>&1
OUT=$(sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' "$TMP/globout")
assert_contains "--skip is not globbed against the working directory" "$OUT" "unknown step in --skip: *"

run -- --only npm --skip npm
assert_eq "selecting nothing exits 2" "$RC" "2"
assert_contains "selecting nothing says so" "$OUT" "no steps selected"

# --- dry run --------------------------------------------------------------
run -- --dry-run
assert_eq "--dry-run exits 0" "$RC" "0"
assert_contains "--dry-run says nothing will run" "$OUT" "nothing will run"
assert_missing "--dry-run never asks for a password" "$OUT" "warming sudo"
if [[ -e "$TMP/sudo-called" ]]; then bad "--dry-run does not invoke sudo"; else ok "--dry-run does not invoke sudo"; fi

# --- guards ---------------------------------------------------------------
reset_stubs
rm -f "$STUB"/*   # nothing installed at all
stub whoami 'echo tester'
stub sudo 'exit 1'
run -- --dry-run
assert_contains "missing nix is named" "$OUT" "nix not installed"
assert_contains "missing brew is named" "$OUT" "brew not installed"

reset_stubs
rm -rf "$TMP/rustup/toolchains"
run -- --dry-run
# A rustup shim with no toolchains behind it errored on every single run.
assert_contains "rustup without toolchains is skipped, not run" "$OUT" "no rustup toolchains"
mkdir -p "$TMP/rustup/toolchains"

reset_stubs
run -- --dry-run
# The inverse of the obvious test, because the obvious one was the bug: a guard
# that required ${XDG_DATA_HOME}/atuin/session skipped a working step, since an
# Atuin Hub login does not write that file. Verified on a real machine — no
# session file, `atuin sync -f` returns 0 and uploads.
assert_contains "atuin is not skipped just because there is no session file" \
    "$OUT" "✓ 🐢 atuin sync"

reset_stubs
rm -f "$TMP/dotfiles/flake.nix"
run -- --dry-run
# The nix steps act on DOTFILES_DIR's flake; the binary alone is not enough.
assert_contains "nix steps need a flake.nix, not just nix" "$OUT" "no flake.nix"
touch "$TMP/dotfiles/flake.nix"

# --- sudo ------------------------------------------------------------------
reset_stubs
run -- --only npm
assert_missing "no sudo prompt when no selected step needs root" "$OUT" "warming sudo"
if [[ -e "$TMP/sudo-called" ]]; then bad "--only npm never invokes sudo"; else ok "--only npm never invokes sudo"; fi

# Three distinct outcomes, and they used to collapse into one message. Both
# branches below are forced deterministically rather than depending on whether
# the suite happens to have a controlling terminal.
if command -v python3 >/dev/null 2>&1; then
    # (1) No controlling terminal: sudo cannot prompt, and its own error is
    # "a terminal is required to read the password". Calling that "not
    # authorized" sends the reader to check sudoers for nothing. Hit for real
    # by running bump from a shell that captured its output.
    reset_stubs
    # shellcheck disable=SC2016  # literal $1 for the stub: it inspects its own arg.
    stub sudo 'if [ "$1" = "-n" ]; then exit 1; fi
echo "sudo: a terminal is required to read the password" >&2; exit 1'
    cat >"$TMP/nosid.py" <<'NOSID'
import os, sys
os.setsid()                      # drop the controlling terminal, then run
os.execvp(sys.argv[1], sys.argv[1:])
NOSID
    OUT=$(env -i PATH="$STUB:$SYSBIN" HOME="$TMP" TERM=dumb \
        XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data" \
        RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=5 \
        python3 "$TMP/nosid.py" "$SHELL_UNDER_TEST" "$BUMP" --only darwin,brew \
        </dev/null 2>&1 | sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g')
    assert_contains "no controlling terminal is reported as such" "$OUT" "no terminal to ask for a password on"
    assert_missing "no controlling terminal is not called an authorization failure" "$OUT" "not authorized"
    assert_matches "no controlling terminal still runs the steps that need no root" "$OUT" '✓.*homebrew formulae' 

    # (2) A terminal exists and sudo refuses: that IS an authorization failure.
    reset_stubs
    stub sudo 'exit 1'
    cat >"$TMP/sudorun.sh" <<SUDORUN
export PATH="$STUB:$SYSBIN" HOME="$TMP" TERM=dumb
export XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data"
export RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=5
"$SHELL_UNDER_TEST" "$BUMP" --only darwin,brew
SUDORUN
    cat >"$TMP/ptyplain.py" <<'PTY'
import os, pty, select, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash"] + sys.argv[1:])
    os._exit(1)
out = b""
while True:
    try:
        r, _, _ = select.select([fd], [], [], 30)
        if not r:
            break
        d = os.read(fd, 65536)
        if not d:
            break
        out += d
    except OSError:
        break
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
PTY
    OUT=$(python3 "$TMP/ptyplain.py" "$TMP/sudorun.sh" 2>/dev/null \
        | tr -d '\r' | sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g')
    assert_contains "a refusal with a terminal present is an authorization failure" "$OUT" "not authorized"
    assert_missing "a refusal with a terminal present is not blamed on the terminal" "$OUT" "no terminal to ask"
fi

# (3) An already-warm sudo timestamp needs no prompt and should not print one.
reset_stubs
run -- --only darwin
assert_missing "an already-warm sudo grant prints no prompt line" "$OUT" "warming sudo"

reset_stubs
stub sudo "touch \"$TMP/sudo-called\"; exit 1"   # grant refused
run -- --skip flake
assert_contains "refused sudo skips the nix-darwin step" "$OUT" "nix-darwin switch — skipped (needs sudo)"
# The cask upgrade is the step that actually needs root mid-run. Unguarded, it
# sat on an invisible password prompt until the watchdog killed it 30min later.
assert_contains "refused sudo skips the cask step" "$OUT" "homebrew casks — skipped (needs sudo)"
assert_matches "refused sudo still runs the formula step" "$OUT" '✓.*homebrew formulae' 

# --- failures, timeouts, exit codes ---------------------------------------
reset_stubs
run -- --only mise
assert_eq "a clean run exits 0" "$RC" "0"

reset_stubs
stub brew 'echo "brew exploded" >&2; exit 3'
run -- --only brew
assert_eq "a failing step exits 1" "$RC" "1"
assert_contains "a failing step reports its exit status" "$OUT" "exit 3"
# Output is captured to a log, so the tail has to be surfaced or it is invisible.
assert_contains "a failing step's log tail is printed inline" "$OUT" "brew exploded"

if $HAVE_TIMEOUT; then
    reset_stubs
    stub gh 'sleep 30'
    run BUMP_TIMEOUT=2 -- --only gh
    assert_contains "a hung step is reported as a timeout" "$OUT" "timed out"
    assert_eq "a hung step makes the run exit 1" "$RC" "1"
else
    printf '%s  · skipped: watchdog tests need timeout(1) from coreutils%s\n' "$dim" "$off"
fi

# --- homebrew trust pre-flight --------------------------------------------
# Homebrew 7 refuses to load anything from an untrusted tap, and both
# `brew upgrade` and the `brew bundle` that ends a nix-darwin switch load every
# installed package rather than only what they mean to touch. One hand-installed
# `sqld` from an untrusted tap therefore failed BOTH the brew step and the
# nix-darwin step of a real run, with an error that named the formula and
# nothing else — no indication that the two failures were one cause.
#
# brew_stub <trust-json> <full-name formulae> <full-name casks>
# The JSON is single-quoted into the sh stub, so it must not contain a quote of
# that kind — Homebrew's own output never does.
brew_stub() {
    stub brew "case \"\$1\" in
  trust) echo '$1' ;;
  list)  case \"\$*\" in
           *--formula*) echo '$2' ;;
           *--cask*)    echo '$3' ;;
         esac ;;
  *) echo \"brew \$*\" ;;
esac
exit 0"
}

UNTRUSTED='{"taps":[],"formulae":[],"casks":[],"commands":[]}'
FORMULA_OK='{"taps":[],"formulae":["libsql/sqld/sqld"],"casks":[],"commands":[]}'
TAP_OK='{"taps":["libsql/sqld"],"formulae":[],"casks":[],"commands":[]}'

reset_stubs; brew_stub "$UNTRUSTED" "libsql/sqld/sqld" ""
run -- --only brew
assert_eq "an untrusted installed formula fails the brew step" "$RC" "1"
assert_contains "the untrusted formula is named" "$OUT" "libsql/sqld/sqld"
assert_contains "the report gives the exact command to fix it" "$OUT" \
    "brew trust --formula libsql/sqld/sqld"
# The point of probing rather than letting brew discover it: the step gives up
# before `brew update` spends a minute refreshing the catalog to earn a worse
# error. If this regresses the probe still reports, but has stopped paying.
assert_missing "no upgrade is attempted once the probe fails" "$OUT" "brew update"

reset_stubs; brew_stub "$FORMULA_OK" "libsql/sqld/sqld" ""
run -- --only brew
assert_eq "a trusted tap formula does not block the step" "$RC" "0"

reset_stubs; brew_stub "$TAP_OK" "libsql/sqld/sqld" ""
run -- --only brew
assert_eq "whole-tap trust covers the formulae inside it" "$RC" "0"

# --full-name prints core formulae bare. Reading those as untrusted would fail
# every run on every machine, since the trust store never lists them.
reset_stubs; brew_stub "$UNTRUSTED" "jq
ripgrep" ""
run -- --only brew
assert_eq "bare core formulae are never reported as untrusted" "$RC" "0"

# The probe also skips anything under homebrew/core/ or homebrew/cask/ by
# prefix, and nothing here reached that: `brew list --full-name` prints core
# formulae bare, so the "no slash" clause above catches them first and zero
# entries on this machine start with either prefix — mutating the prefix tuple
# to match nothing survived the whole suite. The guard is worth keeping for a
# brew that qualifies them, but it needs input shaped that way to mean
# anything, so here it is.
reset_stubs; brew_stub "$UNTRUSTED" "homebrew/core/jq" ""
run -- --only brew
assert_eq "a fully-qualified core formula is not reported as untrusted" "$RC" "0"
reset_stubs; brew_stub "$UNTRUSTED" "" "homebrew/cask/firefox"
run -- --only brew-cask
assert_eq "a fully-qualified core cask is not reported as untrusted" "$RC" "0"

reset_stubs; brew_stub "$UNTRUSTED" "" "kanywst/tap/y509"
run -- --only brew-cask
assert_eq "an untrusted installed cask fails the cask step" "$RC" "1"
assert_contains "a cask is fixed with --cask, not --formula" "$OUT" \
    "brew trust --cask kanywst/tap/y509"

# Fails open, deliberately: a brew too old to have `trust --json` must not start
# failing runs that would otherwise work. The probe explains failures; it is not
# allowed to become one.
reset_stubs
# shellcheck disable=SC2016  # $1/$* are the stub's own args, not this shell's.
stub brew 'case "$1" in trust) exit 1 ;; esac; echo "brew $*"; exit 0'
run -- --only brew
assert_eq "a brew with no trust --json is not treated as untrusted" "$RC" "0"

# The switch applies every nix-side change before its brew bundle runs, so the
# probe must NOT pre-empt it — blocking there would cost the nix half of the
# switch, which works fine. It may only explain the failure afterwards, at the
# end of the log, which is the part `tail` shows.
# The default sudo stub returns 0 without running its command, so darwin-rebuild
# would never run and every assertion here would pass vacuously. These use a
# stub that execs through instead. It has to strip sudo's own options rather
# than `shift` once: the up-front warm-up is `sudo -n -v`, which is all options
# and no command, and a stub that tried to exec `-v` failed — which bump read as
# "no sudo", skipped the step, and handed the assertions a run that never
# happened.
SUDO_EXEC="touch \"$TMP/sudo-called\"
while [ \$# -gt 0 ]; do case \"\$1\" in -*) shift ;; *) break ;; esac; done
[ \$# -eq 0 ] && exit 0
exec \"\$@\""

reset_stubs; brew_stub "$UNTRUSTED" "libsql/sqld/sqld" ""
stub sudo "$SUDO_EXEC"
stub darwin-rebuild 'echo "Error: Refusing to load formula libsql/sqld/sqld"; exit 1'
run -- --only darwin
assert_eq "a failing switch still exits 1" "$RC" "1"
assert_contains "a failing switch is explained by the trust probe" "$OUT" \
    "brew trust --formula libsql/sqld/sqld"

reset_stubs; brew_stub "$UNTRUSTED" "libsql/sqld/sqld" ""
stub sudo "$SUDO_EXEC"
run -- --only darwin
assert_eq "an untrusted tap does not fail a switch that succeeded" "$RC" "0"
assert_missing "a successful switch prints no trust report" "$OUT" "untrusted tap"

# --- summary honesty -------------------------------------------------------
reset_stubs
rm -f "$STUB"/*
stub whoami 'echo tester'
stub sudo 'exit 1'
run --
assert_contains "a run where everything skipped is not 'all done'" "$OUT" "nothing to do"
assert_eq "a run that did nothing still exits 0" "$RC" "0"
# Empty lists are omitted now rather than printed as rows of em dashes, so a
# run that did nothing says what it skipped and nothing else.
assert_contains "a run that did nothing still names what it skipped" "$OUT" "skipped  "
assert_missing "a run with no failures prints no failed line" "$OUT" "failed  "

reset_stubs
run -- --only npm,gh
# Labels contain spaces, so a space-joined summary gave no way to count them.
assert_contains "summary joins labels with commas" "$OUT" "npm globals, gh extensions"

# --- npm ------------------------------------------------------------------
reset_stubs
# shellcheck disable=SC2016  # the stub body is a script of its own; $1 is its arg.
stub npm 'case "$1" in
outdated) printf "%s\n" "/p/node_modules/foo:foo@2.0.0:foo@1.0.0:foo@2.0.0" "/p/node_modules/@sc/pkg:@sc/pkg@3.0.0:@sc/pkg@1.0.0:@sc/pkg@3.0.0"; exit 1;;
*) echo "INSTALL $*";;
esac'
run -- --only npm
assert_eq "npm step succeeds" "$RC" "0"
NPMLOG=$(cat "$TMP"/cache/bump/*/npm.log 2>/dev/null)
assert_contains "npm reinstalls a plain package at @latest" "$NPMLOG" "foo@latest"
# `sed 's/@[^@]*$//'` must strip the version without eating the @scope.
assert_contains "npm keeps the @scope on a scoped package" "$NPMLOG" "@sc/pkg@latest"

reset_stubs
# `npm outdated` exits 1 when something IS outdated, so only >1 is a failure.
# This used to be 2>/dev/null with the status dropped: a broken npm reported ✓.
# shellcheck disable=SC2016  # ditto: literal $1 for the stub, not for us.
stub npm 'case "$1" in outdated) echo "npm is broken" >&2; exit 2;; *) ;; esac'
run -- --only npm
assert_eq "a broken npm fails the step instead of reporting success" "$RC" "1"
assert_contains "a broken npm's stderr reaches the reader" "$OUT" "npm is broken"

# The steps must not follow the caller's cwd. mise puts a per-directory node
# straight onto PATH, so `bump` from inside a mise project upgraded that node's
# empty global prefix and reported success. bump drops mise's install dirs and
# puts its shims first, which resolve as $HOME does.
reset_stubs
rm -rf "$TMP/cache/bump"
mkdir -p "$TMP/data/mise/installs/node/9/bin"
# shellcheck disable=SC2016  # the fake npm's own $*.
printf '%s\n' '#!/bin/sh' 'echo "PROJECTNPM $*"' >"$TMP/data/mise/installs/node/9/bin/npm"
chmod +x "$TMP/data/mise/installs/node/9/bin/npm"
# shellcheck disable=SC2016
stub npm 'case "$1" in outdated) echo "/p/node_modules/foo:foo@2.0.0:foo@1.0.0:foo@2.0.0"; exit 1;; esac; echo "HOMENPM $*"'
run PATH="$TMP/data/mise/installs/node/9/bin:$STUB:$SYSBIN" -- --only npm
NPMLOG=$(cat "$TMP"/cache/bump/*/npm.log 2>/dev/null)
assert_contains "npm uses the npm \$HOME resolves" "$NPMLOG" "HOMENPM install -g foo@latest"
assert_missing "npm ignores the caller's per-directory mise node" "$NPMLOG" "PROJECTNPM"

reset_stubs
rm -rf "$TMP/cache/bump"
mkdir -p "$TMP/data/mise/shims"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'echo "SHIMNPM $*" >&2' >"$TMP/data/mise/shims/npm"; chmod +x "$TMP/data/mise/shims/npm"
run PATH="$STUB:$SYSBIN:$TMP/data/mise/shims" -- --only npm
assert_contains "mise's shims go first, so a global mise node wins" \
    "$(cat "$TMP"/cache/bump/*/npm.log 2>/dev/null)" "SHIMNPM outdated"
rm -rf "$TMP/data/mise"

# cargo honours a rust-toolchain.toml in the cwd, so the steps run from $HOME.
reset_stubs
rm -rf "$TMP/cache/bump"
# shellcheck disable=SC2016  # $PWD is the stub's.
stub uv 'echo "CWD=$PWD"'
run -- --only uv
assert_contains "steps run from \$HOME, not from where bump started" \
    "$(cat "$TMP"/cache/bump/*/uv.log 2>/dev/null)" "CWD=$(cd "$TMP" && pwd)"

# The caller's mise exported its project env too (RUSTUP_TOOLCHAIN from a
# pinned rust, GOROOT, a project [env]). bump has mise undo it from $HOME.
reset_stubs
rm -rf "$TMP/cache/bump"
# shellcheck disable=SC2016  # the stub's own $1.
stub mise 'case "$1" in hook-env) echo "unset RUSTUP_TOOLCHAIN";; esac; exit 0'
# shellcheck disable=SC2016
stub rustup 'echo "TC=${RUSTUP_TOOLCHAIN:-unset}"'
run RUSTUP_TOOLCHAIN=1.70 __MISE_DIFF=x -- --only rustup
assert_contains "the caller's mise env is undone before the steps run" \
    "$(cat "$TMP"/cache/bump/*/rustup.log 2>/dev/null)" "TC=unset"

reset_stubs
run IN_NIX_SHELL=impure -- --only uv
assert_contains "running inside a nix shell is called out" "$OUT" "running inside a nix shell"

# A mise shim exists for any tool some project once installed. In $HOME it only
# counts when it resolves: else the step must skip, not fail every run.
reset_stubs
mkdir -p "$TMP/data/mise/shims"
printf '%s\n' '#!/bin/sh' 'echo "No version is set for shim: npm" >&2; exit 1' >"$TMP/data/mise/shims/npm"
chmod +x "$TMP/data/mise/shims/npm"
rm -f "$STUB/npm"
stub mise 'exit 1'
run PATH="$STUB:$SYSBIN:$TMP/data/mise/shims" -- --only npm
assert_contains "an unresolvable mise shim is not 'installed'" "$OUT" "npm not installed"
rm -rf "$TMP/data/mise"

# --- mise -------------------------------------------------------------------
# `mise upgrade` only sees the configs of the directory it starts in, and bump
# runs from $HOME: every run said "All tools are up to date" while the dotfiles
# mise.toml sat on an old node LTS.
reset_stubs
rm -rf "$TMP/cache/bump"
stub mise 'echo "MISE $*"'
run -- --only mise
assert_contains "mise also upgrades the dotfiles checkout's config" \
    "$(cat "$TMP"/cache/bump/*/mise.log 2>/dev/null)" "MISE -C $TMP/dotfiles upgrade"
run DOTFILES_DIR="$TMP/nowhere" -- --only mise
assert_contains "a missing checkout is said out loud, not hidden behind a green tick" \
    "$OUT" "only the global mise config was upgraded"

# --- casks ------------------------------------------------------------------
# A bare `brew upgrade --cask` skips every auto_updates cask, and several never
# updated themselves (copilot-cli was 81 releases behind). Each is judged: an
# app that already self-updated is left alone, and one that is running is not
# quit by the upgrade (Ghostty would close every window), it is reported.
mkdir -p "$TMP/apps/Selfup.app/Contents" "$TMP/apps/Ahead.app/Contents" "$TMP/apps/Renamed.app/Contents" \
    "$TMP/apps/Behind.app/Contents" "$TMP/apps/Busy.app/Contents/MacOS"
plist() { printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>%s</string></dict></plist>\n' "$1" >"$2/Contents/Info.plist"; }
plist 2.0 "$TMP/apps/Selfup.app"; plist 2.1.0 "$TMP/apps/Ahead.app"; plist 2.0.0 "$TMP/apps/Renamed.app"
plist 1.0 "$TMP/apps/Behind.app"; plist 1.0 "$TMP/apps/Busy.app"
# ahead: the app updated itself PAST the cask (reinstalling would downgrade it).
# renamed: the app stanza installs Src.app under another name.
# busy: closed by `signal`, not `quit`, which kills a running app just the same.
OUTDATED='{"casks":[{"name":"cli","current_version":"3.0"},{"name":"selfup","current_version":"2.0"},{"name":"ahead","current_version":"2.0"},{"name":"renamed","current_version":"2.0"},{"name":"behind","current_version":"2.0"},{"name":"busy","current_version":"2.0,abc"}]}'
INFO='{"casks":[{"token":"cli","artifacts":[{"binary":["cli"]}]},{"token":"selfup","artifacts":[{"app":["Selfup.app"]},{"uninstall":[{"quit":"x.selfup"}]}]},{"token":"ahead","artifacts":[{"app":["Ahead.app"]},{"uninstall":[{"quit":"x.ahead"}]}]},{"token":"renamed","artifacts":[{"app":["Src.app",{"target":"Renamed.app"}]},{"uninstall":[{"quit":"x.renamed"}]}]},{"token":"behind","artifacts":[{"app":["Behind.app"]},{"uninstall":[{"quit":"x.behind"}]}]},{"token":"busy","artifacts":[{"app":["Busy.app"]},{"uninstall":[{"signal":[["TERM","x.busy"]]}]}]}]}'
cask_stub() {
    stub brew "case \"\$1 \$2\" in
        'trust --json') exit 1 ;;
        'outdated --cask') echo '$OUTDATED' ;;
        'info --cask') echo '$INFO' ;;
        *) echo \"BREW \$*\" ;;
    esac"
}
reset_stubs; rm -rf "$TMP/cache/bump"; cask_stub
_busy_pid=; _no_path_ps=
if ps -axo comm= >/dev/null 2>&1; then
    # A symlink, not a copy: macOS kills a copied system binary on exec
    # (Killed: 9), while ps reports a symlinked launch under the link's path.
    ln -sf /bin/sleep "$TMP/apps/Busy.app/Contents/MacOS/Busy"
    "$TMP/apps/Busy.app/Contents/MacOS/Busy" 30 & _busy_pid=$!
    # Only macOS ps prints the executable's full path in `comm`; Linux (CI)
    # prints a 15-char name, so there the running-app branch cannot be staged.
    # Polled, not a fixed sleep: under load the exec can take a while to show.
    _seen=
    for _i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        # Captured, then matched, as bump does. `ps | grep -q` under pipefail
        # failed at random: grep exits on the first match, ps dies of SIGPIPE,
        # and the pipeline reports that as a miss.
        case "$(ps -axo comm= 2>/dev/null)" in *"$TMP/apps/Busy.app/Contents/"*) _seen=1; break ;; esac
        sleep 0.2
    done
    if [[ -z "$_seen" ]]; then
        kill "$_busy_pid" 2>/dev/null; wait "$_busy_pid" 2>/dev/null; _busy_pid=; _no_path_ps=1
    fi
fi
run HOMEBREW_CASK_OPTS="--appdir=$TMP/apps" -- --only brew-cask
[[ -n "$_busy_pid" ]] && { kill "$_busy_pid" 2>/dev/null; wait "$_busy_pid" 2>/dev/null; }
CASKLOG=$(cat "$TMP"/cache/bump/*/brew-cask.log 2>/dev/null)
assert_eq "the cask step succeeds" "$RC" "0"
assert_matches "regular casks are still upgraded first" "$CASKLOG" '^BREW upgrade --cask$'
assert_matches "an auto_updates cask with no app to quit is upgraded" "$CASKLOG" "^BREW upgrade --cask cli"
assert_contains "an app that already updated itself is left alone" "$CASKLOG" "selfup: the app already updated itself"
assert_contains "an app that updated past the cask is not downgraded" "$CASKLOG" "ahead: the app already updated itself (2.1.0)"
assert_contains "an app installed under a target name is found by that name" "$CASKLOG" "renamed: the app already updated itself (2.0.0)"
if [[ -n "$_busy_pid" ]]; then
    assert_matches "an app that is behind and closed is upgraded" "$CASKLOG" "^BREW upgrade --cask cli behind$"
    assert_missing "a running app the upgrade would quit is not upgraded" "$CASKLOG" "behind busy"
    assert_contains "a running app that was held back is reported at the end" "$OUT" "busy is behind (1.0 -> 2.0) but running"
elif [[ -n "$_no_path_ps" ]]; then
    ok "(ps here has no executable paths, as on Linux: the running-app checks need macOS)"
else
    # No process list (a sandbox): a cask whose upgrade quits its app is held
    # back rather than upgraded on the guess that nothing is open.
    assert_missing "with no process list, an app the upgrade would quit is held back" "$CASKLOG" "behind busy"
    assert_contains "with no process list, the held-back app is reported" "$OUT" "busy is behind (1.0 -> 2.0), but whether it is running could not be checked"
fi

# One broken regular cask must not hold every auto_updates cask back with it.
reset_stubs; rm -rf "$TMP/cache/bump"
stub brew "case \"\$1 \$2\" in
    'trust --json') exit 1 ;;
    'outdated --cask') echo '{\"casks\":[{\"name\":\"cli\",\"current_version\":\"3.0\"}]}' ;;
    'info --cask') echo '{\"casks\":[{\"token\":\"cli\",\"artifacts\":[]}]}' ;;
    *) echo \"BREW \$*\"; [ \"\$#\" -eq 2 ] && exit 1; exit 0 ;;
esac"
run -- --only brew-cask
assert_contains "a failing regular cask upgrade still lets auto_updates casks go" \
    "$(cat "$TMP"/cache/bump/*/brew-cask.log 2>/dev/null)" "BREW upgrade --cask cli"
assert_eq "a failing regular cask upgrade still fails the step" "$RC" "1"

# Unable to judge (no python3 / broken JSON): upgrade none of them, and say so.
reset_stubs; rm -rf "$TMP/cache/bump"
# shellcheck disable=SC2016
stub brew 'case "$1" in trust) exit 1;; outdated) echo "not json";; *) echo "BREW $*";; esac'
run -- --only brew-cask
assert_eq "an unreadable outdated list does not fail the step" "$RC" "0"
assert_contains "an unreadable outdated list is reported" "$OUT" "could not inspect auto_updates casks"

# A bare `brew upgrade` goes on to the casks, so the formula step used to do the
# cask step's sudo-needing work and fail on cask-side errors after every formula
# had upgraded. It is formulae only now.
reset_stubs; rm -rf "$TMP/cache/bump"
# shellcheck disable=SC2016
stub brew 'case "$1" in trust) exit 1;; *) echo "BREW $*";; esac'
run -- --only brew
assert_matches "the formula step upgrades formulae only" \
    "$(cat "$TMP"/cache/bump/*/brew.log 2>/dev/null)" '^BREW upgrade --formula$'

# Homebrew's own sudo (cask uninstall scripts, pkg installers) has no -n, so a
# grant that does not reach it prompted behind the spinner and hung. With
# SUDO_ASKPASS set Homebrew uses -A, and the helper refuses at once.
reset_stubs; rm -rf "$TMP/cache/bump"
# shellcheck disable=SC2016
stub brew 'case "$1" in
    trust) exit 1;;
    outdated) echo "{\"casks\":[]}";;
    upgrade) if [ -x "$SUDO_ASKPASS" ]; then "$SUDO_ASKPASS"; echo "ASKPASS rc=$?"; else echo "NO ASKPASS"; fi;;
    *) :;;
esac'
run -- --only brew-cask
CASKLOG=$(cat "$TMP"/cache/bump/*/brew-cask.log 2>/dev/null)
assert_contains "the cask step hands Homebrew a refusing askpass helper" "$CASKLOG" "ASKPASS rc=1"
assert_contains "a refused mid-step sudo says why in the log" "$CASKLOG" "refused instead of hanging"
assert_contains "a refused mid-step sudo is reported at the end" "$OUT" "brew-cask: sudo asked for a password mid-step"
# --verbose too: the step is in timeout's background process group, so a sudo
# prompt there stops on SIGTTIN and what is typed only echoes.
rm -rf "$TMP/cache/bump"
run -- --only brew-cask --verbose
assert_contains "--verbose refuses a mid-step sudo prompt as well" "$OUT" "ASKPASS rc=1"

# --- uv ---------------------------------------------------------------------
reset_stubs
rm -rf "$TMP/cache/bump"
stub uv 'echo "UV $*"'
run -- --only uv
assert_contains "uv upgrades every installed tool" \
    "$(cat "$TMP"/cache/bump/*/uv.log 2>/dev/null)" "UV tool upgrade --all"
reset_stubs
rm -f "$STUB/uv"
run -- --only uv
assert_contains "uv is skipped when it is not installed" "$OUT" "uv not installed"

# --- PATH shadowing -----------------------------------------------------------
# Every step can be green while the shell runs an older copy from earlier on
# PATH (jq 1.7.1 in ~/.local/bin over brew's 1.8.2, for real).
reset_stubs
mkdir -p "$TMP/shadow" "$TMP/shadowpfx/bin"
for b in jq rustup same; do
    printf '%s\n' '#!/bin/sh' 'exit 0' >"$TMP/shadowpfx/bin/$b"; chmod +x "$TMP/shadowpfx/bin/$b"
done
for b in jq rustup; do
    printf '%s\n' '#!/bin/sh' 'exit 0' >"$TMP/shadow/$b"; chmod +x "$TMP/shadow/$b"
done
ln -sf "$TMP/shadowpfx/bin/same" "$TMP/shadow/same"
# shellcheck disable=SC2016
stub brew 'case "$1" in --prefix) echo "'"$TMP/shadowpfx"'";; trust) exit 1;; esac; exit 0'
run PATH="$TMP/shadow:$STUB:$TMP/shadowpfx/bin:$SYSBIN" -- --only mise
assert_contains "a binary shadowing brew's copy is named" "$OUT" "shadow/jq"
assert_missing "a symlink to brew's own copy is not a shadow" "$OUT" "shadow/same"
assert_missing "a self-updating copy on the allow list is not reported" "$OUT" "shadow/rustup"
run PATH="$TMP/shadow:$STUB:$TMP/shadowpfx/bin/:$SYSBIN" -- --only mise
assert_contains "brew's bin written with a trailing slash is still found" "$OUT" "shadow/jq"
run PATH="$STUB:$TMP/shadowpfx/bin:$TMP/shadow:$SYSBIN" -- --only mise
assert_missing "a copy after brew on PATH is not a shadow" "$OUT" "shadows"
# With brew's bin not on PATH at all, the scan used to walk everything and
# report /usr/bin as shadowing brew. Nothing can shadow what is not on PATH.
cp "$SYSBIN/date" "$TMP/shadowpfx/bin/date" 2>/dev/null || :
run PATH="$TMP/shadow:$STUB:$SYSBIN" -- --only mise
assert_missing "brew's bin missing from PATH reports nothing" "$OUT" "shadows"
run HOMEBREW_PREFIX="$TMP/shadowpfx" PATH="$TMP/shadow:$STUB:$TMP/shadowpfx/bin:$SYSBIN" -- --only mise
assert_contains "HOMEBREW_PREFIX is used without asking brew" "$OUT" "shadow/jq"

# --- cargo -----------------------------------------------------------------
# The prebuilt cargo-binstall carries a bundled resolver that dies on a router
# answering EDNS with FORMERR, failing every cargo update. bump pins binstall to
# a source build without trust-dns before cargo-update runs.
reset_stubs
rm -rf "$TMP/cache/bump"
stub cargo-binstall 'exit 0'
stub cargo 'echo "CARGO $*"'
run -- --only cargo
assert_eq "cargo step succeeds" "$RC" "0"
CARGOLOG=$(cat "$TMP"/cache/bump/*/cargo.log 2>/dev/null)
assert_contains "cargo pins binstall's features before updating" "$CARGOLOG" "CARGO install-update -a"
assert_missing "binstall's pin output stays out of the log" "$CARGOLOG" "install-update-config"

reset_stubs
rm -rf "$TMP/cache/bump"
stub cargo-binstall 'exit 0'
# shellcheck disable=SC2016  # literal $1 for the stub.
stub cargo 'case "$1" in install-update-config) echo "PIN $*" >&2;; *) echo "CARGO $*";; esac'
run -- --only cargo
CARGOLOG=$(cat "$TMP"/cache/bump/*/cargo.log 2>/dev/null)
assert_contains "binstall is pinned without default features" "$CARGOLOG" "--default-features false"
assert_matches "binstall keeps rustls and git" "$CARGOLOG" "f rustls.*-f git"
assert_missing "binstall is pinned without trust-dns" "$CARGOLOG" "trust-dns"

reset_stubs
rm -rf "$TMP/cache/bump"
# shellcheck disable=SC2016  # literal $1 for the stub.
stub cargo 'case "$1" in install-update-config) echo "PIN" >&2;; *) echo "CARGO $*";; esac'
run -- --only cargo
CARGOLOG=$(cat "$TMP"/cache/bump/*/cargo.log 2>/dev/null)
assert_missing "no binstall means nothing to pin" "$CARGOLOG" "PIN"

reset_stubs
rm -rf "$TMP/cache/bump"
stub cargo-binstall 'exit 0'
# shellcheck disable=SC2016  # literal $1 for the stub.
stub cargo 'case "$1" in install-update-config) exit 3;; *) echo "CARGO $*";; esac'
run -- --only cargo
assert_eq "a failed binstall pin fails the step" "$RC" "1"

# --- parallel phase --------------------------------------------------------
reset_stubs
run -- --skip flake,darwin,brew,brew-cask
assert_eq "the parallel phase exits 0 when every step passes" "$RC" "0"
assert_contains "the parallel phase announces itself" "$OUT" "in parallel:"
# Results arrive out of order, so each needs its own step tag to be identifiable.
assert_eq "every parallel step reports exactly one result" \
    "$(printf '%s' "$OUT" | grep -cE '^  (✓|✗) \[[0-9]+/9\]')" "9"
PARLINE=$(printf '%s\n' "$OUT" | grep 'in parallel:')
assert_contains "rustup runs in the parallel phase" "$PARLINE" "rustup"
assert_contains "uv tools run in the parallel phase" "$PARLINE" "uv tools"

# cargo builds with the toolchain rustup replaces, and npm runs on the node mise
# replaces, so each waits for its pair. Nothing else waits.
reset_stubs
rm -rf "$TMP/cache/bump"
stub rustup "sleep 3; touch \"$TMP/rustup-done\""   # 3s: room for gh to start first even on a slow machine
stub mise "sleep 1; touch \"$TMP/mise-done\""
stub cargo "[ -e \"$TMP/rustup-done\" ] && echo AFTER-RUSTUP || echo BEFORE-RUSTUP"
stub npm "{ [ -e \"$TMP/mise-done\" ] && echo AFTER-MISE || echo BEFORE-MISE; } >&2"
stub gh "[ -e \"$TMP/rustup-done\" ] && echo GH-WAITED || echo GH-FREE"
stub uv "[ -e \"$TMP/mise-done\" ] && echo AFTER-MISE || echo BEFORE-MISE"
rm -f "$TMP/rustup-done" "$TMP/mise-done"
run -- --only rustup,cargo,mise,npm,gh,uv
assert_contains "cargo starts after rustup finishes" "$(cat "$TMP"/cache/bump/*/cargo.log 2>/dev/null)" "AFTER-RUSTUP"
assert_contains "npm starts after mise finishes" "$(cat "$TMP"/cache/bump/*/npm.log 2>/dev/null)" "AFTER-MISE"
assert_contains "uv (a mise python can carry its venvs) waits for mise" "$(cat "$TMP"/cache/bump/*/uv.log 2>/dev/null)" "AFTER-MISE"
assert_contains "an unrelated step does not wait" "$(cat "$TMP"/cache/bump/*/gh.log 2>/dev/null)" "GH-FREE"
rm -f "$TMP/rustup-done" "$TMP/mise-done"
# A dependency that is not running this time must not be waited for.
reset_stubs
_t0=$SECONDS
run -- --only cargo
assert_eq "cargo alone does not wait for an unselected rustup" "$(( SECONDS - _t0 < 5 ))" "1"

# --- logs ------------------------------------------------------------------
reset_stubs
rm -rf "$TMP/cache/bump"
stub brew 'echo "log me" >&2; exit 1'
run -- --only brew
LOGDIR=$(find "$TMP/cache/bump" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
assert_contains "the run prints where its logs went" "$OUT" "logs:"
assert_contains "the failing step's log holds its output" "$(cat "$LOGDIR/brew.log" 2>/dev/null)" "log me"

reset_stubs
mkdir -p "$TMP/cache/bump"
for i in $(seq -w 1 25); do mkdir -p "$TMP/cache/bump/200001$i-000000"; done
run -- --only mise
assert_eq "old run logs are pruned to the last 20" \
    "$(find "$TMP/cache/bump" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "20"

# A run where every step skipped records nothing, so it should not take a slot.
reset_stubs
rm -rf "$TMP/cache/bump"; rm -f "$STUB"/*; stub whoami 'echo tester'; stub sudo 'exit 1'
run --
assert_eq "a run that logged nothing leaves no log dir behind" \
    "$(find "$TMP/cache/bump" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')" "0"

# Back-to-back runs used to land in the same second-resolution log dir, where
# the second run read the first's leftover sentinels and reported ITS results.
reset_stubs
rm -rf "$TMP/cache/bump"
run -- --only mise
run -- --only mise
assert_eq "two runs in the same second get their own log dirs" \
    "$(find "$TMP/cache/bump" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "2"

# --- verbose ---------------------------------------------------------------
reset_stubs
stub mise 'echo "mise says hello"'
run -- -v --only mise,npm
assert_contains "verbose streams the command's own output" "$OUT" "mise says hello"
# Concurrent live output is unreadable, so verbose has to force serial.
assert_missing "verbose runs serially" "$OUT" "in parallel:"

# --- the slow paths -------------------------------------------------------
# Two branches that a normal run never reaches: the sudo keep-alive only
# refreshes after 60s, and the watchdog's SIGKILL only lands 30s after its
# SIGTERM is ignored. Both were shipped untested because "no real run is long
# enough". They are perfectly testable with a stub that sleeps, just slowly, so
# they are opt-in — BUMP_TEST_SLOW=1, about two and a half minutes.
if [[ "${BUMP_TEST_SLOW:-}" == 1 ]]; then
    # macOS expires a sudo timestamp after ~5 minutes, and `brew upgrade --cask`
    # reached a Pkg cask ~25 minutes into a run — so the grant is refreshed every
    # 60s in the background. If that loop is broken the refresh never happens and
    # the late sudo prompts invisibly behind a spinner, which is the original hang.
    reset_stubs
    stub sudo "date +%s >>\"$TMP/sudo-times\"; exit 0"
    stub brew 'sleep 45'
    rm -f "$TMP/sudo-times"
    run BUMP_TIMEOUT=300 -- --only brew,brew-cask
    # The cadence is the property, not the count: a broken loop can still call
    # sudo a few times while never actually refreshing on schedule. Measured on
    # a 7-minute run the gaps were 60, 60, 60, 60, 60, 60, 61.
    _gap=$(awk 'NR>1 && $1-p > m { m = $1-p } { p = $1 } END { print m+0 }' "$TMP/sudo-times" 2>/dev/null)
    _n=$(wc -l <"$TMP/sudo-times" 2>/dev/null | tr -d ' ')
    if [[ "${_n:-0}" -ge 4 && "${_gap:-999}" -le 75 ]]; then
        ok "the sudo grant is refreshed on a 60s cadence ($_n calls, largest gap ${_gap}s)"
    else
        bad "the sudo keep-alive did not hold its cadence: $_n calls, largest gap ${_gap}s"
    fi
    # The keep-alive's `sleep 60` used to outlive the run by up to a minute.
    if pgrep -f 'sleep 60' >/dev/null 2>&1; then
        bad "a keep-alive sleep outlived the run"
    else
        ok "the keep-alive leaves no sleep behind"
    fi

    # timeout sends TERM, which a step can ignore; -k escalates to KILL 30s
    # later. Without it a step that traps TERM outlives its own watchdog, which
    # is the hang the watchdog exists to end.
    if $HAVE_TIMEOUT; then
        reset_stubs
        # `trap "" TERM; sleep 600` does NOT survive: timeout signals the whole
        # process group, and the sleep child does not ignore TERM, so the stub
        # returns immediately and the -k escalation is never exercised. The loop
        # form survives because the shell ignoring TERM is the one that persists.
        stub gh 'trap "" TERM; while :; do sleep 1; done'
        _t0=$SECONDS
        run BUMP_TIMEOUT=2 -- --only gh
        _took=$((SECONDS - _t0))
        assert_contains "a step that ignores SIGTERM is reported as killed, not just failed" \
            "$OUT" "ignored the 2s timeout, SIGKILLed"
        # 2s watchdog + 30s kill-after. Under 25s means TERM alone ended it and
        # the escalation went untested; over 90s means nothing killed it.
        if ((_took >= 25 && _took < 90)); then
            ok "the watchdog escalates to SIGKILL after its TERM is ignored (${_took}s)"
        else
            bad "the SIGKILL escalation did not happen as expected: the run took ${_took}s"
        fi
        # --verbose builds a different runner (a tee pipeline instead of an exec
    # redirect), so the TERM trap has to be on that path too. It was, but only
    # the non-verbose path had ever been exercised.
    if $HAVE_TIMEOUT; then
        reset_stubs
        stub gh 'trap "" TERM; while :; do sleep 1; done'
        _t0=$SECONDS
        run BUMP_TIMEOUT=2 -- -v --only gh
        _took=$((SECONDS - _t0))
        if ((_took >= 25 && _took < 90)); then
            ok "--verbose is killed by the watchdog too (${_took}s)"
        else
            bad "--verbose did not get the kill-after: ${_took}s"
        fi
    fi

    # The runner has to survive TERM for the kill-after to fire at all, but
        # it must not make its CHILDREN survive it: `trap ''` is inherited across
        # exec and made every ordinary step sit out the full 30s for nothing.
        reset_stubs
        stub gh 'sleep 600'
        _t0=$SECONDS
        run BUMP_TIMEOUT=2 -- --only gh
        _took=$((SECONDS - _t0))
        if ((_took < 15)); then
            ok "a step that respects SIGTERM pays no kill-after penalty (${_took}s)"
        else
            bad "an ordinary step waited out the kill-after: ${_took}s"
        fi
    fi

    # The deadline that ends the parallel poll when a child never reports its
    # result. It needs BUMP_TIMEOUT+60 seconds to fire, which is why it is here
    # — and until this was written nothing in the suite reached it at all:
    # replacing say_lost with say_result survived a whole mutation run.
    #
    # A child is made unable to land its sentinel by taking write permission off
    # the log directory the moment it appears, which is the same shape as a
    # child killed before writing, and reachable without killing anything.
    if $HAVE_TIMEOUT; then
        reset_stubs
        rm -rf "$TMP/cache/bump"
        stub gh 'sleep 3'
        _t0=$SECONDS
        (
            env -i PATH="$STUB:$SYSBIN" HOME="$TMP" TERM=dumb \
                XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data" \
                RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=1 \
                "$SHELL_UNDER_TEST" "$BUMP" --only gh </dev/null >"$TMP/lost.out" 2>&1
        ) &
        _runner=$!
        _ld=
        for _ in $(seq 1 100); do
            _ld=$(find "$TMP/cache/bump" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
            [[ -n "$_ld" ]] && break
            sleep 0.1
        done
        [[ -n "$_ld" ]] && chmod 500 "$_ld"
        wait "$_runner" 2>/dev/null
        [[ -n "$_ld" ]] && chmod 700 "$_ld"
        _took=$((SECONDS - _t0))
        OUT=$(sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' "$TMP/lost.out")
        assert_contains "a child that never reports is named as lost, not given an invented status" \
            "$OUT" "no result after"
        assert_missing "a lost child is not reported with a made-up exit code" "$OUT" "exit 137"
        if ((_took >= 55 && _took < 120)); then
            ok "the parallel poll ends at the deadline instead of hanging (${_took}s)"
        else
            bad "the deadline did not bound the poll as expected: ${_took}s"
        fi
    fi
fi

# --- the summary ----------------------------------------------------------
reset_stubs
# shellcheck disable=SC2016  # literal $1 for the stub, not for us.
stub brew 'case "$1" in update) sleep 3;; esac; exit 0'   # one slow step
run -- --skip flake,darwin,brew-cask
# The chart replaced a comma-joined list of a dozen names in which the one step
# that took 14 of the run's 21 seconds was indistinguishable from the eleven
# that took none.
assert_matches "a slow step gets a bar scaled to the slowest" "$OUT" 'homebrew formulae +█+ +[0-9]+s'
assert_matches "sub-second steps collapse into one line" "$OUT" '\+[0-9]+ more +under 1s'
assert_missing "the chart replaces the updated-names line" "$OUT" "updated  homebrew"

# Whether every step lands under a second depends on process spawn time, so the
# testable invariant is that the two presentations never appear together: bars,
# or the names, never both.
reset_stubs
run -- --only mise,npm
if printf '%s' "$OUT" | grep -q '█'; then
    assert_missing "a charted summary does not also list the names" "$OUT" "updated  mise"
else
    assert_contains "an uncharted summary names them instead" "$OUT" "updated  mise, npm globals"
fi

# .last lives in the cache root and outlives reset_stubs, so clear it here or
# the "first run" is never the first.
reset_stubs
rm -rf "$TMP/cache/bump"
run -- --only mise
assert_missing "the first run reports no previous one" "$OUT" "last run"
run -- --only mise
assert_contains "a later run reports how long since the last" "$OUT" "last run"

# --- the box fits the terminal --------------------------------------------
# Reported from a real run: with twelve steps named on one line the summary box
# was ~160 columns, overflowed a narrower terminal and came out as broken
# border fragments. gum sizes a box to its longest line and does not wrap.
if command -v python3 >/dev/null 2>&1 && command -v gum >/dev/null 2>&1; then
    cat >"$TMP/ptywide.py" <<'WIDE'
import os, pty, select, sys, fcntl, termios, struct
cols = int(sys.argv[1])
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash"] + sys.argv[2:])
    os._exit(1)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, cols, 0, 0))
out = b""
while True:
    try:
        r, _, _ = select.select([fd], [], [], 30)
        if not r:
            break
        d = os.read(fd, 65536)
        if not d:
            break
        out += d
        for p, rep in ((b"\x1b[?2026$p", b"\x1b[?2026;2$y"),
                       (b"\x1b[?2027$p", b"\x1b[?2027;2$y")):
            for _ in range(d.count(p)):
                os.write(fd, rep)
    except OSError:
        break
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
WIDE
    # gum alone, never its whole directory: that is /opt/homebrew/bin, and with
    # it on PATH a guard that fails open (a mutation the harness applies) found
    # the machine's real brew, nix and mise and ran them from inside the test,
    # in a pty session the watchdog could not kill. One run hung for two hours.
    mkdir -p "$TMP/realgum" && ln -sf "$(command -v gum)" "$TMP/realgum/gum"
    cat >"$TMP/widerun.sh" <<WIDERUN
sleep 0.5
export PATH="$STUB:$TMP/realgum:$SYSBIN"
export HOME="$TMP" TERM=xterm-256color
export XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data"
export RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=20
"$SHELL_UNDER_TEST" "$BUMP"
WIDERUN
    # The scenario has to produce a line whose length does NOT follow the
    # terminal, or the check cannot fail: the duration chart sizes its bars from
    # box_width(), so with every step succeeding the content adapts on its own
    # and the box fits even with --width removed — measured at 50 cells in a
    # 50-column terminal, i.e. passing for the wrong reason. The skipped list is
    # unbounded, so leave most managers missing and let it grow.
    reset_stubs
    rm -f "$STUB"/nix "$STUB"/rustup "$STUB"/mise "$STUB"/kubectl "$STUB"/gh \
          "$STUB"/atuin "$STUB"/cargo "$STUB"/cargo-install-update "$STUB"/gup
    for _cols in 50 100; do
        _w=$(python3 "$TMP/ptywide.py" "$_cols" "$TMP/widerun.sh" 2>/dev/null \
            | tr -d '\r' | sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' \
            | grep -E '^[╭╰╔╚]' \
            | python3 -c 'import sys; print(max((len(l.rstrip("\n")) for l in sys.stdin), default=0))')
        if [[ "${_w:-0}" -gt 0 && "${_w:-0}" -le "$_cols" ]]; then
            ok "the summary box fits a ${_cols}-column terminal (${_w} cells)"
        else
            bad "the summary box is ${_w:-?} cells in a ${_cols}-column terminal"
        fi
    done
fi

# --- the terminal-probe leak ----------------------------------------------
# `gum spin` ends by asking the terminal about synchronized output (DECRQM
# \e[?2026$p) and exits without reading the reply. The terminal writes the reply
# onto the tty input queue, where it waits until the shell reads the pile as
# typed input: a prompt full of "2026;2$y2027;2$y…" after the run. This checks
# the drain that bump does after every spinner actually empties that queue.
if command -v python3 >/dev/null 2>&1; then
    # bump's own drain_tty, cut out of the script under test. This used to be a
    # hand-written copy, so the check passed whatever bump's drain did: deleting
    # the drain from bump outright survived the mutation harness.
    sed -n '/^drain_tty() {/,/^}/p' "$BUMP" >"$TMP/drain.sh"
    cat >>"$TMP/drain.sh" <<'DRAIN'
sleep 1
[ "${1:-}" = "drain" ] && drain_tty
# Measured with a non-blocking read rather than `read -t`, because bash 3.2
# THROWS AWAY partial input when `read -t` times out (bash 4.0 changed that),
# so the control case would report an empty queue there and pass for free.
saved=$(stty -g </dev/tty 2>/dev/null)
stty -icanon min 0 time 0 </dev/tty 2>/dev/null
n=$(dd bs=4096 count=1 </dev/tty 2>/dev/null | wc -c | tr -d ' ')
stty "$saved" </dev/tty 2>/dev/null
printf 'LEFTOVER=%d\n' "$n"
DRAIN
    cat >"$TMP/ptyharness.py" <<'PY'
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash"] + sys.argv[1:])
    os._exit(1)
time.sleep(0.4)
os.write(fd, b"\x1b[?2026;2$y\x1b[?2027;2$y" * 8)   # 8 spinner steps' worth
out = b""
while True:
    try:
        r, _, _ = select.select([fd], [], [], 6)
        if not r:
            break
        d = os.read(fd, 65536)
        if not d:
            break
        out += d
    except OSError:
        break
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
PY
    left_without=$(python3 "$TMP/ptyharness.py" "$TMP/drain.sh" | tr -d '\r' | sed -n 's/.*LEFTOVER=\([0-9]*\).*/\1/p' | tail -1)
    left_with=$(python3 "$TMP/ptyharness.py" "$TMP/drain.sh" drain | tr -d '\r' | sed -n 's/.*LEFTOVER=\([0-9]*\).*/\1/p' | tail -1)
    if [[ "${left_without:-0}" -gt 0 ]]; then
        ok "control: terminal replies really do pile up on the tty ($left_without bytes)"
    else
        bad "control: expected leftover bytes without a drain, got '${left_without:-}'"
    fi
    assert_eq "drain_tty empties the terminal's replies" "${left_with:-x}" "0"
    # And the same thing end to end: a pty that answers the DECRQM probes the
    # way a real terminal does, with bump driving `gum spin`. Through a fake gum
    # that probes the way gum 1.x did (once as the spinner starts, once as it
    # exits), not the real one: gum 2.x sends no probes at all, so against it
    # these checks had nothing to catch, and deleting bump's drain, its mute, or
    # the drain's wait all survived the mutation harness. bump has to keep
    # coping with a terminal program that probes; this pins that it does.
    mkdir -p "$TMP/fakegum"
    cat >"$TMP/fakegum/gum" <<'FAKEGUM'
#!/bin/sh
case "$1" in
    spin)
        shift
        while [ $# -gt 0 ] && [ "$1" != "--" ]; do shift; done
        shift
        printf '\033[?2004h\033[?2026$p\033[?2027$p' >/dev/tty
        sleep 0.3   # still "drawing" when the terminal's answer lands
        "$@"; rc=$?
        printf '\033[?2026$p\033[?2027$p\033[?2004l' >/dev/tty
        exit $rc ;;
    style)
        echo "[gum style]" ;;
esac
FAKEGUM
    chmod +x "$TMP/fakegum/gum"
    {
        cat >"$TMP/responder.py" <<'RESP'
import os, pty, select, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash"] + sys.argv[1:])
    os._exit(1)
out = b""
answered = 0
while True:
    try:
        r, _, _ = select.select([fd], [], [], 30)
        if not r:
            break
        d = os.read(fd, 65536)
        if not d:
            break
        out += d
        for probe, reply in ((b"\x1b[?2026$p", b"\x1b[?2026;2$y"),
                             (b"\x1b[?2027$p", b"\x1b[?2027;2$y")):
            for _ in range(d.count(probe)):
                os.write(fd, reply)
                answered += 1
    except OSError:
        break
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
sys.stdout.write("\nPROBES=%d\n" % answered)
RESP
        cat >"$TMP/gumrun.sh" <<GUMRUN
export PATH="\$STUB_PATH"
export HOME="$TMP" XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data"
export RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=20
"$BUMP" --only brew,brew-cask
saved=\$(stty -g </dev/tty 2>/dev/null)
# -echo here too: without it this measurement window is itself a place where a
# straggling reply gets painted on screen, and the test then counts its own
# instrument's output as a leak from bump.
stty -icanon -echo min 0 time 1 </dev/tty 2>/dev/null
n=\$(dd bs=4096 count=1 </dev/tty 2>/dev/null | wc -c | tr -d ' ')
stty "\$saved" </dev/tty 2>/dev/null
printf '\nTTYLEFT=%d\n' "\$n"
GUMRUN
        reset_stubs
        gum_out=$(STUB_PATH="$STUB:$TMP/fakegum:$SYSBIN" \
            python3 "$TMP/responder.py" "$TMP/gumrun.sh" 2>/dev/null | tr -d '\r')
        gum_left=$(printf '%s' "$gum_out" | sed -n 's/.*TTYLEFT=\([0-9]*\).*/\1/p' | tail -1)
        gum_probes=$(printf '%s' "$gum_out" | sed -n 's/.*PROBES=\([0-9]*\).*/\1/p' | tail -1)
        # Without this, the check below passes for free against any bump that
        # exits before it reaches a spinner — which is what happened the first
        # time this was pointed at the pre-fix revision, where `--only` does not
        # exist yet and the run died on an unknown argument.
        # The fake gum probes on every spinner, so a run that reached one
        # answered at least one probe.
        if [[ "$gum_out" == *$'\e[?2004h'* && "${gum_probes:-0}" -gt 0 ]]; then
            ok "the gum run really did reach a spinner (${gum_probes:-0} probe replies sent)"
        else
            bad "the gum run never reached a spinner, so the next check is vacuous" "$gum_out"
        fi
        assert_eq "a real gum-driven run leaves the tty queue empty" "${gum_left:-x}" "0"
        # The same run against a terminal that answers after a short delay, the
        # way a real one does. Answering instantly hides a race: a non-blocking
        # drain returns before the reply is in flight, the reply then arrives
        # with nothing reading it, and the tty echoes it into the middle of the
        # run's own output — seen for real as
        #   ^[[?2026;2$y^[[?2027;2$y  ✓ [3/12] 🍺 homebrew formulae
        cat >"$TMP/laggy.py" <<'LAGGY'
import os, pty, select, sys, threading, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash"] + sys.argv[1:])
    os._exit(1)
def reply(b):
    time.sleep(0.05)
    try:
        os.write(fd, b)
    except OSError:
        pass
out = b""
while True:
    try:
        r, _, _ = select.select([fd], [], [], 30)
        if not r:
            break
        d = os.read(fd, 65536)
        if not d:
            break
        out += d
        for p, rep in ((b"\x1b[?2026$p", b"\x1b[?2026;2$y"),
                       (b"\x1b[?2027$p", b"\x1b[?2027;2$y")):
            for _ in range(d.count(p)):
                threading.Thread(target=reply, args=(rep,), daemon=True).start()
    except OSError:
        break
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
LAGGY
        reset_stubs
        # shellcheck disable=SC2016  # `$y` is literal here: it is what grep looks for.
        _echoed=$(STUB_PATH="$STUB:$TMP/fakegum:$SYSBIN" \
            python3 "$TMP/laggy.py" "$TMP/gumrun.sh" 2>/dev/null \
            | tr -d '\r' | grep -c '\[?202[67];2\$y')
        if [[ "${_echoed:-x}" == 0 ]]; then
            ok "a slow terminal's replies are not echoed into the output"
        else
            bad "a slow terminal's replies are echoed into the output" \
                "echoed occurrences: ${_echoed:-<empty>}"
        fi
    }
else
    printf '%s  · skipped: pty test needs python3%s\n' "$dim" "$off"
fi

# --- result ----------------------------------------------------------------
printf '\n%s%d passed%s  %s%d failed%s\n' \
    "$grn" "$PASS" "$off" "$([[ $FAIL -gt 0 ]] && printf '%s' "$red" || printf '%s' "$dim")" "$FAIL" "$off"
((FAIL == 0))
