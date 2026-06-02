{ configVars, ... }:
let
  userHome = "/Users/${configVars.username}";

  # Paths excluded from BOTH Time Machine backups and APFS local snapshots.
  # Limit to caches, recreatable build artifacts, and VM disk images —
  # NEVER add anything that holds user data (browser profiles, app config, etc.).
  exclusions = [
    "${userHome}/.cache"
    "${userHome}/.cargo/registry"
    "${userHome}/.colima"
    "${userHome}/.npm"
    "${userHome}/.nvm"
    "${userHome}/Library/Caches"
    "${userHome}/Library/Developer/Xcode/DerivedData"
    "${userHome}/go/pkg"
  ];
in
{
  system.activationScripts.timeMachineExclusions.text = ''
    for path in ${builtins.concatStringsSep " " (map (p: "\"${p}\"") exclusions)}; do
      if [ -e "$path" ] && ! /usr/bin/tmutil isexcluded "$path" | grep -q '\[Excluded\]'; then
        echo "tmutil: excluding $path"
        /usr/bin/tmutil addexclusion -p "$path"
      fi
    done
  '';
}
