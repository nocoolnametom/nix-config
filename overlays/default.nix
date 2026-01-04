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
    # helium-browser from a flake
    helium-browser-flake = inputs.helium.defaultPackage.${final.stdenv.hostPlatform.system};
    myWpPlugins = inputs.my-wordpress-plugins.packages.${final.stdenv.hostPlatform.system};
    appleFonts = inputs.apple-fonts.packages.${final.stdenv.hostPlatform.system};
    # Fixes installation of open-webui
    # See if https://github.com/NixOS/nixpkgs/pull/382920 has been merged, if so you can remove this!
    python312 = prev.python312.override { packageOverrides = rapidocrOverrides prev; };
    python313 = prev.python313.override { packageOverrides = rapidocrOverrides prev; };
    python314 = prev.python314.override { packageOverrides = rapidocrOverrides prev; };
    python315 = prev.python315.override { packageOverrides = rapidocrOverrides prev; };
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
