# 01-atuin-pty.zsh - re-exec the shell inside `atuin pty-proxy`
#
# Atuin's output capture ([output] in atuin/config.toml) needs every
# interactive shell to run inside the pty-proxy. The proxy re-execs zsh, so
# everything sourced before this line runs twice. That is why it sits right
# after 00-env (which puts atuin on PATH) instead of next to 95-atuin, where it
# would double the whole conf.d. Inside the proxy the snippet is a no-op, and
# 95-atuin's regular `atuin init` coexists with it (the proxy starts once).
#
# Off switch: `[output] enabled = false` stops storing at once. To skip the
# proxy too, `export ATUIN_PTY_PROXY_FAILED=1` in ~/.zshenv (not ~/.zshrc.local,
# which 99-local sources long after this file has already exec'd).
#
# Skipped inside herdr: the proxy puts the shell on a nested pty, so herdr sees
# `atuin` as the pane's foreground process and never detects the agent in it.

if command -v atuin &>/dev/null && [[ "${HERDR_ENV:-}" != "1" ]]; then
    _atuin_pty_cache="${XDG_CACHE_HOME:-$HOME/.cache}/atuin/pty-proxy-init.zsh"
    _atuin_pty_bin="$(whence -p atuin 2>/dev/null)"
    if [[ ! -e "$_atuin_pty_cache" || ( -n "$_atuin_pty_bin" && "$_atuin_pty_bin" -nt "$_atuin_pty_cache" ) ]]; then
        [[ -d "${_atuin_pty_cache:h}" ]] || mkdir -p "${_atuin_pty_cache:h}"
        _atuin_pty_tmp="$(mktemp "${_atuin_pty_cache}.XXXXXX")"
        if atuin pty-proxy init zsh > "$_atuin_pty_tmp" 2>/dev/null; then
            mv -f "$_atuin_pty_tmp" "$_atuin_pty_cache"
        else
            rm -f "$_atuin_pty_tmp"
            : > "$_atuin_pty_cache"   # sentinel; binary mtime check re-triggers regen
        fi
        unset _atuin_pty_tmp
    fi
    [[ -s "$_atuin_pty_cache" ]] && source "$_atuin_pty_cache"
    unset _atuin_pty_cache _atuin_pty_bin
fi
