# Dev Log

## 2026-03-08

### Step 26 - Procedural octopus rig wrapper foundation (`OctoRig` / `OctoArm` / `OctoHead`)

- Added rig-wrapper scripts for procedural animation groundwork:
  - `scripts/OctoRig.gd`
  - `scripts/OctoArm.gd`
  - `scripts/OctoHead.gd`
- Attached `OctoRig` to `PlayerVisual` in `scenes/player.tscn` so rig setup lives with the visual model layer.
- Implemented skeleton resolution for nested imported model scenes:
  - optional direct export (`skeleton`),
  - optional `skeleton_path`,
  - fallback recursive child search for `Skeleton3D`.
- Added manual rig configuration constants:
  - `HEAD_BONE_NAMES`
  - richer `ARM_CONFIGS` format with `side`, `role_bias`, and `bones`.
- Implemented startup rig validation:
  - missing skeleton/config checks,
  - per-bone existence checks,
  - arm minimum-length checks,
  - duplicate assignment warnings across head/arm configs.
- Implemented chain partitioning + cached data for procedural layers:
  - base/mid/tip grouping by thirds,
  - convenience accessors (`base_bone`, `middle_bone`, `tip_bone`),
  - cached rest transforms, rest positions, and rest rotations (`Quaternion`) per resolved bone.
- Added future-facing per-arm runtime fields:
  - state enum (`IDLE`, `SUPPORT`, `STEP`, `HOLD`, `REACH`),
  - phase offset,
  - held-item reference,
  - target position / target node.
- Added debug output helpers:
  - setup summary by head/arm,
  - optional resolved bone index printing.
- Updated architecture and README docs to include the new rig layer.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 25 - Player scene extraction + octo model integration

- Extracted player into reusable scene:
  - added `scenes/player.tscn` (`CharacterBody3D` + `CollisionShape3D` + `PlayerVisual`).
- Replaced inline player node in `scenes/main.tscn` with an instance of `res://scenes/player.tscn`.
- Switched player visual from placeholder cube to imported octo model:
  - `res://assets/models/octo/octo.glb`
  - source asset path: `assets/models/octo/octo.glb`.
- Updated gameplay focus-visual toggling in `scripts/main.gd` to target `PlayerVisual` (with fallback to old mesh path for compatibility).
- Fixed first-frame camera startup pop by initializing camera pivot follow position during `_ready()`.
- Removed temporary runtime pose prototype (`scripts/octo_pose.gd`) and restored imported default rig pose.

### Validation commands (pass)
1. `HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path /Users/nadiiaiv/Documents/GodotProjects/Octotest --quit`
   - Result: scene/scripts parse and project boots headless without runtime script errors.

## 2026-02-25

### Step 24 - Scope update + planning docs overhaul (single-building version)

- Updated `docs/GDD.md` to match revised game scope:
  - indoor gameplay only (single building),
  - open-water moment moved to ending cutscene only,
  - removed camouflage and tangle systems,
  - clarified simple interaction visuals (subtle movement toward targets, no full contact animation).
- Rewrote `docs/TASK_LIST.md` into a literal, step-by-step implementation plan with:
  - pre-production mapping tasks,
  - puzzle-planning tasks,
  - reusable module tasks,
  - explicit content-authoring tasks for room creation.
- Added planning templates:
  - `docs/misc/PUZZLE_PLAN.md`,
  - `docs/misc/room_concepts/ROOM_TEMPLATE.md`.
- Synced docs references:
  - updated `docs/README.md` docs map,
  - updated `docs/PROCEDURES.md` project facts and initialization checklist.

### Validation commands
1. Not run (docs-only changes).

## 2026-02-24

### Step 23 - Office room rescale/layout polish + climb/interaction fixes

- Reworked gameplay room into the target data-office layout and scaled scene elements for consistent proportions.
- Tuned octopus traversal for elevated props:
  - stabilized chair/desk climbing behavior,
  - reduced unwanted climbs onto chair backs,
  - improved post-climb rotation behavior.
- Updated camera follow behavior to keep camera above occluding furniture and reduced focus zoom distance for close interactables.
- Adjusted held-item presentation:
  - refined held-item spacing/orientation (8-direction layout),
  - corrected hold/focus transform behavior so held pickups preserve visual size.
- Fixed focus interaction issues:
  - code panel keypad columns no longer become unclickable due to sibling LOS blocking,
  - card reader insertion now preserves card world scale (no resize on insert/eject cycle).
