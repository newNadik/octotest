# Project Architecture

This document describes the current runtime architecture of the prototype and must be updated when structural changes are made.

## High-Level Runtime

1. `res://scenes/main_menu.tscn` is the startup scene.
2. `MainMenu` (`Control`) owns menu UI flow into gameplay (`Play`) or app exit (`Quit`).
3. `res://scenes/main.tscn` is the gameplay scene.
4. `Main` (`Node3D`) owns world setup, camera behavior, click-to-move input routing, and in-game UI menu flow.
5. `Player` (`CharacterBody3D`) is instanced from `res://scenes/player.tscn` and owns locomotion, gravity handling, and slope alignment.
6. `Room` contains authored static geometry for the office layout (floor, ceiling, walls, windows, doors, desks, chairs, console, storage/tank props).
7. `Interactables` contains authored clickable and pickup objects (`Area3D` + `RigidBody3D`/`StaticBody3D`), including focus-enabled objects such as `CardReader` and `CodePanel`.
8. `WorldEnvironment` provides sky/background visuals visible through wall openings.

## Scene Graph Responsibilities

1. `Main`:
- Script: `res://scripts/main.gd`
- Handles mouse raycast targeting on ground collision layer.
- Handles orbit camera controls (RMB drag, Q/E yaw, wheel zoom).
- Handles in-game menu (`Esc` toggle) with `Main Menu` and `Quit` actions.
- Delegates interaction/carry systems to `InteractionController`.
2. `UI` (`CanvasLayer`) in gameplay scene:
- `HUD` contains key hints anchored to screen corner.
- HUD controls are set to ignore mouse input so world clicks pass through.
- `InGameMenu` blocks world input while visible and routes button actions.
3. `WorldEnvironment`:
- Provides procedural sky and ambient environment settings.
4. `Room`:
- `Floor` uses ground collision layer for click-to-move raycast targeting.
- `Ceiling` and wall pieces use wall collision layer for physical boundaries.
- Includes authored office set dressing and climbable elevated surfaces (chairs/desks).
- Includes window/skylight geometry and door/cabinet blocking geometry used for navigation/LOS.
5. `Player`:
- Is authored as a reusable scene instance (`res://scenes/player.tscn`) in `main.tscn`.
- Uses `CollisionShape3D` + `PlayerVisual` (`Node3D`) with imported octo model (`res://assets/models/octo/octo.glb`).
- Updated each physics frame by `player_controller.gd`.
6. `Interactables`:
- `LightButton` (`StaticBody3D`) with `Interactable` child for click interaction.
- Multiple pickup objects (`RigidBody3D`) with `Interactable` child areas.
- `CardReader` (`StaticBody3D`) with `Interactable` and `FocusTarget` children for zoomed precision interaction.
- `CodePanel` (`StaticBody3D`) with `Interactable` + `FocusTarget` on the host and keypad button interactables that are enabled only during active focus.
- All interactables use collision layer 8 for interaction raycasts.
7. Camera rig:
- `CameraPivot -> CameraYaw -> CameraPitch -> SpringArm3D -> Camera3D`.
- Pivot follows player position.

## Script Architecture

1. `res://scripts/main_menu.gd`
- Handles startup menu button actions.
- Changes to gameplay scene on `Play`.
- Quits app on `Quit`.
2. `res://scripts/main.gd`
- Lightweight scene orchestrator.
- Owns camera orbit/zoom behavior.
- Initializes camera pivot follow position during `_ready()` to avoid first-frame startup pop.
- Owns in-game menu visibility and scene change/quit actions.
- Routes click-to-move and delegates interact/drop input to `InteractionController`.
- Owns focus-mode transitions (auto-enter after approach, movement lock, click-based exit rules).
3. `res://scripts/player_controller.gd`
- Character movement state (`_target_position`, `_has_target`).
- Gravity and grounded handling.
- Uses `MovementMath.next_velocity_2d()` for planar acceleration/deceleration.
- Uses `MovementMath.project_planar_direction_on_surface()` to keep movement stable on slopes.
- Includes click-to-climb mantle logic with landing-footprint validation for stable chair/desk climbing.
4. `res://scripts/movement_math.gd`
- Pure helper math (no scene dependencies).
- Designed for headless logic testing.
5. `res://scripts/interactable.gd`
- Reusable `Area3D` interaction component.
- Encapsulates interaction type (`CLICK`, `PICKUP`), range, prompts, held-state toggles, and visual overlays.
- Emits `clicked`, `picked_up`, and `dropped` signals for gameplay-specific reactions.
6. `res://scripts/interaction_controller.gd`
- Centralized interaction and carry system.
- Handles interactable raycasts, hover state transitions, line-of-sight and range checks, and queued auto-interact.
- Handles octopus hand-socket layout, held-item updates, targeted drop, and carry movement penalties.
- Handles wall-switch callback, HUD interaction hints, and focus-mode interaction routing.
- Handles same-object-family LOS exceptions for focus interactions (card reader/code panel subparts).
- Preserves held item global scale while attached/focused.
- Provides a unified focus-held item application pipeline with extension points:
  - `_can_focus_target_accept_held_item(...)`,
  - `_apply_held_item_to_focus_target(...)`,
  - `_get_focus_item_target_position(...)`.
7. `res://scripts/focus_target.gd`
- Configures per-object focus behavior (anchor, click-outside threshold, optional angle overrides, solved-state auto-exit).
8. `res://scripts/card_reader.gd`
- Manages card reader state (`EMPTY`, `WRONG`, `CORRECT`), LED state, insertion/ejection, and slot anchors.
- Preserves inserted card world scale when snapping into the slot.
9. `res://scripts/focus_reject_feedback.gd`
- Encapsulates short "apply failed" item motion toward slot and return.
10. `res://scripts/interaction_hint_builder.gd`
- Builds HUD hint text from controller state so text policy is not embedded in interaction flow logic.
11. `res://scripts/code_panel.gd`
- Runtime-builds keypad geometry and interactables.
- Enforces focus-gated keypad input.
- Handles code-entry state (`ENTER CODE`, masked input, `DENIED`, latched `GRANTED`) and LED material-state transitions.

## Movement Data Flow

1. User clicks floor/ramp.
2. `main.gd` raycasts against ground layer and sends target to player when in-game menu is hidden.
3. `player_controller.gd` computes planar velocity toward target.
4. If grounded, planar direction is projected onto floor tangent for slope handling.
5. Gravity is applied when airborne.
6. `move_and_slide()` resolves motion/collision.
7. Interact clicks either execute immediately (in range) or queue movement + auto-interact when close.

## Test Architecture

1. `res://tests/movement_math_test.gd`
- Pure logic tests for `movement_math.gd` helpers.
2. `res://tests/slope_movement_test.gd`
- Headless integration test validating uphill/downhill traversal with gravity.
- Uses `res://tests/slope_movement_test_scene.tscn`.
3. `res://tests/card_reader_interaction_test.gd`
- Headless integration test validating reader insert/eject and occupied-slot behavior.

## Extension Points

1. Add new gameplay math to `movement_math.gd` first when testable in isolation.
2. Add physics integration tests under `tests/` for interaction-heavy behavior.
3. Keep room geometry authored in scene files when editor visibility matters.

## Update Policy

When changing scene hierarchy, collision layers, movement flow, or test strategy:

1. Update this file in the same branch/commit set.
2. Update `docs/PROCEDURES.md` only if workflow expectations also change.
3. Add a `docs/DEVLOG.md` entry summarizing architectural impact.
