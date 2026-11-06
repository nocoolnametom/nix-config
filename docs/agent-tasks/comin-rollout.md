# comin rollout: five Hermes worker tasks

Real tasks, not evals: there is no reference answer, the review is the check.
Run them in order; each one is a separate PR for me to review. Paste only the
**Prompt** block into the task (the harness adds the `Test targets:` header).
**Before** and **I'll check** are mine, not the worker's.

Shared facts for all five (true as of 2026-11-04):
- Auto-upgrade today: `hosts/common/optional/headless-server.nix` (feanor,
  bombadil). `--update-input` nixpkgs/nixpkgs-stable/nixpkgs-unstable +
  `headlessServer.extraUpdateInputs` (bombadil: my-wordpress-plugins),
  `--no-write-lock-file`, flake = `inputs.self.outPath`.
- Private inputs over `git+ssh`: nix-secrets, my-sd-models.
- The worker has no network: it cannot add or lock a new flake input, cannot
  run a GitHub Action, cannot reach any host.

---

## Task 1 - nightly lock update Action (do this first, alone)

**Before:** nothing. (The GitHub-side setup is done *after* this PR, see below.)

**Prompt:**

> Add a GitHub Actions workflow to this repo that keeps `flake.lock` current
> without me. Today feanor and bombadil update their nixpkgs inputs themselves
> every night (see `hosts/common/optional/headless-server.nix`) and never write
> the lock back, so the repo's lock falls behind what is running. I want the
> update to happen in git instead:
>
> - Nightly (and on manual dispatch), update exactly the inputs the hosts
>   auto-update today: nixpkgs, nixpkgs-stable, nixpkgs-unstable, plus every
>   host's `headlessServer.extraUpdateInputs`. Read that list from the Nix
>   config rather than hard-coding it if you reasonably can; if not, hard-code
>   it and say so.
> - Open (or update) a single PR from a fixed branch with only `flake.lock`
>   changed, and enable auto-merge on it.
> - A separate check workflow runs on that PR (and on every PR): every
>   nixosConfiguration evaluates, and bombadil's `system.build.toplevel` builds.
>   Its job name must be stable, because I will make it a required check.
> - The PR must be opened with a GitHub App token, not the default
>   `GITHUB_TOKEN`: PRs made with `GITHUB_TOKEN` don't trigger other workflows,
>   so the check would never run. Use secrets named `LOCK_BOT_APP_ID` and
>   `LOCK_BOT_PRIVATE_KEY`.
> - Evaluation needs the two private inputs, which are `git+ssh` URLs. Work out
>   how the runner can fetch them read-only, and name every secret I must
>   create. Nix's git fetcher may not honour git's `url.insteadOf`; check
>   before relying on it.
> - Pin every third-party action to a full commit SHA, with the version in a
>   comment.
>
> You cannot run any of this: no network, no GitHub. Validate the YAML
> locally (actionlint if it's in nixpkgs), and in the report list, separately,
> every setting I must make in GitHub's web UI, every secret with what it
> holds, and anything you're unsure would work on a real runner (e.g. disk
> space for bombadil's build).

**I'll check:** lock-only diff on the bot branch; SHA pins; job names; no
secret values anywhere; the private-input fetch actually works (first real
run); runner disk.

**GitHub web UI, after the PR merges (mine):**
1. Create a GitHub App "lock-bot" on my account: Contents read/write,
   Pull requests read/write; install on nix-config only. Store its ID and
   private key as Actions secrets `LOCK_BOT_APP_ID` / `LOCK_BOT_PRIVATE_KEY`.
2. Read access for the private inputs, per the worker's report (deploy keys
   on nix-secrets and my-sd-models, or one read-only identity).
3. Settings -> General: allow auto-merge.
4. Settings -> Rules -> Rulesets on `main`: require a PR, require the check
   job, block force-push and deletion. Require 1 approval, with lock-bot
   (only) allowed to bypass the approval. Later: the Hermes identity gets no
   bypass.
5. Watch a week of nightly PRs merge before task 3 touches bombadil.

---

## Task 2 - comin module + "never go backwards" guard

