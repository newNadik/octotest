# Testing Guide

## Automated Checks

Run all required headless checks:

```bash
./scripts/check.sh
```

Equivalent commands:

```bash
GODOT_BIN=/absolute/path/to/godot ./scripts/check.sh
```

or, if a Godot binary is on your `PATH`:

```bash
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot --headless --path /path/to/octotest --quit-after 5
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot --headless --path /path/to/octotest --script res://tests/movement_math_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot --headless --path /path/to/octotest --script res://tests/slope_movement_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot --headless --path /path/to/octotest --script res://tests/card_reader_interaction_test.gd
```

`scripts/check.sh` also supports `godot4`, `Godot`, default macOS app path, and the legacy `/ssd2/...` Linux path.

## Manual Visual QA Checklist

1. Launch project and confirm startup menu (`main_menu.tscn`) appears first.
2. Click `New Game` and confirm gameplay scene loads.
3. Confirm room is larger and ceiling is high.
4. Confirm north/south windows show sky (true wall openings, not just transparent overlays).
5. Confirm transparent window blocks are still collidable (player cannot pass through).
6. Confirm room palette is muted and lower contrast than player cube.
7. Confirm elevated office props (chairs/desks) are climbable with smooth mantle motion.
8. Confirm player does not climb onto chair backs/non-walkable narrow tops.
9. Confirm camera orbit and zoom still behave as expected.
10. Confirm HUD key-hint panel is visible in a corner and does not block click-to-move when clicking through it.
11. Press `Esc` to open/close in-game pause menu; verify `Resume` closes pause menu and `Main Menu` returns to startup menu.
12. In startup main menu, press `Esc` and confirm the app does not exit.
13. Click startup `Load Game` and `Settings` and confirm placeholder warnings are logged (not implemented yet).
14. Confirm light switch is mounted on wall and toggles room light + button material.
15. Confirm hover color state when out of range.
16. Confirm in-range interaction color state.
17. Confirm blocked interaction color state.
18. Confirm click on out-of-range interactable moves player closer and auto-interacts when in range.
19. Confirm octopus can hold up to 8 pickup items.
20. Confirm movement slows at heavy carry threshold and stops when fully loaded.
21. Confirm `LMB` on held item drops that specific item.
22. Confirm `F` drops last held item and `Shift + F` drops all.
23. Confirm clicking a focus-enabled object enters focus mode after approach (e.g. `CardReader`).
24. In focus mode, confirm held items appear at the bottom and can be selected by click.
25. Confirm clicking outside focus interaction area exits focus immediately.
26. Confirm card reader LED states: yellow (empty), red (wrong), green (correct).
27. Confirm reader holds one card at a time: second card cannot replace inserted card.
28. Confirm clicking inserted card retrieves/ejects it back to held items (when a slot is available).
29. Confirm non-applicable held item click in focus (e.g. mug on reader) animates toward slot and returns.
30. Confirm code panel can be clicked to enter focus mode.
31. Confirm code panel keypad is only clickable while focused.
32. Confirm code panel input supports `0-9`, `<<` (backspace), and `OK`.
33. Confirm default code `1234` sets display to `GRANTED` and latches green LED.
34. Confirm wrong code sets display to `DENIED`, red LED, then resets to `ENTER CODE` + yellow LED.
35. Confirm code panel LED colors match card reader colors for idle/wrong/correct states.
36. Confirm non-applicable held item click in code panel focus animates toward panel and returns.
37. Confirm all code panel button columns are clickable (no blocked `2/3`, `5/6`, `8/9`, `0/OK` patterns).
38. Confirm pickup item size stays consistent through hold -> reader insert -> eject -> hold cycles.

## Regression Focus Areas

1. Scene authoring changes can break collision layers used by click raycast.
2. Ramp position/height adjustments can invalidate slope movement expectations.
3. Wall/window edits can accidentally remove visual access to sky.
4. Interaction layer (`collision_layer = 8`) misconfiguration can break hover/click detection.
5. Carry layout changes can cause held-item clipping or unstable drop behavior.
6. Focus click hit areas are sensitive to camera/layout tuning; verify no accidental near-click item activation.
7. Reparenting items between world/hand/reader can cause scale drift; verify world scale is preserved.
