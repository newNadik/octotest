# Octotest Prototype

Godot `4.6.1` 3D isometric prototype with:

1. Point-and-click movement.
2. Orbit camera rig (`SpringArm3D`).
3. Gravity locomotion with authored climb/mantle movement for low elevated surfaces (chairs/desks).
4. Authored data-office room geometry (walls, windows, doors, console, desks, chairs, storage, tank).
5. UI flow with a startup main menu (browser-frame styled), in-game pause menu, and gameplay HUD hints.
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
17. Surface crawl is driven by `OctoSurfaceLocomotion` arm-state stepping (`SEARCH/REACH/GRAB/PUSH_PULL/RELEASE`) with role-phase pose synthesis (`plant/load/push/stabilize/recover/swing`).
18. Crawl->idle handoff is explicit: when movement command drops, non-hold arms switch immediately to idle targets while hold arms remain in hold override.
19. Crawl propulsion is normalized by active push-arm count to reduce uneven slide spikes when arm participation changes.
20. Editor rig preview supports `Static Targets`, `Idle`, `Crawl`, `Mixer`, and `Hold`; crawl preview uses the same surface locomotion pipeline and `preview_motion_speed` input as gameplay.
21. Hold flow assigns items to free arm slots with mid-arm priority, keeps each item in a stable slot, and drives occupied arms in hold animation.
22. Held-item placement follows real rig arm anchors with size-aware clearance (cards stay close, larger props get extra anti-clipping offset).
23. Camera defaults now support a closer gameplay view with increased zoom-in range.
24. Display stretch configured for fixed design height with adaptive width (`canvas_items` + `keep_height`) for desktop/tablet fullscreen layouts.
25. Click movement now prefers navmesh path following via `NavigationAgent3D` when navigation data is available, with automatic fallback to direct movement when navmesh is missing or target is unreachable.
26. Procedural animated fish-school system with per-volume schooling controls, timed school waves, species randomization (1-2 types per school), and directional flow modes (`Two-Way`, `Four-Way XZ`, `Fixed Direction`).
27. Desktop rendering defaults now target cleaner 3D output in debug and regular play: `Forward Plus`, `1600x900` default window, `MSAA 4x`, screen-space AA, and full-resolution 3D scaling.

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

## Rendering Defaults

Desktop quality defaults are configured in [`project.godot`](/Users/nadiiaiv/Documents/GodotProjects/Octotest/project.godot):

1. Renderer: `Forward Plus`
2. Default window size: `1600x900`
3. `MSAA 3D`: `4x`
4. Screen-space AA: enabled
5. 3D scaling: `1.0` (full-resolution render, no undersampling)

If you see performance issues on lower-end hardware, reduce window size first, then lower AA quality before changing gameplay content or scene lighting.

## Controls

1. `LMB` click/tap: move/interact (context-sensitive).
2. `LMB` drag: orbit camera.
3. Mouse wheel / pinch: zoom camera.
4. `LMB` on interactable in range: interact immediately.
5. `LMB` on interactable out of range: move closer and auto-interact when close.
6. `LMB` on held item: drop that specific item.
7. `Esc`: toggle in-game pause menu during gameplay.
8. Focus mode:
- Auto-zooms when a focus-enabled object is clicked and the player reaches interaction distance.
- `LMB` outside interaction area exits focus.
- While focused, held items are selectable at the bottom of the screen.
- Code panel keypad buttons are only interactive while the panel is focused.
9. Octopus does not jump; climb/mantle is triggered automatically when moving onto valid low elevated surfaces.
10. Navigation setup note: authored station floors should be covered by `NavigationRegion3D` + baked `NavigationMesh` for best path quality around walls/corners.

## Menu Notes

1. Main menu actions:
- `New Game` starts gameplay.
- `Continue` appears only when a save exists and loads the latest save.
- `Settings` opens the shared settings overlay.
- `Quit` exits the app.
2. In-game pause menu actions:
- `Resume` closes pause menu.
- `Save Game` writes current state to `user://save_game.json`.
- `Settings` opens the shared settings overlay.
- `Main Menu` returns to startup menu.
3. Save behavior:
- Autosave triggers when opening station doors (room traversal flow).
- Manual save is available from pause menu.
- Saved state currently includes player position and key interactable state (doors and room lights/switches).
- In-game save feedback is shown as a bottom-right toast (`Game Saved`, `Autosaved`, `Save Failed`).
4. Settings menu controls:
- `Music` and `Sound Effects` sliders persist audio values.
- `Subtitles` toggles with `<`/`>`.
- `Language` switches between `English (UK)` and `Ukrainian` with `<`/`>`.
- Language preference is saved to `user://settings.cfg` and applied on startup.
5. `Esc` on the startup main menu does not quit the app.
6. Text policy:
- Player-visible source text should use UK English.
- New/changed text should include Ukrainian translation coverage in `i18n/uk_UA.po`.

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
10. Third-party asset credits and license notes: `docs/ATTRIBUTION.md`
