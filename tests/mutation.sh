#!/usr/bin/env bash
# Mutation harness for tests/bump.test.sh.
#
# "The suite is thorough" is an opinion until something measures it. This breaks
# one behaviour of bump at a time and checks the suite notices. A mutation that
# survives is a hole: the code could regress that way and every test would still
# be green.
#
# Usage:
#   tests/mutation.sh          # the fast mutations
#   tests/mutation.sh --slow   # only the ones BUMP_TEST_SLOW=1 can catch
#   tests/mutation.sh --show   # print what each mutation actually changes
#
# Each mutation is `name | sed program`. They are deliberately crude — the point
# is to change behaviour, not to write plausible code.
#
# Run it on its own. The slow suite asserts on wall-clock (a 60s refresh
# cadence, a 30s kill-after), so anything else heavy on the machine at the same
# time skews those and a green baseline turns red for no reason — which is
# exactly what a concurrent `mise run lint` did here.

set -uo pipefail

ROOT="$(cd -P "$(dirname "$0")/.." && pwd)"
BUMP="$ROOT/bin/.local/bin/bump"
SUITE="$ROOT/tests/bump.test.sh"
SLOW=false
[[ "${1:-}" == "--slow" ]] && SLOW=true

red=$'\e[38;5;203m'; grn=$'\e[38;5;84m'; dim=$'\e[38;5;244m'; off=$'\e[0m'
TMP="$(mktemp -d "${TMPDIR:-/tmp}/bump-mut.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# shellcheck disable=SC2016  # single quotes are the point; see the note below.
# name|sed program.
#
# SINGLE-quoted, every one of them. In double quotes the harness's own shell
# expands `$(...)`, `$$` and `${...}` inside the sed program before sed ever
# sees it — which silently produced a different mutant than the one named, and
# then reported the result as if it had tested the named behaviour. It happened
# twice: `$$` became the harness pid, and `$(box_width)` was command-substituted
# away so the mutation deleted every `--width` instead of one. Run with --show
# to print what each mutation actually changes.
MUTATIONS=(
    'summary box is not sized to the terminal|s|--width "\$(box_width)"||'
    'terminal width is read from tput, which lies through a pipe|/stty size <\/dev\/tty/s@.*@    c=$(tput cols 2>/dev/null)@'
    'the tty is never drained at all|/^ *drain_tty$/d'
    '--only matches as a regex instead of literally|s/grep -qxF --/grep -qx --/'
    'the step list is split with globbing enabled|s/^    set -f$//'
    'every run shares one log directory|s|^LOG_DIR=.*|LOG_DIR="\$LOG_ROOT/fixed"|'
    'a failing guard falls through instead of returning|s/{ _missing rustup; return 1; }/_missing rustup/'
    "npm's exit status is dropped again|s/((rc > 1)) && return \"\\\$rc\"//"
    "an all-skipped run calls itself a success|s/elif ((\\\${#DONE\\[@\\]} == 0)); then/elif false; then/"
    "summary lists are space-joined again|s/join_with ', '/join_with ' '/g"
    'the nix steps stop checking for a flake|s|\[\[ -f "\$DOTFILES_DIR/flake.nix" \]\]|true|'
    '--only= with no value is accepted again|s/need_arg --only "\${1#\*=}"; //'
    'the numeric check on a parallel result is removed|/=~ \^\[0-9\]/s@.*@            :@'
    'sudo outcomes collapse into one message|s|elif ! { : </dev/tty; } 2>/dev/null; then|elif false; then|'
)
# Only reachable with BUMP_TEST_SLOW=1, so `--slow` runs THESE and not the whole
# set again: the fast ones are already measured and re-running each against a
# four-minute suite would take an hour to learn nothing new.
SLOW_MUTATIONS=(
    'a lost child is reported with a made-up exit status|s/say_lost "/say_result "/'
    'the watchdog never escalates to SIGKILL|s/ -k 30//'
    'the runner ignores TERM instead of catching it, and so does every child|s/trap .:. TERM; /trap '"''"' TERM; /'
    'the sudo grant is never refreshed|s|^        while sudo -n -v 2>/dev/null; do$|        while false; do|'
)
$SLOW && MUTATIONS=("${SLOW_MUTATIONS[@]}")

