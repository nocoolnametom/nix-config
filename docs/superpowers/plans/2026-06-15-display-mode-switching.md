# Display-mode-aware aerospace + sketchybar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a laptop-friendly aerospace binding set (`ctrl-alt-*`) alongside the existing Meh/Hyper bindings, and make sketchybar adapt automatically when the macbookpro's built-in display is attached (taller bar to clear the notch, mode indicator routed off-center, compact widgets, tighter padding).

**Architecture:** A small Swift utility (`display-info`) prints `NSScreen.safeAreaInsets.top` and the built-in display index. A new sketchybar `display_router` plugin script consumes this output on startup and on `display_change` events. It sets bar height, item `display=` properties for the mode indicator, item padding, and writes a flag file that compact-mode widget scripts read on each render. Aerospace bindings are pure additions to the existing shared darwin module — both binding sets coexist.

**Tech Stack:** Nix-Darwin, sketchybar (built-in `display_change` event, per-item `display=` property), AeroSpace (binding modes), Swift (`AppKit.NSScreen`, `safeAreaInsets`).

**Source spec:** `docs/superpowers/specs/2026-06-15-display-mode-switching-design.md`

**VCS note:** This repo uses jj (Jujutsu). `git status` always shows `## HEAD (no branch)` — that's normal. Commits below use `jj commit -m`.

**Darwin config name:** The flake names the macbookpro's darwin config by the work hostname from nix-secrets — not literally `macbookpro`. Discover the actual name with `nix flake show --json | jq -r '.darwinConfigurations | keys[]'` and substitute it for `<HOSTNAME>` in the commands below. (As of writing, that name is `ZG15993` but it could change.)

---

## Task 1: `display-info` Swift utility package

**Files:**
- Create: `pkgs/display-info/default.nix`
- Create: `pkgs/display-info/display-info.swift`
- Modify: `pkgs/default.nix`

- [ ] **Step 1: Write the Swift source.**

Create `pkgs/display-info/display-info.swift`:

```swift
import Cocoa
import Foundation

let screens = NSScreen.screens

let maxInset = screens.map { Int(ceil($0.safeAreaInsets.top)) }.max() ?? 0

// Built-in heuristic: any screen reporting a non-zero top safe area is the
// built-in (only notched MBP built-ins do this). Fallback to localizedName
// match for older notchless built-ins.
let builtinIndex: Int? = screens.enumerated().first { (_, screen) in
    screen.safeAreaInsets.top > 0
        || screen.localizedName.localizedCaseInsensitiveContains("built-in")
}.map { $0.offset + 1 }

let externals = screens.enumerated()
    .filter { (i, _) in (i + 1) != (builtinIndex ?? -1) }
    .map { String($0.offset + 1) }
    .joined(separator: ",")

print("NOTCH_INSET=\(maxInset)")
print("BUILTIN_DISPLAY=\(builtinIndex.map(String.init) ?? "")")
print("EXTERNAL_DISPLAYS=\(externals)")
```

- [ ] **Step 2: Write the package derivation.**

Create `pkgs/display-info/default.nix`:

```nix
{
  lib,
  stdenv,
  swift,
}:
stdenv.mkDerivation {
  pname = "display-info";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc -O display-info.swift -o display-info
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp display-info $out/bin/
    runHook postInstall
  '';

  meta = {
    description = "Print macOS display info — max safe-area-inset top and the built-in display index — as shell-sourceable KEY=value lines.";
    platforms = lib.platforms.darwin;
    mainProgram = "display-info";
  };
}
```

- [ ] **Step 3: Register the package in `pkgs/default.nix`.**

In `pkgs/default.nix`, add a new line under the existing `callPackage` block, keeping alphabetical order where reasonable:

```nix
  display-info = pkgs.callPackage ./display-info { };
```

The complete diff to add (between `disk` … and the closing `}`):

```nix
  display-info = pkgs.callPackage ./display-info { };
```

