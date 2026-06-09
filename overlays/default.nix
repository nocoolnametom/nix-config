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

    # Adding this fix against openldap to fix issues with bottles and openldap in hydra
    # See if this is still needed (https://github.com/NixOS/nixpkgs/issues/426717#issuecomment-3120592896)
    openldap = prev.openldap.overrideAttrs {
      doCheck = !prev.stdenv.hostPlatform.isi686;
    };
    direnv = prev.direnv.overrideAttrs {
      # Build is hanging on Darwin, for some reason, when I need to build this, checking zsh and never finishing
      doCheck = false;
    };

    # gamescope: jovian overrides nixpkgs' gamescope to bump version 3.16.23 → 3.16.24,
    # but inherits nixpkgs' line-anchored `shaders-path.patch` (anchored at line 34
    # of src/reshade_effect_manager.cpp). Between point releases the file shifted
    # and the hunk no longer applies. Replace the fragile patch with an equivalent
    # `substituteInPlace` that's content-anchored — survives gamescope's upstream
    # churn without needing nixpkgs (or jovian) to coordinate. Composes safely with
    # jovian's own overrideAttrs regardless of overlay order.
    #
    # Forward-compatibility: fully idempotent.
    #   - If nixpkgs updates shaders-path.patch in place (same name): our filter
    #     still strips it by suffix and our substitution does the work.
    #   - If nixpkgs renames the patch but keeps the same content fix: the
    #     renamed patch applies first, then our `grep -qF` guard sees the
    #     original string is gone and skips our substitution. Build succeeds.
    #   - If nixpkgs aligns versions and jovian stops overriding: we still
    #     filter + substitute; identical final source. Build succeeds.
    #   - If upstream gamescope changes `return "/usr";` to a different
    #     literal: our guard skips, build succeeds but shader path lookup
    #     reverts to /usr at runtime. This is the one case to watch for —
    #     loud-failing here would be wrong because the patch removal might
    #     be intentional upstream (e.g. they switched to env-var lookup).
    gamescope = prev.gamescope.overrideAttrs (old: {
      # gamescope 3.16.24 tests/meson.build pulls in catch2-with-main (Catch2 v3),
      # which nixpkgs' gamescope buildInputs don't provide. Tests aren't useful
      # for end-user builds; disable to avoid the dep. Alternative: add catch2_3
      # to buildInputs, but jovian overrides the src so we'd be adding a runtime
      # cost for the test suite no one runs.
      mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Denable_tests=false" ];

      patches = builtins.filter (
        p:
        let
          s = toString p;
        in
        # shaders-path.patch (replaced by substituteInPlace in postPatch)
        !(prev.lib.hasSuffix "shaders-path.patch" s)
        # nixpkgs backport "wlroots fix for libinput 1.31" — gamescope 3.16.24's
        # vendored wlroots already includes it; the fetchpatch URL uses a commit
        # range so we match by the trailing commit SHA.
        && !(prev.lib.hasInfix "c08d99437ec8bb56a703f04ad1ef199502c62d10" s)
      ) (old.patches or [ ]);
      # In gamescope 3.16.24 the GetUsrDir() helper was moved from
      # src/reshade_effect_manager.cpp to src/Utils/DirHelpers.cpp. The line
      # itself is unchanged (`return "/usr";`), just relocated. Substitute it
      # directly to $out; we don't need the @out@ intermediate since we own
      # this postPatch.
      #
      # nixpkgs' inherited postPatch ALSO does a `--replace-fail "@out@" "$out"`
      # on the old file path; with shaders-path.patch filtered out, that
      # marker never gets written, so the inherited substitution would fail
      # build with "pattern @out@ doesn't match anything". Rewrite that call
      # to use --replace-quiet so it tolerates the missing marker (which is
      # the correct behavior once we're doing the substitution at the source).
      postPatch = ''
        if grep -qF 'return "/usr";' src/Utils/DirHelpers.cpp; then
          substituteInPlace src/Utils/DirHelpers.cpp \
            --replace-fail 'return "/usr";' "return \"$out\";"
        fi
      ''
      +
        builtins.replaceStrings [ ''--replace-fail "@out@" "$out"'' ] [ ''--replace-quiet "@out@" "$out"'' ]
          (old.postPatch or "");
    });
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
