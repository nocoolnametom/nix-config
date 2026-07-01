#
# This file defines overlays/custom modifications to upstream packages
#

{ inputs, ... }:

let
  rapidocrOverrides = prev: self: super: {
    rapidocr-onnxruntime = super.rapidocr-onnxruntime.overridePythonAttrs (old: rec {
      disabledTests = [
        # Needs Internet access
        "test_long_img"
      ]
      ++ prev.lib.optionals prev.onnxruntime.cudaSupport [
        # segfault when built with cuda support but GPU is not availaible in build environment
        "test_ort_cuda_warning"
        "test_ort_dml_warning"
      ];
    });
  };
in
{
  # This one brings our custom packages from the 'pkgs' directory
  additions =
    final: _prev:
    import ../pkgs {
      inherit inputs;
      pkgs = final;
    };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://wiki.nixos.org/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: let ... in {
    # ...
    # });
    # I'm not using zen and dislike having to keep rebuild it
    # zen-browser-flake = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system};
    # helium-browser and orion-browser from a flake
    helium-browser-flake = inputs.helium.defaultPackage.${final.stdenv.hostPlatform.system};
    orion-browser-flake = inputs.orion.packages.${final.stdenv.hostPlatform.system}.default;
    myWpPlugins = inputs.my-wordpress-plugins.packages.${final.stdenv.hostPlatform.system};
    appleFonts = inputs.apple-fonts.packages.${final.stdenv.hostPlatform.system};
    # Fixes installation of open-webui
    # See if https://github.com/NixOS/nixpkgs/pull/382920 has been merged, if so you can remove this!
    python312 = prev.python312.override { packageOverrides = rapidocrOverrides prev; };
    python313 = prev.python313.override { packageOverrides = rapidocrOverrides prev; };
    python314 = prev.python314.override { packageOverrides = rapidocrOverrides prev; };
    python315 = prev.python315.override { packageOverrides = rapidocrOverrides prev; };

    direnv = prev.direnv.overrideAttrs {
      # Build is hanging on Darwin, for some reason, when I need to build this, checking zsh and never finishing
      doCheck = false;
    };

    # Bottles ships gamescope and mangohud in its FHS runtime chroot. On jovian
    # machines (barliman, smeagol) both resolve to jovian's overridden versions,
    # which cache.nixos.org has never seen -> forces bottles + its whole gaming
    # closure to build from source. Bottles doesn't need jovian's patches; any
    # gamescope/mangohud binary in the FHS is enough for its optional gaming
    # integrations. Pin these two inputs to plain nixpkgs (pre-jovian, pre-overlay)
    # so bottles-unwrapped's derivation hash matches cache.nixos.org's build.
    # On non-jovian machines this is a no-op (same drv hash as prev.*).
    bottles-unwrapped =
      let
        upstream = inputs.nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system};
      in
      prev.bottles-unwrapped.override {
        inherit (upstream) gamescope mangohud;
      };
  };

  # When applied, the stable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  old-packages = final: _prev: {
    old = import inputs.nixpkgs-old {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # When applied, the master nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.bleeding'
  bleeding-packages = final: _prev: {
    bleeding = import inputs.nixpkgs-master {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  my-sd-models = inputs.my-sd-models.overlay;
}
