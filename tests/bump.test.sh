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

TMP="$(mktemp -d "${TMPDIR:-/tmp}/bump-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/bin"
mkdir -p "$STUB" "$TMP/dotfiles" "$TMP/cache" "$TMP/data" "$TMP/rustup"
touch "$TMP/dotfiles/flake.nix"

stub() { printf '%s\n' "#!/bin/sh" "$2" >"$STUB/$1"; chmod +x "$STUB/$1"; }

# The stub PATH is deliberately minimal, which would leave the watchdog tests
# vacuous on macOS (no timeout(1) in /usr/bin — it comes from brew's coreutils).
# Link whatever the outer PATH has into the stub dir so they mean something.
HAVE_TIMEOUT=false
for _t in timeout gtimeout; do
    _p=$(command -v "$_t" 2>/dev/null) && { ln -sf "$_p" "$STUB/timeout"; HAVE_TIMEOUT=true; break; }
done

# Defaults: every manager present and succeeding. Individual tests override.
reset_stubs() {
    rm -f "$STUB"/*
    $HAVE_TIMEOUT && ln -sf "$(command -v timeout || command -v gtimeout)" "$STUB/timeout"
    local t
    for t in nix rustup mise kubectl gh cargo cargo-install-update gup darwin-rebuild brew npm atuin; do
        stub "$t" 'exit 0'
    done
    stub whoami 'echo tester'
    # Records that it was called, so "did bump ask for a password?" is testable.
    stub sudo "touch \"$TMP/sudo-called\"; exit 0"
    rm -f "$TMP/sudo-called"
    mkdir -p "$TMP/rustup/toolchains"
    printf 'session\n' >"$TMP/data/atuin/session" 2>/dev/null \
        || { mkdir -p "$TMP/data/atuin"; printf 'session\n' >"$TMP/data/atuin/session"; }
}

# run [env assignments...] -- <bump args...>; sets $OUT and $RC.
run() {
    local -a env_extra=()
    while [[ $# -gt 0 && "$1" != "--" ]]; do env_extra+=("$1"); shift; done
    shift || true
    OUT=$(env -i \
        PATH="$STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
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

# --- CLI surface ----------------------------------------------------------
reset_stubs

run -- --list
assert_eq "--list prints every step, one per line" "$(printf '%s' "$OUT" | grep -c .)" "12"
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

# Names are matched literally: as a regex this validated against every step.
run -- --only '.*'
assert_eq "--only regex is not a pattern" "$RC" "2"

# Splitting the list also globbed it against \$PWD.
run -- --skip '*'
assert_eq "--skip glob is not expanded" "$RC" "2"

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
rm -f "$TMP/data/atuin/session"
run -- --dry-run
# atuin without a login failed on every run and looked like a sync error.
assert_contains "atuin without a session is skipped, not run" "$OUT" "not signed in"

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

reset_stubs
stub sudo "touch \"$TMP/sudo-called\"; exit 1"   # grant refused
run -- --skip flake
assert_contains "refused sudo skips the nix-darwin step" "$OUT" "nix-darwin switch — skipped (needs sudo)"
# The cask upgrade is the step that actually needs root mid-run. Unguarded, it
# sat on an invisible password prompt until the watchdog killed it 30min later.
assert_contains "refused sudo skips the cask step" "$OUT" "homebrew casks — skipped (needs sudo)"
assert_contains "refused sudo still runs the formula step" "$OUT" "🍺 homebrew formulae ("

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

# --- summary honesty -------------------------------------------------------
reset_stubs
rm -f "$STUB"/*
stub whoami 'echo tester'
stub sudo 'exit 1'
run --
assert_contains "a run where everything skipped is not 'all done'" "$OUT" "nothing to do"
assert_eq "a run that did nothing still exits 0" "$RC" "0"
assert_contains "the empty summary lists are an em dash" "$OUT" "updated: —"

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

# --- parallel phase --------------------------------------------------------
reset_stubs
run -- --skip flake,darwin,brew,brew-cask
assert_eq "the parallel phase exits 0 when every step passes" "$RC" "0"
assert_contains "the parallel phase announces itself" "$OUT" "in parallel:"
# Results arrive out of order, so each needs its own step tag to be identifiable.
assert_eq "every parallel step reports exactly one result" \
    "$(printf '%s' "$OUT" | grep -cE '^  (✓|✗) \[[0-9]+/8\]')" "8"

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

# --- the terminal-probe leak ----------------------------------------------
# `gum spin` ends by asking the terminal about synchronized output (DECRQM
# \e[?2026$p) and exits without reading the reply. The terminal writes the reply
# onto the tty input queue, where it waits until the shell reads the pile as
# typed input: a prompt full of "2026;2$y2027;2$y…" after the run. This checks
# the drain that bump does after every spinner actually empties that queue.
if command -v python3 >/dev/null 2>&1; then
    cat >"$TMP/drain.sh" <<'DRAIN'
drain_tty() {
    { : </dev/tty; } 2>/dev/null || return 0
    saved=$(stty -g </dev/tty 2>/dev/null)
    if [ -n "$saved" ]; then
        stty -icanon min 0 time 0 </dev/tty 2>/dev/null
        dd bs=4096 count=1 </dev/tty >/dev/null 2>&1
        stty "$saved" </dev/tty 2>/dev/null
    fi
}
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
    # And the same thing end to end, through gum itself: a pty that answers the
    # DECRQM probes the way a real terminal does, with bump driving real
    # `gum spin` calls. This is the exact reported failure, so it is worth the
    # cost of being the one test that needs gum installed.
    if command -v gum >/dev/null 2>&1; then
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
stty -icanon min 0 time 0 </dev/tty 2>/dev/null
n=\$(dd bs=4096 count=1 </dev/tty 2>/dev/null | wc -c | tr -d ' ')
stty "\$saved" </dev/tty 2>/dev/null
printf '\nTTYLEFT=%d\n' "\$n"
GUMRUN
        reset_stubs
        gum_out=$(STUB_PATH="$STUB:$(dirname "$(command -v gum)"):/usr/bin:/bin" \
            python3 "$TMP/responder.py" "$TMP/gumrun.sh" 2>/dev/null | tr -d '\r')
        gum_left=$(printf '%s' "$gum_out" | sed -n 's/.*TTYLEFT=\([0-9]*\).*/\1/p' | tail -1)
        gum_probes=$(printf '%s' "$gum_out" | sed -n 's/.*PROBES=\([0-9]*\).*/\1/p' | tail -1)
        # Without this, the check below passes for free against any bump that
        # exits before it reaches a spinner — which is what happened the first
        # time this was pointed at the pre-fix revision, where `--only` does not
        # exist yet and the run died on an unknown argument.
        if [[ "${gum_probes:-0}" -gt 0 ]]; then
            ok "the gum run really did probe the terminal ($gum_probes replies sent)"
        else
            bad "the gum run never reached a spinner, so the next check is vacuous" "$gum_out"
        fi
        assert_eq "a real gum-driven run leaves the tty queue empty" "${gum_left:-x}" "0"
    else
        printf '%s  · skipped: end-to-end probe test needs gum%s\n' "$dim" "$off"
    fi
else
    printf '%s  · skipped: pty test needs python3%s\n' "$dim" "$off"
fi

# --- result ----------------------------------------------------------------
printf '\n%s%d passed%s  %s%d failed%s\n' \
    "$grn" "$PASS" "$off" "$([[ $FAIL -gt 0 ]] && printf '%s' "$red" || printf '%s' "$dim")" "$FAIL" "$off"
((FAIL == 0))
