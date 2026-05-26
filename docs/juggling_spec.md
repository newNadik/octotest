# Juggling Logic Specification (Octo + Balls)

## 1. Overview

Juggling is driven by a single `JuggleController` node (child of the player). All ball
counts — 1 through 8 — use the same **lane model**: a lane is a pair of arm sockets that
exchange balls. Single-ball is just a lane whose two sockets are the same arm (a self-toss).
This unifies all modes under one loop, with no special-casing per ball count.

---

## 2. Core Abstraction: the Lane

A **lane** is a record `{ arm_a, arm_b, balls[] }`.

- `arm_a` and `arm_b` are arm socket references.
- For a self-toss (1 ball on one arm), `arm_a == arm_b`.
- Each ball in the lane has a `phase_offset ∈ [0, 1)` that staggers it in time.
  - 1 ball per lane → offset `0.0`
  - 2 balls per lane → offsets `0.0` and `0.5`

A ball's current phase is:

```
t = fmod(total_time / beat_duration + ball.phase_offset, 1.0)
```

where `total_time` is the shared timer owned by `JuggleController`.

At `t = 0.0` the ball is at `arm_a`. At `t = 1.0` the ball arrives at `arm_b`,
ownership swaps (`arm_a ↔ arm_b`), and the cycle repeats.

---

## 3. Lane Assignment (1–8 Balls)

`lane_count = ceil(ball_count / 2)`. Balls are distributed across lanes, filling
each lane with 2 balls before opening the next.

| Balls held | Lanes | Layout               |
|:----------:|:-----:|----------------------|
| 1          | 1     | [1]                  |
| 2          | 1     | [2]                  |
| 3          | 2     | [2, 1]               |
| 4          | 2     | [2, 2]               |
| 5          | 3     | [2, 2, 1]            |
| 6          | 3     | [2, 2, 2]            |
| 7          | 4     | [2, 2, 2, 1]         |
| 8          | 4     | [2, 2, 2, 2]         |

Lane arm pairs are assigned from the set of arms currently holding balls, sorted
deterministically (by socket index). Lane 0 gets arms `[0, 1]`, lane 1 gets `[2, 3]`,
and so on.

---

## 4. Ball Position Formula

Each ball's world position is computed every frame from its lane and phase `t`:

```
smooth_t   = smoothstep(0.0, 1.0, t)                         # smooth horizontal travel
base_pos   = lerp(arm_a.socket_pos, arm_b.socket_pos, smooth_t)
arc_y      = arc_height * 4.0 * t * (1.0 - t)               # parabolic peak at t=0.5
sway_fwd   = sin(PI * t) * forward_offset                    # gentle forward lean
ball.pos   = base_pos + Vector3(0, arc_y, 0) + forward * sway_fwd
```

For a self-toss lane (`arm_a == arm_b`), `base_pos` is constant and only the arc
and sway offsets move the ball.

---

## 5. Arm Gestures

Gestures are fired on phase thresholds, not on discrete beats:

| Phase threshold | Event                         | Which arm        |
|:---------------:|-------------------------------|------------------|
| `t < 0.05`      | **Toss** — tip/flick gesture  | `arm_a`          |
| `t > 0.80`      | **Prepare catch** — extend    | `arm_b`          |
| `t ≥ 1.0`       | **Catch confirmed** + swap    | `arm_b` → `arm_a`|

Fire each gesture only once per cycle (guard with a `toss_fired` / `catch_fired` flag
per ball; reset both flags when `t` wraps).

---

## 6. Lifecycle

### Start
- `InteractionController` calls `JuggleController.on_ball_picked_up(ball, arm)`.
- If juggling is inactive, start: set `total_time = 0`, assign lanes, set `active = true`.
- If juggling is already active, add the new ball to the lowest-count lane and
  recalculate that lane's phase offsets.

