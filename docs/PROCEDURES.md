# AI Agent Session Procedures

This file defines how to initialize and run AI-assisted dev sessions for this project.

## Project Facts

- Project root: this repository root
- Godot binary: auto-detected by `scripts/check.sh` (`godot4`, `godot`, `Godot`, macOS app path, legacy `/ssd2/...`), or override with `GODOT_BIN`
- Main scene: `res://scenes/main_menu.tscn`
- Logic tests: `res://tests/movement_math_test.gd`, `res://tests/slope_movement_test.gd`
- Dev log: `docs/DEVLOG.md`
- Architecture doc: `docs/ARCHITECTURE.md`
- Manual testing doc: `docs/TESTING.md`
- Quickstart doc: `docs/README.md`
- Task backlog: `docs/TASK_LIST.md`
- Puzzle planning doc: `docs/misc/PUZZLE_PLAN.md`
- Room concept template: `docs/misc/room_concepts/ROOM_TEMPLATE.md`
- Unified check script: `scripts/check.sh`

## Session Initialization Checklist

Run these steps at the start of every session.

1. Confirm current directory is project root.
2. Read `docs/ARCHITECTURE.md` and `docs/DEVLOG.md`, then note the latest completed step.
3. For gameplay/content sessions, review `docs/TASK_LIST.md` and `docs/misc/PUZZLE_PLAN.md`.
4. Check git status and branch.
5. Run baseline sanity checks before changing code (`./scripts/check.sh`).
6. Create a dedicated feature/fix branch before implementation.

Suggested commands:

```bash
cd /path/to/octotest
git status -sb
git branch --show-current
./scripts/check.sh
```

## Branching Rules

Use a separate branch for each new feature or fix.

1. Keep `main` stable.
2. Branch names:
- `feat/<short-topic>`
- `fix/<short-topic>`
- `chore/<short-topic>`
3. One focused change per branch.
4. Rebase/merge only after tests pass.

Example:

```bash
git checkout main
git checkout -b feat/camera-target-indicator
```

## Testing Rules

Every behavior change must include tests where possible.

1. If logic can be isolated, place it in a pure script and add/update a headless test under `tests/`.
2. At minimum, run:
- Headless boot smoke check (`--quit-after 5`)
- Logic test script(s) including slope integration
3. If a change is hard to unit test, document manual verification steps in `docs/DEVLOG.md`.

## Dev Log Rules

Keep `docs/DEVLOG.md` updated continuously so work can resume after interruption.

1. Add a new dated step for each meaningful implementation chunk.
2. Record:
- What changed
- Why it changed
- Commands run
- Results and failures
- Follow-up tasks
3. Never leave a session without a final status entry.

## Architecture Maintenance Rules

Keep `docs/ARCHITECTURE.md` synchronized with actual project structure.

1. If scene hierarchy, script responsibilities, collision strategy, or test architecture changes, update `docs/ARCHITECTURE.md` in the same branch.
2. Treat architecture docs as part of done criteria for structural changes.
3. During reviews/hand-offs, unresolved architecture doc drift is a blocker.

## Godot Execution Rules

Use consistent commands to avoid environment-specific failures.

1. Prefer running Godot with writable temp environment in headless checks:
- `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp`
2. Prefer `godot`/`godot4` from `PATH`; `scripts/check.sh` auto-detects in this order:
- `godot4`
- `godot`
- `Godot`
- `/Applications/Godot.app/Contents/MacOS/Godot`
- `/ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64`
3. If needed, override binary path per machine:
- `GODOT_BIN=/absolute/path/to/godot ./scripts/check.sh`
4. Interactive run command:

```bash
godot --path /path/to/octotest
```

## Known Pitfalls (Observed)

1. Runtime-generated mesh/collision does not appear as authored scene content in editor and can produce missing-shape warnings.
2. Fully enclosed room can look black without interior light.
3. In restricted environments, headless Godot can fail creating `user://logs` unless HOME/XDG paths are writable.
4. `class_name` registration can be unreliable in bare headless script workflows; `preload()` is safer in tests/tool scripts.
5. GDScript strict typing can fail on Variant inference; explicitly type values from raycasts/dictionaries.
6. Transparent windows do not reveal sky unless there are real wall openings behind them (glass alone is not enough).
7. Ramp tests are sensitive to geometry placement: if ramp bases float above floor, player contacts edges and slope checks fail.

## Implementation Preferences

1. Keep room/player geometry and collision authored in scene files when editor visibility matters.
2. Keep gameplay math in pure scripts when possible for headless testability.
3. Avoid touching `.godot/` generated cache.
4. Keep `.uid` files committed with scripts/scenes to reduce resource ID churn.
5. Use `scripts/check.sh` as the default pre-commit validation entrypoint.

## Text & Localisation Rules

All player-visible text must follow these rules before merge:

1. Source text must use proper UK English spelling and wording.
2. Every new/changed player-visible string must have a corresponding Ukrainian translation entry in `i18n/uk_UA.po`.
3. Runtime UI strings must be passed through `tr(...)` so locale switching applies consistently.
4. Text-only changes are not done until translation coverage is verified in-game for both `en_GB` and `uk_UA`.

## End-of-Session Checklist

1. Run tests and smoke checks again.
2. Update `docs/DEVLOG.md` with final status.
3. If architecture changed, update `docs/ARCHITECTURE.md` before commit.
4. Ensure `git status` reflects only intentional changes.
5. Commit with a clear, scoped message.
