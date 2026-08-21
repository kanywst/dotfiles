# 35-herdr.zsh — herdr: AI コーディングエージェント向けターミナルワークスペース
#
# herdr はバックグラウンドサーバーがペインを保持し、クライアントがアタッチする構成。
# CLI はサーバーを自動起動しないので、ヘルパー側で面倒を見る。
# 設定: ~/.config/herdr/config.toml  /  解説: github.com/0-draft/herdr-man

if command -v herdr &>/dev/null; then

    # --- 起動・接続 ---------------------------------------------------------
    alias hd='herdr'                     # 起動 or 既存セッションにアタッチ
    alias hdr='herdr --remote'           # SSH 越しにリモートサーバーへアタッチ
    alias hdst='herdr status'
    alias hdstop='herdr server stop'     # 全ペインのプロセスが死ぬ点に注意

    # --- 設定 ---------------------------------------------------------------
    alias hdrl='herdr server reload-config'
    alias hdck='herdr config check'      # サーバー不要のバリデータ
    alias hdcfg='${EDITOR:-vim} "$HOME/.config/herdr/config.toml"'
    alias hddef='herdr --default-config'

    # --- 観測 ---------------------------------------------------------------
    alias hdls='herdr agent list'
    alias hdint='herdr integration status'
    alias hdws='herdr workspace list'
    alias hdwt='herdr worktree list'

    # herdr ペイン内かどうか
    _herdr_inside() { [[ "${HERDR_ENV:-}" == "1" ]] }

    # サーバーが動いていなければ起動して待つ。CLI は自動起動しないため。
    _herdr_ensure_server() {
        herdr workspace list &>/dev/null && return 0
        print -u2 -- "herdr: バックグラウンドサーバーを起動中..."
        herdr server &>/dev/null &!
        local i
        for i in {1..20}; do
            sleep 0.25
            herdr workspace list &>/dev/null && return 0
        done
        print -u2 -- "herdr: サーバーが起動しませんでした (herdr status で確認)"
        return 1
    }

    # エージェント名は [a-z][a-z0-9_-]{0,31} かつライブエージェント間で一意
    _herdr_agent_name() {
        local base="${1:l}" n
        base="${base//[^a-z0-9_-]/-}"
        [[ "$base" == [a-z]* ]] || base="a$base"
        base="${base[1,31]}"
        herdr agent get "$base" &>/dev/null || { print -r -- "$base"; return 0 }
        for n in {2..99}; do
            herdr agent get "${base[1,29]}-$n" &>/dev/null || {
                print -r -- "${base[1,29]}-$n"; return 0
            }
        done
        print -r -- "$base-$RANDOM"
    }

    # hdgo [dir] — プロジェクトへ移動して herdr にアタッチする (cd は zoxide)
    hdgo() {
        if _herdr_inside; then
            print -u2 -- "herdr: すでに herdr ペインの中にいます (入れ子起動は不可)"
            return 1
        fi
        [[ -n "$1" ]] && { cd -- "$1" || return 1 }
        herdr
    }

    # hdup [label] [kind] — cwd 用ワークスペースを作り、エージェントを 1 体起動する
    #   hdup                 → ディレクトリ名のワークスペース + claude
    #   hdup api codex       → ラベル api + codex
    # フォーカスは奪わないので、herdr にアタッチしてから叩いても邪魔にならない。
    hdup() {
        command -v jq &>/dev/null || { print -u2 -- "herdr: jq が要ります"; return 1 }
        local label="${1:-${PWD:t}}" kind="${2:-claude}"
        _herdr_ensure_server || return 1

        local created ws pane name
        created=$(herdr workspace create --cwd "$PWD" --label "$label" --no-focus) || return 1
        ws=$(print -r -- "$created"   | jq -r '.result.workspace.workspace_id')
        pane=$(print -r -- "$created" | jq -r '.result.root_pane.pane_id')
        name=$(_herdr_agent_name "$label")

        if herdr agent start "$name" --kind "$kind" --pane "$pane" >/dev/null; then
            print -r -- "workspace=$ws  pane=$pane  agent=$name ($kind)"
        else
            print -u2 -- "herdr: $kind の起動に失敗 (workspace=$ws は残っています)"
            return 1
        fi
    }

    # hdb — いま判断待ち (blocked) のエージェントだけ出す
    hdb() {
        command -v jq &>/dev/null || { print -u2 -- "herdr: jq が要ります"; return 1 }
        herdr agent list | jq -r '
            .result.agents[]
            | select(.agent_status == "blocked")
            | "\(.name // .pane_id)\t\(.agent // "?")\t\(.workspace_id)"
        '
    }

    # hdw [state] — エージェントを状態つきで一覧 (省略時は全部)
    hdw() {
        command -v jq &>/dev/null || { print -u2 -- "herdr: jq が要ります"; return 1 }
        local want="${1:-}"
        herdr agent list | jq -r --arg want "$want" '
            .result.agents[]
            | select($want == "" or .agent_status == $want)
            | "\(.agent_status)\t\(.name // .pane_id)\t\(.agent // "?")\t\(.workspace_id)"
        '
    }

    # hdrun <pane_id> <command...> — ペインでコマンドを実行して終了行を待つ
    hdrun() {
        local pane="$1"; shift
        [[ -n "$pane" && $# -gt 0 ]] || {
            print -u2 -- "usage: hdrun <pane_id> <command...>"; return 2
        }
        herdr pane run "$pane" "$*"
    }

fi
