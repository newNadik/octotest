# Gone Exploring - Step-by-Step Task List

This list is in literal execution order.

Scope lock for this version:
- Indoor game only (one building).
- Open-water escape is ending cutscene only.
- No camouflage.
- No tangle.
- Interactions use simple visual nudge toward object (no full touch animation).

## Already Done

- [x] Basic movement and camera.
- [x] Slope movement and climb behavior.
- [x] Interaction system base.
- [x] Object pickup/carry/drop.
- [x] Focus interactions.
- [x] Card reader.
- [x] Code panel.
- [x] Basic automated tests and `./scripts/check.sh`.

## Next Tasks (In Order)

### 0. Pre-production art and flow planning

- [ ] Draw station map (top-down) with all planned rooms.
- [ ] Mark intended player route from start to ending trigger.
- [ ] Mark side-paths/optional curiosity rooms.
- [ ] Mark where each human appears and their patrol zone.
- [ ] Mark puzzle gates on the map (what blocks progress at each gate).
- [ ] Mark clue locations on the map (where player learns each code/sequence).
- [ ] Make one "flow line" version of the map (clean, minimal, progression only).
- [ ] Make one "art mood" version of the map (lighting/color mood notes per zone).
- [ ] Export map images and save to `docs/misc/` for team reference.
- [ ] Add final room list and map image links to docs.

### 0.1 Puzzle planning before implementation

- [ ] Create `docs/misc/PUZZLE_PLAN.md`.
- [ ] Define 3-5 puzzle archetypes to reuse in game:
- [ ] Code entry puzzle.
- [ ] Sequence input puzzle.
- [ ] Multi-step unlock puzzle (A enables B enables C).
- [ ] Carry/place object puzzle.
- [ ] Light-state dependent clue puzzle.
- [ ] For each room, write a one-line puzzle goal.
- [ ] For each room, define:
- [ ] Required clues.
- [ ] Required interactables/modules.
- [ ] Unlock result (what opens/changes).
- [ ] Optional content reward (if any).
- [ ] Catch/reset behavior for that room.
- [ ] Build puzzle dependency chain for full game:
- [ ] Which puzzle must be solved before next one appears.
- [ ] Which puzzles are optional side-paths.
- [ ] Mark one “critical path only” route to credits.
- [ ] Add difficulty pacing notes per room (easy/medium/hard).
- [ ] Add “stuck prevention” note per room (extra clue, shortcut, or reset help).

### 1. Prepare game structure for multiple rooms

- [ ] Decide first playable route (example: Data Office -> Systems -> Core -> Public Exit).
- [ ] Create separate scene file for each room (instead of one giant room scene).
- [ ] Create one shared "Game" scene that loads and switches room scenes.
- [ ] Add room IDs (string or enum) so progression can track where player is.
- [ ] Update `docs/ARCHITECTURE.md` after room structure is decided.

### 2. Add navigation between rooms

- [ ] Create reusable `RoomDoor` module (scene + script).
- [ ] Give each door config fields: source room ID, target room ID, target spawn point, optional lock state.
- [ ] Implement player transition through door.
- [ ] Ensure transitions keep player state; solved-state persistence is completed in Step 3.
- [ ] Add manual test pass: go forward and back through all connected doors.

### 3. Add save/load (simple first)

- [x] Create `GameSave` singleton.
- [x] Save current room ID, spawn point, solved puzzle states, and important moved object states.
- [x] Autosave when entering a room.
- [x] Load on "Continue" from main menu.
- [ ] Add one automated test for save -> quit -> load -> correct room.

### 4. Build reusable puzzle modules

- [ ] Keep existing modules and clean them for reuse:
- [ ] Card Reader module.
- [ ] Code Panel module.
- [ ] Light Switch module.
- [ ] Create 2 new small modules:
- [ ] `ClueNote` (readable code clue).
- [ ] `SequenceButtons` (press in order).
- [ ] For each module, define simple inspector config values and one prefab example scene.
- [ ] Add short usage docs: "How to place this module in a room".

### 5. Content task for you: place modules in Room 1

- [ ] Create/author Room 1 scene layout.
- [ ] Make quick Room 1 concept sketch (entrances, landmarks, puzzle area).
- [ ] Place puzzle modules in Room 1.
- [ ] Place clue objects in Room 1.
- [ ] Define what unlocks exit door of Room 1.
- [ ] Run playtest and adjust object positions for readability.

