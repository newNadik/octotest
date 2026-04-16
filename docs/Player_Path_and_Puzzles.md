# Player Path & Interactables

---

## Door Logic

| Door | Type | How to open |
|---|---|---|
| Staff wing entrance | Keypad | Staff code (sticky note, Data Office) |
| Data Office | Keypad | Staff code |
| Systems Room | Keypad | Staff code |
| Quarters / Kitchen / Showers | No lock | Inside staff wing |
| Chemistry Lab | Card reader | Researcher card |
| Workshop | Card reader | Researcher card |
| Energy Lab | Card reader | Researcher card |
| Wet Room | Card reader + hatch | Researcher card + wrench |
| Medical Bay / Public areas | No lock | Always open |

---

## Critical Path

```
Data Office → Quarters → Workshop → Energy Lab → Wet Room ✓
```

## Key Items

| Item | Found | Used |
|---|---|---|
| Staff code (sticky note) | Data Office, desk | All keypad doors |
| Researcher card | Quarters, sleeping crew member | All lab card readers |
| USB drive | Data Office, desk | Workshop terminal |
| Wrench | Workshop, pegboard | Wet room hatch release |

---
---

## Rooms

---

### Data Office *(start)*

> OCT-05 wakes up here. Station is quiet. Lights on.

| Interactable | Type | Detail |
|---|---|---|
| Sticky note on desk | 🔑 Key item | Staff code. Note reads: *"New code as of Monday — please memorise and destroy (Karen)"* |
| USB drive | 🔑 Key item | On desk. Carry to Workshop |
| PC monitor A | 💬 Read | Partial station map — shows wet room is the exit |
| PC monitor B | 🔒 Locked terminal | Requires login code from Kitchen fridge note |
| Whiteboard / corkboard | 💬 Read | Research notes, names, lore |
| Printed report — OCT-05 incident | 💬 Read | Filed report: OCT-05 found tangled in new test energy equipment during installation. Showed unusual curiosity around the hardware. Minor head trauma. Brought in to recover on-site. |
| Wall calendar | 💬 Read/Inspect | A date circled in marker: *"OCT-05 release"* — Monday or Tuesday next week |
| Desk lamp | 🔘 Toggle | Turns on/off |
| Coffee mug | 📦 Carry | Prop |
| Small cactus pot | 📦 Carry | On desk. Prop |
| Energy drink cans | 📦 Carry | Prop — tower of them on one desk |

---

### Systems Room *(optional — staff wing)*

> Likely explored while searching the wing. No key items but good foreshadowing.

| Interactable | Type | Detail |
|---|---|---|
| Maintenance log clipboard | 💬 Read | Notes a known fault in Energy Lab — power to wet room section intermittent |
| Status monitor | 💬 Read | Shows which systems are offline. Wet room section flagged |
| Life support panel | 🔘 Toggle | Switches and dials — atmospheric, no mechanical effect |
| "DO NOT TURN OFF" note | 💬 Read | Taped to a server. Character touch |
| Coffee mug | 📦 Carry | Prop — engineer's mug, has a name on it |
| Torch / flashlight | 📦 Carry | Prop |

---

### Kitchen *(optional — staff wing)*

> Open, no lock. Quiet, someone left a mug out.

| Interactable | Type | Detail |
|---|---|---|
| Fridge | 🔑 Key item inside | Labelled lunch container holds a folded note with PC login code (for Data Office monitor B — optional) |
| Noticeboard | 💬 Read | Crew duty rota. Confirms only skeleton crew on-site |
| Passive-aggressive dishes note | 💬 Read | Character touch |
| "DO NOT EAT — Chen" label | 💬 Read | Character touch |
| Coffee machine | 🔘 Toggle | Makes noise, does nothing |
| Coffee mug | 📦 Carry | Someone's special mug — clearly labelled as theirs |
| Single sad banana | 📦 Carry | Prop |

---

### Quarters *(critical)*

> Lights off. Researcher asleep in a bunk.
> Turning on the light switch triggers the scene: *"I'm sleeping. I asked you a million times, Mark!"*
> Researcher card is on the bedside table. OCT-05 takes it while they sleep.

| Interactable | Type | Detail |
|---|---|---|
| Light switch | 🎬 Trigger | Triggers sleeping researcher scene |
| Researcher card | 🔑 Key item | On bedside table. Unlocks all labs |
| Journal / notebook | 💬 Read | Personal lore — includes entries about OCT-05: *"the little one keeps tapping at the glass, she's too clever for her own good"* |
| Framed photo | 💬 Read/Inspect | Personal touch, lore |
| Toy shark | 📦 Carry | On pillow. Prop — fun to carry |
| Movie poster | 💬 Inspect | Above bunk 2. Sci-fi |
| Octopus plushie on shelf | 📦 Carry | OCT-05 can carry a plushie version of themselves |
| Small cactus pot | 📦 Carry | On desk. Personal touch |
| Playing cards (mid-game) | 💬 Inspect | Left on table, character touch |

---

### Atrium & Observation Deck *(optional — public)*

> Open hub. Good place to get oriented. Connects to all lab doors.

| Interactable | Type | Detail |
|---|---|---|
| Mission briefing board | 💬 Read | What the station was researching. Key lore |
| Crew roster noticeboard | 💬 Read | Who was on-site. Cross-reference with personal items found elsewhere |
| "Days since last incident" board | 💬 Inspect | Number is a detail — can hint at timeline |
| Visitor log | 💬 Read | Last entries. Lore |
| Intercom panel | 🔘 Toggle | Triggers PA announcement. Atmospheric |
| Vending machine | 🔘 Toggle | Lights up, hums. Doesn't dispense |
| Telescope | 🔘 Toggle | Look through it — see something outside in the water |

