{
  description = "kanywst macOS — nix-darwin glue (macOS defaults + declarative Homebrew). Shell/zsh stays stow-managed.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nix-darwin, nixpkgs }:
  let
    system = "aarch64-darwin";
    username = builtins.getEnv "USER";
  in {
    darwinConfigurations.${username} = nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        ({ pkgs, ... }: {
          # Nix daemon + flakes
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.config.allowUnfree = true;

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
          # on every `darwin-rebuild switch`. `cleanup = "zap"` removes anything
          # not listed — keep that off ("none") until your brew list is fully
          # mirrored here, otherwise it will uninstall packages.
          homebrew = {
            enable = true;
            onActivation = {
              autoUpdate = false;
              upgrade = false;
              cleanup = "none";
            };
            # External taps. bun lives in oven-sh/bun rather than homebrew/core.
            taps = [
              "oven-sh/bun"
            ];
            brews = [
              "aichat"
              "ast-grep"
              "atuin"
              "bat"
              "btop"
              "bun"
              "carapace"
              "direnv"
              "dust"
              "eza"
              "fd"
              "fzf"
              "fzf-tab"
              "gh"
              "ghq"
              "git-delta"
              "gitleaks"
              "glow"
              "go"
              "hyperfine"
              "jq"
              "k9s"
              "kubecolor"
              "kubectx"
              "kubernetes-cli"
              "lazydocker"
              "lazygit"
              "lefthook"
              "mas"
              "mise"
              "onefetch"
              "procs"
              "ripgrep"
              "sd"
              "starship"
              "stow"
              "tlrc"
              "tokei"
              "uv"
              "xh"
              "yazi"
              "yq"
              "zellij"
              "zoxide"
              "zsh-autosuggestions"
              "zsh-syntax-highlighting"
              "zstd"
            ];
            casks = [
              "claude-code"
              "font-hack-nerd-font"
              "ghostty"
            ];
          };

          system.stateVersion = 6;
        })
      ];
    };
  };
}
