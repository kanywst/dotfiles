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
MANAGED="nix rustup mise npm kubectl gh atuin cargo cargo-install-update gup brew darwin-rebuild"

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
    cat >"$TMP/widerun.sh" <<WIDERUN
sleep 0.5
export PATH="$STUB:\$(dirname "\$(command -v gum)"):$SYSBIN"
export HOME="$TMP" TERM=xterm-256color
export XDG_CACHE_HOME="$TMP/cache" XDG_DATA_HOME="$TMP/data"
export RUSTUP_HOME="$TMP/rustup" DOTFILES_DIR="$TMP/dotfiles" BUMP_TIMEOUT=20
"$SHELL_UNDER_TEST" "$BUMP"
WIDERUN
    reset_stubs
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
        gum_out=$(STUB_PATH="$STUB:$(dirname "$(command -v gum)"):$SYSBIN" \
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