- Updated scene content with additional office props and pickup placement for interaction testing.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 22 - Unify focus held-item apply/reject routing for future interactables

- Refactored focus held-item click handling in `InteractionController` into one pipeline used by both ray-picked and screen-picked held items.
- Introduced explicit extension points for future focus interactables:
  - `_can_focus_target_accept_held_item(...)`,
  - `_apply_held_item_to_focus_target(...)`,
  - `_get_focus_item_target_position(...)`.
- Kept card-reader behavior unchanged while enabling reject feedback animation for non-applicable held items in code panel focus mode.
- Reject animation target now resolves by focus context:
  - card reader slot for reader focus,
  - focus target position for other focus-enabled objects.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 21 - Add and polish wall code panel (focus-gated keypad)

- Added new wall-mounted `CodePanel` gameplay object on the wall opposite the card reader.
- Implemented keypad with `0-9`, `<<` backspace, and `OK` confirm.
- Integrated with existing focus interaction flow:
  - panel enters focus before keypad input,
  - keypad button interactables are enabled only while that panel is the active focus target.
- Added display feedback and solved-state behavior:
  - `ENTER CODE` (idle),
  - masked typed input,
  - `DENIED` on wrong code then timed reset,
  - latched `GRANTED` on success until next entry attempt.
- Aligned code panel LED visuals with card reader by matching both color values and material properties.
- Tuned panel layout/interaction details through QA fixes:
  - corrected wall-fixed label orientation,
  - reduced overall panel and text size,
  - fixed top-row button interaction blocking via focus-point offset and hit-area tuning.
- Updated scene/script wiring:
  - `scripts/code_panel.gd`,
  - `scenes/main.tscn`,
  - `scripts/main.gd` (focus-target query helper for panel gating).
- Default scene code is set to `1234` on the `CodePanel` node instance.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 20 - Focus interaction + card reader polish and controller modularization

- Implemented focus-mode precision interaction flow:
  - auto-enter focus after approach to `FocusTarget`,
  - movement locked while focused,
  - click-outside exits focus,
  - no item dropping while focused.
- Added `CardReader` gameplay loop with strict one-card occupancy:
  - insert held card,
  - LED states (`EMPTY` yellow, `WRONG` red, `CORRECT` green),
  - click inserted card to eject/retrieve.
- Added robust focus click routing improvements:
  - inserted card click detection while focused,
  - prevention of accidental near-click activations for held-item use,
  - LOS exception handling for colliders within the same reader hierarchy.
- Added feedback motion for invalid item application in focus mode:
  - non-applicable held item moves to reader slot and returns.
- Refactored `InteractionController` responsibilities by extracting helpers:
  - `scripts/focus_reject_feedback.gd` (reject animation state/offset),
  - `scripts/interaction_hint_builder.gd` (HUD hint text assembly).
- Added/updated scripts and scene wiring:
  - `scripts/focus_target.gd`,
  - `scripts/card_reader.gd`,
  - `scripts/main.gd`,
  - `scenes/main.tscn`.
- Added interaction integration coverage:
  - `tests/card_reader_interaction_test.gd`,
  - `scripts/check.sh` now runs this test.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 19 - Refactor gameplay interaction logic out of `main.gd`

- Added `scripts/interaction_controller.gd` and moved interaction-heavy responsibilities out of `main.gd`:
  - interactable raycasts,
  - hover/range/blocked state transitions,
  - queued auto-interact flow,
  - octopus carry/drop behavior,
  - hand-socket layout and held-item transform updates,
  - carry-based movement penalties,
  - interaction HUD hint composition,
  - wall light switch callback wiring.
- Rewrote `scripts/main.gd` as a lean orchestrator:
  - camera orbit/zoom,
  - menu visibility + scene transitions,
  - ground click-to-move,
  - delegation of interaction/drop input to `InteractionController`.
- Updated architecture docs for the new script boundary.

### Validation commands (pass)
1. `/Applications/Godot.app/Contents/MacOS/godot --headless --path . --scene res://scenes/main.tscn --log-file /tmp/octotest-main.log --quit-after 5`
   - Result: gameplay scene boots with no script parse/runtime errors.