---

### Gift Shop *(optional — public)*

> No key items. Pure character moment.

| Interactable | Type | Detail |
|---|---|---|
| Octopus plushie rack | 📦 Carry | OCT-05 can carry one |
| Snow globe | 📦 Carry / Inspect | Ocean themed |
| Postcard stand | 💬 Read | Station postcards, lore |
| Book rack | 💬 Read | Field guide — sea creatures, lore |
| Till / register | 🔘 Toggle | Opens drawer. Empty |

---

### WC *(optional — public)*

> Brief, comic relief.

| Interactable | Type | Detail |
|---|---|---|
| Light switch | 🔘 Toggle | Flickers. One bulb is out |
| Stall graffiti | 💬 Read | Comic lore, character voices |
| Wet floor sign | 📦 Carry | Can be placed anywhere |
| Mirror | 💬 Inspect | OCT-05 looks at their reflection |

---

### Medical Bay *(optional — public)*

> Always open. No key items but contains the most significant story lore.

| Interactable | Type | Detail |
|---|---|---|
| Patient clipboard | 💬 Read | OCT-05's intake form. *"Subject: OCT-05. Admitted [date]. Cause: head trauma, sustained during test energy equipment installation. Prognosis: full recovery expected. Scheduled release: [release date]."* |
| Medic terminal | 💬 Read | Medical logs — recovery notes, daily check-ins on OCT-05, hints she was more alert than expected |
| Sticky note on terminal | 💬 Read | *"Don't forget — OCT-05 release Monday! Someone needs to be here to see her off — she deserves a proper goodbye"* |
| Medicine cabinet | 🔘 Toggle | Opens. Inspectable contents |
| Defibrillator | 💬 Inspect | Wall-mounted, inspectable |
| Stethoscope | 📦 Carry | Prop |

---

### Chemistry Lab *(optional — researcher card)*

> Interesting to explore, nothing critical.

| Interactable | Type | Detail |
|---|---|---|
| Lab computer | 💬 Read | Research logs — what they were studying |
| Whiteboard | 💬 Read | Formulas, notes, someone's hypothesis |
| Microscope | 🔘 Toggle | Look through it — specimen on the slide |
| Specimen jars | 💬 Inspect | Labelled. Lore |
| Fume hood | 🔘 Toggle | Fan turns on |
| Lab notebook | 💬 Read | Researcher's personal notes. Lore |

---

### Workshop *(critical — researcher card)*

> Dark when entered. Mid-project on one bench.

| Interactable | Type | Detail |
|---|---|---|
| Wrench on pegboard | 🔑 Key item | Carry to wet room hatch release |
| Workbench terminal | 🔑 Key item use | Insert USB drive → displays wet room hatch schematic |
| 3D printer | 🔘 Toggle | Starts printing. Ambient noise |
| Pegboard tools | 💬 Inspect | Various. One gap where wrench was |
| Half-finished robot | 💬 Inspect | Personal project on bench corner |
| Printed schematics (pinned) | 💬 Read | Technical lore |
| Sticker-covered toolbox | 💬 Inspect | Band logos, nerdy stickers |
| Named 3D printer label | 💬 Read | Character touch — someone named it |
| Coffee mug | 📦 Carry | On bench. Has a name on it |

---

### Energy Lab *(critical — researcher card)*

> Power to wet room section is offline. Fix it here.

| Interactable | Type | Detail |
|---|---|---|
| Power distribution board | 🔑 Puzzle | Two steps: flip breaker → confirm on console. Restores wet room power |
| Console panel | 💬 Read / 🔘 Toggle | Shows wet room status. Changes after power restored |
| Project brief (pinned to wall) | 💬 Read | *"New test energy unit — installation phase 2. Do not operate near open water tanks. Keep all marine subjects at safe distance during calibration."* OCT-05 was clearly not at a safe distance |
| Warning tape on floor | 💬 Inspect | Marks the area around the new equipment — still half-installed |
| Maintenance clipboard | 💬 Read | Energy log — confirms the fault, notes power to wet room section tripped during the incident |
| High-voltage signage | 💬 Inspect | Flavour |

---

### Wet Room *(exit)*

> Power is restored. Card reader works. Hatch is still sealed — needs the wrench.

| Interactable | Type | Detail |
|---|---|---|
| Card reader | 🔑 Key item use | Researcher card → door opens |
| Hatch manual release | 🔑 Puzzle | Use wrench on release point → hatch opens |
| Conditions board | 💬 Read | Water temp, visibility. Final atmospheric detail |
| Dive log board | 💬 Read | Last entry. Final lore beat |
| Underwater torch | 📦 Carry | Into the ending |
| Moon pool | 🎬 Trigger | Final interaction → escape sequence |

---

## Interactable Types Key

| Icon | Type | Meaning |
|---|---|---|
| 🔑 | Key item / Key item use | Critical path — must find or use |
| 💬 | Read / Inspect | Lore, atmosphere, character |
| 🔘 | Toggle | Button, switch, machine — no puzzle use |
| 📦 | Carry | Pick up and hold, no puzzle use |
| 🎬 | Trigger | Triggers a scene or sequence |
