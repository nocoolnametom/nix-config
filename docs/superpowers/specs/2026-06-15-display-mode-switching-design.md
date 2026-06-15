# Display-mode-aware aerospace + sketchybar (macbookpro)

Date: 2026-06-15
Scope: nix-darwin host `macbookpro` (shared modules under `hosts/common/darwin/`)

## Problem

The macbookpro is normally used in clamshell with two external monitors, driven
by an Ergodox with Meh (`alt-ctrl-shift`) and Hyper (`alt-ctrl-shift-cmd`) keys.
In that configuration:

- Aerospace bindings live on `meh-*` / `hyper-*` — comfortable on Ergodox.
- Sketchybar bar height is `30`, sized for the externals' menubar area.
- Workspaces 1-5 prefer the `secondary` external; 6-A prefer the `main` external.

When the laptop is disconnected from externals (lid open, no monitors, built-in
keyboard only), two things break:

1. **Bindings are unreachable.** `meh-*` / `hyper-*` require 3-4 modifier keys
   plus a letter, which is impractical on the built-in keyboard.
2. **Bar height is wrong.** The MBP built-in display has a notch that reserves
   a top safe area; a 30-point bar leaves a visible gap between the bar and
   the topmost window.

The existing external-monitor setup must remain intact — we are not migrating
away from Meh/Hyper, only adding a laptop-friendly fallback.

## Approach

**Coexisting bindings + display-aware bar height.** Selected after comparison
with mode-based switching and config-swap-and-reload — see Alternatives
considered.

- Aerospace gains a parallel `ctrl-alt-*` binding set in the existing `main`
  mode, alongside the current `meh-*` / `hyper-*` bindings. Both sets are
  always active; the user picks whichever is reachable given the current
  keyboard.
- Aerospace's `alter` mode gains bare-digit move-to-workspace bindings and
  arrow-key move-within-workspace bindings, so window manipulation no longer
  requires Hyper.
- Sketchybar bar height is computed at startup and on `display_change` from
  `NSScreen.safeAreaInsets.top`, via a small Swift utility packaged as a
  nix-darwin derivation. No mode-switching, no manual toggle.

**Why this approach:** aerospace doesn't need to know about display state at
all. Both binding sets work in any keyboard scenario (laptop keyboard with
externals, Ergodox in laptop mode, etc.). If the display detector ever fails,
the only consequence is a 2-3 pixel cosmetic gap — bindings are unaffected.

## Components

### 1. `pkgs/display-info` — Swift utility

A new custom package providing a single binary, `display-info`, that prints
structured display state to stdout in shell-sourceable form:

```
NOTCH_INSET=32
BUILTIN_DISPLAY=1
EXTERNAL_DISPLAYS=2,3
```

- `NOTCH_INSET` — the maximum `safeAreaInsets.top` across all attached
  `NSScreen.screens`, rounded up as an integer. `0` if no screen has a
  non-zero top safe area (clamshell, or external-only without a notch).
- `BUILTIN_DISPLAY` — the macOS-assigned display index of the built-in
  display (matched by `safeAreaInsets.top > 0` or by `localizedName`
  containing `Built-in`), or empty if the built-in isn't currently
  attached.
- `EXTERNAL_DISPLAYS` — comma-separated indices of non-built-in displays,
  or empty.

Display indices are 1-based to match sketchybar's `display=` numbering.

```swift
import Cocoa
let screens = NSScreen.screens
let maxInset = screens.map { Int(ceil($0.safeAreaInsets.top)) }.max() ?? 0
// Built-in heuristic: non-zero top safe area OR localizedName contains "Built-in".
let builtinIdx = screens.enumerated().first { (_, s) in
    s.safeAreaInsets.top > 0
        || s.localizedName.localizedCaseInsensitiveContains("built-in")
}.map { $0.offset + 1 }
let externals = screens.enumerated()
    .filter { (i, _) in (i + 1) != (builtinIdx ?? -1) }
    .map { String($0.offset + 1) }
    .joined(separator: ",")

print("NOTCH_INSET=\(maxInset)")
print("BUILTIN_DISPLAY=\(builtinIdx.map(String.init) ?? "")")
print("EXTERNAL_DISPLAYS=\(externals)")
```

