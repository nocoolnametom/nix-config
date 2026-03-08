# Remote x86_64-linux builders for cross-architecture Nix evaluation on macOS.
#
# Configures a three-tier graduated fallback:
#   1. smeagol LAN  — powerful AMD desktop, speed=4  (preferred when at home)
#   2. estel LAN    — weak x86_64 mini PC, speed=2   (fallback when smeagol is down)
#   3. estel remote — same machine via bombadil proxy, speed=1  (fallback when away)
#
# Nix connects to all builders simultaneously and schedules work by speed-factor × free-slots.
# Unreachable builders are skipped after ConnectTimeout (10s).
#
# SETUP REQUIRED before this module is useful:
#
#   1. Generate a dedicated SSH key pair:
#        ssh-keygen -t ed25519 -f /tmp/nix-builder -N "" -C "nix-builder@macbookpro"
#
#   2. Add the PRIVATE key to nix-secrets at path:
#        ssh/personal/root_only/nix-builder
#
#   3. Add the PUBLIC key to this repo at:
#        hosts/common/users/tdoggett/keys/id_nixbuilder.pub
#        (it will be auto-added to authorized_keys on all NixOS hosts)
#
#   4. Rebuild smeagol and estel:
#        nixos-rebuild switch --flake .#smeagol
#        nixos-rebuild switch --flake .#estel
#
#   5. Test SSH connectivity (use /usr/bin/ssh to bypass Homebrew SSH):
#        sudo /usr/bin/ssh -i /etc/nix/nix-builder-key tdoggett@nix-builder-smeagol
#        sudo /usr/bin/ssh -i /etc/nix/nix-builder-key tdoggett@nix-builder-estel
#        sudo /usr/bin/ssh -i /etc/nix/nix-builder-key tdoggett@nix-builder-estel-ext
#
{
  configVars,
  ...
}:
let
  smeagolHost = "${configVars.networking.subnets.smeagol.name}.${configVars.homeLanDomain}";
  estelHost = "${configVars.networking.subnets.estel.name}.${configVars.homeLanDomain}";
in
{
  # Private key for nix daemon SSH authentication to remote builders
  # Key is placed at a path accessible to the nix daemon (runs as root)
  sops.secrets."nix-builder-key" = {
    key = "ssh/personal/root_only/nix-builder";
    mode = "0600";
    owner = "root";
    path = "/etc/nix/nix-builder-key";
  };

  # SSH host aliases for nix daemon.
  # NOTE: sudo ssh uses Homebrew SSH (/opt/homebrew/etc/ssh/ssh_config) which does NOT
  # read this file. Use `sudo /usr/bin/ssh` for manual testing. The nix daemon itself
  # runs via launchd with a minimal PATH pointing to /usr/bin/ssh, so it reads this fine.
  environment.etc."ssh/ssh_config.d/nix-builders.conf" = {
    text = ''
      # Primary LAN builder — smeagol (powerful, home network only)
      Host nix-builder-smeagol
        HostName ${smeagolHost}
        User ${configVars.username}
        IdentityFile /etc/nix/nix-builder-key
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /var/root/.ssh/known_hosts
        ConnectTimeout 10

      # LAN fallback — estel direct (weaker, home network only)
      Host nix-builder-estel
        HostName ${estelHost}
        User ${configVars.username}
        IdentityFile /etc/nix/nix-builder-key
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /var/root/.ssh/known_hosts
        ConnectTimeout 10

      # Remote fallback — estel via bombadil SSH proxy (available from anywhere)
      Host nix-builder-estel-ext
        HostName ssh.nocoolnametom.com
        Port ${toString configVars.networking.ports.tcp.estelSshProxy}
        User ${configVars.username}
        IdentityFile /etc/nix/nix-builder-key
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /var/root/.ssh/known_hosts
        ConnectTimeout 10
    '';
  };

  # Builder list — nix prefers highest (speed-factor × free-slots):
  #   at home:     smeagol (4×8=32) > estel-lan (2×4=8) > estel-ext (1×4=4)
  #   away:        estel-ext (1×4=4) only (smeagol and estel-lan time out)
  environment.etc."nix/machines" = {
    text = ''
      ssh-ng://nix-builder-smeagol    x86_64-linux /etc/nix/nix-builder-key 8 4 benchmark,big-parallel,kvm,nixos-test
      ssh-ng://nix-builder-estel      x86_64-linux /etc/nix/nix-builder-key 4 2 benchmark,big-parallel,kvm,nixos-test
      ssh-ng://nix-builder-estel-ext  x86_64-linux /etc/nix/nix-builder-key 4 1 benchmark,big-parallel,kvm,nixos-test
    '';
  };

  # Tell nix to use the machines file and allow builders to fetch from substituters.
  # With Determinate Nix on macOS (nix.enable = false), nix-darwin's nix.settings are
  # not written anywhere. The Determinate Installer's /etc/nix/nix.conf includes
  # `!include nix.custom.conf`, so we write there instead.
  environment.etc."nix/nix.custom.conf" = {
    text = ''
      builders = @/etc/nix/machines
      builders-use-substitutes = true
    '';
  };
}
