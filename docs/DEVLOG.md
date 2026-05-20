# Dev Log

## 2026-05-20

### Step 58 - Room layer splitting and loading system refactor

**Room scene splitting**

All station rooms now split into two scene layers:
- `_arch.tscn` — walls, floor, ceiling, collision, nav mesh, lights, occluders. Always loaded when a room is in range.
- `_details.tscn` — furniture and items. Loaded alongside arch; appears shortly after since arch is smaller.
- `_room.tscn` — kept as an editor-only preview that instances both layers.

Each room now lives in its own subfolder (e.g. `scenes/station/atrium/`). `surrounding_full.tscn` is unchanged (effects only, no details layer).

**Room streaming refactor (`main.gd`)**

`ROOM_REGISTRY` entries now use `layers: Array[String]` instead of `path` + `details_path`. The streaming system was rewritten around this:
- `_queue_room(room_name)` — starts threaded loads for all pending layers simultaneously.
- `_load_room_arch_sync(room_name)` — sync-loads layer 0 from cache (instant on startup); used for rooms preloaded by the loading screen.
- `_add_layer_node(room_name, layer, inst, path)` — shared instantiation path for both sync and async. Layer 0 also registers nav regions, adds hub seam light, applies exit codes, connects autosave doors.
- Pending loads tracked in a single `_stream_pending` dict keyed `"room_name:layer_idx"` (was five separate dicts).
- `_check_if_should_start_deferred()` fires `surrounding` only after all non-deferred arch (layer 0) loads finish.
- Always-keep rooms that are far from the player (e.g. atrium when player is in chem_lab) now load async instead of blocking the main thread for 12+ seconds.
- `player.room` is now saved in the save payload so the loading screen knows the exact room to preload on continue.

**Loading screen refactor (`loading_screen.gd`)**

Two-phase sequential loading preserved; phase 1 logic unified into a single `_start_phase_1()` that drains `_phase1_paths`:
- **New game**: all layers of the nearest room (arch + details preloaded so player spawns with no pop-in).
- **Continue game**: all layers of the saved room (`player.room` from save data) + arch only of other rooms within `INITIAL_LOAD_RADIUS`. Arch-only rooms are sync-loaded from cache at game start; their details queue async immediately after and arrive in the background.
- `ROOM_PATHS` uses the same `layers` array format as `ROOM_REGISTRY`.

## 2026-05-05

### Step 57 - Door access logic, indicator overhaul, and card-reader integration

- Rewrote inside/outside detection in `door_lock_group.gd`:
  - Uses the group node's own world orientation instead of the clicked slide's orientation so double-door leaves (door_slide2 rotated 180°) give consistent results.
  - Convention: group's **+Z axis faces outside**. Doors should be oriented accordingly in the editor.
  - CARD_LOCKED doors open freely from inside; require card from outside.
  - `grant_access_and_open` no longer sets `_authorized_next_open`, preventing the door from staying unlocked after auto-close.

- Replaced single `button` indicator mesh with two separate LED meshes per leaf (`door_indicator_front`, `door_indicator_back`):
  - Colors match card reader scheme: green (unlocked/accessible), yellow (card required), red (disabled).
  - Front/back assignment auto-detects door_slide2's 180° flip via X-basis dot product.
  - Inside face (room side) always shows green when the door is openable from inside; outside face shows yellow when card is required.

- Added 2-pulse blink feedback to door indicators:
  - **Green blink**: door opens (from inside click or card grant).
  - **Red blink**: unauthorized outside click on CARD_LOCKED door, click on DISABLED door, or wrong/insufficient card at reader.
  - Ongoing blink is cancelled and restarted if a new event fires during playback.

- DISABLED doors now allow player interaction (prompt: "Locked") so the red blink feedback is visible rather than silently ignoring clicks.

- Card reader exits focus mode (deferred) on successful card tap, and calls `signal_access_denied()` on the linked door group when a card is rejected.

## 2026-04-29

### Step 56 - TV and computer screen image support + computer screensaver proximity

- Added `res://scripts/station/items/screen_display.gd`: a `@tool` script attached to `wall_tv` and `computer` root nodes.
  - Exports `screen_image: Texture2D`; when assigned, duplicates the `screen_mesh` surface material and applies it to both `albedo_texture` and `emission_texture` so the screen appears self-lit.
  - Each scene instance can show a different image; setter runs in-editor so the result is visible during authoring without entering play mode.
- Added `res://scripts/station/items/computer_proximity.gd`: an `Area3D` script on a new `ProximityArea` child of the `computer` scene.
  - Detects the player entering the desk area (collision mask targets player layer `1 << 2` only).
  - On entry: hides `Node3D/Monitor_2/black_screen` and starts a 45-second timer.
  - On timeout: restores `black_screen` (screensaver-style behaviour).
  - Re-entry resets the countdown.
