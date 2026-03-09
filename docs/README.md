# Octotest Prototype

Godot `4.6.1` 3D isometric prototype with:

1. Point-and-click movement.
2. Orbit camera rig (`SpringArm3D`).
3. Gravity locomotion with authored climb/mantle movement for low elevated surfaces (chairs/desks).
4. Authored data-office room geometry (walls, windows, doors, console, desks, chairs, storage, tank).
5. UI flow with a startup main menu, in-game menu, and gameplay HUD hints.
6. Interactable object system with hover/in-range/blocked visualization.
7. Clickable wall light switch.
8. Multi-item octopus carry system (up to 8 held items) with overload movement penalties.
9. Focus-mode interaction system for precision objects (e.g. card reader).
10. Card reader gameplay with one-slot insertion, LED feedback, and clickable card ejection.
11. Wall-mounted code panel gameplay with focus-first keypad input (`0-9`, `<<`, `OK`), display feedback, and card-reader-matched LED states.
12. Player extracted into a dedicated scene (`res://scenes/player.tscn`) with imported octo model visual (`res://assets/models/octo/octo.glb`).
13. Procedural octopus rig wrapper (`OctoRig`) over `Skeleton3D` with manual head/arm bone config and cached rest pose data for future runtime animation.
14. Section-based arm posing controls (`base/mid/tip` with `bend` + `bend_angle`), smooth cross-section blending, and clamped bend ranges for natural defaults.
15. Arm animation mixer with per-arm modes (`STATIC`, `IDLE`, `CRAWL`, `HOLD`) so different arms can run different behaviors at the same time.
16. Idle animation system with subtle global sway plus per-idle-run randomized per-arm offsets/signs to avoid identical settle poses after movement.
17. Editor rig preview supports `Static Targets`, `Idle`, `Crawl`, `Mixer`, and `Hold` modes for visual tuning without entering gameplay.
18. Hold flow assigns items to free arm slots with mid-arm priority, keeps each item in a stable slot, and drives occupied arms in hold animation.
19. Held-item placement follows real rig arm anchors with size-aware clearance (cards stay close, larger props get extra anti-clipping offset).
20. Camera defaults now support a closer gameplay view with increased zoom-in range.

## Canonical Branch

Use `main` as the default stable branch.

## Run

```bash
cd /path/to/octotest
godot --path .
```

If your binary is named differently, these also work:

```bash
godot4 --path .
Godot --path .
```

For checks, `./scripts/check.sh` auto-detects, in order:

1. `GODOT_BIN` (if set)
2. `godot4` in `PATH`
3. `godot` in `PATH`
4. `Godot` in `PATH`
5. `/Applications/Godot.app/Contents/MacOS/godot` (macOS app install, lowercase binary)
6. `/Applications/Godot.app/Contents/MacOS/Godot` (macOS app install, legacy uppercase binary)
7. `/ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64` (legacy team Linux path)

You can still force a specific binary:

```bash
GODOT_BIN=/absolute/path/to/godot ./scripts/check.sh
```

## Controls

1. `LMB`: set move target.
2. `RMB + drag`: orbit camera.
3. `Q` / `E`: keyboard orbit.
4. Mouse wheel: zoom camera.
5. `LMB` on interactable in range: interact immediately.
6. `LMB` on interactable out of range: move closer and auto-interact when close.
7. `LMB` on held item: drop that specific item.
8. `F`: drop last held item.
9. `Shift + F`: drop all held items.
10. `Esc`: toggle in-game menu.
11. Focus mode:
- Auto-zooms when a focus-enabled object is clicked and the player reaches interaction distance.
- `RMB` exits focus.
- `LMB` outside interaction area exits focus.
- While focused, held items are selectable at the bottom of the screen.
- Code panel keypad buttons are only interactive while the panel is focused.
12. Octopus does not jump; climb/mantle is triggered automatically when moving onto valid low elevated surfaces.

## Validate

Run the unified check script:

```bash
./scripts/check.sh
```

## Docs Map

1. Session workflow and dev rules: `docs/PROCEDURES.md`
2. Runtime/code structure: `docs/ARCHITECTURE.md`
3. Running change history: `docs/DEVLOG.md`
4. Manual + automated test checklist: `docs/TESTING.md`
5. Gameplay implementation notes: `docs/misc/STAIRS.md`
6. Canonical game design document (active project version): `docs/GDD.md`
7. Editable game task backlog: `docs/TASK_LIST.md`
8. Puzzle planning template and dependency sheet: `docs/misc/PUZZLE_PLAN.md`
9. Per-room concept template: `docs/misc/room_concepts/ROOM_TEMPLATE.md`
