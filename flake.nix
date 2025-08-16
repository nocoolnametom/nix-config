{
  description = "Tom Doggett's Nix-Config";

  inputs = {
    #################### Official NixOS and HM Package Sources ####################

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05"; # also see 'stable-packages' overlay at 'overlays/default.nix"
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # also see 'unstable-packages' overlay at 'overlays/default.nix"
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-24.11";

    impermanence.url = "github:nix-community/impermanence";

    # Rasbpi Helping Stuff
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";

    # Lanzaboote Secure Bootloader for NixOS
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.2";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    #################### Utilities ####################

    # Styling for Visual Applications
    stylix.url = "github:danth/stylix/release-25.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Pre-commit hooks
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixified.AI
    # nixified-ai.url = "github:nixified-ai/flake";
    # Using this upstream MR branch until it get merged to get a newer version of Comfy
    # BatteredBunny's branch is for ComfyUI v0.3.30
    nixified-ai.url = "github:BatteredBunny/nixifed-ai/bump-comfyui";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-old";

    # Declarative Flatpak management (like homebrew on nix-darwin)
    # "latest" should be the most recent released version
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Cosmis Desktop Environment
    # nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    # nixos-cosmic.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Plasma Manager
    # plasma-manager.url = "github:nix-community/plasma-manager";
    # plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    # plasma-manager.inputs.home-manager.follows = "home-manager";

    # Jovian SteamOS-like helpers
    jovian.url = "github:Jovian-Experiments/Jovian-NixOS/f81c48f403c976463fe5812e9e6bca8cf49aebdc";
    jovian.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Disposable email list
    disposable-email-domains.url = "github:disposable-email-domains/disposable-email-domains";
    disposable-email-domains.flake = false;

    #################### Personal Repositories ####################
    # My Wordpress Themes and Plugins
    my-wordpress-plugins.url = "github:nocoolnametom/my-wordpress-plugins";
    my-wordpress-plugins.inputs.nixpkgs.follows = "nixpkgs";

    # My SD models for various machines
    # Authenticate via ssh and use shallow clone (in case I ever put a model in here)
    # my-sd-models.url = "path:/home/tdoggett/Projects/nocoolnametom/my-sd-models"; # For testing
    my-sd-models.url = "git+ssh://git@github.com/nocoolnametom/my-sd-models.git?ref=main&shallow=1";
    my-sd-models.inputs.nixpkgs.follows = "nixpkgs-old";
    my-sd-models.inputs.nixified-ai.follows = "nixified-ai";

    # Private secrets repo
    # Authenticate via ssh and use shallow clone
    nix-secrets.url = "git+ssh://git@github.com/nocoolnametom/nix-secrets.git?ref=main&shallow=1";
    nix-secrets.inputs = { };
  };

  nixConfig.extra-substituters = [
    "https://nixos-raspberrypi.cachix.org"
  ];
  nixConfig.extra-trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];

  outputs =
    {
      self,
      nixpkgs,
      nixos-raspberrypi,
      impermanence,
      lanzaboote,
      hardware,
      home-manager,
      nix-darwin,
      nixos-wsl,
      stylix,
      sops-nix,
      nixified-ai,
      nix-flatpak,
      # nixos-cosmic,
      # plasma-manager,
      # hyprland,
      jovian,
      disposable-email-domains,
      my-wordpress-plugins,
      my-sd-models,
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
          nixos-raspberrypi
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
        # Raspberry Pi 5
        # To build remotely, run as regular user:
        # nixos-rebuild switch --use-remote-sudo --flake .#william -v --target-host william --build-host localhost --use-substitutes
        william = nixos-raspberrypi.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/william
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