CAUGHT=0; SURVIVED=0; BROKEN=0
declare -a SURVIVORS=()

# Without this the whole run is worthless and does not look it: on a suite that
# is already failing, every mutation is "caught" by whatever was broken to begin
# with. That happened — 15/15 reported while the baseline was red, six of them
# credited to an assertion nothing had mutated.
printf '%s▸ checking the baseline is green before measuring anything%s\n' "$dim" "$off"
declare -a base_env=()
$SLOW && base_env+=("BUMP_TEST_SLOW=1")
if ! env "${base_env[@]+"${base_env[@]}"}" "$SUITE" >"$TMP/base" 2>&1; then
    printf '%s  the suite fails on the unmutated script — fix that first:%s\n' "$red" "$off"
    sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' "$TMP/base" | grep -- '✗' | sed 's/^ */    /'
    exit 1
fi
printf '%s  baseline green%s\n\n' "$dim" "$off"

if [[ "${1:-}" == "--show" ]]; then
    for entry in "${MUTATIONS[@]}" "${SLOW_MUTATIONS[@]}"; do
        printf '%s── %s%s\n' "$dim" "${entry%%|*}" "$off"
        sed "${entry#*|}" "$BUMP" 2>/dev/null | diff -u "$BUMP" - | grep -E '^[-+][^-+]' | head -6
        echo
    done
    exit 0
fi

printf '%s▸ mutating bump, %d ways%s\n\n' "$dim" "${#MUTATIONS[@]}" "$off"
for entry in "${MUTATIONS[@]}"; do
    name=${entry%%|*}
    prog=${entry#*|}
    mutant="$TMP/bump.mutant"
    sed "$prog" "$BUMP" >"$mutant" 2>/dev/null
    chmod +x "$mutant"

    # A mutation that changes nothing tests nothing, and one that will not even
    # parse proves only that sed made a mess.
    if cmp -s "$mutant" "$BUMP"; then
        printf '%s  ?  %s%s\n' "$dim" "$name — sed changed nothing, mutation is a no-op" "$off"
        BROKEN=$((BROKEN + 1)); continue
    fi
    if ! bash -n "$mutant" 2>/dev/null; then
        printf '%s  ?  %s%s\n' "$dim" "$name — mutant does not parse" "$off"
        BROKEN=$((BROKEN + 1)); continue
    fi

    # NOT `${SLOW:+...}`: that is non-empty whenever SLOW is set at all, "false"
    # included, so it turned every fast run into a slow one.
    declare -a env_prefix=("BUMP_UNDER_TEST=$mutant")
    $SLOW && env_prefix+=("BUMP_TEST_SLOW=1")
    if env "${env_prefix[@]}" "$SUITE" >"$TMP/out" 2>&1; then
        printf '%s  ✗  SURVIVED: %s%s\n' "$red" "$name" "$off"
        SURVIVED=$((SURVIVED + 1)); SURVIVORS+=("$name")
    else
        first=$(sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' "$TMP/out" | grep -m1 -- '✗' | sed 's/^ *✗ *//')
        [[ -z "$first" ]] && first="(the suite exited non-zero without a failing assertion — check $TMP/out)"
        printf '%s  ✓%s  caught: %s\n%s      by: %s%s\n' "$grn" "$off" "$name" "$dim" "${first:-?}" "$off"
        CAUGHT=$((CAUGHT + 1))
    fi
done

printf '\n%s%d caught%s  %s%d survived%s  %s%d unusable%s\n' \
    "$grn" "$CAUGHT" "$off" \
    "$([[ $SURVIVED -gt 0 ]] && printf '%s' "$red" || printf '%s' "$dim")" "$SURVIVED" "$off" \
    "$dim" "$BROKEN" "$off"
if ((SURVIVED)); then
    printf '%suncovered behaviour:%s\n' "$red" "$off"
    printf '  - %s\n' "${SURVIVORS[@]}"
fi
((SURVIVED == 0))
