###############################################################################
#
#  Pangolin11 - Laptop
#  NixOS running on System76 Pangolin11 AMD Laptop
#
###############################################################################

{
  inputs,
  pkgs,
  lib,
  configLib,
  config,
  configVars,
  ...
}:
{
  imports = [
    ######################## Every Host Needs This ############################
    ./hardware-configuration.nix

    ########################## Hardware Modules ###############################
    #inputs.hardware.nixosModules.system76

    ########################### Impermanence ##################################
    ./persistence.nix

    ############################ Lanzaboote ###################################
    inputs.lanzaboote.nixosModules.lanzaboote # Must also use the config below
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/boot/hibernation.nix"
    "hosts/common/optional/boot/plymouth.nix"
    "hosts/common/optional/boot/silent.nix"
    "hosts/common/optional/homelab-ca.nix" # Install homelab CA certificate
    "hosts/common/optional/homelab-status-page.nix" # Homelab status page
    "hosts/common/optional/services/homelab-beszel-agent.nix" # Homelab Beszel monitoring agent
    # "hosts/common/optional/services/greetd.nix"
    "hosts/common/optional/services/openssh.nix" # allow remote SSH access
    "hosts/common/optional/services/pipewire.nix" # audio
    "hosts/common/optional/services/printing.nix"
    "hosts/common/optional/services/synergy.nix"
    "hosts/common/optional/services/flatpak.nix"
    "hosts/common/optional/services/work-block.nix"
    "hosts/common/optional/adb.nix" # Android Debugging
    "hosts/common/optional/blinkstick.nix"
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/cosmic.nix"
    # "hosts/common/optional/cosmic-niri.nix"
    "hosts/common/optional/gpg-agent.nix" # GPG-Agent, works with HM module for it
    "hosts/common/optional/lanzaboote.nix" # Lanzaboote Secure Bootloader
    "hosts/common/optional/light.nix" # Monitor brightness
    # "hosts/common/optional/niri.nix"
    "hosts/common/optional/nvtop.nix"
    "hosts/common/optional/scanning.nix"
    "hosts/common/optional/steam.nix"
    "hosts/common/optional/stylix.nix"
    "hosts/common/optional/thunar.nix" # Thunar File-Browser
    "hosts/common/optional/yubikey.nix"
    "hosts/common/optional/bluetooth.nix"
    "hosts/common/optional/foreign-binaries.nix"
    "hosts/common/optional/vr.nix"

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/pangolin11.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # services.gotosocial.settings.landing-page-user = "tom";

  # Mark this node as ephemeral since it's a laptop that goes offline regularly
  # This prevents warnings on the parent node (estel) when it disconnects
  # Once synergy is actually working on Comsic we can re-enable this, but until then it
  # makes sense to not have a useless service just sitting open
  services.synergy.client.enable = false;

  # Enable YubiKey auto-lock for security when laptop is left unattended
  # Screen will lock automatically when YubiKey is removed
  yubikey.autoScreenLock = true;

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "pangolin11";
    networkmanager.enable = true;
    enableIPv6 = true;
    firewall = {
      allowedTCPPortRanges = [
        {
          # KDE Connect
          from = 1714;
          to = 1764;
        }
        {
          # mDNS
          from = 5353;
          to = 5353;
        }
      ];
      allowedUDPPorts = [
        51820 # Wireguard
      ];
      allowedUDPPortRanges = [
        {
          # KDE Connect
          from = 1714;
          to = 1764;
        }
      ];
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    appleFonts.sf-pro-nerd
    appleFonts.sf-mono-nerd
  ];

  environment.systemPackages = [
    pkgs.gparted
    pkgs.split-my-cbz
    pkgs.update-cbz-tags
  ];

  # Enable Powertop
  powerManagement.enable = true;
  powerManagement.powertop.enable = true; # Should work fine with system76-power

  # Optional, hint electron apps to use wayland:
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Gnome keyring daemon is enabled via Home Manager for VSCode/app credential storage
  # NixOS PAM integration disabled - it conflicts with COSMIC login timing and causes
  # "gkr-pam: unable to locate daemon control file" errors during boot
  # services.gnome.gnome-keyring.enable = false; # Already false by default
  programs.dconf.enable = true;

  # Homelab Beszel monitoring - filesystems and GPU auto-detected
  # services.homelab-beszel-agent = { };

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