Built as a Nix derivation using `pkgs.swift` linked against the macOS Cocoa
framework. The exact nixpkgs idiom for Apple SDK frameworks has been in
flux across recent nixpkgs releases (`pkgs.darwin.apple_sdk.frameworks.Cocoa`,
`pkgs.apple-sdk_<n>`, or a system-SDK fallback may apply); the
implementation plan picks the form that compiles cleanly against the
current pinned nixpkgs. Follows the existing `pkgs/yknotify/` pattern:
registered in `pkgs/default.nix`, exposed via the `additions` overlay in
`overlays/default.nix`.

### 2. Sketchybar bar height and per-monitor routing

Both startup configuration and runtime updates are driven by a single
`display_router` script. It runs once during sketchybar startup and again
on every `display_change` event. It:

1. Sources `display-info` output to get `$NOTCH_INSET`, `$BUILTIN_DISPLAY`,
   `$EXTERNAL_DISPLAYS`.
2. Computes bar height: `max($NOTCH_INSET, $baselineHeight)` where
   `baselineHeight = 30`. Applies via `sketchybar --bar height=$new`.
3. Writes `$BUILTIN_DISPLAY` to a flag file at
   `/tmp/sketchybar-builtin-display` (empty if no built-in). Compact-mode
   widget scripts read this on each update.
4. Applies per-item display routing (mode indicator) and per-item padding
   (compact spacing) — see Sections 6 and 7.

A hidden `display_handler` sketchybar item is added, subscribed to the
built-in `display_change` event:

```bash
sketchybar --add item display_handler left \
          --set display_handler \
            drawing=off \
            script="${plugins.display_router}" \
          --subscribe display_handler display_change
```

`display-info` is added to `services.sketchybar.extraPackages` so it's
discoverable from sketchybar's scripts.

### 3. Sketchybar plugin: `plugins/display_router.nix`

