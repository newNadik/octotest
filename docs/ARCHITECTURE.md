# Project Architecture

This document describes the current runtime architecture of the prototype and must be updated when structural changes are made.

## High-Level Runtime

1. `res://scenes/main_menu.tscn` is the startup scene.
2. `MainMenu` (`Control`) owns startup UI flow (`New Game`, `Load Game` placeholder, `Settings`, `Quit`) and slideshow presentation.
3. `res://scenes/main.tscn` is the gameplay scene.
4. `Main` (`Node3D`) owns world setup, camera behavior, click-to-move input routing, and in-game UI menu flow.
5. `Player` (`CharacterBody3D`) is instanced from `res://scenes/player.tscn` and owns locomotion, gravity handling, and slope alignment.
6. Navigation data is scene-authored (`NavigationRegion3D` + `NavigationMesh`) and consumed by the player's runtime `NavigationAgent3D` when present.
7. `Room` contains authored static geometry for the office layout (floor, ceiling, walls, windows, doors, desks, chairs, console, storage/tank props).
8. `Interactables` contains authored clickable and pickup objects (`Area3D` + `RigidBody3D`/`StaticBody3D`), including focus-enabled objects such as `CardReader` and `CodePanel`.
9. `WorldEnvironment` provides sky/background visuals visible through wall openings.
10. `FishSchool` instances (for example `FishSchoolSkylight`) run procedural animated fish waves inside authored swim volumes around/over the station.
11. `CausticRig` instances under `lights` project animated caustics onto nearby geometry using spotlight projector textures.

## Scene Graph Responsibilities

1. `Main`:
- Script: `res://scripts/core/main.gd`
- Handles mouse raycast targeting on ground collision layer.
- Handles simplified pointer controls:
  - click/tap for move/interact,
  - drag with primary pointer for orbit,
  - wheel/pinch for zoom.
- Handles in-game pause menu (`Esc` toggle) with `Resume`, `Settings`, and `Main Menu` actions.
- Opens settings as an in-scene overlay from pause flow and restores pause menu focus on close.
- Delegates interaction/carry systems to `InteractionController`.
2. `UI` (`CanvasLayer`) in gameplay scene:
- `HUD` contains key hints anchored to screen corner.
- HUD controls are set to ignore mouse input so world clicks pass through.
- `InGameMenu` blocks world input while visible and routes pause actions.
3. `WorldEnvironment`:
- Provides procedural sky and ambient environment settings.
- Owns underwater depth readability profile via exponential + depth fog plus volumetric fog.
- Current tuning intent: near exterior terrain visible through windows, far exterior fades into dark ocean.
4. `Room`:
- `Floor` uses ground collision layer for click-to-move raycast targeting.
- `Ceiling` and wall pieces use wall collision layer for physical boundaries.
- Includes authored office set dressing and climbable elevated surfaces (chairs/desks).
- Includes window/skylight geometry and door/cabinet blocking geometry used for navigation/LOS.
5. `Player`:
- Is authored as a reusable scene instance (`res://scenes/player.tscn`) in `main.tscn`.
- Uses `CollisionShape3D` + `PlayerVisual` (`Node3D`) with imported octo model (`res://assets/models/octo/octo.glb`).
- `PlayerVisual` runs `res://scripts/rig/OctoRig.gd`, which resolves the model `Skeleton3D` and builds procedural rig wrappers (`OctoHead` + `OctoArm` objects).
- Updated each physics frame by `player_controller.gd`.
6. `Interactables`:
- `LightButton` (`StaticBody3D`) with `Interactable` child for click interaction.
- Multiple pickup objects (`RigidBody3D`) with `Interactable` child areas.
- `CardReader` (`StaticBody3D`) with `Interactable` and `FocusTarget` children for zoomed precision interaction.
- `CodePanel` (`StaticBody3D`) with `Interactable` + `FocusTarget` on the host and keypad button interactables that are enabled only during active focus.
- All interactables use collision layer 8 for interaction raycasts.
7. Station interior door prefabs:
- `res://scenes/station/interior/door_slide.tscn` is a reusable interactive sliding leaf with:
  - click-to-open interaction,
  - state-indicator button colors (allowed/openable vs moving/locked),
  - delayed auto-close with doorway occupancy safety sensor (player/items block close).
