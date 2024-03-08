# GEMINI.md

## 1. Project Structure Summary

The `dotfiles` repository is a collection of configuration files used to customize and manage the user's development environment. It primarily targets the Zsh shell and integrates various modern development tools.

### Key Files:
- **`.zshrc`**: The core configuration file for the Zsh shell. It manages:
    - **Environment Variables**: Sets up `PATH` for various tools like `krew`, `openssl`, `golang`, `yarn`, `istio`, and `wasmtime`.
    - **Shell Customization**: Configures syntax highlighting, terminal colors, and the `starship` prompt.
    - **Tool Integration**: Initializes `kube-ps1` for Kubernetes context, `compinit` for completions, and `fzf` for fuzzy searching.
    - **Aliases**: Provides numerous shortcuts for `kubectl`, `docker`, `git`, and `fzf`-based workflows.
    - **Version Managers**: Loads `nvm` (Node Version Manager) and `cargo` (Rust) environments.
- **`.gitignore_global`**: Defines global patterns for Git to ignore, ensuring that temporary or sensitive files are not accidentally tracked across different repositories.
- **`README.md`**: A minimal guide providing the commands to symlink the configuration files to the user's home directory.

---

## 2. Initialization Flow

The following sequence diagram illustrates the initialization process when a new Zsh session is started and `.zshrc` is sourced.

```mermaid
sequenceDiagram
    participant Zsh as Zsh Shell
    participant Env as Environment Variables
    participant FS as File System / Scripts
    participant Ext as External Tools (Brew, Starship, etc.)

    Note over Zsh: Start .zshrc sourcing

    Zsh->>Env: Set krew PATH
    Zsh->>FS: Source zsh-syntax-highlighting.zsh
    Zsh->>Env: Set CLICOLOR=1 & TERM=xterm-256color
    
    Zsh->>Ext: Execute starship init zsh
    Ext-->>Zsh: Return initialization script
    Zsh->>Zsh: Eval starship script

    Zsh->>FS: Source kube-ps1.sh
    Zsh->>Zsh: Update PS1 with kube_ps1 context

    Zsh->>Zsh: Load compinit (Completion System)
    Zsh->>Zsh: Set kubectl completion (compdef)

    Zsh->>Ext: Get brew prefix for openssl & golang
    Zsh->>Env: Update PATH & Set GOROOT

    Zsh->>Zsh: Define Aliases (k, d, fzf, g, gco, etc.)
    Zsh->>Env: Set FZF_DEFAULT_OPTS

    Zsh->>Env: Update PATH for Rancher Desktop
    
    alt envman exists
        Zsh->>FS: Source ~/.config/envman/load.sh
    end

    Zsh->>Env: Update PATH for yarn
    
    alt nvm exists
        Zsh->>FS: Source nvm.sh
        Zsh->>FS: Source nvm bash_completion
    end

    Zsh->>FS: Source ~/.cargo/env
    
    Zsh->>Env: Update PATH for istio & wasmtime
    
    Zsh->>Zsh: Define gemini-init alias

    Note over Zsh: Initialization Complete
```