New plugin file. Mirrors the structure of existing plugins (a
`writeShellScript` that's parameterized by `pkgs`, `config`, `sketchybar`).
Wired into `plugins/default.nix` alongside the others. Coordinates bar
height, item routing, padding, and the flag file write.

### 4. Aerospace: new `main` mode bindings

Added to `hosts/common/darwin/optional/services/aerospace/default.nix`, all
using `lib.mkDefault`. They coexist with the existing `meh-*` / `hyper-*`
bindings — no existing binding is changed.

| Chord                            | Action                                      |
|----------------------------------|---------------------------------------------|
| `ctrl-alt-1` … `ctrl-alt-9`      | `workspace 1` … `workspace 9`               |
| `ctrl-alt-0`                     | `workspace A`                               |
| `ctrl-alt-h` / `j` / `k` / `l`   | `focus left` / `down` / `up` / `right`      |
| `ctrl-alt-left` / `ctrl-alt-right` | `workspace prev` / `workspace next`       |
| `ctrl-alt-up` / `ctrl-alt-down`  | `focus-monitor prev` / `focus-monitor next` |
| `ctrl-alt-tab`                   | `workspace-back-and-forth`                  |
| `ctrl-alt-f`                     | `fullscreen`                                |
| `ctrl-alt-a`                     | enter `alter` mode (+ sketchybar trigger)   |
| `ctrl-alt-semicolon`             | enter `service` mode (+ sketchybar trigger) |

`alt-slash` and `alt-comma` (layout commands in main mode) already use a
single-modifier chord that's reachable on the built-in keyboard — left
unchanged. `hyper-tab` (`move-workspace-to-monitor --wrap-around next`) has
no laptop equivalent: it's a multi-monitor operation that's meaningless
when only the built-in is attached. Users who need it on the dual-monitor
keyboard can keep using `hyper-tab` from the Ergodox.

The mode-entry bindings use the existing `toMode` helper so the sketchybar
mode indicator stays in sync (as documented in
`plugins/aerospace_mode.nix`).

### 5. Aerospace: new `alter` mode bindings

Window manipulation moves into `alter` mode (the "vim-style manipulation
mode"), entered via either `hyper-a` (existing) or `ctrl-alt-a` (new). All
existing alter bindings (`h`/`j`/`k`/`l` = join-with, `f` = layout,
`r` = flatten, `-`/`=` = resize, `esc` = exit) are preserved.

Additions:

| Chord                  | Action                                                  |
|------------------------|---------------------------------------------------------|
| `1` … `9`              | `move-node-to-workspace N --focus-follows-window`       |
| `0`                    | `move-node-to-workspace A --focus-follows-window`       |
| `left` / `down` / `up` / `right` | `move left` / `down` / `up` / `right`         |

Arrow keys (rather than `shift-h/j/k/l`) match the existing alter-mode
pattern of bare keys for chained repeats.

The `move-node-to-workspace` bindings stay in `alter` mode rather than
being added to `main` because the equivalent `meh+shift` modifier slot is
already meh (used for focus in main).

### 6. Aerospace mode indicator: two items, display-gated

The existing center-positioned `aerospace_mode` item is kept but its
`display=` is set dynamically:

- Built-in present → `display=$EXTERNAL_DISPLAYS` (hidden on built-in
  because the notch swallows centered items).
- Built-in not present (clamshell + externals only) → `display=` cleared
  to default (shown everywhere).

A new left-positioned `aerospace_mode_compact` item is added, positioned
after `front_app`. It subscribes to the same `aerospace_mode_change` event
and runs the same `aerospace_mode` plugin script. Its `display=` is set
dynamically:

- Built-in present → `display=$BUILTIN_DISPLAY` (shown only on built-in).
- Built-in not present → drawing=off (always hidden).

Both items share the same script, so the mode label (`alter` / `service`)
appears in exactly one place per display.

### 7. Compact-on-built-in widgets

The user-selected widgets — `calendar`, `now_playing`, `clock` — get a
compact mode active whenever the built-in display is attached. Each widget
gains:

- A read of `/tmp/sketchybar-builtin-display` at the top of its update
  script. If the file is non-empty (i.e., a built-in is attached), the
  script renders a compact label; otherwise the full label.
- Subscriptions to `mouse.entered` and `mouse.exited`. The hover handlers
  toggle `label.drawing` to expose / hide the full content while the
  cursor is over the item.

Note: compact mode is bar-wide, not per-display. Sketchybar's per-item
properties (`label.drawing`, label text content) cannot be set per-display.
When the built-in is attached alongside externals, compact rendering
applies on the externals too. This is the trade-off the user accepted.

Compact-mode content per widget:

| Widget        | Compact label                   | Hover label                  |
|---------------|----------------------------------|------------------------------|
| `calendar`    | Time of next event only          | Full event preview (current) |
| `now_playing` | Music icon only (no label text)  | Track + artist (current)     |
| `clock`       | Time only (`HH:MM`)              | Date + time (current)        |

Mode change is instantaneous: on `display_change`, the router writes the
new flag-file state and triggers each widget's update script via
`sketchybar --trigger` (or `--update` for the whole bar) so each re-renders
in the new mode.

### 8. Compact padding on built-in

When the built-in is the focal display, items get tighter horizontal
spacing — roughly half the default. Implemented by the `display_router`
script applying explicit `--set` overrides to all known items:

```
padding_left=2, padding_right=2
icon.padding_left=2, icon.padding_right=2
label.padding_left=2, label.padding_right=2
```

(Halved from current defaults of 5 / 4 / 4.) When externals are present,
the router restores the default values.

This requires the router to know the full list of sketchybar item names.
The Nix-side config will export this list as a shell variable in the
config snippet so the router doesn't need to be kept in sync manually.

## File touch list

- **New**: `pkgs/display-info/default.nix` — Swift derivation.
- **New**: `pkgs/display-info/display-info.swift` — source.
- **Modified**: `pkgs/default.nix` — register `display-info`.
- **New**: `hosts/common/darwin/optional/services/sketchybar/plugins/display_router.nix`.
- **Modified**: `hosts/common/darwin/optional/services/sketchybar/plugins/default.nix` — import `display_router`.
- **Modified**: `hosts/common/darwin/optional/services/sketchybar/default.nix`:
  - drop the unused `macbookMonitorHeight = 33` constant from the draft diff;
  - keep `baselineHeight = 30`;
  - compute startup height via `display-info`;
  - add `display_handler` item subscribed to `display_change`;
  - add `aerospace_mode_compact` item (left, after `front_app`) subscribed to `aerospace_mode_change`;
  - add `mouse.entered` / `mouse.exited` subscriptions to `calendar`, `now_playing`, `clock`;
  - export the list of item names to the router script;
  - add `display-info` to `extraPackages`.
- **Modified**: existing plugin scripts for `calendar`, `now_playing`, `clock` — add compact-mode branch keyed off `/tmp/sketchybar-builtin-display`.
- **Modified**: `hosts/common/darwin/optional/services/aerospace/default.nix`:
  - add `ctrl-alt-*` `main`-mode bindings (table 4);
  - add bare-digit and arrow-key `alter`-mode bindings (table 5).

## Behavior matrix

| Display state                          | `NOTCH_INSET` | Bar height | Mode indicator               | Compact widgets | Padding   |
|----------------------------------------|---------------|------------|------------------------------|-----------------|-----------|
| Clamshell + 2 externals (default)      | 0             | 30         | center (existing)            | full            | default   |
| Lid open, no externals                 | ~32           | 32         | left (compact item)          | compact-on-hover| halved    |
| Lid open + externals connected         | ~32           | 32         | center on externals, left on built-in | compact-on-hover (built-in only — but per simplest mechanic, applied bar-wide whenever the built-in is present) | halved bar-wide |
| Asleep / no displays                   | n/a           | unchanged  | unchanged                    | unchanged       | unchanged |

Note on the dual-display scenario: because sketchybar's `padding_*` and
widget `label.drawing` are per-item global properties (no per-display
override exists), when the built-in is present alongside externals the
compact behavior applies bar-wide, including on the externals. The user
accepted this trade-off ("even if it looks bad") in exchange for fitting
the bar within the notch geometry.

## Non-goals / explicit decisions

- **No mode-based switching in aerospace.** Both binding sets are always
  active; we don't enter or leave a `laptop` mode based on display state.
- **No automatic gap re-tuning.** The existing
  `gaps.outer.top = [{ monitor."built-in" = 0; } 33]` already does the right
  thing per-monitor and is left untouched.
- **No workspace re-assignment.** `workspace-to-monitor-force-assignment`
  fallback to `built-in` already collapses workspaces correctly when
  externals disappear.
- **No manual toggle.** Detection is purely `display_change`-driven; there's
  no widget to override it.
- **No host-specific overrides.** Bindings live in the shared
  `hosts/common/darwin/optional/services/aerospace/` module and are harmless
  on any darwin host that imports it. macbookpro is the only consumer
  today.

## Alternatives considered

**Mode-based switching.** Define a `laptop` binding mode mirroring `main`
with `ctrl-alt` modifiers; an external script calls `aerospace mode laptop`
or `aerospace mode main` on `display_change`. Rejected: more moving parts,
a missed mode switch (e.g. detector crash) strands the user with the wrong
bindings, and it forbids mixed scenarios like "laptop keyboard with
externals attached."

**Config swap + reload.** Two aerospace config variants; detector swaps a
symlink and runs `aerospace reload-config`. Rejected: overkill for a binding
addition; reload may briefly drop window-tracking state.

**Hardcoded `33` bar height.** Simpler but a guess; `safeAreaInsets`
reports the value macOS itself uses, eliminating the eyeball-tuning step.

**Polling launchd agent for display state.** Rejected: sketchybar's
built-in `display_change` event is event-driven and already wired through
the existing extension mechanism.

## Validation

- `nix flake check --no-build` from the nix-config root.
- `sudo darwin-rebuild switch --flake .#macbookpro`.
- `display-info` returns sensible values in all four scenarios from the
  behavior matrix.
- Manually verify with lid open / closed and external connect / disconnect:
  - Bar height changes to ~32 when built-in is attached, 30 otherwise.
  - Mode indicator: visible in center on externals-only; visible on left
    (after `front_app`) when built-in is attached; never overlaps the notch.
  - `calendar`, `now_playing`, `clock` render compactly when built-in is
    attached, and expand to full content on hover.
  - Item padding halves bar-wide when built-in is attached, restores on
    externals-only.
  - `ctrl-alt-1..0` switches workspaces.
  - `ctrl-alt-a` enters alter mode; bare `1..0` moves the focused window;
    bare arrows move the window directionally; `esc` returns to main.
  - Existing `meh-*` / `hyper-*` bindings still work unchanged.
