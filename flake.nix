{
  description = "macOS system and home environment configuration";

  inputs = {
    # 最新のパッケージを利用するためunstableブランチを指定
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }: 
  let
    # Apple Siliconの場合は aarch64-darwin、Intelの場合は x86_64-darwin
    system = "aarch64-darwin";
    username = "user"; # ★ここをご自身のMacのユーザー名に変更★
  in {
    darwinConfigurations."macbook" = nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        # --- OS (nix-darwin) の設定 ---
        ({ pkgs, ... }: {
          services.nix-daemon.enable = true;
          nix.settings.experimental-features = "nix-command flakes";

          # システムレベルのパッケージ
          environment.systemPackages = with pkgs; [ vim git ];

          # macOSのシステム設定
          system.defaults = {
            dock.autohide = true;
            NSGlobalDomain.KeyRepeat = 2;
            NSGlobalDomain.InitialKeyRepeat = 15;
          };

          # Homebrewとの連携 (GUIアプリ用)
          homebrew = {
            enable = true;
            casks = [
              "jetbrains-fleet"
              "google-chrome"
            ];
          };

          # 後方互換性のための記述
          system.stateVersion = 4;
        })

        # --- ユーザー (home-manager) の設定 ---
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${username} = { pkgs, ... }: {
            
            # ホームディレクトリ配下にインストールするツール群
            home.packages = with pkgs; [
              go
              rustup
              kubernetes-cli
              k9s
              gh
              jq
            ];

            # Gitの設定
            programs.git = {
              enable = true;
              userName = "kanywst";
              userEmail = "your.email@example.com"; # ★ここを変更★
            };

            # Zshの設定
            programs.zsh = {
              enable = true;
              enableCompletion = true;
              syntaxHighlighting.enable = true;
            };

            # 後方互換性のための記述
            home.stateVersion = "23.11";
          };
        }
      ];
    };
  };
}
