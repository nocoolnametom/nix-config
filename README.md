To update only a specific inputs (eg, nix-secrets and nixpkgs-unstable):

```bash
nix flake lock --update-input nix-secrets --update-input nixpkgs-unstable
```

### TODO

 * [ ] Finish moving Wordpress from elrond to glorfindel
 * [ ] Fix custom Wordpress plugins from breaking `nix flake check` - Maybe move to their own flake repo?
 * [ ] Add fedibox configuration
   * [ ] Pleroma
   * [ ] Personal resume site (it'd also be cool to have this auto-update the date as part of the git hooks)
   * [ ] Matrix? (Probably not, I don't need it)
   * [ ] Anything else
   * [ ] Figure out how to build a VM from the fedibox config for local testing of stuff
 * [ ] Fix and add steamdeck HM configuration
 * [x] ~~Remove references to diskio - I'm not planning on adjusting partitions using a tool, and it's not useful for existing systems~~
 * [ ] Investigate the impact of migrating back to Sway from Hyprland - I don't need the visual special sauce and Sway might be a bit easier on resources
 * [ ] Clean up configuration of pangolin, thinkpad, and melian to move the majority of the custom configuration into imported files
 * [ ] Rebuild the script creation for auto-downloading of work repos and define the list of work repos in their own flake repo?
 * [ ] Figure out how to have active machines pull down new configurations when commits are pushed to GitHub master
     * [ ] It may make sense to re-visit using some centralized system, like GitHub Actions, to use NixOps to build and push out new configs.  I need to figure out where and how to store the keys and state data, though.
     * [ ] Relatedly, figure out how to have active machines update flake inputs of my private repos, like nix-secrets, when I push new commits
 * [ ] Figure out how to have systems, like glorfindel, which are set to auto-update send me an email when a rebuild fails
 * [ ] See if there's any way I can rebuild my personal packages (with shasums and verson numbers) when a new stable version is released
 * [X] ~~Look into nix-mineral for security hardening~~
     * Looked into it; should probably just use the NixOS hardening guides in the wiki to apply to remotes like bombadil directly