(Place it before the `journalofdiscourses` line; it's fine if order differs slightly.)

- [ ] **Step 4: Tell the flake about the new file.**

The new `.nix` files must be tracked by git before flake eval can see them. See `~/.claude/projects/-Users-tdoggett-Projects-nocoolnametom-nix-config/memory/nix-flake-git-tracking.md`.

```bash
git add pkgs/display-info/default.nix pkgs/display-info/display-info.swift
```

(No commit yet — just staging so flake eval sees the file.)

- [ ] **Step 5: Build the package in isolation.**

```bash
nix build .#display-info --print-build-logs
```

Expected: build succeeds; `result/bin/display-info` exists.

If the build fails with "Cocoa framework not found" or similar SDK linking error, fall back to adding `pkgs.apple-sdk` (or `pkgs.darwin.apple_sdk.frameworks.Cocoa` on older nixpkgs) as a `buildInputs` entry in `pkgs/display-info/default.nix`. Try in this order:

  - `buildInputs = [ pkgs.apple-sdk ];` (most recent nixpkgs)
  - `buildInputs = [ pkgs.apple-sdk_15 ];` (next-most recent)
  - `buildInputs = [ pkgs.darwin.apple_sdk.frameworks.Cocoa ];` (older nixpkgs)

Rebuild after each attempt. Stop when one works.

- [ ] **Step 6: Smoke-test the built binary.**

```bash
./result/bin/display-info
```

Expected output: three `KEY=value` lines. Example on a notched MBP without externals:

```
NOTCH_INSET=32
BUILTIN_DISPLAY=1
EXTERNAL_DISPLAYS=
```

Verify by inspection that the values match your current display state.

- [ ] **Step 7: Commit.**

```bash
jj commit -m "pkgs: add display-info utility for safeAreaInsets + built-in display index"
```

---

## Task 2: Sketchybar bar height via `display_router`

**Files:**
- Create: `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/plugins/default.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/default.nix`

**Outcome:** Sketchybar bar height changes from 30 to 32 (or vice versa) within a few seconds of attaching/detaching displays. No other sketchybar behavior changes yet.

- [ ] **Step 1: Write the display_router plugin.**

Create `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`:

```nix
{
  pkgs,
  config,
  sketchybar ? pkgs.sketchybar,
  # Baseline bar height when no notched display is attached.
  baselineHeight ? 30,
  ...
}:
let
  displayInfo = "${pkgs.display-info}/bin/display-info";
  sketchybarBin = "${sketchybar}/bin/sketchybar";
in
pkgs.writeShellScript "sketchybar_display_router" ''
  # Runs once at sketchybar startup and on every `display_change` event.
  # Computes the bar height from display-info's reported notch inset and
  # writes the built-in display index to a flag file consumed by
  # compact-mode widget scripts.

  set -u

  # Read display info into shell variables.
  eval "$(${displayInfo})"

  # Bar height: max(NOTCH_INSET, baselineHeight).
  baseline=${toString baselineHeight}
  if [ "''${NOTCH_INSET:-0}" -gt "$baseline" ]; then
    height="$NOTCH_INSET"
  else
    height="$baseline"
  fi

  ${sketchybarBin} --bar height="$height"

  # Flag file for compact-mode widget scripts. Empty when no built-in.
  flag_file="/tmp/sketchybar-builtin-display"
  printf '%s' "''${BUILTIN_DISPLAY:-}" > "$flag_file"
''
```

- [ ] **Step 2: Wire it into the plugins import.**

In `hosts/common/darwin/optional/services/sketchybar/plugins/default.nix`, add to the `rec { ... }` block (alphabetical placement is fine, near `disk`):

```nix
  display_router = import ./display_router.nix { inherit pkgs config sketchybar; };
```

- [ ] **Step 3: Modify the sketchybar config to use the router for startup height and subscribe to display_change.**

In `hosts/common/darwin/optional/services/sketchybar/default.nix`:

(a) Replace the existing `config = let ... in {` block opening with a single baseline constant (drop the unused `macbookMonitorHeight`):

```nix
  config = let
    baselineHeight = 30;
  in {
```

(b) Add `display-info` to `extraPackages`:

```nix
    services.sketchybar.extraPackages = lib.mkDefault [
      config.services.aerospace.package
      pkgs.jq
      pkgs.display-info
    ];
```

(c) Replace the line that currently reads:

```bash
sketchybar --bar position=top height=${toString nonMacbookMonitorHeight} blur_radius=30 color=0x40000000
```

with a startup-height computation followed by the bar declaration, and add the hidden `display_handler` item subscribed to `display_change`. Replace that single line with:

```bash
      # Compute initial bar height from display-info. The display_router
      # script also runs on every display_change event (see below).
      initial_inset=$(${pkgs.display-info}/bin/display-info | /usr/bin/sed -n 's/^NOTCH_INSET=//p')
      if [ "$initial_inset" -gt ${toString baselineHeight} ]; then
        initial_height=$initial_inset
      else
        initial_height=${toString baselineHeight}
      fi

      sketchybar --bar position=top height=$initial_height blur_radius=30 color=0x40000000
```

(d) Immediately after the `sketchybar --default "${"$"}{default[@]}"` line (which ends the `default=` block setup), add the `display_handler` item registration. It must come before any item that depends on the flag file, so adding it right after `--default` is safest. Add this block:

```bash
      ##### Display Router #####
      # Hidden item that responds to display_change events. Sets bar
      # height, updates per-display item routing, and writes the
      # built-in-display flag file. Also runs once at startup via the
      # --update call at the end of this config.
      sketchybar --add item display_handler left \
                --set display_handler \
                  drawing=off \
                  updates=on \
                  script="${plugins.display_router}" \
                --subscribe display_handler display_change
```

- [ ] **Step 4: Stage new files for flake eval visibility.**

```bash
git add hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix
```

- [ ] **Step 5: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

Expected: build succeeds; sketchybar restarts.

- [ ] **Step 6: Verify bar height is correct for the current display state.**

If the laptop is currently in laptop-only mode (lid open, no externals):
- Bar height should be ~32 (matching the notch). Use macOS Screenshot (`Cmd-Shift-5`) and measure if visually unclear, or just inspect.

If currently in clamshell + externals:
- Bar height should be 30.

Then physically change display state (close lid, plug/unplug an external, etc.) and confirm the bar height changes within a few seconds.

If verification fails: check `tail -f /tmp/sketchybar-builtin-display` after a display change to see if the router is running. Run `display-info` directly to verify it reports the expected values.

- [ ] **Step 7: Commit.**

```bash
jj commit -m "hosts: dynamic sketchybar bar height via display_router + display-info"
```

---

## Task 3: ctrl-alt-* main mode aerospace bindings

**Files:**
- Modify: `hosts/common/darwin/optional/services/aerospace/default.nix`

**Outcome:** All workspace navigation, focus, and mode-entry actions work via `ctrl-alt-*` on the built-in keyboard, alongside the existing Meh/Hyper bindings.

- [ ] **Step 1: Add ctrl-alt-* bindings to main mode.**

In `hosts/common/darwin/optional/services/aerospace/default.nix`, find the end of the existing `mode.main.binding` entries (just before the `# See: https://nikitabobko.github.io/AeroSpace/commands#mode` comment around line 290). Add this block of bindings immediately before that comment. They all use `lib.mkDefault`:

```nix
  # ────────────────────────────────────────────────────────────────────
  # Laptop-friendly bindings — coexist with meh/hyper. ctrl-alt is
  # reachable on the MBP built-in keyboard whereas meh (alt-ctrl-shift)
  # and hyper (alt-ctrl-shift-cmd) are not.
  # ────────────────────────────────────────────────────────────────────

  # Focus
  services.aerospace.settings.mode.main.binding."ctrl-alt-h" = lib.mkDefault "focus left";
  services.aerospace.settings.mode.main.binding."ctrl-alt-j" = lib.mkDefault "focus down";
  services.aerospace.settings.mode.main.binding."ctrl-alt-k" = lib.mkDefault "focus up";
  services.aerospace.settings.mode.main.binding."ctrl-alt-l" = lib.mkDefault "focus right";

  # Workspace nav
  services.aerospace.settings.mode.main.binding."ctrl-alt-1" = lib.mkDefault "workspace 1";
  services.aerospace.settings.mode.main.binding."ctrl-alt-2" = lib.mkDefault "workspace 2";
  services.aerospace.settings.mode.main.binding."ctrl-alt-3" = lib.mkDefault "workspace 3";
  services.aerospace.settings.mode.main.binding."ctrl-alt-4" = lib.mkDefault "workspace 4";
  services.aerospace.settings.mode.main.binding."ctrl-alt-5" = lib.mkDefault "workspace 5";
  services.aerospace.settings.mode.main.binding."ctrl-alt-6" = lib.mkDefault "workspace 6";
  services.aerospace.settings.mode.main.binding."ctrl-alt-7" = lib.mkDefault "workspace 7";
  services.aerospace.settings.mode.main.binding."ctrl-alt-8" = lib.mkDefault "workspace 8";
  services.aerospace.settings.mode.main.binding."ctrl-alt-9" = lib.mkDefault "workspace 9";
  services.aerospace.settings.mode.main.binding."ctrl-alt-0" = lib.mkDefault "workspace A";

  services.aerospace.settings.mode.main.binding."ctrl-alt-left" = lib.mkDefault "workspace prev";
  services.aerospace.settings.mode.main.binding."ctrl-alt-right" = lib.mkDefault "workspace next";
  services.aerospace.settings.mode.main.binding."ctrl-alt-up" = lib.mkDefault "focus-monitor prev";
  services.aerospace.settings.mode.main.binding."ctrl-alt-down" = lib.mkDefault "focus-monitor next";

  services.aerospace.settings.mode.main.binding."ctrl-alt-tab" = lib.mkDefault "workspace-back-and-forth";

  # Fullscreen
  services.aerospace.settings.mode.main.binding."ctrl-alt-f" = lib.mkDefault "fullscreen";

  # Mode entry — `toMode` triggers the sketchybar mode indicator update.
  services.aerospace.settings.mode.main.binding."ctrl-alt-a" = lib.mkDefault (toMode "alter");
  services.aerospace.settings.mode.main.binding."ctrl-alt-semicolon" = lib.mkDefault (
    toMode "service"
  );
```

- [ ] **Step 2: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 3: Verify the new bindings.**

Test (on the built-in keyboard if available):
- `ctrl-alt-1` through `ctrl-alt-9` and `ctrl-alt-0` — switches to workspaces 1-9 and A.
- `ctrl-alt-h/j/k/l` — moves focus directionally.
- `ctrl-alt-tab` — toggles to previous workspace.
- `ctrl-alt-f` — fullscreens the focused window (press again to exit).
- `ctrl-alt-a` — enters `alter` mode (sketchybar shows amber `ALTER` label); `esc` exits.
- `ctrl-alt-semicolon` — enters `service` mode (sketchybar shows blue label); `esc` exits.

Also confirm existing Meh/Hyper bindings still work unchanged (`meh-1`, `hyper-h`, etc., from the Ergodox).

- [ ] **Step 4: Commit.**

```bash
jj commit -m "hosts: add ctrl-alt-* main-mode aerospace bindings for laptop keyboard"
```

---

## Task 4: alter mode additions (bare digits + arrows)

**Files:**
- Modify: `hosts/common/darwin/optional/services/aerospace/default.nix`

**Outcome:** Inside `alter` mode, bare digit keys move the focused window to the corresponding workspace; bare arrow keys move it directionally.

- [ ] **Step 1: Add bare-digit move-to-workspace bindings.**

Find the existing `alter` mode block (search for `mode.alter.binding.r = lib.mkDefault`). Immediately before the `# Resize the focused window` comment block, add:

```nix
  # ────────────────────────────────────────────────────────────────────
  # Move-to-workspace (laptop-friendly equivalent of main-mode hyper-N).
  # Bare digits to chain quickly: enter alter, press a digit, done.
  # ────────────────────────────────────────────────────────────────────
  services.aerospace.settings.mode.alter.binding."1" = lib.mkDefault "move-node-to-workspace 1 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."2" = lib.mkDefault "move-node-to-workspace 2 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."3" = lib.mkDefault "move-node-to-workspace 3 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."4" = lib.mkDefault "move-node-to-workspace 4 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."5" = lib.mkDefault "move-node-to-workspace 5 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."6" = lib.mkDefault "move-node-to-workspace 6 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."7" = lib.mkDefault "move-node-to-workspace 7 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."8" = lib.mkDefault "move-node-to-workspace 8 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."9" = lib.mkDefault "move-node-to-workspace 9 --focus-follows-window";
  services.aerospace.settings.mode.alter.binding."0" = lib.mkDefault "move-node-to-workspace A --focus-follows-window";

  # Move within workspace — bare arrow keys (matches the bare-key chain
  # pattern of the existing resize bindings on minus/equal).
  services.aerospace.settings.mode.alter.binding.left = lib.mkDefault "move left";
  services.aerospace.settings.mode.alter.binding.down = lib.mkDefault "move down";
  services.aerospace.settings.mode.alter.binding.up = lib.mkDefault "move up";
  services.aerospace.settings.mode.alter.binding.right = lib.mkDefault "move right";
```

- [ ] **Step 2: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 3: Verify the new bindings.**

- Open a couple windows on workspace 1.
- Press `ctrl-alt-a` to enter alter mode (sketchybar should show amber `ALTER`).
- Press `2` — focused window moves to workspace 2 and focus follows.
- Press `esc` to exit alter mode.
- Re-enter alter, press `left`/`right`/`up`/`down` arrows — the focused window moves directionally within its workspace.
- Existing alter bindings still work: `h/j/k/l` join-with, `r` flatten, `f` toggle floating, `-`/`=` resize, `esc` exit.

- [ ] **Step 4: Commit.**

```bash
jj commit -m "hosts: add alter-mode bare digit + arrow bindings for laptop window manipulation"
```

---

## Task 5: Mode indicator per-display routing

**Files:**
- Modify: `hosts/common/darwin/optional/services/sketchybar/default.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`

**Outcome:** When the built-in is attached, the center `aerospace_mode` indicator is hidden on it (the notch swallows it) and a new left-positioned `aerospace_mode_compact` item appears on the built-in only. When the built-in is detached, the center indicator behaves as today.

- [ ] **Step 1: Add the second mode-indicator item to the sketchybar config.**

In `hosts/common/darwin/optional/services/sketchybar/default.nix`, find the existing `front_app` `--add item` block (around the `##### Adding Left Items #####` comment). Immediately AFTER the `--subscribe front_app front_app_switched` line, add the new compact mode item:

```bash
      ##### Aerospace Mode Indicator (left, built-in only) #####
      # Sister item to the center `aerospace_mode`. Same script, same
      # subscriptions — but positioned on the left so it doesn't collide
      # with the notch. display_router toggles which of the two is
      # visible per attached display.
      sketchybar --add item aerospace_mode_compact left \
                --set aerospace_mode_compact \
                  drawing=off \
                  background.corner_radius=5 \
                  background.height=23 \
                  background.padding_left=2 \
                  background.padding_right=2 \
                  label.font="SFProDisplay Nerd Font:Heavy:12.0" \
                  label.padding_left=10 \
                  label.padding_right=10 \
                  script="${plugins.aerospace_mode}" \
                --subscribe aerospace_mode_compact aerospace_mode_change
```

- [ ] **Step 2: Update display_router to route the two mode indicators.**

Edit `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`. Replace the existing body (from `set -u` to the end of the heredoc) with:

```nix
pkgs.writeShellScript "sketchybar_display_router" ''
  # Runs once at sketchybar startup and on every `display_change` event.
  # Computes the bar height from display-info's reported notch inset,
  # writes the built-in display index to a flag file consumed by
  # compact-mode widget scripts, and routes the aerospace mode indicator
  # items to the correct displays.

  set -u

  eval "$(${displayInfo})"

  baseline=${toString baselineHeight}
  if [ "''${NOTCH_INSET:-0}" -gt "$baseline" ]; then
    height="$NOTCH_INSET"
  else
    height="$baseline"
  fi

  ${sketchybarBin} --bar height="$height"

  flag_file="/tmp/sketchybar-builtin-display"
  printf '%s' "''${BUILTIN_DISPLAY:-}" > "$flag_file"

  # Mode-indicator routing.
  # When the built-in is attached, the center indicator must skip the
  # built-in (the notch hides it). The compact indicator shows only on
  # the built-in.
  if [ -n "''${BUILTIN_DISPLAY:-}" ]; then
    if [ -n "''${EXTERNAL_DISPLAYS:-}" ]; then
      ${sketchybarBin} --set aerospace_mode display="$EXTERNAL_DISPLAYS"
    else
      # Built-in is the only display — hide center indicator entirely.
      ${sketchybarBin} --set aerospace_mode drawing=off
    fi
    ${sketchybarBin} --set aerospace_mode_compact \
        display="$BUILTIN_DISPLAY" \
        drawing=on
  else
    # No built-in attached — restore default center behavior.
    ${sketchybarBin} --set aerospace_mode \
        display=active \
        drawing=on
    ${sketchybarBin} --set aerospace_mode_compact drawing=off
  fi
''
```

Note: the `display=active` reset uses sketchybar's `active` keyword, which restores the default behavior of rendering on whichever display is active. If your existing config relies on a different default, replace `display=active` with the appropriate value.

- [ ] **Step 3: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 4: Verify mode-indicator routing.**

Press `ctrl-alt-a` (or `hyper-a`) to enter alter mode. Observe:

- **Built-in only**: amber `ALTER` label appears on the LEFT side of the bar (after front_app). No center label.
- **Externals only (clamshell)**: amber `ALTER` label appears in the CENTER of the bar. No left label.
- **Built-in + externals**: amber `ALTER` label appears in the CENTER on each external AND on the LEFT on the built-in.

Press `esc` to exit alter mode — the label hides.

- [ ] **Step 5: Commit.**

```bash
jj commit -m "hosts: route aerospace mode indicator per-display via display_router"
```

---

## Task 6: Compact-on-built-in mode for the clock widget

**Files:**
- Modify: `hosts/common/darwin/optional/services/sketchybar/plugins/clock.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/default.nix` (subscriptions)

**Outcome:** When the built-in is attached, the clock label shows only `HH:MM AM/PM` until hovered; on hover it shows `Day DD Mon HH:MM AM/PM`. When the built-in is not attached, behavior matches today.

- [ ] **Step 1: Rewrite the clock plugin to handle compact mode and hover events.**

Replace the body of `hosts/common/darwin/optional/services/sketchybar/plugins/clock.nix` with:

```nix
{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# When the built-in display is attached (flag file non-empty), shows just
# the time. Hovering expands to the full date+time. When the built-in
# isn't attached, always shows the full date+time.
writeShellScript "sketchybar_clock" ''
  flag_file="/tmp/sketchybar-builtin-display"
  if [ -s "$flag_file" ]; then
    COMPACT=1
  else
    COMPACT=0
  fi

  full_label="$(date +'%a %d %b %I:%M %p')"
  compact_label="$(date +'%I:%M %p')"

  case "$SENDER" in
    mouse.entered)
      sketchybar --set "$NAME" label="$full_label"
      exit 0
      ;;
    mouse.exited)
      if [ "$COMPACT" = "1" ]; then
        sketchybar --set "$NAME" label="$compact_label"
      else
        sketchybar --set "$NAME" label="$full_label"
      fi
      exit 0
      ;;
  esac

  if [ "$COMPACT" = "1" ]; then
    sketchybar --set "$NAME" label="$compact_label"
  else
    sketchybar --set "$NAME" label="$full_label"
  fi
''
```

- [ ] **Step 2: Subscribe the clock to mouse events.**

In `hosts/common/darwin/optional/services/sketchybar/default.nix`, find the existing `clock` item declaration (search for `sketchybar --add item clock right`). Currently it has `--set clock update_freq=10 icon.drawing=off script="${plugins.clock}" click_script="..."` without a `--subscribe`. Append the subscription. The existing block looks like:

```bash
sketchybar --add item clock right \
          --set clock update_freq=10 icon.drawing=off script="${plugins.clock}" \
            click_script="${config.services.sketchybar.personalizedOptions.clockClickCommand}" \
```

Modify it to add a `--subscribe`:

```bash
sketchybar --add item clock right \
          --set clock update_freq=10 icon.drawing=off script="${plugins.clock}" \
            click_script="${config.services.sketchybar.personalizedOptions.clockClickCommand}" \
          --subscribe clock mouse.entered mouse.exited \
```

Be careful with backslash continuations — the existing config uses a bash chain. The `--subscribe` must precede the next `--add item` (`vpn`).

- [ ] **Step 3: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 4: Verify the compact-clock behavior.**

With built-in attached:
- Clock shows `HH:MM AM/PM` (no day or date).
- Hover over the clock — label expands to `Day DD Mon HH:MM AM/PM`.
- Move cursor away — label collapses back to time-only.

With built-in detached (clamshell + externals):
- Clock shows the full `Day DD Mon HH:MM AM/PM` always (hover is a no-op).

- [ ] **Step 5: Commit.**

```bash
jj commit -m "hosts: clock widget compact-on-built-in mode with hover expansion"
```

---

## Task 7: Compact-on-built-in mode for the now_playing widget

**Files:**
- Modify: `hosts/common/darwin/optional/services/sketchybar/plugins/now_playing.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/default.nix` (subscriptions)

**Outcome:** When the built-in is attached, now_playing shows only the music icon while music is playing; on hover it expands to `Artist — Title`. When built-in is not attached, behavior matches today.

- [ ] **Step 1: Add compact-mode and hover handling to now_playing.**

Replace the body of `hosts/common/darwin/optional/services/sketchybar/plugins/now_playing.nix` with:

```nix
{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Now-playing display — polls Apple Music + Spotify via AppleScript.
#
# (See file history for background on the MediaRemote / AppleScript
# fallback. Logic below extends the polling script with a compact-on-
# built-in mode keyed off /tmp/sketchybar-builtin-display.)
writeShellScript "sketchybar_now_playing" ''
  flag_file="/tmp/sketchybar-builtin-display"
  if [ -s "$flag_file" ]; then
    COMPACT=1
  else
    COMPACT=0
  fi

  # Hover handlers only toggle label.drawing — content is set on each
  # poll below. In non-compact mode hover is a no-op (label is always
  # already drawn).
  case "$SENDER" in
    mouse.entered)
      if [ "$COMPACT" = "1" ]; then
        sketchybar --set "$NAME" label.drawing=on
      fi
      exit 0
      ;;
    mouse.exited)
      if [ "$COMPACT" = "1" ]; then
        sketchybar --set "$NAME" label.drawing=off
      fi
      exit 0
      ;;
  esac

  query_app() {
    local app="$1"
    /usr/bin/osascript -e "
      tell application \"System Events\"
        if not (exists process \"$app\") then return \"\"
      end tell
      tell application \"$app\"
        try
          if player state is playing then
            return (name of current track) & \"|\" & (artist of current track)
          end if
        end try
        return \"\"
      end tell
    " 2>/dev/null
  }

  RESULT=""
  for app in "Music" "Spotify"; do
    RESULT=$(query_app "$app")
    if [ -n "$RESULT" ]; then break; fi
  done

  if [ -z "$RESULT" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  TITLE="''${RESULT%%|*}"
  ARTIST="''${RESULT##*|}"

  if [ -n "$ARTIST" ] && [ "$ARTIST" != "$TITLE" ]; then
    LABEL="$ARTIST — $TITLE"
  else
    LABEL="$TITLE"
  fi

  if [ ''${#LABEL} -gt 35 ]; then
    LABEL="''${LABEL:0:32}..."
  fi

  if [ "$COMPACT" = "1" ]; then
    sketchybar --set "$NAME" drawing=on icon="󰎈" label="$LABEL" label.drawing=off
  else
    sketchybar --set "$NAME" drawing=on icon="󰎈" label="$LABEL" label.drawing=on
  fi
''
```

- [ ] **Step 2: Subscribe now_playing to mouse events.**

In `hosts/common/darwin/optional/services/sketchybar/default.nix`, find the existing `now_playing` item declaration (search for `--add item now_playing`). Currently it ends without a `--subscribe`. Append:

```bash
                  --subscribe now_playing mouse.entered mouse.exited
```

It's the last `--add` block in the right-items chain — so it sits right at the end of that chained block. Care: the existing chain uses backslash continuations, and now_playing was the terminal `--add`. Adding `--subscribe` keeps it terminal.

- [ ] **Step 3: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 4: Verify the compact-now_playing behavior.**

Play music in Apple Music (or Spotify).

With built-in attached:
- now_playing shows only the music icon (no track text).
- Hover → label "Artist — Title" appears.
- Move away → label hides again.

With built-in detached:
- Full label always visible.

- [ ] **Step 5: Commit.**

```bash
jj commit -m "hosts: now_playing widget compact-on-built-in mode with hover expansion"
```

---

## Task 8: Compact-on-built-in mode for the calendar widget

**Files:**
- Modify: `hosts/common/darwin/optional/services/sketchybar/plugins/calendar.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/default.nix` (subscriptions)

**Outcome:** When the built-in is attached, the calendar label shows only the next event's start time (or `NOW` for in-progress events). On hover it shows the full label with the event title. When the built-in is not attached, behavior matches today.

- [ ] **Step 1: Modify calendar.nix to compute compact and full labels, write both to state files, and handle hover events.**

In `hosts/common/darwin/optional/services/sketchybar/plugins/calendar.nix`, do three edits:

(a) **At the very top of the `writeShellScript` body**, before `# Locate icalBuddy with Homebrew`, add:

```bash
  flag_file="/tmp/sketchybar-builtin-display"
  if [ -s "$flag_file" ]; then
    COMPACT=1
  else
    COMPACT=0
  fi

  full_label_cache="/tmp/sketchybar-calendar-full-label.txt"
  compact_label_cache="/tmp/sketchybar-calendar-compact-label.txt"

  case "$SENDER" in
    mouse.entered)
      if [ "$COMPACT" = "1" ] && [ -f "$full_label_cache" ]; then
        sketchybar --set "$NAME" label="$(cat "$full_label_cache")"
      fi
      exit 0
      ;;
    mouse.exited)
      if [ "$COMPACT" = "1" ] && [ -f "$compact_label_cache" ]; then
        sketchybar --set "$NAME" label="$(cat "$compact_label_cache")"
      fi
      exit 0
      ;;
  esac
```

(b) **Inside `render_event()`**, replace each `sketchybar --set "$NAME" drawing=on icon="󰃭" label="..." ...` call so that BOTH labels are computed and written to the cache files, and the rendered label is chosen based on `COMPACT`. The existing render_event has three branches: NOW, ≤15min, and normal. For each branch, replace the `label="..."` argument with a variable that we set conditionally.

The cleanest pattern: at the top of `render_event`, compute both labels for each branch. Replace the body of `render_event()` (the `if [ "$delta_min" -le 0 ]; then ... else ... fi` block) with:

```bash
    # Compute both compact and full labels for this branch.
    local now_full="NOW: $title"
    local now_compact="NOW"
    local warn_full="''${start_time} $title (''${delta_min}m)"
    local warn_compact="''${start_time}"
    local norm_full="''${start_time} $title"
    local norm_compact="''${start_time}"

    local full_lbl compact_lbl

    if [ "$delta_min" -le 0 ]; then
      local end_epoch=""
      if [ -n "$end_time" ]; then
        end_epoch=$(/bin/date -j -f "%Y-%m-%d %H:%M" "$start_date $end_time" +%s 2>/dev/null || echo "")
      fi
      if [ -n "$end_epoch" ] && [ "$end_epoch" -gt "$NOW_EPOCH" ]; then
        full_lbl="$now_full"
        compact_lbl="$now_compact"
        local chosen
        if [ "$COMPACT" = "1" ]; then chosen="$compact_lbl"; else chosen="$full_lbl"; fi
        sketchybar --set "$NAME" drawing=on \
          icon="󰃭" label="$chosen" \
          icon.color=0xffffffff label.color=0xffffffff \
          background.drawing=on \
          background.color=0xffcc4444 \
          background.corner_radius=5 \
          background.height=23
        printf '%s' "$full_lbl" > "$full_label_cache"
        printf '%s' "$compact_lbl" > "$compact_label_cache"
        RENDERED_AS_NOW=1
        return 0
      fi
      return 1
    elif [ "$delta_min" -le 15 ]; then
      full_lbl="$warn_full"
      compact_lbl="$warn_compact"
      local chosen
      if [ "$COMPACT" = "1" ]; then chosen="$compact_lbl"; else chosen="$full_lbl"; fi
      sketchybar --set "$NAME" drawing=on \
        icon="󰃭" label="$chosen" \
        icon.color=0xff000000 label.color=0xff000000 \
        background.drawing=on \
        background.color=0xffe09000 \
        background.corner_radius=5 \
        background.height=23
      printf '%s' "$full_lbl" > "$full_label_cache"
      printf '%s' "$compact_lbl" > "$compact_label_cache"
      return 0
    else
      full_lbl="$norm_full"
      compact_lbl="$norm_compact"
      local chosen
      if [ "$COMPACT" = "1" ]; then chosen="$compact_lbl"; else chosen="$full_lbl"; fi
      sketchybar --set "$NAME" drawing=on \
        icon="󰃭" label="$chosen" \
        icon.color=0xffffffff label.color=0xffffffff \
        background.drawing=off
      printf '%s' "$full_lbl" > "$full_label_cache"
      printf '%s' "$compact_lbl" > "$compact_label_cache"
      return 0
    fi
```

(c) **Also clear the cache files** when the script decides there's no event to draw. Find the two places where the script sets `drawing=off` on `calendar` (the early-return for no icalBuddy / no events, and the post-loop `if [ "$found" -eq 0 ]; then` block). Immediately after each `sketchybar --set "$NAME" drawing=off` call, add:

```bash
  /bin/rm -f "$full_label_cache" "$compact_label_cache" 2>/dev/null || true
```

- [ ] **Step 2: Subscribe calendar to mouse events.**

In `hosts/common/darwin/optional/services/sketchybar/default.nix`, find the existing `calendar` item registration (search for `--add item calendar right`). It currently has `--subscribe calendar calendar_dismissed`. Extend it to also subscribe to mouse events:

```bash
                --subscribe calendar calendar_dismissed mouse.entered mouse.exited \
```

- [ ] **Step 3: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 4: Verify the compact-calendar behavior.**

Find a time when icalBuddy has a future event to show.

With built-in attached:
- Calendar shows only `HH:MM` (e.g., `14:30`).
- Hover → full label appears (e.g., `14:30 Team standup` or `NOW: All-hands`).
- Move away → collapses back to time-only.
- For NOW events (in-progress): compact label is just `NOW`, hover expands to `NOW: Title`.

With built-in detached:
- Full label always visible (current behavior unchanged).

If the cache files don't exist (first render after rebuild before icalBuddy succeeds), hover does nothing — that's expected; once the regular update runs, the cache populates.

- [ ] **Step 5: Commit.**

```bash
jj commit -m "hosts: calendar widget compact-on-built-in mode with hover expansion"
```

---

## Task 9: Compact padding when built-in is attached

**Files:**
- Modify: `hosts/common/darwin/optional/services/sketchybar/default.nix`
- Modify: `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`

**Outcome:** When the built-in display is attached, all sketchybar items have halved horizontal padding (2/2/2 instead of 5/4/4). When the built-in is not attached, padding restores to defaults.

- [ ] **Step 1: Export the item list from the sketchybar config to the router.**

In `hosts/common/darwin/optional/services/sketchybar/default.nix`, inside the `config = let ... in {` block (just under `baselineHeight = 30;`), add a Nix-side list of all known sketchybar item names:

```nix
    # List of all sketchybar item names (excluding workspace indicators,
    # which are added in a loop). display_router applies per-item
    # padding overrides to these.
    compactPaddingItems = [
      "chevron"
      "front_app"
      "space_separator"
      "aerospace_mode"
      "aerospace_mode_compact"
      "clock"
      "vpn"
      "weather"
      "battery"
      "cpu"
      "memory"
      "disk"
      "volume"
      "calendar"
      "calendar_dismiss"
      "now_playing"
    ] ++ lib.optional (config.services.litra.enable or false) "litra";
```

(`lib` is already in scope from the function header.)

- [ ] **Step 2: Pass the list to display_router via its plugin args.**

In `hosts/common/darwin/optional/services/sketchybar/plugins/default.nix`, the `display_router` import line needs to receive the list. Update it:

```nix
  display_router = import ./display_router.nix {
    inherit pkgs config sketchybar;
    compactPaddingItems = config.services.sketchybar.personalizedOptions.compactPaddingItems or [ ];
  };
```

Then in `hosts/common/darwin/optional/services/sketchybar/default.nix`, register a new `personalizedOptions.compactPaddingItems` option so the value can flow through. Inside `options.services.sketchybar.personalizedOptions`, add:

```nix
    compactPaddingItems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        List of sketchybar item names that get half-padding when the
        built-in display is attached. Populated by the sketchybar
        config, not user-facing.
      '';
    };
```

And inside the `config = { ... }` block, set:

```nix
    services.sketchybar.personalizedOptions.compactPaddingItems = compactPaddingItems;
```

- [ ] **Step 3: Update display_router to apply padding.**

In `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`, accept the new parameter and use it. Update the file header:

```nix
{
  pkgs,
  config,
  sketchybar ? pkgs.sketchybar,
  baselineHeight ? 30,
  # List of sketchybar item names to apply compact padding to.
  compactPaddingItems ? [ ],
  ...
}:
let
  displayInfo = "${pkgs.display-info}/bin/display-info";
  sketchybarBin = "${sketchybar}/bin/sketchybar";
  # Bash array literal of item names.
  itemsBash = builtins.concatStringsSep " " (map (n: ''"${n}"'') compactPaddingItems);
in
```

Then, in the script body, after the existing mode-indicator routing block, add a padding-routing block (still inside the heredoc):

```bash
  # Padding routing.
  items=( ${itemsBash} )
  if [ -n "''${BUILTIN_DISPLAY:-}" ]; then
    # Halved spacing.
    for item in "''${items[@]}"; do
      ${sketchybarBin} --set "$item" \
        padding_left=2 padding_right=2 \
        icon.padding_left=2 icon.padding_right=2 \
        label.padding_left=2 label.padding_right=2
    done
  else
    # Default spacing (matches the `default=` block in the sketchybar config).
    for item in "''${items[@]}"; do
      ${sketchybarBin} --set "$item" \
        padding_left=5 padding_right=5 \
        icon.padding_left=4 icon.padding_right=4 \
        label.padding_left=4 label.padding_right=4
    done
  fi
```

- [ ] **Step 4: Rebuild and switch.**

```bash
sudo darwin-rebuild switch --flake .#<HOSTNAME>
```

- [ ] **Step 5: Verify the padding behavior.**

With built-in attached:
- Item spacing is visibly tighter (≈ half) compared to before.

With built-in detached (clamshell + externals):
- Item spacing is back to the original defaults.

If the padding looks wrong: run `display-info` and confirm `BUILTIN_DISPLAY` is set / unset as expected.

- [ ] **Step 6: Commit.**

```bash
jj commit -m "hosts: tighten sketchybar item padding when built-in display is attached"
```

---

## Task 10: Final cleanup and integration verification

**Files:**
- Verify: `hosts/common/darwin/optional/services/sketchybar/default.nix` (no stale constants)

**Outcome:** No dead code from the original WIP diff remains; full end-to-end behavior verified across the four scenarios.

- [ ] **Step 1: Confirm no stale `macbookMonitorHeight` constant remains.**

```bash
grep -n macbookMonitorHeight hosts/common/darwin/optional/services/sketchybar/default.nix
```

Expected: no output. (Task 2 already replaced the WIP `let` block with `let baselineHeight = 30; in` plus the rest.)

If there are leftovers, remove them now and amend the most recent commit (using `jj squash` or by editing and re-running `jj commit`).

- [ ] **Step 2: Run flake check.**

```bash
nix flake check --no-build
```

Expected: no errors.

- [ ] **Step 3: Integration test — clamshell + externals (default scenario).**

Plug into externals, close lid (or keep lid open if you can confirm `BUILTIN_DISPLAY` is then set). Verify:

- Bar height = 30.
- Item padding = defaults.
- `aerospace_mode` indicator visible in center on each external.
- `aerospace_mode_compact` not visible.
- `clock`, `now_playing`, `calendar` show full labels.
- Meh/Hyper bindings (Ergodox) work.

- [ ] **Step 4: Integration test — laptop only.**

Disconnect externals, lid open. Verify:

- Bar height ≈ 32.
- Item padding = halved.
- `aerospace_mode_compact` visible on left.
- `aerospace_mode` NOT visible in center.
- `clock`, `now_playing` (if playing), `calendar` (if event) show compact labels.
- Hover on any of them expands the label.
- `ctrl-alt-*` bindings work.
- `ctrl-alt-a` → alter mode → bare digits move windows between workspaces.
- `ctrl-alt-a` → alter mode → arrow keys move windows within workspace.

- [ ] **Step 5: Integration test — laptop + externals.**

Plug in externals with lid open. Verify:

- Bar height ≈ 32 on all displays.
- Item padding = halved (bar-wide; this is the accepted trade-off).
- `aerospace_mode` visible in center on externals, NOT on built-in.
- `aerospace_mode_compact` visible on left on built-in only.
- Compact widgets behave compactly on all displays (bar-wide, accepted trade-off).
- Both Meh/Hyper (Ergodox) and ctrl-alt (built-in keyboard) bindings work.

- [ ] **Step 6: Final commit if anything changed in Step 1.**

If Step 1 found and fixed leftovers:

```bash
jj commit -m "hosts: clean up unused sketchybar height constant"
```

Otherwise nothing to commit.

---

## Spec coverage check

| Spec section                                | Implemented in task |
|---------------------------------------------|---------------------|
| 1. `display-info` Swift utility             | Task 1              |
| 2. Sketchybar bar height                    | Task 2              |
| 3. `display_router` plugin                  | Task 2 (height), 5 (mode), 9 (padding) |
| 4. ctrl-alt-* main mode bindings            | Task 3              |
| 5. alter mode additions                     | Task 4              |
| 6. Mode indicator per-display routing       | Task 5              |
| 7. Compact widgets (clock/now_playing/cal)  | Tasks 6, 7, 8       |
| 8. Compact padding                          | Task 9              |
| Cleanup, integration verify                 | Task 10             |

## Notes for the implementer

- **Bash chain hygiene in sketchybar config.** The sketchybar `services.sketchybar.config` is one giant bash script with backslash continuations grouping `--add` / `--set` / `--subscribe` invocations. When inserting new items mid-config (Tasks 2 & 5), make sure the backslashes on the preceding/following lines remain correct. See the existing `sketchybar-widget-patterns` memory note about bash-chain breakage when injecting widgets mid-config.
- **Cache TTL.** The label cache files for calendar persist across reboots. That's intentional — first-render-after-reboot hover then works. They get overwritten on every successful render and deleted when there's no event. No cleanup needed.
- **Mouse hover events fire often.** Each `mouse.entered`/`mouse.exited` triggers a script run. Scripts must exit fast in those branches. The patterns above all `exit 0` immediately after the hover branch.
- **Test on the actual hardware.** Display detection and notch geometry are device-specific. There's no way to dry-run the visual checks; rebuild and look.
- **Existing WIP diff in sketchybar/default.nix.** The user's working copy already has `nonMacbookMonitorHeight = 30; macbookMonitorHeight = 33;` defined. Task 2 replaces those with the single `baselineHeight = 30`. Don't keep both.
