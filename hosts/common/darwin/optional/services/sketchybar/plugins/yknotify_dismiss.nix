{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Click handler for the yknotify panic button. Removes any live yknotify
# banner from Notification Center and restarts the launchd agent so a stuck
# or spurious yknotify process is killed cleanly without needing a YubiKey
# touch. Uses full Nix store paths so it runs correctly from sketchybar's
# restricted environment.
writeShellScript "sketchybar_yknotify_dismiss" ''
  ${pkgs.terminal-notifier}/bin/terminal-notifier -remove "yknotify"
  /bin/launchctl stop com.user.yknotify
  /bin/launchctl start com.user.yknotify
''