2. `./scripts/check.sh`
   - Result: boot smoke test PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`.

### Step 18 - Interactable objects + octopus carry prototype

- Added reusable interaction component:
  - `scripts/interactable.gd`
  - Supports interaction types (`CLICK`, `PICKUP`), visual states (idle/hover/in-range/blocked/held), prompts, and pickup/drop signals.
- Implemented gameplay interaction flow in `scripts/main.gd`:
  - Hover + range + blocked visualization.
  - Click-to-interact and move-closer + queued auto-interact.
  - Clickable held item drop.
  - `F` drop last, `Shift + F` drop all.
- Implemented octopus carry behavior:
  - Up to 8 simultaneously held items.
  - Dynamic hand socket layout in rings to reduce clipping.
  - Movement penalties: slow when heavily loaded, immobilize when full.
- Authored interactables directly in scene (`scenes/main.tscn`):
  - Wall-mounted light switch.
  - Multiple pickup objects for full-hands testing (10 total pickups).
- Fixed local Godot check reliability:
  - `scripts/check.sh` now supports lowercase macOS app binary path and sets explicit writable `--log-file`.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke test PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`.
2. `/Applications/Godot.app/Contents/MacOS/godot --headless --path . --scene res://scenes/main.tscn --log-file /tmp/octotest-main.log --quit-after 5`
   - Result: gameplay scene boots with no script parse/runtime errors.

### Step 17 - GDD review and clarifications

Full review of `docs/GDD.md`. Resolved open design questions and corrected structural issues:

- **Catch/return behaviour**: world state preserved on catch, no cooldown, room puzzle progress resets.
- **Movement**: Octo walks on surfaces inside the station; swimming only in outdoor open-water sections.
- **Save system**: autosave on entering each new room; players can quit and resume.
- **Collectibles**: objects are actionable or not (visually distinct, no UI); fancy things occupy arm slots, no separate inventory.
- **Controls**: PC-first target documented; iPad/Mac input deferred to post-PC review. Removed swipe/pinch references.
- **Scope**: World Bible (Blue Current Research Facility) is now the explicit source of truth for rooms and layout.
- **Arm system**: removed biology breakdown table; simplified to 8 arms with specialisation deferred to prototyping.
- **Roadmap**: added missing Step 5 (pick up / carry / set down); deferred iPad touch input note.
- **TASK_LIST.md**: updated Milestone 5 to reflect PC-first export order and removed iPad-specific performance target.

No code changes. Design docs only.

## 2026-02-23

### Step 16 - Update project icon to octopus PNG
- Updated Godot application icon to use PNG asset:
  - `project.godot` -> `config/icon="res://icon.png"`
- Added icon asset file:
  - `icon.png` (single source for Godot project icon and Git/SourceTree usage)
- Validation:
  - Ran `./scripts/check.sh` -> PASS.

### Step 15 - Import Gone Exploring design docs and split backlog
- Imported the provided source doc into project docs as the initial canonical GDD:
  - `docs/GDD.md`
- Split planning into a separate editable backlog tailored to current repo baseline:
  - `docs/TASK_LIST.md`
- Updated top-level docs map (`docs/README.md`) to link the new game docs.
- Note: `docs/GDD.md` was later refined in-repo (task-list removal, image removal, and tangle marked optional/post-MVP).

### Step 14 - Portable Godot binary detection and docs sync
- Updated `scripts/check.sh` binary resolution to support cross-device setups without per-run path overrides.
- Detection order now:
  - `GODOT_BIN` override
  - `godot4` in `PATH`
  - `godot` in `PATH`
  - `Godot` in `PATH`
  - `/Applications/Godot.app/Contents/MacOS/Godot` (macOS app install)
  - `/ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64` (legacy Linux fallback)
- Updated docs to match current behavior:
  - `docs/README.md`
  - `docs/PROCEDURES.md`
  - `docs/TESTING.md`

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke test + movement math test + slope integration test all passed.

### Step 1 - Project bootstrap
- Confirmed this is an empty Godot 4.6 template project.
- Created baseline folders: `scenes/`, `scripts/`, `tests/`.
- Plan: implement runtime-built 3D cube room, point-and-click player movement with gravity, orbit camera via SpringArm3D, and headless logic tests for movement math.

### Step 2 - Core prototype implementation
- Added `scripts/movement_math.gd` with pure movement logic (`arrived_2d`, `next_velocity_2d`).
- Added `scripts/player_controller.gd`:
  - `CharacterBody3D` click-target movement.
  - Gravity from project settings.
  - Runtime-created cube mesh + collision shape.