### Per-frame (`_process(delta)`)
1. `total_time += delta`
2. For each ball, compute `t` and update position.
3. Fire arm gestures where applicable.
4. If `t ≥ 1.0`: swap lane's `arm_a ↔ arm_b`, reset gesture flags.
5. If `total_time ≥ beat_count * beat_duration`: call `_end_juggling()`.

### End
- Called when the beat limit is reached or all balls leave juggling state.
- Clear all lane and ball juggle state.
- Balls resume normal held-item follow via `InteractionController`.

### Ball Dropped or Consumed
- Remove ball from its lane immediately.
- If the lane now has 0 balls: remove the lane; reassign remaining balls across
  remaining lanes (rebalance and recalculate phase offsets).
- If no lanes remain: call `_end_juggling()`.
- Otherwise, continue from current `total_time` (no reset).

---

## 7. Ball Eligibility

- A ball is eligible if its pickup root script is `res://scripts/station/items/the_ball.gd`.
- Non-ball held items never enter juggling state and their arms are never used as lane arms.
- `ball_id` (export int, `1..8`) will be added as a deterministic identifier in Phase 2.

---

## 8. Data Model

### JuggleController state
```
active:         bool
total_time:     float          # continuous timer, stopped at beat_count * beat_duration
beat_count:     int            # default 8
beat_duration:  float          # default 0.42 s
lanes:          Array[Lane]
```

### Lane
```
arm_a:          NodePath / socket ref
arm_b:          NodePath / socket ref   # == arm_a for self-toss
balls:          Array[BallState]
```

### BallState
```
item_ref:       Node
phase_offset:   float          # 0.0 or 0.5 (within lane)
toss_fired:     bool
catch_fired:    bool
```

---

## 9. Configuration Defaults

```
beat_count            = 8
beat_duration         = 0.42      # seconds — should be validated against arm gesture anim length
arc_height            = 0.22      # self-toss and default multi-ball height
forward_offset        = 0.10      # forward sway amplitude
```

Multi-ball lane-specific overrides (Phase 3):
```
lane_arc_height       = 0.35      # higher arc for cross-body throws
lane_forward_offset   = 0.05
```

> **Note:** `beat_duration` must be ≥ the arm gesture animation length. If arm
> animations have a fixed duration, drive `beat_duration` from that value rather
> than setting it independently.

---

## 10. Integration Points

| Hook | Location |
|------|----------|
| Ball picked up | `InteractionController._pick_up_interactable` → `JuggleController.on_ball_picked_up(ball, arm)` |
| Ball dropped | `InteractionController._on_item_dropped` → `JuggleController.on_ball_dropped(ball)` |
| Position override | `InteractionController._update_held_item_transform` — skip normal follow if `JuggleController.is_juggling_ball(ball)` |
| Arm gesture | `player.play_interaction_arm_gesture(arm_name, target_position)` |

`JuggleController` is a child node of the player. It is not a global autoload.

---

## 11. Non-Goals (Current Phase)

- No projectile physics — balls do not leave socket control.
- No infinite loops — juggling always ends after `beat_count` beats.
- No random lane assignment or random ball behavior.
- No arms used that are not holding balls.

---

## 12. Implementation Phases

### Phase 1 — Single-ball self-toss *(current)*
- 1 lane, `arm_a == arm_b`, 1 ball.
- Arc + sway offsets applied each frame.
- Toss and catch arm gestures.
- Ends after `beat_count` beats.

### Phase 2 — Two-ball alternating loop
- 1 lane, `arm_a ≠ arm_b`, 2 balls with offsets `0.0` and `0.5`.
- Ownership swap at `t ≥ 1.0`.
- Lane pair chosen from the two ball-holding arms.
- Add `ball_id` export to `the_ball.gd`.

### Phase 3 — 3–8 balls with lane scaling
- Full lane assignment table (§3).
- Lane rebalancing on drop/add.
- Per-lane arc height config.
- Graceful degradation: ball count drops → lanes collapse → juggling ends cleanly.