- `res://scenes/station/interior/door_single.tscn` and `res://scenes/station/interior/door_double.tscn` wrap one or two slide leaves and expose group lock state.
- Double-door wrapper propagates open requests to both leaves, supports per-leaf travel distance overrides, and synchronizes hover highlight across both sides.
8. Camera rig:
- `CameraPivot -> CameraYaw -> CameraPitch -> SpringArm3D -> Camera3D`.
- Pivot follows player position.
9. `FishSchool` (`Node3D`):
- Scene: `res://scenes/station/fish_school.tscn`.
- Runtime children:
  - `FishRoot` hosts spawned animated fish instances.
  - `SwimVolume/CollisionShape3D` provides optional authored volume source.
  - `VolumePreview` is editor-only sizing preview.
- Supports timed school lifecycle (spawn -> cross volume -> despawn -> random delay), species selection limits per school, and directional modes.
10. `CausticRig` (`Node3D`):
- Scene: `res://scenes/effects/caustic_rig.tscn`.
- Script: `res://scripts/lighting/caustic_rig.gd`.
- Hosts projected `SpotLight3D` caustic lights.
- Applies `light_projector` textures to child lights and animates slow counter-rotation plus mild energy pulsing.
- Supports either an authored `projector_texture` or a generated fallback cookie when no texture is assigned.

## Script Architecture

1. `res://scripts/ui/main_menu.gd`
- Handles startup menu button actions.
- Changes to gameplay scene on `New Game`.
- Emits placeholder warnings for `Load Game`.
- Opens `res://scenes/ui/settings_menu.tscn` as an overlay for `Settings`.
- Quits app on `Quit`.
2. `res://scripts/core/main.gd`
- Lightweight scene orchestrator.
- Owns camera orbit/zoom behavior.
- Initializes camera pivot follow position during `_ready()` to avoid first-frame startup pop.
- Owns in-game pause menu visibility and scene-change actions.
- Opens `res://scenes/ui/settings_menu.tscn` as an overlay from pause menu and closes it with back/`Esc`.
- Routes click-to-move and delegates interact/drop input to `InteractionController`.
- Owns focus-mode transitions (auto-enter after approach, movement lock, click-based exit rules).
- Drives underwater directional-light animation/pulse behavior.
- Reads shared pulse from `Node3D/GodRays` and applies synchronized `DirectionalLight3D` energy pulsing using:
  - `main_light_min_factor`
  - `main_light_max_factor`
  - `main_light_sway_enabled`
  - `sync_main_light_with_god_rays`
3. `res://scripts/ui/settings_menu.gd`
- Shared settings UI controller used from both startup and pause flows.
- Supports overlay mode (close signal + fast close path) and standalone scene mode.
- Persists and applies settings through `/root/GameSettings`:
  - music and SFX volume,
  - subtitles toggle,
  - locale (`en_GB`, `uk_UA`).
- Applies translatable labels at runtime (`tr(...)`).
- Generates custom slider grabber icon to match menu visual style.
4. `res://scripts/player/player_controller.gd`
- Character movement state (`_target_position`, `_has_target`).
- Gravity and grounded handling.
- Owns runtime `NavigationAgent3D` setup for click path-following on navmesh.
- Uses navmesh path points when reachable; falls back to direct click target movement when navmesh is missing/unreachable.
- Uses `MovementMath.next_velocity_2d()` for planar acceleration/deceleration.
- Uses `MovementMath.project_planar_direction_on_surface()` to keep movement stable on slopes.
- Includes click-to-climb mantle logic with landing-footprint validation for stable chair/desk climbing.
- Runs a climb pre-mantle sequence before body translation:
  - smooth turn toward click direction,
  - first front-arm reach, then second front-arm reach,
  - brief transition into mantle.
- Keeps surface crawl pose updates active during pre-mantle + mantle so arms continue moving while climbing.
- Adds climb-specific visual feedback on `PlayerVisual`:
  - blocked-move "no" wiggle when overloaded,
  - subtle climb head tilt blend during pre-mantle/mantle.
5. `res://scripts/core/movement_math.gd`
- Pure helper math (no scene dependencies).
- Designed for headless logic testing.
6. `res://scripts/interaction/interactable.gd`
- Reusable `Area3D` interaction component.
- Encapsulates interaction type (`CLICK`, `PICKUP`), range, prompts, held-state toggles, and visual overlays.
- Supports two highlight presentation modes:
  - shader-outline highlight for meshes collected from `visual_root_path` / `highlight_mesh_paths`,
  - reveal-mesh highlight for authored nodes listed in `highlight_visible_paths`.