- Updated `scenes/station/items/wall_tv.tscn` and `scenes/station/items/computer.tscn` to attach `screen_display.gd` to each scene's root node.
- Updated `scenes/station/items/computer.tscn` with a new `ProximityArea` (`Area3D`) + `CollisionShape3D` (`BoxShape3D`) for proximity detection.

## 2026-04-28

### Step 55 - Distance-based station room streaming

- Added room streaming to gameplay scene orchestration in `res://scripts/core/main.gd`.
- Streaming now tracks room instances under `station` and updates them by player distance with hysteresis:
  - load within `room_load_distance`,
  - unload beyond `room_unload_distance`.
- Added exported tuning controls:
  - `room_streaming_enabled`,
  - `room_load_distance`,
  - `room_unload_distance`,
  - `room_names_to_always_keep`.
- Default always-loaded room list includes `atrium` to keep spawn/menu-adjacent space stable.
- Streaming updates are throttled (`ROOM_STREAM_UPDATE_INTERVAL_SEC`) to reduce runtime churn.

## 2026-04-22

### Step 54 - Gift-shop spinning rack interaction and audio pass

- Added a new interactable spinning rack item:
  - `res://scenes/station/items/spinning_rack.tscn`
  - `res://scripts/station/items/spinning_rack.gd`
- Wired rack interaction through the shared `Interactable` flow (`clicked` signal) so player click triggers spin.
- Tuned rack behavior to a slower comedic spin profile:
  - `spin_degrees_per_click = 540`
  - `spin_duration = 5.2`
- Added rack SFX integration:
  - new sound asset `res://assets/sound/metal_squeak.wav`,
  - one-shot playback per click with no restart if the previous sound is still playing.
- Added per-click pitch variation to avoid repetitive playback:
  - `spin_sound_pitch_min` / `spin_sound_pitch_max` exports.
- Removed prior fade-out logic after SFX workflow decision to use a single trimmed squeak.
- Updated station props checklist to mark gift-shop spinning rack/books item as complete.

## 2026-04-20

### Step 53 - In-world rigged clock + game-time system

- Added a new rigged wall clock scene and runtime controller:
  - `res://scenes/station/items/clock.tscn`
  - `res://scripts/station/items/clock.gd`
  - integrated into atrium room placement.
- Fixed runtime scene override that disabled clock logic on the atrium instance (`script = null` removed).
- Added in-game time singleton:
  - `res://scripts/core/game_time.gd`
  - autoloaded as `/root/GameTime` in `project.godot`.
- Wired gameplay startup/save/load to game-time state in `res://scripts/core/main.gd`:
  - `New Game` initializes clock time to `17:00`,
  - `Continue`/load restores saved `game_time`,
  - save payload now includes `game_time.seconds_of_day`.
- Updated wall-clock behavior:
  - reads time from `/root/GameTime` (system-time fallback only if singleton missing),
  - second-hand smoothing toggle now works for in-game time too.
- Pause behavior:
  - in-game time uses `PROCESS_MODE_PAUSABLE`, so time stops while paused and continues on resume.

## 2026-04-17

### Step 52 - Async game loading screen + main-menu background preload

- Added a dedicated loading transition scene:
  - `res://scenes/ui/loading_screen.tscn`
  - `res://scripts/ui/loading_screen.gd`
- Implemented threaded game-scene loading for startup transition:
  - starts/continues `ResourceLoader.load_threaded_request("res://scenes/main.tscn")`,
  - updates a simple progress bar,
  - swaps to packed scene when threaded load completes,
  - includes direct-load fallback path on loader failure.
- Updated main menu flow to route `New Game` and `Continue` through loading scene instead of direct scene switch.
- Added proactive background preload from main menu `_ready()`:
  - starts threaded preload of `main.tscn` before player clicks,
  - loading screen now reuses in-progress/already-loaded state for faster perceived startup.
- Visual pass:
  - loading screen styled to match main-menu language (palette/layout cadence) while staying minimal.

### Step 51 - Shower room completion and mirrored pickup stability

- Completed shower-room prop pass and scene integration:
  - added reusable `shower`, `duck`, and `flip_flop` interior scenes,
  - placed shower setup and mirrored flip-flop variant in quarters.
- Finalized interaction behavior for shower props:
  - `flip_flop` now uses `requires_line_of_sight = false` in-scene,
  - kept global `Interactable` LOS default at `true` to avoid broad behavior regressions.
- Cleaned held-item transform handling in `interaction_controller.gd`:
  - removed old scale bookkeeping/reapply path,
  - now preserves local scale while applying hold/follow transforms,
  - added mirrored-basis-safe handling so mirrored props no longer rotate incorrectly on pickup.
- Updated station checklist:
  - marked shower section and shower character touches as complete,
  - marked slippers/flip-flops under bunk as complete.

## 2026-04-16

