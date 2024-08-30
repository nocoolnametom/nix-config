{
  pkgs,
  lib,
  hyprlandPlugins,
  hyprland,
  fetchFromGitHub,
  ...
}:

hyprlandPlugins.mkHyprlandPlugin hyprland {
  pluginName = "split-monitor-workspaces";
  version = "0.38.1-5ba1e2e";

  src = fetchFromGitHub {
    owner = "Duckonaut";
    repo = "split-monitor-workspaces";
    rev = "5ba1e2e";
    hash = "sha256-zzRQxnXVrEjkF23rEuPcBB6+QZp9qh3c5aZNIAOX8Jg=";
  };

  nativeBuildInputs = with pkgs; [
    clang-tools_16
    bear
    meson
    ninja
    pkg-config
  ];

  buildInputs = with pkgs; [
    pango
    cairo
    jq
  ];

  meta = {
    homepage = "https://github.com/Duckonaut/split-monitor-workspaces/";
    description = "A small Hyprland plugin to provide awesome-like workspace behavior";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
