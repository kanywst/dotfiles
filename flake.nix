{
  description = "kanywst macOS - nix-darwin glue (macOS defaults + declarative Homebrew). Shell/zsh stays stow-managed.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home-manager is additive: stow still owns the dotfiles today, but the
    # input is wired up so you can migrate modules (`programs.zsh`, `git`, …)
    # incrementally. Run with `home-manager switch --flake .#$(whoami)`.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager }:
  let
    system = "aarch64-darwin";
    # Resolved from $USER at eval time (needs `--impure`) so this public repo
    # carries no account name. Under pure eval getEnv returns "", so fall back
    # to "user" - that keeps `nix flake check` green in CI. Real switches use
    # `--impure` + `#"$(whoami)"` to pick up the actual user.
    username = let u = builtins.getEnv "USER"; in if u == "" then "user" else u;
  in {
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [
        ({ pkgs, ... }: {
          home.username = username;
          home.homeDirectory = "/Users/${username}";
          home.stateVersion = "25.11";
          programs.home-manager.enable = true;
          # Migrate gradually: enable programs.zsh / programs.git / programs.starship
          # here and remove the matching files from stow once verified.
        })
      ];
    };

    darwinConfigurations.${username} = nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        ({ pkgs, ... }: {
          # Determinate Nix manages the Nix daemon + flake settings itself, so
          # opt nix-darwin out of touching them. Flakes / nix-command are
          # already enabled by Determinate's installer.
          nix.enable = false;
          nixpkgs.config.allowUnfree = true;

          # Don't build the offline HTML manual. nix-darwin's manual builder
          # hardcodes `nixos-render-docs manual html --toc-depth`, which
          # nixpkgs-unstable (2026-07 onward) removed in favour of --sidebar-depth,
          # so the build fails the switch until upstream nix-darwin catches up.
          # `doc.enable` drops it from our own system-path; the uninstaller app
          # embeds a defaults-built darwin-system that rebuilds the same manual,
          # so it has to go too. man pages / info / package doc outputs are
          # unaffected, and `darwin-rebuild`/the flake still uninstall fine.
          documentation.doc.enable = false;
          system.tools.darwin-uninstaller.enable = false;

          # The user nix-darwin manages on this Mac
          system.primaryUser = username;
          users.users.${username} = {
            name = username;
            home = "/Users/${username}";
          };

          # Tiny system-level package set. Most software comes via Homebrew
          # below; only put things here that you want present even before brew
          # bootstraps.
          environment.systemPackages = with pkgs; [ vim git ];

          # macOS preferences
          system.defaults = {
            dock.autohide = true;
            dock.show-recents = false;
            dock.mineffect = "scale";
            NSGlobalDomain.KeyRepeat = 2;
            NSGlobalDomain.InitialKeyRepeat = 15;
            NSGlobalDomain.AppleShowAllExtensions = true;
            NSGlobalDomain.AppleInterfaceStyle = "Dark";
            NSGlobalDomain.AppleICUForce24HourTime = true;
            # Stop macOS from autocorrecting / capitalising code-y text.
            NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
            NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
            NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
            NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
            NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
            # Disable press-and-hold accent menu so key repeat works in every app.
            NSGlobalDomain.ApplePressAndHoldEnabled = false;
            finder.AppleShowAllFiles = true;
            finder.FXPreferredViewStyle = "Nlsv";
            finder.ShowPathbar = true;
            finder.ShowStatusBar = true;
            screencapture.location = "~/Downloads";
            screencapture.type = "png";
            screencapture.disable-shadow = true;
            loginwindow.GuestEnabled = false;
          };

          # Declarative Homebrew. nix-darwin keeps brew in sync with this list
          # on every `darwin-rebuild switch`. This list mirrors `brew leaves` /
          # `brew list --cask` / `mas list` on the live machine, so a fresh Mac
          # reconciles to the same set. `cleanup = "zap"` removes anything not
          # listed - keep that off ("none") until you're ready to let the flake
          # be the sole authority, otherwise it will uninstall packages.
          homebrew = {
            enable = true;
            onActivation = {
              autoUpdate = false;
              upgrade = false;
              cleanup = "none";
            };
            # External taps referenced by the brews / casks below.
            taps = [
              "anomalyco/tap"        # opencode
              "charmbracelet/tap"    # crush, vhs
              "kanywst/tap"          # approval-hub, y509
              "nikitabobko/tap"      # aerospace cask
              "ory/tap"              # ory cli
              "oven-sh/bun"          # bun
            ];
            brews = [
              # homebrew/core (bare name resolves against core)
              "actionlint"
              "aichat"
              "ansible"
              "ast-grep"
              "atuin"
              "awscli"
              "bat"
              "binwalk"
              "btop"
              "caddy"
              "carapace"
              "cmake"
              "codespell"
              "cosign"
              "d2"
              "diffoscope"
              "direnv"
              "dust"
              "envoy"
              "exiftool"
              "eza"
              "fd"
              "flock"
              "foremost"
              "fswatch"
              "fzf"
              "fzf-tab"
              "gh"
              "ghq"
              "git"
              "git-delta"
              "git-filter-repo"
              "gitleaks"
              "glow"
              "go"
              "golangci-lint"
              "goreleaser"
              "grpcurl"
              "grype"
              "gum"
              "helm"
              "httpie"
              "hubble"
              "hyperfine"
              "imagemagick"
              "istioctl"
              "jj"
              "jq"
              "jqp"
              "just"
              "k9s"
              "kind"
              "krew"
              "kube-ps1"
              "kubebuilder"
              "kubecolor"
              "kubectx"
              "kubernetes-cli"
              "kustomize"
              "lazydocker"
              "lazygit"
              "lefthook"
              "lima"
              "mas"
              "mise"
              "mysql"
              "nginx"
              "node"
              "node_exporter"
              "onefetch"
              "opa"
              "openblas"
              "openjdk@17"
              "opentofu"
              "operator-sdk"
              "osv-scanner"
              "pillow"
              "plantuml"
              "pngcheck"
              "pngquant"
              "podman-compose"
              "poppler"
              "procs"
              "prometheus"
              "protoc-gen-go"
              "protoc-gen-go-grpc"
              "python@3.11"
              "qemu"
              "reattach-to-user-namespace"
              "ripgrep"
              "rustup"
              "sd"
              "shellcheck"
              "slsa-verifier"
              "starship"
              "step"
              "stow"
              "syft"
              "tlrc"
              "tmux"
              "tokei"
              "tor"
              "traefik"
              "unar"
              "unzip"
              "uv"
              "vegeta"
              "vexctl"
              "wget"
              "wrk"
              "xh"
              "yamllint"
              "yazi"
              "yq"
              "zellij"
              "zig"
              "zoxide"
              "zsh-autosuggestions"
              "zsh-syntax-highlighting"
              "zstd"
              # third-party taps (tap declared above)
              "anomalyco/tap/opencode"
              "charmbracelet/tap/crush"
              "charmbracelet/tap/vhs"
              "kanywst/tap/approval-hub"
              "ory/tap/cli"
              "oven-sh/bun/bun"
            ];
            casks = [
              "claude-code"
              "codex"
              "copilot-cli"
              "font-hack-nerd-font"
              "ghostty"
              "karabiner-elements"
              "multipass"
              "ollama-app"
              "warp"
              # third-party taps
              "kanywst/tap/y509"
              "nikitabobko/tap/aerospace"
            ];
            # App Store apps (needs `mas`, declared above). ID from `mas list`.
            masApps = {
              "Keynote" = 409183694;
              "LINE" = 539883307;
            };
          };

          system.stateVersion = 6;
        })
      ];
    };
  };
}
