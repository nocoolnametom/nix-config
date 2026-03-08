# Remote x86_64-linux builders for cross-architecture Nix evaluation on macOS.
#
# Configures a graduated fallback:
#   1. smeagol (powerful AMD desktop, LAN-only, speed-factor=4)
#   2. estel (weak x86_64 mini PC, remote via bombadil SSH proxy, speed-factor=1)
#
# Nix picks the builder with the highest available (speed-factor × free-slots).
# When smeagol is unreachable (10s timeout), nix falls back to estel automatically.
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
#   5. Test SSH connectivity as root:
#        sudo ssh -i /etc/nix/nix-builder-key tdoggett@<smeagol-ip>
#        sudo ssh -i /etc/nix/nix-builder-key -p <estelSshProxy> tdoggett@ssh.nocoolnametom.com
#
{
  configVars,
  ...
}:
{
  # Private key for nix daemon SSH authentication to remote builders
  # Key is placed at a path accessible to the nix daemon (runs as root)
  sops.secrets."nix-builder-key" = {
    key = "ssh/personal/root_only/nix-builder";
    mode = "0600";
    owner = "root";
    path = "/etc/nix/nix-builder-key";
  };

  # SSH host aliases for nix daemon — macOS reads /etc/ssh/ssh_config.d/*.conf
  environment.etc."ssh/ssh_config.d/nix-builders.conf" = {
    text = ''
      # LAN builder — preferred when on the home network
      Host nix-builder-smeagol
        HostName ${configVars.networking.subnets.smeagol.ip}
        User ${configVars.username}
        IdentityFile /etc/nix/nix-builder-key
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /var/root/.ssh/known_hosts
        ConnectTimeout 10

      # Remote builder — reachable externally via bombadil's SSH proxy to estel
      Host nix-builder-estel
        HostName ssh.nocoolnametom.com
        Port ${toString configVars.networking.ports.tcp.estelSshProxy}
        User ${configVars.username}
        IdentityFile /etc/nix/nix-builder-key
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /var/root/.ssh/known_hosts
        ConnectTimeout 10
    '';
  };

  # Builder list — nix prefers highest (speed-factor × free-slots)
  # smeagol: 8 jobs × speed 4 = 32; estel: 4 jobs × speed 1 = 4
  environment.etc."nix/machines" = {
    text = ''
      ssh-ng://nix-builder-smeagol x86_64-linux /etc/nix/nix-builder-key 8 4 benchmark,big-parallel,kvm,nixos-test
      ssh-ng://nix-builder-estel x86_64-linux /etc/nix/nix-builder-key 4 1 benchmark,big-parallel,kvm,nixos-test
    '';
  };

  # Tell nix to use the machines file and allow builders to fetch from substituters
  nix.settings = {
    builders = "@/etc/nix/machines";
    builders-use-substitutes = true;
  };
}