### Step 50 - Interactable highlight modes, authored reveal meshes, and double-door feedback sync

- Extended `res://scripts/interaction/interactable.gd` with authored highlight configuration:
  - `highlight_mode` now supports shader-outline or reveal-mesh presentation,
  - `highlight_visible_paths` lets scenes toggle dedicated highlight geometry instead of forcing the shader path.
- Retuned/iterated the interaction outline shader during authoring and kept cactus on shader-based highlight while allowing hard-surface props to use authored reveal meshes.
- Configured `res://scenes/station/interior/light_switch.tscn` to use reveal-mesh highlight for its dedicated hidden outline mesh.
- Updated double-door group feedback flow:
  - both `door_slide` leaves now mirror highlight state when either side is hovered,
  - group sync avoids self-sustaining highlight loops by separating source hover from mirrored override state,
  - grouped double doors keep one shared midpoint indicator while idle.

### Validation
1. Manual in-editor gameplay check
   - Result: cactus shader highlight remains usable, light switch reveal-mesh highlight works, double doors now highlight both leaves with one shared idle indicator.

### Step 49 - Interactable indicator overhaul (visibility, placement, and door-specific tuning)

- Reworked interactable indicator-dot behavior in `res://scripts/interaction/interactable.gd`:
  - stabilized visibility flow (shown only when not highlighted/held/disabled),
  - fixed-size world marker rendering with camera-facing orientation,
  - sharpened/brightened dot texture and additive unshaded material for UI-like readability,
  - support for authored indicator anchors via `indicator_anchor_path`,
  - support for per-object marker placement via `indicator_local_offset` and `indicator_camera_bias`,
  - public `get_indicator_world_position()` accessor for group systems.
- Tuned reusable door leaf interactable marker setup in `res://scenes/station/interior/door_slide.tscn`:
  - door-specific anchor path, height, and camera bias overrides.
- Updated `res://scripts/station/interior/door_lock_group.gd` to compute double-door shared indicator override from each leaf’s indicator world position rather than focus/button position.
- Result:
  - single-door marker appears at intended button-height region,
  - double-door marker aligns to center midpoint at same vertical intent,
  - non-door interactables retain center-based defaults with scene-level override support.

### Validation
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`.
   - Note: existing `card_reader_interaction_test` still fails (`card reader should exist`, `focus target should exist`, `card interactables should exist`); unrelated to this indicator work.

## 2026-04-15

### Step 48 - Interactable pickup workflow cleanup, deterministic drop behavior, and interactable save/load persistence

- Reworked cactus into a clean scene-authoring pattern:
  - dedicated pickup body (`StaticBody3D`) plus child `Interactable` `Area3D`,
  - corrected interaction collision to prevent atrium wall-wide false highlights.
- Simplified `Interactable` authoring:
  - grouped exports into `Interaction`, `Pickup`, `Advanced`,
  - added smart defaults for empty `display_name` and `prompt_action`,
  - reduced required per-object manual parameter setup.
- Made held-item drop behavior deterministic and floor-aware in `interaction_controller.gd`:
  - drop always resolves in front of Octo,
  - drop distance scales by item width (with minimum),
  - floor snap via raycast and removed upward throw impulse.
- Added interactable save/load persistence:
  - `Interactable` now participates in `save_state_provider`,
  - persists interaction enabled state and pickup transform for pickup items,
  - supports stable provider save keys to remain resolvable after runtime reparenting.
- Added held-at-save restore rule:
  - items saved while held restore as dropped near Octo on floor,
  - multi-item restore uses nearby slot search to avoid stacked overlaps/blocking.
- Menu decision/documentation:
  - kept pause menu without `Load Game` entry,
  - load flow remains `Main Menu` -> `Continue`.

### Validation
1. `godot --headless --path . --quit-after 1`
   - Result: startup/parse PASS after each interaction/save-load change batch.

## 2026-04-04

### Step 47 - Projected underwater caustics rig for exterior light breakup

- Added a reusable projected-caustics rig:
  - `res://scenes/effects/caustic_rig.tscn`
  - `res://scripts/lighting/caustic_rig.gd`
- The rig uses two animated `SpotLight3D` nodes with `light_projector` textures to fake underwater caustic motion on nearby geometry.
- Added authored projector texture asset `res://assets/textures/caustics.png`.
- Integrated one or more caustics rig instances into `res://scenes/main.tscn` under the main light stack and tuned them for readable underwater shimmer against the existing skylight/fog setup.
- Kept the rig reusable by supporting either an authored `projector_texture` or a generated fallback cookie when no texture is assigned.
- Final tuning favored visible projected breakup rather than low numeric light-energy values, since the caustics texture masks most of the emitted light.

### Validation
1. `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp /Applications/Godot.app/Contents/MacOS/godot --headless --path . --scene res://scenes/main.tscn --quit-after 2`
   - Result: scene boot PASS.
   - Note: existing material/fish import warnings still appear and were not introduced by the caustics rig.

