#!/usr/bin/env bash
# trust-coverage.sh — every third-party formula/cask declared in flake.nix must
# also be trusted in the vendored Homebrew trust store, and its tap must be
# declared alongside it.
#
# A backstop, NOT the defense against the failure that prompted it. Read this
# before assuming it catches more than it does:
#
# Homebrew 7 refuses to load a formula or cask from an untrusted tap, which
# broke a `bump` run at both the nix-darwin and homebrew steps. But the thing
# that actually broke was an UNDECLARED formula — something installed by hand
# from a tap flake.nix never mentions. That case is invisible from the repo and
# is caught by bump's pre-flight probe instead (brew_trust_probe, which is what
# to change if this class bites again).
#
# The declared case largely takes care of itself: nix-darwin emits every entry
# of its generated Brewfile as `brew "owner/tap/name", trusted: true` — 139 of
# them in the current generation — and `brew bundle` records those into the
# trust store as it goes. So a third-party formula added to flake.nix and not to
# trust.json is trusted by the next switch rather than breaking it.
#
# What this check is for, then, is that "rather than breaking it" resting
# entirely on an upstream choice nothing here controls. If nix-darwin stops
# emitting `trusted: true`, every declared third-party entry silently becomes a
# switch failure, and the first symptom would be the same inscrutable one-line
# brew error. Pinning the invariant costs two file reads, so it is pinned.
#
# Static on purpose: it reads the two tracked files and shells out to nothing,
# so it runs identically in a pre-commit hook and on a Linux CI runner with no
# Homebrew installed.
#
# Usage: tests/trust-coverage.sh [flake.nix] [trust.json]

set -uo pipefail

ROOT="$(cd -P "$(dirname "$0")/.." && pwd)"
FLAKE="${1:-$ROOT/flake.nix}"
TRUST="${2:-$ROOT/homebrew/.config/homebrew/trust.json}"

for f in "$FLAKE" "$TRUST"; do
    [[ -f "$f" ]] || { printf '✗ missing: %s\n' "$f" >&2; exit 1; }
done

python3 - "$FLAKE" "$TRUST" <<'PY'
import json, re, sys

flake_path, trust_path = sys.argv[1], sys.argv[2]

def nix_list(text, name):
    """Pull the quoted strings out of a `name = [ ... ];` block in flake.nix.

    Deliberately not a nix parser: these three lists are flat arrays of string
    literals and have been for the life of the file. Anything cleverer would be
    a second thing to maintain. If the block shape ever changes, the block is
    not found and the check fails loudly below rather than passing vacuously.
    """
    m = re.search(r'^\s*%s\s*=\s*\[\s*$' % re.escape(name), text, re.M)
    if not m:
        return None
    out, depth = [], 0
    for line in text[m.end():].splitlines():
        stripped = line.strip()
        if stripped.startswith('#'):
            continue
        if stripped == '];' and depth == 0:
            return out
        depth += line.count('[') - line.count(']')
        out.extend(re.findall(r'"([^"]+)"', line))
    return None

text = open(flake_path, encoding='utf-8').read()

lists = {}
for name in ('taps', 'brews', 'casks'):
    got = nix_list(text, name)
    if got is None:
        print('✗ could not find the `%s = [ ... ];` block in %s' % (name, flake_path))
        print('  The parser expects a flat list of string literals. If the file was')
        print('  restructured, update nix_list() in tests/trust-coverage.sh to match.')
        sys.exit(1)
    lists[name] = got

try:
    trust = json.load(open(trust_path, encoding='utf-8'))
except json.JSONDecodeError as e:
    print('✗ %s is not valid JSON: %s' % (trust_path, e))
    print('  Homebrew rewrites this file on every `brew trust`; a hand-edit that')
    print('  breaks it makes every tapped formula untrusted at once.')
    sys.exit(1)

trusted = {
    'brews': set(trust.get('trustedformulae', [])),
    'casks': set(trust.get('trustedcasks', [])),
}
trusted_taps = set(trust.get('trustedtaps', []))
declared_taps = set(lists['taps'])

# A bare name resolves against homebrew/core (or homebrew/cask), which is always
# trusted. Only a fully-qualified third-party name needs an entry.
CORE = ('homebrew/core/', 'homebrew/cask/')

problems = []
for kind in ('brews', 'casks'):
    key = 'trustedformulae' if kind == 'brews' else 'trustedcasks'
    flag = '--formula' if kind == 'brews' else '--cask'
    for entry in lists[kind]:
        if '/' not in entry or entry.startswith(CORE):
            continue
        tap = '/'.join(entry.split('/')[:2])
        if entry not in trusted[kind] and tap not in trusted_taps:
            problems.append(
                '✗ %s is declared in flake.nix `%s` but not trusted\n'
                '  add it to "%s" in %s, or run:\n'
                '      brew trust %s %s'
                % (entry, kind, key, trust_path, flag, entry))
        if tap not in declared_taps:
            problems.append(
                '✗ %s is declared in flake.nix `%s` but its tap is not\n'
                '  add "%s" to the `taps` list in %s'
                % (entry, kind, tap, flake_path))

# Deliberately one-directional. The reverse — a trust entry with no flake.nix
# declaration — is the normal shape of a trial install (see do_brew in
# bin/.local/bin/bump: "Homebrew lives partly outside the flake"), so flagging
# it here would nag on every commit for tools that are supposed to be undeclared.
# The one reverse case worth reporting, a trust entry for something no longer
# installed, needs the machine to see and is handled by bump's probe.
if problems:
    print('\n'.join(problems))
    sys.exit(1)

counted = sum(1 for k in ('brews', 'casks') for e in lists[k]
              if '/' in e and not e.startswith(CORE))
print('✓ trust coverage: %d third-party entries in flake.nix, all trusted '
      'and tapped' % counted)
PY
