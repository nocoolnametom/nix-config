{
  description = "Tom Doggett's Nix-Config";

  inputs = {
    #################### Official NixOS and HM Package Sources ####################

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11"; # also see 'stable-packages' overlay at 'overlays/default.nix"
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # also see 'unstable-packages' overlay at 'overlays/default.nix"
    nixpkgs-master.url = "github:NixOS/nixpkgs/master"; # also see 'bleeding-packages' overlay at 'overlays/default.nix"
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-25.05";

    impermanence.url = "github:nix-community/impermanence";

    # Rasbpi Helping Stuff
    # Currently not used, but may be in the future
    # nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";

    # Lanzaboote Secure Bootloader for NixOS
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.3";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    # home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    # nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    arion.url = "github:hercules-ci/arion";
    arion.inputs.nixpkgs.follows = "nixpkgs";

    # Windows Subsystem for Linux (WSL)
    # Currently not used, but may be in the future
    # nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    #################### Utilities ####################

    # Styling for Visual Applications
    stylix.url = "github:nix-community/stylix/release-25.11";
    # stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # San Francisco Fonts | Apple Fonts
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    apple-fonts.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Pre-commit hooks
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    # Helium Browser
    helium.url = "github:FKouhai/helium2nix/main";
    helium.inputs.nixpkgs.follows = "nixpkgs";

    # Nixified.AI
    nixified-ai.url = "github:nixified-ai/flake";

    # Declarative Flatpak management (like homebrew on nix-darwin)
    # "latest" should be the most recent released version
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Jovian SteamOS-like helpers
    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
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
    my-sd-models.inputs.nixpkgs.follows = "nixpkgs";
    my-sd-models.inputs.nixified-ai.follows = "nixified-ai";

    # Private secrets repo
    # Authenticate via ssh and use shallow clone
    nix-secrets.url = "git+ssh://git@github.com/nocoolnametom/nix-secrets.git?ref=main&shallow=1";
    nix-secrets.inputs = { };
  };

  outputs =
    {
      self,
      nixpkgs,
      # nixos-raspberrypi,
      impermanence,
      lanzaboote,
      hardware,
      home-manager,
      nix-darwin,
      arion,
      # nixos-wsl,
      stylix,
      apple-fonts,
      sops-nix,
      helium,
      nixified-ai,
      nix-flatpak,
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
        # Beelink SER5 Mini PC
        estel = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/estel
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
        # AMD Desktop Dual Boot
        smeagol = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/smeagol
          ];
        };
        # AMD Framework Desktop Dual Boot
        barliman = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/barliman
          ];
        };
        # KAMRUI E2 Mini PC
        durin = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/durin
          ];
        };
      };

      #################### Archived NixOS Configurations ####################
      #
      # These systems are no longer in active use but are maintained for reference
      # and to ensure configuration examples remain valid. They are still validated
      # by `nix flake check`.
      #
      # To build an archived system: `nixos-rebuild build --flake .#thinkpadx1`
      #
      archivedNixosConfigurations = {
        # Thinkpad X1 Carbon Laptop (ARCHIVED)
        thinkpadx1 = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/archived/thinkpadx1
          ];
        };
        # Asus Zenbook 13 Laptop (ARCHIVED)
        melian = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/archived/melian
          ];
        };
        # Raspberry Pi 5 (ARCHIVED)
        # Commented out because the nixos-raspberrypi input is currently not used
        # Uncomment the input above and the block below before using it!
        # william = nixos-raspberrypi.lib.nixosSystem {
        #   inherit specialArgs;
        #   modules = [
        #     home-manager.nixosModules.home-manager
        #     { home-manager.extraSpecialArgs = specialArgs; }
        #     ./hosts/archived/william
        #   ];
        # };
        # Windows WSL2 NixOS (ARCHIVED)
        sauron = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/archived/sauron
          ];
        };
        # Linode 4GB VPS (ARCHIVED)
        glorfindel = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/archived/glorfindel
          ];
        };
        # Raspberry Pi 4 (ARCHIVED)
        # Did not use the nixos-raspberrypi input, so not commented out
        bert = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/archived/bert
          ];
        };
        # AWS EC2 Instance (ARCHIVED)
        fedibox = lib.nixosSystem {
          inherit specialArgs;
          modules = [
            home-manager.nixosModules.home-manager
            { home-manager.extraSpecialArgs = specialArgs; }
            ./hosts/archived/fedibox
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