### Step 46 - Gameplay cohesion art pass for the underwater facility interior

- Added a dedicated gameplay fullscreen shader in `res://assets/shaders/gameplay_cohesion.gdshader` and applied it from `res://scenes/main.tscn` as a scene-only overlay above 3D and below HUD.
- Tuned the pass to support an indoor-underwater-station look instead of a full blue submersion filter:
  - mild desaturation,
  - softened contrast,
  - slightly lifted blacks,
  - teal-leaning shadow tint,
  - restrained edge cooling,
  - faint animated light wash for exterior water influence.
- Retuned `WorldEnvironment` and key light colours in `res://scenes/main.tscn` so the scene keeps a dusty, readable interior palette while exterior haze remains cool and aquatic.

### Validation
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`.
   - Note: existing `card_reader_interaction_test` still fails (`card reader should exist`, `focus target should exist`, `card interactables should exist`); this was not touched by the visual pass.

### Step 45 - Desktop rendering quality defaults and debug clarity pass

- Updated `res://project.godot` desktop rendering defaults to improve visible 3D edge quality during normal play and debug runs:
  - switched project renderer from `GL Compatibility` to `Forward Plus`,
  - increased default window size from `1280x720` to `1600x900`,
  - enabled `MSAA 3D` (`4x`),
  - enabled screen-space AA, debanding, and roughness limiting,
  - kept 3D render scale at `1.0` to avoid undersampled output.
- Updated `docs/README.md` with the new rendering defaults and the recommended order for reducing quality if performance tuning is needed later.

### Validation
1. Manual visual check in-editor/gameplay debug run
   - Result: noticeably cleaner edges and improved scene readability versus previous defaults.

## 2026-04-01

### Step 44 - Save/load system, Continue flow, autosave hooks, and save feedback UI

- Added persistent save backend:
  - new autoload singleton `res://scripts/core/game_save.gd`,
  - save file path `user://save_game.json`,
  - API for save/load/clear plus pending-load request handling for menu-to-game transitions.
- Implemented gameplay save/load integration in `res://scripts/core/main.gd`:
  - load-on-start when entering from `Continue`,
  - save payload includes player position and world provider states,
  - provider system based on `save_state_provider` group with `get_save_state` / `apply_save_state`.
- Added world-state persistence providers:
  - `res://scripts/station/interior/door_slide.gd` (locked/open state),
  - `res://scripts/interaction/room_light.gd` (light on/off state),
  - `res://scenes/station/interior/light_switch.gd` (switch on/off state).
- Added autosave trigger path:
  - `door_slide` now emits `door_opened`,
  - main scene listens to door events (`autosave_door` group) and autosaves with rate limiting.
- Updated menu flow:
  - main menu now uses `New Game` + conditional `Continue` (visible only when save exists),
  - `New Game` clears existing save and starts fresh,
  - legacy `Load Game` path hidden in UI.
- Updated pause flow:
  - added `Save Game` action in in-game pause menu.
- Added in-game save feedback:
  - bottom-right toast under `UI` root for `Game Saved`, `Autosaved`, and `Save Failed`.

### Validation commands (pass)
1. `/Applications/Godot.app/Contents/MacOS/godot --headless --path . --quit`
   - Result: boot smoke PASS and scripts parse cleanly.

## 2026-03-31

### Step 43 - Animated fish-school wave system, directional modes, and editor swim-volume preview

- Implemented a new fish-school setup on branch `fish-school-setup` using animated fish scene instances from `res://assets/models/fish/`:
  - one school wave at a time per volume,
  - each wave uses 1-2 fish species max,
  - each wave crosses the volume, despawns, then respawns after random delay.
- Replaced the earlier close/mid multimesh scaffold with scene-instance fish spawning in:
  - `res://scripts/station/fish_school.gd`,
  - `res://scenes/station/fish_school.tscn`.
- Added directional behavior controls:
  - `Two-Way`, `Four-Way XZ`, and `Fixed Direction` modes,
  - optional reverse-direction randomization,
  - heading variation per spawned school (default `+/- 15` degrees).
- Added school-packing controls to keep fish as a coherent moving group:
  - anchor-based cluster pull and max distance clamp around the moving school center.
- Added editor-only volume preview mesh and runtime hiding:
  - visible in editor for sizing/tuning,
  - explicitly hidden in gameplay runtime.
- Added reusable helper module:
  - `res://scripts/station/fish_school_utils.gd` for direction/species/random helpers.
- Updated main scene fish-school instance tuning in `res://scenes/main.tscn`:
  - configured for `Four-Way XZ`,
  - set compact school parameters and adjusted volume sizing for test pass.

### Step 42 - Underwater lighting/art pass: exterior haze, synchronized godray pulse, and shadow softness