- Added `scripts/main.gd`:
  - Runtime cube room (floor, ceiling, 4 walls) with collisions.
  - Point-and-click floor raycast movement.
  - Orbit camera around player with `SpringArm3D` (RMB drag + Q/E orbit, wheel zoom).
- Added `scenes/main.tscn` with player + camera rig + light and script bindings.
- Updated `project.godot` to run `res://scenes/main.tscn`.

### Step 3 - Unit-testable sanity checks
- Added `tests/movement_math_test.gd` for headless movement math validation.
- Next: run `Godot_v4.6.1-stable_linux.x86_64 --headless --script res://tests/movement_math_test.gd` and fix any issues.

### Step 4 - Verification and hardening
- Headless test initially crashed because the sandbox blocked default Godot user paths.
- Resolved test runtime by launching Godot with `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp`.
- Found/Fixed strict typing parse issue in `scripts/main.gd`:
  - Replaced `Variant`-inferred click position with explicit `Vector3` flow.
  - `_raycast_to_ground()` now returns `Vector3` and uses `Vector3.INF` as a no-hit sentinel.

### Validation commands (pass)
1. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --quit-after 5`
   - Result: project boots in headless mode with no script errors.
2. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/movement_math_test.gd`
   - Result: `movement_math_test: PASS`.

### Current status
- Prototype functionality implemented and sanity-checked.
- Dev log is current and can be used to resume from this point.

### Step 5 - Fix visibility and collision-shape authoring
- User-reported issue: scene looked transparent in editor, runtime view was black, and player warned for missing collision shape.
- Root causes:
  - Room/player visuals and collision were generated in `_ready()`, so editor had no authored geometry.
  - Enclosed room could render very dark without an interior light source.
- Fixes:
  - Converted room + player to explicit authored nodes in `scenes/main.tscn`.
  - Added real `CollisionShape3D` and `MeshInstance3D` under `Player`.
  - Added static bodies and collision/mesh children for floor, ceiling, and 4 walls.
  - Added an `OmniLight3D` inside the room.
  - Simplified scripts:
    - Removed runtime room construction from `scripts/main.gd`.
    - Removed runtime mesh/collision creation from `scripts/player_controller.gd`.
- Revalidated:
  - Headless project boot passes.
  - `movement_math_test` still passes.

### Step 6 - Session procedure documentation
- Added `PROCEDURES.md` with AI-agent session initialization rules.
- Documented:
  - Project/Godot paths and startup commands.
  - Branch policy (feature/fix branches, keep `main` stable).
  - Testing policy (always add/update tests where possible, run headless checks).
  - Dev log maintenance requirements.
  - Known pitfalls discovered in this project so far.
- Purpose: reduce re-onboarding time and prevent repeated setup mistakes in future sessions.

### Step 7 - Slope/ramp test branch and movement validation
- Created branch: `feat/slope-ramps`.
- Added authored ramps to main scene (`scenes/main.tscn`) to test slope traversal in gameplay:
  - `Room/RampWest`
  - `Room/RampEast`
- Ramps are on ground collision layer (`collision_layer = 2`) so point-and-click raycasts can target them.
- Added slope-related movement helper in `scripts/movement_math.gd`:
  - `project_planar_direction_on_surface(direction, surface_normal)`
- Updated `scripts/player_controller.gd` to align planar movement direction with floor slope when grounded.
- Expanded unit tests in `tests/movement_math_test.gd` with slope projection checks.
- Added headless physics integration test assets:
  - `tests/slope_movement_test_scene.tscn`
  - `tests/slope_movement_test.gd`
- Found/fixed a ramp placement issue during testing (initially too high above floor, causing failed uphill/downhill checks).

### Validation commands (pass)
1. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --quit-after 5`
2. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/movement_math_test.gd`
3. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/slope_movement_test.gd`

### Step 14 - Main menu and in-game UI
- Added startup menu scene and script:
  - `scenes/main_menu.tscn`
  - `scripts/main_menu.gd`
- Main menu has `Play` and `Quit` actions.
- Switched startup scene in `project.godot`:
  - `run/main_scene="res://scenes/main_menu.tscn"`
- Added gameplay UI under `scenes/main.tscn`:
  - HUD key-hint panel anchored in a corner.
  - In-game menu with `Main Menu` and `Quit` buttons.
- Updated `scripts/main.gd`:
  - `Esc` toggles in-game menu visibility.
  - Menu visibility blocks gameplay input while open.
  - HUD controls are forced to `MOUSE_FILTER_IGNORE` so gameplay remains clickable through hint UI.
  - Added scene return (`Main Menu`) and app quit handlers.
- Updated docs for the new scene flow and manual QA:
  - `docs/README.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROCEDURES.md`
  - `docs/TESTING.md`

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke test PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`.