- Owns world-space indicator-dot rendering and placement:
  - per-object anchor path override (`indicator_anchor_path`),
  - per-object local offset (`indicator_local_offset`) and camera-facing bias (`indicator_camera_bias`),
  - camera-facing sprite orientation and fixed-size marker rendering.
- Emits `clicked`, `picked_up`, and `dropped` signals for gameplay-specific reactions.
- Exposes current visual-state query via `get_visual_state()` for group-level visual sync systems.
7. `res://scripts/interaction/interaction_controller.gd`
- Centralized interaction and carry system.
- Handles interactable raycasts, hover state transitions, line-of-sight and range checks, and queued auto-interact.
- Handles octopus hand-socket layout, held-item updates, targeted drop, and carry movement penalties.
- Blocks move/approach click intents when fully loaded and triggers blocked-move feedback instead of queuing locomotion.
- Assigns held items to persistent arm-linked slots (mid-arm priority first) and syncs occupied slots to `OctoRig` hold-arm state.
- Uses rig-driven hold anchoring (`OctoRig` arm anchors) plus size-aware clearance so larger held objects avoid clipping while cards stay tight to arm tips.
- Handles wall-switch callback, HUD interaction hints, and focus-mode interaction routing.
- Uses world-geometry-focused LOS checks for blocked state while still allowing focus interaction against target-host colliders.
- Preserves held item global scale while attached/focused.
8. `res://scripts/lighting/god_rays.gd`
- Controls center volumetric shaft presentation (`RoofShaft`, `RoofShaftFillA`, `RoofShaftFillB`).
- Animates shaft sway and pulse over time.
- Exposes shared pulse values (`master_pulse_normalized`, `master_pulse_01`) so other lighting systems can lock to the same phase.
- Provides a unified focus-held item application pipeline with extension points:
  - `_can_focus_target_accept_held_item(...)`,
  - `_apply_held_item_to_focus_target(...)`,
  - `_get_focus_item_target_position(...)`.
9. `res://scripts/lighting/caustic_rig.gd`
- Controls the projected caustics spotlight rig.
- Assigns projector cookies to child spotlights at runtime.
- Animates counter-rotation and subtle brightness pulsing.
- Generates a procedural fallback projector texture if no authored texture is supplied.
10. `res://scripts/interaction/focus_target.gd`
- Configures per-object focus behavior (anchor, click-outside threshold, optional angle overrides, solved-state auto-exit).
11. `res://scripts/interaction/card_reader.gd`
- Manages card reader state (`EMPTY`, `WRONG`, `CORRECT`), LED state, insertion/ejection, and slot anchors.
- Preserves inserted card world scale when snapping into the slot.
12. `res://scripts/interaction/focus_reject_feedback.gd`
- Encapsulates short "apply failed" item motion toward slot and return.
13. `res://scripts/interaction/interaction_hint_builder.gd`
- Builds HUD hint text from controller state so text policy is not embedded in interaction flow logic.
14. `res://scripts/interaction/code_panel.gd`
- Runtime-builds keypad geometry and interactables.
- Enforces focus-gated keypad input.
- Handles code-entry state (`ENTER CODE`, masked input, `DENIED`, latched `GRANTED`) and LED material-state transitions.
15. `res://scripts/rig/OctoRig.gd`
- Procedural rig bootstrap around imported octopus skeleton.
- Accepts manual bone assignment for head + arms using `HEAD_BONE_NAMES` and `ARM_CONFIGS`.
- Applies section-based arm bend targets (`base/mid/tip`, each with `bend` + `bend_angle`).
- Blends section influence across the full chain to avoid segmented transitions.
- Runs a per-arm animation mixer (`STATIC`/`IDLE`/`CRAWL`/`HOLD`) with runtime arm-level overrides.
- Uses `OctoSurfaceLocomotion` for crawl locomotion and pose driving:
  - arm state machine (`SEARCH`/`REACH`/`GRAB`/`PUSH_PULL`/`RELEASE`),
  - reach/anchor target solving against floor via ray queries,
  - support-normal aggregation and body drive velocity output,
  - phase-role pose synthesis (`plant`/`load`/`push`/`stabilize`/`recover`/`swing`) mapped to arm sections.
- Surface animation ownership is explicit:
  - `OctoSurfaceLocomotion` owns crawl targets and no-command settle targets.
  - `OctoRig` applies post-overrides only (idle handoff for non-hold arms, hold override for occupied arms).