- Reworked gameplay lighting in `res://scenes/main.tscn` for underwater readability:
  - tuned `WorldEnvironment` fog/volumetric fog so near outside terrain remains visible while distance falls into dark ocean haze,
  - retuned procedural sky colors and ambient contribution for underwater mood,
  - softened direct and shaft-cast shadows to feel filtered through water.
- Upgraded center godray composition:
  - kept a primary shaft (`RoofShaft`) and layered fills (`RoofShaftFillA/B`) for richer beam structure,
  - raised volumetric contribution while reducing hard floor hotspot dominance.
- Added dynamic godray behavior in `res://scripts/lighting/god_rays.gd`:
  - animated sway and energy pulses for shafts,
  - exposed tuning exports (`sway_speed`, `sway_pitch_degrees`, `sway_yaw_degrees`, `energy_pulse_strength`, `volumetric_pulse_strength`),
  - added shared pulse outputs (`master_pulse_normalized`, `master_pulse_01`) for other systems.
- Synced main directional light pulse with godray pulse in `res://scripts/core/main.gd`:
  - fixed light node paths to runtime scene locations under `Node3D`,
  - directional light now uses the exact godray pulse phase/value,
  - added pulse range controls via `main_light_min_factor` / `main_light_max_factor`,
  - disabled directional sway by default while keeping pulsing active.
- Improved window readability and outside visibility:
  - updated `res://assets/materials/glass.tres` (less tint/roughness, refraction disabled),
  - final fog tuning starts close to camera with strong falloff to dark distance.
- Improved player floor contact perception:
  - lowered octo start height in `res://scripts/core/main.gd`,
  - lowered octo visual offset in `res://scenes/player.tscn`.

## 2026-03-29

### Step 41 - Station sliding door system (single/double), safety auto-close, and visual polish

- Added interactive station door prefabs and runtime controllers:
  - `res://scripts/station/interior/door_slide.gd`,
  - `res://scripts/station/interior/door_lock_group.gd`.
- Implemented door-slide behavior:
  - click-to-open interaction on door leaf,
  - cinematic smooth open/close tweening (`EASE_IN_OUT + TRANS_QUART`),
  - open travel configured to slide left by near full leaf width.
- Implemented lock-state support:
  - exported/group lock state on `DoorSingle` and `DoorDouble`,
  - lock propagation from group wrapper to child slide leaves.
- Implemented double-door coordination:
  - clicking either side opens both leaves,
  - per-leaf open-distance overrides for alignment tuning.
- Implemented safe delayed auto-close:
  - closes after delay only when doorway is clear,
  - close is blocked by player/items in sensor area,
  - for double doors, if either side is blocked, neither side closes.
- Updated door indicator visuals:
  - muted allowed/openable color `#3ed180`,
  - muted blocked/moving/locked color `#de3d4d`.
- Removed yellow hover conflict for door interactables by overriding door-specific interaction overlay colors.
- Added synchronized hover highlight across both sides of double doors.
- Extended `Interactable` with `get_visual_state()` to support group-level highlight synchronization.

## 2026-03-28

### Step 40 - Camera collision hardening and click-navigation pathing fallback

- Improved third-person camera reliability in `res://scripts/core/main.gd`:
  - widened spring arm obstacle mask coverage for both wall and floor collision layers,
  - added spring arm collision probe shape and safer margin defaults,
  - tightened maximum gameplay zoom distance to reduce out-of-room framing issues.
- Upgraded click movement in `res://scripts/player/player_controller.gd` to support navmesh pathing:
  - added runtime `NavigationAgent3D` setup under player controller,
  - movement follows nav path points when navigation target is reachable,
  - automatic fallback to direct click movement remains active when navmesh is missing or target is unreachable.
- Preserved existing climb/mantle behavior by steering climb probes from the active movement drive target (path step or direct target).
- Updated docs (`README`, `ARCHITECTURE`, `TESTING`) with navmesh authoring expectations and QA coverage for navigation fallback/path-follow behavior.

### Validation commands (pass)
1. `godot --headless --path . --quit`
   - Result: boot smoke PASS.

## 2026-03-20

### Step 39 - Popup localisation coverage and documentation rule update

- Completed localisation pass for new popup/login strings and added missing Ukrainian entries in `i18n/uk_UA.po`.
- Ensured popup title/body content uses `tr(...)` so about/contact/staff popup text follows active locale.
- Added workflow requirement to `docs/PROCEDURES.md`:
  - all player-visible source text must be proper UK English,
  - all new/updated strings must have Ukrainian translation coverage.
- Added matching policy notes in `docs/README.md` and QA checklist coverage in `docs/TESTING.md`.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 38 - Shared settings menu implementation, style polish, and audio default updates

- Implemented `res://scenes/ui/settings_menu.tscn` and `res://scripts/ui/settings_menu.gd` as a shared settings screen used from:
  - startup main menu (`Settings` button),
  - in-game pause menu (`Settings` button).