### Step 13 - Stair implementation research note
- Added `docs/misc/STAIRS.md` with a practical Godot stair-handling guide.
- Documented the most reliable pattern seen in practice:
  - pre-move step-up probe,
  - normal `move_and_slide()`,
  - post-move step-down probe.
- Included parameter tuning guidance (`step_height_max`, `floor_snap_length`, `safe_margin`) and geometry pitfalls.
- Linked the new note from `docs/README.md` so it is discoverable during session restarts.

### Step 11 - Canonical branch reset and restart hardening
- Synced `main` with latest work (merged prior `master` history forward into `main`).
- Set workflow docs to treat `main` as canonical stable branch.
- Added missing restart docs:
  - `README.md` (quickstart, controls, run/validate commands, docs map).
  - `TESTING.md` (automated + manual visual QA checklist).
- Added unified validation script:
  - `scripts/check.sh` (boot smoke + movement math test + slope integration test).
- Added additional hard-won pitfalls not previously centralized:
  - Transparent windows need real wall openings to reveal sky.
  - Ramp base alignment matters; floating ramps cause false slope failures.
- Validation:
  - Ran `./scripts/check.sh` -> PASS.

### Step 12 - Reorganize textures and docs folders
- Moved texture assets:
  - `icon.svg` -> `assets/textures/icon.svg`
  - `icon.svg.import` -> `assets/textures/icon.svg.import`
- Updated `project.godot` icon path to `res://assets/textures/icon.svg`.
- Moved documentation files under `docs/`:
  - `docs/README.md`
  - `docs/PROCEDURES.md`
  - `docs/ARCHITECTURE.md`
  - `docs/TESTING.md`
  - `docs/DEVLOG.md`
- Updated doc cross-references to use `docs/...` paths from project root.

### Step 10 - Merge room-window visuals and add architecture docs
- Merged `feat/room-scale-windows` into `master` (fast-forward).
- Added `ARCHITECTURE.md` documenting:
  - Scene hierarchy responsibilities.
  - Script/module boundaries.
  - Movement data flow.
  - Test architecture and extension points.
- Updated `PROCEDURES.md` to require architecture maintenance:
  - Session init now includes reading `ARCHITECTURE.md`.
  - Added dedicated architecture maintenance rules.
  - End-of-session checklist now requires architecture doc updates for structural changes.

### Step 8 - Room scale and glass windows pass
- Created branch: `feat/room-scale-windows`.
- Updated authored room dimensions in `scenes/main.tscn`:
  - Floor expanded from 20x20 to 32x32.
  - Wall height increased from 6 to 9.
  - Ceiling raised accordingly.
- Added four collidable transparent window blocks on north/south walls:
  - `WindowNorthLeft`, `WindowNorthRight`, `WindowSouthLeft`, `WindowSouthRight`.
  - Added dedicated transparent glass-like material (`StandardMaterial3D_window`).
- Slightly moved ramps farther from center to keep room flow balanced in larger layout.
- Increased interior omni light height/range/energy to better illuminate the larger volume.

### Validation commands (pass)
1. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --quit-after 5`
2. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/movement_math_test.gd`
3. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/slope_movement_test.gd`

### Step 9 - Window openings + visual palette refresh
- Reworked room wall authoring in `scenes/main.tscn`:
  - Replaced monolithic north/south walls with segmented wall blocks around each window aperture.
  - Result: actual holes exist behind window blocks, so outside sky is visible through glass.
- Added `WorldEnvironment` with procedural sky so openings show a proper sky backdrop.
- Retuned room materials to a muted, less depressing color palette (non-acidic, lower contrast than player):
  - Wall: soft blue-gray.
  - Floor: desaturated slate.
  - Ceiling: warm neutral.
  - Ramp: muted green-gray.
  - Window glass: softer cyan tint.

### Validation commands (pass)
1. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --quit-after 5`
2. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/movement_math_test.gd`
3. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64 --headless --path /ssd2/projects/godot/octotest --script res://tests/slope_movement_test.gd`
