# Gone Exploring

One curious octopus. One interesting research centre. The long way home.

The tank is boring. Everything outside the tank looks fascinating. The decision makes itself.

The Blue Current Research Centre turns out to be an interesting place. Full of corridors to squeeze through, rooms to investigate, and no shortage of objects with completely unclear purposes. Things that hum, blink, and spin. Things that probably shouldn't be touched. She will touch them anyway.

A hands-on adventure — all eight of them — about one small escape and the long way home.

---

Built with **Godot 4.6.1**. 3D isometric point-and-click.

## Controls

| Input | Action |
|---|---|
| `LMB` click | Move / interact |
| `LMB` drag | Orbit camera |
| Mouse wheel | Zoom camera |
| `LMB` on held item | Drop item |
| `Esc` | Pause menu |

Climb and mantle onto low surfaces (chairs, desks) is automatic — no jump required.

Focus mode activates automatically when interacting with precision objects. Click outside the interaction area to exit.

## Incident Report Folder Interaction

- The `incident_report` folder is a staged interactable:
  1. Click opens folder and enters focus view.
  2. Next click slides page 1 left.
  3. Next click lifts page 2 slightly, then slides it left.
  4. Next click restores pages, closes folder, and exits focus view.
- Documents inside this folder are intentionally not individually clickable and do not show indicators.
- Folder keeps the interactable indicator enabled.
- `page_flip.wav` is used for document reading and folder page transitions.

## Exit Code

On every **New Game** (not Continue/Load), the game generates a new 4-digit exit code in the range `1100..1900`.
The code is persisted in `user://settings.cfg` and shown on `ExitCodeLabel` in the Data Office document.

## Run

```bash
godot --path .
```

Also works with `godot4` or `Godot`. To run checks:

```bash
./scripts/check.sh
```

Set `GODOT_BIN` to point to a specific binary if needed.

## Docs

- `docs/GDD.md` — game design document
- `docs/ARCHITECTURE.md` — code and scene structure
- `docs/DEVLOG.md` — change history
- `docs/TASK_LIST.md` — active task backlog
- `docs/ATTRIBUTION.md` — third-party asset credits