### 6. Add first full room loop

- [ ] Implement opening setup (tank area + first clue).
- [ ] Implement Room 1 puzzle chain: find clue -> use interactable(s) -> unlock exit.
- [ ] Add fallback feedback if player tries door too early.
- [ ] Add manual QA checklist for Room 1 completion flow.

### 7. Add humans as simple world actors

Treat humans as simple predictable actors (closer to interactable objects than complex AI).

- [ ] Create `HumanActor` module.
- [ ] Add patrol path points.
- [ ] Add vision cone/detection area.
- [ ] Add optional investigate target (example: light switch room).
- [ ] Add `OnDetectOcto` event -> trigger catch/reset.
- [ ] Add 1 human to first playable route and test behavior.

### 8. Add catch/reset behavior

- [ ] On catch, return player to room start (or tank start depending on section).
- [ ] On catch, keep global progress (opened doors, solved permanent puzzles).
- [ ] On catch, reset only room-local in-progress actions.
- [ ] Ensure no long cooldown.
- [ ] Add automated test for "global state kept, local room state reset".

### 9. Add tracking docs before full room production

- [ ] Create one table in docs for all rooms:
- [ ] Room name.
- [ ] Main puzzle.
- [ ] Puzzle archetype.
- [ ] Required clue(s).
- [ ] Unlock result.
- [ ] Dependencies (what must already be solved).
- [ ] Difficulty level.
- [ ] Catch reset rule.
- [ ] Keep this table updated while building rooms.

### 9.1 Add room concept sheet pack

- [ ] Create one mini concept sheet per room in `docs/misc/room_concepts/`.
- [ ] Each sheet includes:
- [ ] Top-down sketch.
- [ ] Mood keywords (3-5 words).
- [ ] Main color notes.
- [ ] Main landmarks.
- [ ] Puzzle summary in one sentence.
- [ ] Human presence note (none/patrol/static).
- [ ] Link each concept sheet from the puzzle tracking table.

### 10. Content task for you: build remaining rooms

Repeat this for each room:
- [ ] Create room scene.
- [ ] Make quick concept sketch before building (layout + puzzle + clue spots).
- [ ] Add environment geometry and collision.
- [ ] Add modules (card/code/switch/sequence/clues).
- [ ] Define room goal and exit condition.
- [ ] Connect doors to previous/next room.
- [ ] Playtest room from a clean save.
- [ ] Update puzzle tracking table and room concept sheet right after playtest.

Recommended minimum for first complete version: 6-8 rooms.

### 11. Character presentation pass (simple but clear)

- [ ] Integrate octopus model/rig.
- [ ] Keep interaction visuals simple:
- [ ] Small directional nudge toward target.
- [ ] Busy-arms "can't interact" nudge.
- [ ] Add mood color shifts (curious, startled, pleased).
- [ ] Verify readability in every room lighting setup.

### 12. Add ending flow

- [ ] Add final indoor trigger room.
- [ ] Trigger ending cutscene at dive airlock.
- [ ] Show open-water escape in cutscene only.
- [ ] Add epilogue scene.
- [ ] Add credits and return to main menu.

### 13. Final test + cleanup

- [ ] Expand `./scripts/check.sh` with new tests.
- [ ] Run full manual playthrough from new game to credits.
- [ ] Fix blockers (progression breaks, bad respawns, softlocks).
- [ ] Update docs:
- [ ] `docs/ARCHITECTURE.md`
- [ ] `docs/TESTING.md`
- [ ] `docs/DEVLOG.md`

## Simple “Current Sprint” Checklist

Use this for immediate next work sessions:

- [ ] Draw first station map draft and lock room order.
- [ ] Create first draft of `docs/misc/PUZZLE_PLAN.md`.
- [ ] Create room puzzle tracking table template.
- [ ] Split current world into Room scenes.
- [ ] Add `RoomDoor` module and first room transition.
- [ ] Add basic `GameState` save/load with room restore.
- [ ] Turn existing interactables into reusable modules.
- [ ] Build Room 1 fully (layout + clues + puzzle + exit).
- [ ] Add first `HumanActor` and catch/reset.
