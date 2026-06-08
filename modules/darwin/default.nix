# Add your reusable Nix-Darwin modules to this directory, on their own file.
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;
  notification-watcher = import ./notification-watcher.nix;
  repo-path = import ./repo-path.nix;
  yubikey = import ./yubikey.nix;
  yknotify = import ./yknotify.nix;
}