- Added settings menu close paths:
  - top-left back button,
  - `Esc` handling in both overlay contexts.
- Replaced previous placeholder `Settings` actions in startup/pause flows with real overlay navigation.
- Added settings controls and persistence wiring through `GameSettings`:
  - `Music` slider,
  - `Sound Effects` slider,
  - `Subtitles` selector (`<` / `>`),
  - `Language` selector (`<` / `>`).
- Added runtime localization refresh in settings screen and ensured startup language dropdown syncs after returning from settings.
- Added and tuned settings UI visual styles:
  - custom blue palette for sliders and selector arrows,
  - custom slider grabber icon rendering for smooth, non-default knob styling.
- Updated audio defaults to `100%` (`1.0`) for first run/fallback paths.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 37 - Localisation foundation (UK/UA), translatable runtime text, and persisted language setting

- Added project-level localisation setup:
  - fallback locale configured to `en_GB`,
  - translation catalog registered in project settings (`res://i18n/uk_UA.po`).
- Added Ukrainian translation catalog with current main menu, pause menu, interaction prompt, and hint strings.
- Normalised visible source text to UK English where applicable (for example, `Centre` spelling).
- Made runtime-generated UI strings translatable via `tr(...)`:
  - interaction hints in `InteractionHintBuilder`,
  - keypad display status text in `CodePanel`.
- Added settings persistence infrastructure for future settings menu work:
  - new autoload singleton `GameSettings`,
  - saves/loads locale in `user://settings.cfg`,
  - applies locale on startup.
- Updated main menu language selector to use persisted locale:
  - initial selection reflects saved value,
  - selecting UK/UA updates locale and stores it for next session.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-20

### Step 36 - Main menu visual polish, display layering, and footer UX refinements

- Upgraded startup menu branding and readability:
  - heavier title treatment for institution name,
  - refined subtitle styling and spacing.
- Added monitor/display treatment for the startup UI:
  - full-screen `DisplayFX` overlay shader layered above website content and below sticker,
  - tuned vignette/glare/scanline balance and added mouse-driven reflection parallax.
- Improved sticker presentation:
  - added dedicated sticker shadow shader,
  - iterated toward softer, wider, more ambient wrap shadow,
  - reduced hard cutout edge feel with alpha-edge softening.
- Added top-nav hyperlink affordance behavior:
  - pointer cursor on hover,
  - underline on hover,
  - click hooks preserved as placeholder warnings for non-implemented sections.
- Added the same hyperlink underline behavior to `BottomNavButtons`.
- Added footer language selector to bottom bar:
  - `UK` / `UA` selection with flag icons,
  - icon-only compact dropdown presentation,
  - locale switching hook (`en_GB` / `uk_UA`),
  - custom dropdown arrow/list colors and compact popup styling.
- Ensured sticker/display overlays do not block UI interactions by adjusting mouse filters.
- Addressed strict typed-warning issues in GDScript (`warnings as errors`) and removed unsupported OptionButton API usage by resizing icon textures in script.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-19

### Step 35 - Menu UI overhaul, pause flow update, and display scaling polish

- Refactored menu UI into reusable scene components and moved pause UI into its own scene.
- Added reusable button style with right-side icon indicator and consistent focus/hover behavior.
- Reworked startup menu visual presentation with:
  - browser-frame styled header image,
  - slideshow panel using `assets/ui/slideshow/*`,
  - dot indicator carousel state.
- Updated startup menu actions:
  - `New Game` (scene load),
  - `Load Game` placeholder warning,
  - `Settings` placeholder warning,
  - `Quit`.
- Updated in-game pause actions:
  - `Resume` (default focused action),
  - `Settings` placeholder warning,
  - `Main Menu`.
- Removed startup `Esc -> quit` shortcut to avoid accidental app exits from main menu.
- Enabled actual gameplay pause via `get_tree().paused` while keeping pause UI/input responsive.
- Added display stretch settings in `project.godot`:
  - `window/stretch/mode="canvas_items"`
  - `window/stretch/aspect="keep_height"`
  - fixed design viewport `1280x720`.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-18

### Step 34 - Climb pre-mantle sequencing and overload move feedback polish

- Added full-load move blocking feedback path:
  - world and approach clicks are consumed when all 8 arm slots are occupied,
  - octo plays a slower "no" wiggle instead of moving.
- Added pre-mantle climb sequence in `player_controller.gd`:
  - smooth turn toward click direction,
  - first front-arm reach, then second front-arm reach with a small lead delay,
  - short transition into mantle translation.
- Tuned climb arm reach shaping:
  - switched to front arms (`arm_0`, `arm_1`),
  - increased forward reach, inward angle bias, and small tip bend for more believable contact.