- Crawl cadence uses two 4-arm cohorts with `gait_duty_cycle` in `[0..1]` and normalized propulsion by active pushing-arm count to reduce uneven slide pulses.
- Exposes hold-arm priority ordering and per-arm world anchors for carry-slot alignment in `InteractionController`.
- Idle mode includes per-arm deterministic variation plus per-idle-entry randomized offsets/signs so repeated stop->idle transitions do not snap to a single identical pose.
- Supports editor-time preview modes (`Static Targets`, `Idle`, `Crawl`, `Mixer`, `Hold`) while temporarily suspending local `AnimationPlayer` playback.
- Crawl preview uses the same cycle-speed math as gameplay, with `preview_motion_speed` as the preview-side speed input.
- Validates rig data on startup and prints debug summaries.
16. `res://scripts/rig/OctoArm.gd`
- Per-arm data model with role metadata (`side`, `role_bias`), resolved indices, base/mid/tip partitions, and rest rotation cache.
- Stores runtime control fields (`current_state`, `phase_offset`, held-item/target references) and bend parameters.
17. `res://scripts/rig/OctoHead.gd`
- Head-chain data model mirroring arm setup patterns (resolved indices, grouped parts, rest pose caches).
18. `res://scripts/station/interior/door_slide.gd`
- Sliding-door leaf controller.
- Handles open/close tweening, lock state, clickable open requests, indicator-button materials, auto-close timing, and doorway blockage checks.
 - Exposes group-highlight source/override helpers so double-door wrappers can mirror leaf visual state without creating permanent hover-feedback loops.
19. `res://scripts/station/interior/door_lock_group.gd`
- Single/double door group controller.
- Propagates lock state to leaf doors, fans open requests across all leaves, applies per-leaf open-distance overrides, and synchronizes double-door highlight state.
- For double doors, computes a shared midpoint indicator position from leaf interactable indicator world positions and applies it as the primary override marker.
20. `res://scripts/station/fish_school.gd`
- School controller for animated fish waves:
  - spawns fish scene instances from folder/pool,
  - simulates schooling motion (flow/cohesion/alignment/separation),
  - supports per-wave direction modes and random heading variation,
  - enforces compact pack movement through a configured volume,
  - handles wave timing and despawn/restart cycle.
21. `res://scripts/station/fish_school_utils.gd`
- Utility helpers for fish-school direction selection, heading variation, random ranges, and species subset selection.

## Script Directory Layout

Scripts are grouped by runtime domain to keep ownership boundaries clear:

1. `res://scripts/core/`
- Scene orchestration and shared gameplay math.
- Current files: `main.gd`, `movement_math.gd`, `game_settings.gd`.
2. `res://scripts/ui/`
- UI scene controllers.
- Current files: `main_menu.gd`, `settings_menu.gd`.
3. `res://scripts/player/`
- Player locomotion/controller logic.
- Current files: `player_controller.gd`.
4. `res://scripts/interaction/`
- Reusable interactable components and interaction systems.
- Current files: `interactable.gd`, `interaction_controller.gd`, `focus_target.gd`, `card_reader.gd`, `code_panel.gd`, `focus_reject_feedback.gd`, `interaction_hint_builder.gd`.
5. `res://scripts/rig/`
- Procedural octopus rig wrapper and arm/head data models.
- Current files: `OctoRig.gd`, `OctoSurfaceLocomotion.gd`, `OctoArm.gd`, `OctoHead.gd`.
6. `res://scripts/lighting/`
- Lighting presentation controllers.
- Current files: `god_rays.gd`, `caustic_rig.gd`, `sun_ray_rig.gd`.
7. `res://scripts/station/interior/`
- Station interior interactive door controllers.
- Current files: `door_slide.gd`, `door_lock_group.gd`.
8. `res://scripts/station/`
- Station ambient/world simulation systems.
- Current files: `fish_school.gd`, `fish_school_utils.gd`.

## Movement Data Flow

1. User clicks floor/ramp.
2. `main.gd` raycasts against ground layer and sends target to player when in-game menu is hidden.
3. `player_controller.gd` updates click target and refreshes `NavigationAgent3D` target.
4. If navmesh path is reachable, movement uses the next nav path position; otherwise movement uses direct click target fallback.
5. If grounded, planar direction is projected onto floor tangent for slope handling.
6. Gravity is applied when airborne.
7. `move_and_slide()` resolves motion/collision.
8. Interact clicks either execute immediately (in range) or queue movement + auto-interact when close.

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
