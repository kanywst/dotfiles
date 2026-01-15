# iTerm2

- [iTerm2](#iterm2)
  - [1. 必須設定](#1-必須設定)
    - [タイトルバーを消す](#タイトルバーを消す)
    - [ステータスバーの有効化 (CPU/Mem/Batt)](#ステータスバーの有効化-cpumembatt)
    - [GPUレンダリング (高速化)](#gpuレンダリング-高速化)
  - [2. Shell Integration](#2-shell-integration)
    - [インストール](#インストール)
    - [何ができるようになるのか？](#何ができるようになるのか)
  - [3. Aesthetic](#3-aesthetic)
    - [フォント (Nerd Fonts)](#フォント-nerd-fonts)
    - [カラーテーマ (Iceberg / Tokyo Night)](#カラーテーマ-iceberg--tokyo-night)
    - [カーソル](#カーソル)
    - [背景画像 (Optional)](#背景画像-optional)
  - [4. プロ用ショートカット (Muscle Memory)](#4-プロ用ショートカット-muscle-memory)
  - [5. 次のステップ](#5-次のステップ)

## 1. 必須設定

### タイトルバーを消す

画面を広く使い、サイバーパンクな雰囲気を出すためにタイトルバーを消します。

- `Preferences` > `Profiles` > `Window`
- **Window Appearance**: `Minimal` に設定（または `Compact`）
- **Settings for New Windows**:
  - `Columns`: 150 (お好みで)
  - `Rows`: 40 (お好みで)

### ステータスバーの有効化 (CPU/Mem/Batt)

ターミナル下部にシステム情報を常時表示します。
- `Preferences` > `Profiles` > `Session`
- **Status bar enabled**: チェックを入れる
- `Configure Status Bar` ボタンをクリック:
  - `CPU Utilization`, `Memory Utilization`, `Battery Level`, `Clock` などをドラッグ＆ドロップで追加。
  - `Auto-Rainbow` を `Advanced` 設定で選ぶと色鮮やかになります。

### GPUレンダリング (高速化)

- `Preferences` > `General` > `Magic`
- **GPU Rendering**: 有効化されているか確認（デフォルトでONのはずですが）。

---

## 2. Shell Integration

iTerm2 と Zsh を密結合させ、魔法のような機能を実現します。

### インストール

iTerm2 のメニューバーから:
`iTerm2` > `Install Shell Integration` をクリック。
インストーラに従ってインストールしてください（自動で `.zshrc` に追記されます）。

### 何ができるようになるのか？

1. **マークジャンプ (`Cmd + Shift + ↑/↓`)**:
    - プロンプトの位置を記憶し、コマンド実行ごとのログ頭出しが一瞬でできます。
    - 長いログ出力（ビルドログなど）の確認でスクロール地獄から解放されます。
2. **コマンド終了通知**:
    - 長いコマンド（`docker build`など）が終わったら通知センターで通知してくれます。
    - `Option + Cmd + A` でアラートを設定可能。
3. **クリック可能なリンク**:
    - ファイルパスやURLを `Cmd + Click` で開けるようになります。

---

## 3. Aesthetic

### フォント (Nerd Fonts)

アイコン表示のために必須です。

- [Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip) または [JetBrains Mono Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip) をダウンロードしてインストール。
- iTerm2: `Preferences` > `Profiles` > `Text` > **Font** で指定。
- **Use Ligatures**: チェックを入れる（`=>` が矢印記号などで表示され、コードが読みやすくなります）。

### カラーテーマ (Iceberg / Tokyo Night)

デフォルトの色は目に優しくありません。プロ御用達のテーマを入れましょう。

**おすすめテーマ:**

- **[Iceberg](https://cocopon.github.io/iceberg.vim/)**: 日本人作者による、目に優しい寒色系テーマ。長時間作業に最適。
- **[Tokyo Night](https://github.com/folke/tokyonight.nvim)**: モダンで鮮やかな夜の街のイメージ。
- **[Catppuccin](https://github.com/catppuccin/iterm)**: パステル調で非常に人気が高い。

**設定方法:**

1. テーマの `.itermcolors` ファイルをダウンロード。
2. `Preferences` > `Profiles` > `Colors` > `Color Presets...` > `Import...`

### カーソル

- `Preferences` > `Profiles` > `Text`
- **Cursor**: `Box` または `Vertical Bar`
- **Blinking**: チェックを入れる（生きている感じがします）

### 背景画像 (Optional)

うっすらと背景画像を透かせると、所有欲が満たされます。
- `Preferences` > `Profiles` > `Window`
- **Transparency**: 10-15% 程度に設定。
- **Blur**: 背景をぼかすと文字が見やすくなります。

---

## 4. プロ用ショートカット (Muscle Memory)

マウスを使ったら負けです。

|     キー操作      |                    動作                     |
| :---------------: | :-----------------------------------------: |
|     `Cmd + D`     |           画面を左右に分割 (Pane)           |
| `Cmd + Shift + D` |              画面を上下に分割               |
|  `Cmd + [` / `]`  |            分割したPaneの行き来             |
|  `Cmd + Opt + B`  | 実行履歴のタイムライン表示 (Instant Replay) |
|     `Cmd + F`     |          検索 (正規表現も使えます)          |
| `Cmd + Shift + H` |          クリップボード履歴の表示           |

---

## 5. 次のステップ

- **Tmux**: さらなる画面分割の自由度を求めるなら、iTerm2 と Tmux の連携（`-CC` モード）を検討してください。
- **Triggers**: 特定の文字列（例: `ERROR`）が出たら背景を赤くするなど、正規表現でアクションを自動化できます。(`Profiles` > `Advanced` > `Triggers`)