- Kept crawl locomotion posing active during pre-mantle and mantle so arms continue animating while body climbs.
- Added subtle climb head tilt blend on `PlayerVisual` during pre-mantle/mantle.
- Cleaned serialized scene property noise in `player.tscn` (removed stale `surface_hold_blend_strength = null`).

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-14

### Step 33 - Surface crawl architecture rewrite (state machine + phase-role posing)

- Replaced authored crawl-shape pass with `OctoSurfaceLocomotion`-driven crawl posing and locomotion.
- Added per-arm crawl state machine and floor-target/anchor pipeline:
  - `SEARCH`, `REACH`, `GRAB`, `PUSH_PULL`, `RELEASE`.
- Added body drive synthesis from anchored arms:
  - support normal blending,
  - traction-weighted push force accumulation,
  - fallback motion when temporarily unanchored.
- Added phase-role pose architecture for arm sections:
  - phases `plant`, `load`, `push`, `stabilize`, `recover`, `swing`,
  - role ownership by segment (`base` placement/sweep, `mid` load/propulsion, `tip` contact/grip),
  - per-phase progress value for deterministic curves.
- Added debug instrumentation:
  - per-arm runtime line includes `STATE/phase(progress)`,
  - optional 3D debug lines in `OctoRig` for arm vectors/targets/anchors.
- Added tuning simplifications for current workflow:
  - deterministic crawl option (`simplify_crawl_motion`),
  - alternating step groups for less chaotic arm concurrency,
  - segment-focus mode (`role_focus_segment`) to tune `base` before `mid`/`tip`.
- Cleaned `OctoRig` inspector exports:
  - grouped active surface locomotion and preview controls,
  - hid legacy raw-IK tuning exports (runtime path retained as non-export vars).

## 2026-03-11

### Step 32 - Crawl movement cleanup and authored crawl-shape pass

- Simplified `OctoRig` crawl flow around the current tuning workflow:
  - removed stale generic crawl tuning/export clutter,
  - moved per-arm crawl base-angle and mid-bend ranges into explicit constants,
  - extracted shared crawl speed helpers so gameplay and preview use the same cycle-speed math.
- Refactored idle target generation into reusable target-data assembly so crawl can intentionally inherit selected idle sections.
- Kept crawl arm shape focused on the current iteration target:
  - authored base bend center/amplitude,
  - authored per-arm base-angle sweep ranges,
  - authored per-arm mid-bend sweep ranges,
  - fixed crawl tip angle at `0.0` while preserving idle-derived tip bend.
- Added `preview_motion_speed` as the single preview-side crawl speed input and serialized a slower default on `PlayerVisual` for easier editor tuning.
- Reverted experimental crawl tip grounding/zeroing passes after review; they were visually too aggressive and are not part of the retained implementation.

## 2026-03-09

### Step 31 - Camera/focus polish and inspector export cleanup

- Increased gameplay close-up capability:
  - lowered camera min zoom and moved default spring-arm distance closer.
- Fixed focus regression affecting `CardReader` and `CodePanel`:
  - updated focus-target lookup to resolve by `FocusTarget` script type instead of brittle node-name matching.
- Refined blocked-state LOS behavior:
  - LOS now focuses on world geometry blockers while still accepting target-host hierarchy hits for focusable objects.
- Added visual grounding adjustment:
  - lowered octo visual model offset under `PlayerVisual` to reduce apparent hover without changing player physics.
- Rebalanced held-item vertical placement after visual offset change:
  - lowered minimum held-item world height and reduced extra upward clearance.
- Cleaned inspector exports for current workflow:
  - hid non-crawl tuning from `OctoRig` while keeping crawl + crawl-preview controls visible,
  - hid `PlayerController` movement/climb tuning exports for cleaner scene editing.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-09

### Step 30 - Hold workflow completion (arm-slot assignment, preview mode, and anchor-based item placement)

- Added `Hold` as an explicit `OctoRig` editor preview mode for direct hold-pose tuning.
- Finalized hold bend defaults and optional shared hold-angle oscillation (`0.0` to `0.5`) for base/mid/tip section angles.
- Completed carry-to-rig hold integration in `InteractionController`:
  - free-arm pickup assignment with mid-arm priority first,
  - persistent slot ownership per item (items keep same slot while held),
  - occupied slots drive corresponding `OctoRig` arms into `HOLD` mode via runtime hold flags.
- Added `OctoRig` hold helpers for systems integration:
  - `get_hold_arm_priority()`,
  - `get_arm_world_anchor(...)`.
- Reworked held-item placement from static/index socket approximation to rig-anchor-following sockets.
- Added size-aware anti-clipping placement:
  - cards keep zero extra clearance,
  - larger props gain bounded radial/upward clearance from octo center,
  - minimum world-height clamp for held items to reduce arm/body clipping.
- Removed obsolete idle-demo path and resolved nil-safety regressions in idle dictionary access introduced during iteration.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-09

### Step 29 - Rig idle/mixer polish, preview updates, and inspector cleanup

