# Dive Lock System Design

## Overview

The dive lock uses a two-step control system: **keypad** (select operation) + **activation lever** (start operation).
Operations will not begin until the lever is pulled. The system enforces safe sequencing — wrong-state commands are rejected,
and interacting with the numpad or inner door while armed cancels the pending operation.

---

## Codes

| Code | Operation |
|---|---|
| *(generated at new game)* | Exit Station |
| **2407** | Enter Station |
| **7700** | Emergency Seal |

**Validity rules:**
- Exit Station only works when chamber is **drained**
- Enter Station only works when chamber is **flooded**
- Emergency Seal works in any state

---

## State Reference

### STANDBY — chamber drained

| Element | State |
|---|---|
| Lamp | blue steady |
| Display | `ENTER CODE` |
| Inner door | green (unlocked) |
| Outer door | red (locked) |

### STANDBY — chamber flooded

| Element | State |
|---|---|
| Lamp | green steady |
| Display | `ENTER CODE` |
| Inner door | red (locked) |
| Outer door | green (unlocked) |

### ARMED — valid code accepted, waiting for lever

| Element | State |
|---|---|
| Lamp | blue rotating beacon |
| Display | `EXIT STATION` / `ENTER STATION` / `EMRG SEAL` + `PULL LEVER` |
| Lever indicator | blue flashing (mirrors lamp) |
| Inner door | red (locked) |
| Outer door | red (locked) |

### RUNNING — lever pulled, operation in progress

| Element | State |
|---|---|
| Lamp | orange rotating beacon |
| Display | `FLOODING` or `DRAINING` |
| Lever indicator | orange solid (mirrors lamp) |
| Inner door | red (locked) |
| Outer door | red (locked) |

### COMPLETE — operation finished

Transitions directly into the new STANDBY state — no separate complete step.
Lever auto-animates back to UP position. The lever rising, lamp color change, and door color change
together form the "done" signal to the player.

| After Exit Station (now flooded) | After Enter Station (now drained) |
|---|---|
| Lamp → green steady | Lamp → blue steady |
| Lever indicator → off | Lever indicator → off |
| Outer door → green | Inner door → green |

### REJECTED — wrong-state code or unsafe condition

| Element | State |
|---|---|
| Lamp | red flash × 3, then previous STANDBY color |
| Display | `REJECTED` briefly, then `ENTER CODE` |
| Doors | unchanged |

### SEALED — Emergency Seal activated

| Element | State |
|---|---|
| Lamp | red rotating beacon |
| Display | `SEALED` |
| Lever indicator | red flashing (mirrors lamp) |
| Inner door | red (locked) |
| Outer door | red (locked) |

After 60 seconds the seal times out automatically. The lever slowly rises over the timeout duration
as a visible countdown. When it reaches the top:
- Lamp shifts to the correct STANDBY color for current chamber state (blue or green)
- Lever indicator turns off
- Lever locks in UP position
- Numpad re-enabled, doors restore to STANDBY rules

---

## Sequence Reset

While in ARMED state, the following cancel back to STANDBY (lamp returns to steady blue or green, lever locks):

- Player presses any key on the numpad
- Player interacts with the inner door (door can open if chamber drained; arm state still clears)

---

## Components

| Script | Node | Responsibility |
|---|---|---|
| `numpad.gd` | `numpad.tscn` root | Button input, masked display, signals: `code_submitted(text)`, `input_changed` |
| `lever.gd` | `lever.tscn` root | UP→DOWN animation, indicator light, interactable toggle, signal: `lever_pulled` |
| `bulkhead_lamp.gd` | lamp node | Color + pulse mode, driven by controller |
| `dive_lock.gd` | parent Node3D | State machine, code validation, door/lamp/lever control |

### Controller exported node paths
- Numpad
- Lever
- Bulkhead lamp
- Inner door
- Outer door
- `exit_code: String` (set at new game)
