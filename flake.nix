{
  description = "Tom Doggett's Nix-Config";

  inputs = {
    #################### Official NixOS and HM Package Sources ####################

    #nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11"; # also see 'stable-packages' overlay at 'overlays/default.nix"
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # also see 'unstable-packages' overlay at 'overlays/default.nix"

    impermanence.url = "github:nix-community/impermanence";

    # Lanzaboote Secure Bootloader for NixOS
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.1";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    nix-schema.url = "github:DeterminateSystems/nix-src/flake-schemas";

    #################### Utilities ####################

    # Styling for Visual Applications
    stylix.url = "github:danth/stylix/release-24.11";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.home-manager.follows = "home-manager";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Deployment Helper
    deploy-rs.url = "github:serokell/deploy-rs";

    # Pre-commit hooks
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixified.AI
    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative Flatpak management (like homebrew on nix-darwin)
    # "latest" should be the most recent released version
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    nix-flatpak.inputs.nixpkgs.follows = "nixpkgs";

    # Cosmis Desktop Environment
    # nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    # nixos-cosmic.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Plasma Manager
    # plasma-manager.url = "github:nix-community/plasma-manager";
    # plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    # plasma-manager.inputs.home-manager.follows = "home-manager";

    # Zen Browser
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    # Hyprland
    # hyprland.url = "github:hyprwm/Hyprland";
    # split-monitor-workspaces.url = "github:Duckonaut/split-monitor-workspaces";
    # split-monitor-workspaces.inputs.hyprland.follows = "hyprland"; # <- make sure this line is present for the plugin to work as intended

    # Disposable email list
    disposable-email-domains.url = "github:disposable-email-domains/disposable-email-domains";
    disposable-email-domains.flake = false;

    # My Wordpress Themes and Plugins
    my-wordpress-plugins.url = "github:nocoolnametom/my-wordpress-plugins";
    my-wordpress-plugins.inputs.nixpkgs.follows = "nixpkgs";

    #################### Personal Repositories ####################

    # Private secrets repo
    # Authenticate via ssh and use shallow clone
    nix-secrets.url = "git+ssh://git@github.com/nocoolnametom/nix-secrets.git?ref=main&shallow=1";
    nix-secrets.inputs = { };
  };

  outputs =
    {
      self,
      nixpkgs,
      impermanence,
      lanzaboote,
      hardware,
      home-manager,
      nix-darwin,
      nixos-wsl,
      nix-schema,
      stylix,
      sops-nix,
      deploy-rs,
      nixified-ai,
      nix-flatpak,
      # nixos-cosmic,
      # plasma-manager,
      zen-browser,
      # split-monitor-workspaces,
      disposable-email-domains,
      my-wordpress-plugins,
      nix-secrets,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux" # Most other systems
        "aarch64-linux" # Raspberry Pi 4
        "aarch64-darwin" # Apple Silicon
      ];
      inherit (nixpkgs) lib;
      configVars = import ./vars { inherit inputs lib; };
      configLib = import ./lib { inherit lib; };
      configurationRevision = self.rev or self.dirtyRev or null;
      specialArgs = {
        inherit
          inputs
          outputs
          configVars
          configLib
          nixpkgs
          configurationRevision
          ;
      };
    in
    {
      # Custom modules to enable special functionality for nixos or home-manager oriented configs.
      nixosModules = import ./modules/nixos;
      darwinModules = import ./modules/darwin;
      homeModules = import ./modules/home-manager;

      # Custom modifications/overrides to upstream packages.
      overlays = import ./overlays { inherit inputs outputs; };

      # Custom packages to be shared or upstreamed.
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./pkgs { inherit inputs pkgs; }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./checks { inherit inputs system pkgs; }
      );

      # Nix formatter available through 'nix fmt' https://github.com/NixOS/nixfmt
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Shell configured with packages that are typically only needed when working on or with nix-config.
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./shell.nix { inherit pkgs; }
      );

      #################### NixOS Configurations ####################
      #
      # Building configurations available through `nixos-rebuild --flake .#hostname`
      #
      # You can dry-run any machine's config on another machine with the flake already in `/etc/nixos`
      # via `nixos-rebuild dry-build --flake .#hostname`

      nixosConfigurations = {
        # System76 Pangolin 11 AMD Laptop
        pangolin11 = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            # cosmicCacheModule
            # nixos-cosmic.nixosModules.default
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/pangolin11
          ];
        };
        # Thinkpad X1 Carbon Laptop
        thinkpadx1 = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/thinkpadx1
          ];
        };
        # Asus Zenbook 13 Laptop
        melian = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/melian
          ];
        };
        # Raspberry Pi 4
        # To build remotely, run as regular user:
        # nixos-rebuild switch --use-remote-sudo --flake .#bert -v --target-host bert --build-host localhost --use-substitutes
        bert = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/bert
          ];
        };
        # Linode 4GB VPS
        glorfindel = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/glorfindel
          ];
        };
        # Linode 4GB VPS
        bombadil = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/bombadil
          ];
        };
        # AWS EC2 Instance
        fedibox = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/fedibox
          ];
        };
        # Windows WSL2 NixOS
        sauron = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/sauron
          ];
        };
        # AMD Desktop Dual Boot
        smeagol = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            # cosmicCacheModule
            # nixos-cosmic.nixosModules.default
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/smeagol
          ];
        };
      };

      #################### Nix-Darwin Configurations ####################
      #
      # Building configurations available through `darwin-rebuild --flake ~/.config/nix-darwin#hostname`
      #
      darwinConfigurations = {
        # Apple Macbook Pro 16 2003
        "${nix-secrets.networking.work.macbookpro.name}" = nix-darwin.lib.darwinSystem {
          inherit specialArgs;
          modules = [
            home-manager.darwinModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/work/macbookpro
          ];
        };
      };

      #################### HM-Only Configurations ####################
      #
      # Building configurations available through `home-manager switch --flake ~/.config/home-manager#user@hostname`
      #
      legacyPackages = forAllSystems (system: {
        homeConfigurations = {
          # Ubuntu VM 1
          "${configVars.username}@${nix-secrets.networking.work.vm1.name}" =
            home-manager.lib.homeManagerConfiguration
              {
                pkgs = specialArgs.nixpkgs.legacyPackages.${system};
                extraSpecialArgs = specialArgs;
                modules = [
                  ./home/tdoggett/vm1.nix
                ];
              };
          # Steam Deck
          "deck@${nix-secrets.networking.subnets.steamdeck.name}" =
            home-manager.lib.homeManagerConfiguration
              {
                pkgs = specialArgs.nixpkgs.legacyPackages.${system};
                extraSpecialArgs = specialArgs;
                modules = [
                  ./home/tdoggett/steamdeck.nix
                ];
              };
        };
      });
    };
}
