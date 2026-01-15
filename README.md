# dotfiles

- [dotfiles](#dotfiles)
  - [特徴](#特徴)
  - [Setup](#setup)
    - [1. リポジトリの取得](#1-リポジトリの取得)
    - [2. インストール](#2-インストール)
    - [4. 必須ツールのインストール](#4-必須ツールのインストール)
    - [5. セットアップ完了](#5-セットアップ完了)

## 特徴

- **Shell**: Zsh + [Starship](https://starship.rs/)
  - Git ブランチ・ステータス表示
  - Kubernetes Context/Namespace 表示
  - Node.js, Go, Rust 等のバージョン表示
- **Efficiency**:
  - `zoxide`: 頻度ベースのスマートなディレクトリ移動 (`z` コマンド)
  - `zsh-autosuggestions`: コマンド履歴からの入力補完
  - `eza`: アイコン付きのモダンな `ls`
  - `bat`: シンタックスハイライト付きの `cat`
  - `fzf`: 強力なファジー検索
- **DevTools**: kubectl, ghq, git などのエイリアス整備済み

## Setup

### 1. リポジトリの取得

ホームディレクトリ直下の `dotfiles` ディレクトリに配置することを想定しています。

```bash
git clone https://github.com/kanywst/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. インストール

```bash
chmod +x install.sh
./install.sh
```

### 4. 必須ツールのインストール

`.zshrc` で設定されている機能をフル活用するために、以下のツールを Homebrew でインストールします。

```bash
# 基本ツール
brew install git gh ghq fzf

# シェル拡張コマンド
brew install starship zsh-autosuggestions zoxide eza bat

# Kubernetes 関連
brew install kubectl kubectx kube-ps1

# フォント
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```

### 5. セットアップ完了

ターミナルを再起動するか、以下のコマンドで設定を読み込みます。

```bash
source ~/.zshrc
```
