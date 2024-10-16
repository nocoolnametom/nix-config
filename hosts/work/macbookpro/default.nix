{
  pkgs,
  inputs,
  configurationRevision ? null,
  ...
}:
{
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina
  # programs.fish.enable = true;

  # My Changes from the default template are below
  homebrew.enable = true;
  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "uninstall";
  homebrew.onActivation.upgrade = true;
  homebrew.brews = [
    { name = "openssh"; } # Need to make sure launchctl is switched first!
    { name = "tfenv"; } # No current nixpkgs
  ];
  homebrew.casks = [ ];
  homebrew.taps = [
    { name = "amar1729/formulae"; }
    { name = "homebrew/services"; }
  ];
  environment.systemPackages = [
    pkgs.silver-searcher # same as ag
    pkgs.awscli2
    pkgs.dnsmasq
    pkgs.docutils
    pkgs.kubectl # same as kubernetes-cli
    pkgs.libaom
    pkgs.libass
    pkgs.libassuan
    pkgs.mkcert
    pkgs.oath-toolkit
    pkgs.openjdk11 # Why do I need version 11? What is this for?
    # pkgs.openssh # Need to make sure launchctl is switched first!
    pkgs.tesseract
  ];

  nixpkgs.config.allowUnfree = true;

  nix.gc.automatic = true;
  nix.optimise.automatic = true;

  environment.shellAliases = {
    darwin-rebuild-switch = "darwin-rebuild switch --flake ~/.config/nix-darwin";
    darwin-rebuild-build = "darwin-rebuild build --flake ~/.config/nix-darwin";
    darwin-rebuild-check = "darwin-rebuild build --flake ~/.config/nix-darwin";
    rm = "rm -i";
    cp = "cp -i";
    ls = "ls -G";
  };

  programs.direnv.enable = true;
  programs.direnv.silent = false;
  programs.tmux.enable = true;
  programs.tmux.enableMouse = true;
  programs.tmux.enableSensible = true;
  programs.vim.enable = true;
  programs.vim.enableSensible = true;
  programs.zsh.enableSyntaxHighlighting = true;

  services.dnsmasq.enable = false; # Find out if we want this as a service or if teleport runs it manually
  services.dnsmasq.addresses =
    {
    }
    // inputs.nix-secrets.networking.workDnsmasq.addresses;

  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.dock.autohide = false;
  system.defaults.dock.orientation = "right";
  system.defaults.dock.showhidden = true;
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;
  # My Changes from the default template are above

  # Set Git commit hash for darwin-version.
  system.configurationRevision = configurationRevision;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