> **Done 2026-11-06 by Clod, not Hermes** (see PLAN.md Phase 5 update). Module:
> `hosts/common/optional/services/comin.nix`; guard:
> `modules/nixos/nixpkgs-downgrade-guard.nix` (tracks `nixpkgs` and
> `nixpkgs-unstable`, override file
> `/var/lib/nixpkgs-downgrade-guard/allow-downgrade-once`). The VM checks under
> "I'll check" have not been run yet.

**Before:** pick the test host (a VM via the VM check, or barliman). Don't
pre-add the comin input: Hermes adds it to `flake.nix`, and locking it (needs
network) is the expected first assist - log it.

**Prompt:**

> Add a common optional module `hosts/common/optional/services/comin.nix` that
> runs comin (github:nlewo/comin) so a host deploys this repo's `main` from
> GitHub by itself. You'll need to add comin as a flake input; you can't fetch
> it, so add it to `flake.nix`, write everything else against comin's module
> as documented upstream, and say in the report exactly what I need to run to
> lock it. If you can't verify an option name without the source, say which. Follow the repo's
> conventions (AGENTS.md): options with defaults, `configVars` for anything
> host-specific, persistence for comin's state on impermanence hosts. Testing
> branches stay supported but are not used yet.
>
> In the same module, add a guard with `system.preSwitchChecks`: keep, in a
> persisted file under /var/lib, the nixpkgs `lastModified` of the newest
> system ever activated on this host, and refuse any switch/test/boot to a
> system built from an older nixpkgs, unless an override file exists (name it
> and print its path in the refusal). The point: a deploy of an older lock
> must never downgrade a service whose database already migrated forward. It
> must apply however the switch is started (comin, nixos-rebuild, auto-upgrade).
>
> Enable both on the test target only. Fetching the private inputs on the host
> will need a credential: don't create one, name what's needed.

**I'll check:** the guard refuses an older system in a VM and passes a newer
one; the override works; the high-water file is persisted; first-ever switch
(no file) passes.

---

## Task 3 - auto-upgrade becomes a stale-lock fallback

**Before:** task 1 has merged a week of lock PRs on its own.

**Prompt:**

> In `hosts/common/optional/headless-server.nix`, hosts should now follow
> `main` with comin (module from the previous change) instead of updating
> their own inputs nightly. Keep `system.autoUpgrade` only as a fallback for
> when the nightly lock-update PRs stop landing: before it runs, it checks the
> nixpkgs `lastModified` of the running system, and does nothing if that is
> under N days old (option, default 3). If older, it runs exactly as today
> and an alert fires through the existing `systemd-failure-alert` mechanism so
> I learn the updater is broken. Keep `extraUpdateInputs` working, and keep the
> per-host reboot settings. Explain in a comment how this fallback interacts
> with the guard from the previous change.

**I'll check:** the fallback is a no-op on a fresh system; the alert path is
real (not just a log line); bombadil and feanor evaluate; nothing else
changed in headless-server.

---

## Task 4 - testing branches can't carry a newer lock

**Prompt:**

> Add a check to the PR workflow: on any branch named `testing-*`, fail if
> `flake.lock` differs from `main`'s. A testing branch is applied with
> `nixos-rebuild test`, which a reboot undoes, but database migrations it
> triggers are not undone, so a testing branch must change config only.

---

## Task 5 - enable comin on the remaining Linux hosts

> **Done 2026-11-06 by Clod, not Hermes.** Enabled on feanor too (so bombadil is
> the only auto-upgrade host). Credential per host: none new; root's existing
> sops GitHub key fetches the private inputs, and GitHub's host key is now in
> `programs.ssh.knownHosts`. First deploy on each host is still by hand.

**Prompt:**

> Enable the comin module on barliman, durin, estel, smeagol and pangolin11
> (not droid). bombadil and feanor already have it through headless-server.
> For each host, list anything host-specific that needed deciding (e.g. the
> laptop being offline for days). For each host, name the credential it needs
> to fetch the private inputs.

**I'll check:** every host evaluates; first deploy to each host is mine, by
hand, then comin takes over.