- Expanded `OctoRig` arm animation into practical per-arm mixer usage (`STATIC`/`IDLE`/`CRAWL`/`HOLD`) suitable for mixed-behavior gameplay (walking while selected arms hold items).
- Tuned defaults and behavior for natural floor-contact idle:
  - base bend resting around `0.68`,
  - stronger mid/tip curl in idle while keeping very low frequency motion.
- Added per-arm idle variation controls:
  - deterministic arm variation terms,
  - optional randomized mid-angle sign behavior (including even/odd split mode),
  - per-idle-entry randomized offsets so each idle settle does not start from the exact same pose.
- Updated head behavior:
  - mouse-follow refinements with front-guard gating and wider acceptance area,
  - stronger debug-follow path for quick tuning,
  - smooth, slow return when mouse leaves viewport.
- Updated editor preview modes:
  - kept `Idle` preview available alongside `Static Targets`, `Crawl`, and `Mixer`,
  - removed obsolete idle-demo preview path.
- Cleaned inspector exposure in `OctoRig`:
  - hid internal idle/head debug tuning exports to reduce editor clutter while keeping values available in script for future tuning.
- Hardened runtime against serialized `nil` states:
  - added defensive idle-runtime state initialization,
  - removed unsafe direct dictionary `.get(...)` calls in hot idle path.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

## 2026-03-08

### Step 28 - Arm pose model rewrite to section bend controls + smoothing

- Replaced high-level arm controls (`spread/curl/lift/twist/tip_bias`) with section-based controls:
  - `base_bend`, `base_bend_angle`
  - `mid_bend`, `mid_bend_angle`
  - `tip_bend`, `tip_bend_angle`
- Updated `OctoArm` runtime blending to apply all three section influences across the full chain (overlapping windows) to reduce segmented transitions at section boundaries.
- Renamed API/export naming to bend terminology for clarity:
  - new canonical methods: `set_target_section_bend(...)` and `set_arm_target_section_bend(...)`,
  - old `set_*_pose_params(...)` kept as compatibility aliases.
- Inverted bend direction so increasing bend values raise arms in the current rig setup.
- Added bend clamping in runtime and inspector ranges:
  - all sections now clamped to `[-1.5, 1.5]`.
- Updated player defaults on `PlayerVisual`:
  - `default_base_bend = 0.67`,
  - `default_mid_bend = 0.0`,
  - `default_tip_bend = 0.0`,
  - preview bends reset to `0.0`.
- Removed unused arm rest caches (`rest_positions`, `rest_transforms`) from `OctoArm`.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

### Step 27 - Script folder restructure + octopus rig/editor-preview cleanup

- Reorganized scripts into domain folders:
  - `scripts/core/`
  - `scripts/player/`
  - `scripts/interaction/`
  - `scripts/rig/`
- Updated scene/script/test references to new paths.
- Fixed post-move GDScript parse/type regressions in interaction and rig stack:
  - stabilized `InteractionController` script-type usage with explicit preloads,
  - removed fragile type inference points introduced during refactor,
  - aligned `main.gd` controller instantiation and focus-target typing to be robust after file moves.
- Kept octopus rig defaults for current gameplay tuning at that step:
  - `default_arm_lift = 0.82` on `PlayerVisual` rig component (later replaced by section bend defaults in Step 28).
- Updated architecture docs with the new script directory layout.

### Validation commands (pass)
1. `./scripts/check.sh`
   - Result: boot smoke PASS, `movement_math_test: PASS`, `slope_movement_test: PASS`, `card_reader_interaction_test: PASS`.

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
### Step 13 - Document interaction polish, localization, and incident report flow
- Refined `DocumentItem` interaction behavior:
  - Removed highlight/indicator while reading.
  - Smoothed focus return camera behavior.
  - Added focus pan while zoomed on documents.
  - Stabilized focus orientation to avoid upside-down/angled document views.
- Added localized document textures with language-based switching:
  - `document_texture` (EN) and `document_texture_ua` (UA).
  - Editor preview updates when locale/texture settings change.
- Updated document sizing:
  - Replaced prior large size with `A1_LANDSCAPE` (3x A4 dimensions in project scale).
  - Outline mesh scales with document size.
- Added persistent exit-code feature:
  - New Game generates a random 4-digit code in `1100..1900`.
  - Stored in global settings and applied to `ExitCodeLabel` in scene labels.
- Added `incident_report` staged folder interaction:
  - Folder-only interaction (documents inside non-clickable, no indicators).
  - Click sequence: open/focus -> page 1 left -> page 2 up+left -> reset+close+exit focus.
  - Folder open/close playback sped up for better pacing.
  - Folder interactable indicator enabled.
- Added page flip SFX integration:
  - `assets/sound/page_flip.wav` now plays when entering document reading view.
  - Same SFX plays during incident report page move stages.
