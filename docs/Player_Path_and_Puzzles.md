# Player Path & Interactables

## Interactable Types Key

| Icon | Type |
|---|---|
| 🔑 | Key item / Key item use |
| 💬 | Read / Inspect |
| 🔘 | Toggle |
| 📦 | Carry |
| 🎬 | Trigger |

---

## Critical Path

```
Data Office → Quarters [steal Neil's card] → [exit staff area] → Atrium/Kitchen [steal Mykhailo's card] → Staff only hall → Workshop → Energy Lab → Wet Room ✓
```

## Key Items

| Item | Found | Used |
|---|---|---|
| Neil's access card | Quarters — Neil's bed | Staff area door (both sides), Systems Room, Data Office |
| Mykhailo's access card | Kitchen — Mykhailo (eating) | Staff only hall, Chem Lab, Energy Lab, Workshop, Wet Room |
| Dive lock code | Data Office — procedure documents | Wet room hatch code pad |

## NPCs

| Character | Location | Threat |
|---|---|---|
| Neil Carver | Quarters | None — card on his bed |
| Rory Fraser (Mechanic) | Systems Room | ⚠️ Resets to start if seen |
| Mykhailo Kovalenko | Kitchen / Atrium | None — card can be stolen |

## Doors

| Door | Requires | Access denied if |
|---|---|---|
| Staff area entrance | Neil's card (both sides — flood-containment protocol) | Wrong card or no card |
| Data Office | Neil's card (re-entry only, player starts inside) | Wrong card or no card |
| Systems Room | Neil's card | Wrong card or no card |
| Staff only hall | Mykhailo's card | Wrong card or no card |
| Chemistry Lab | Mykhailo's card | Wrong card or no card |
| Workshop | Mykhailo's card | Wrong card or no card |
| Energy Lab | Mykhailo's card | Wrong card or no card |
| Wet Room | Mykhailo's card + dive code | Wrong card or no card |
| Quarters / Kitchen / Showers / Medical Bay / Public | No lock | — |

---

## Rooms

### Data Office *(start)*

- [ ] 🔑 Emergency procedure document (dive lock code)
- [ ] 🔘 PC monitor A
- [ ] 🔘 PC monitor B
- [ ] 💬 Printed report — OCT-05 incident
- [ ] 💬 Wall calendar (release date circled)
- [ ] 🔘 Desk lamp
- [ ] 📦 Coffee mug
- [ ] 📦 Small cactus pot
- [ ] 📦 Energy drink cans (tower)

---

### Systems Room *(optional — staff wing)*

> ⚠️ Mechanic NPC — entering her field of view resets to start

- [ ] 📦 Torch / flashlight
- [ ] 🔘 Light switch — mechanic says *"Hey, who turned off the light"* and switches on her headband lights
- [ ] 📦 Bring banana from Kitchen — mechanic says *"Thanks! at least someone cares for mechanics"* (still resets if seen)

---

### Kitchen *(critical — public)*

> Mykhailo Kovalenko eating here — steal his card

- [ ] 🔑 Mykhailo's access card (on Mykhailo)
- [ ] 💬 Passive-aggressive dishes note
- [ ] 💬 Note to keep mugs in the kitchen - when all mugs in the kitchen room "Nicest Person in the world" cale appears 
- [ ] 📦 Single sad banana

---

### Quarters *(critical)*

- [ ] 🎬 Light switch (wakes Neil)
- [ ] 🔑 Neil's access card (on his bed)
- [ ] 📦 Toy shark (on pillow)
- [ ] 💬 Movie poster (above bunk 2)
- [ ] 📦 Octopus plushie on shelf
- [ ] 📦 Small cactus pot
- [ ] 📦 Single flip flop (pair with Shower flip flop)

---

### Atrium & Observation Deck *(optional — public)*

- [ ] 💬 Mission briefing board, other posters
- [ ] 📦 Coffe mug
- [ ] 🔘🔑 Vending machine (needs coin)
- [ ] 🔑 Coin (on bench / under table)

---

### Gift Shop *(optional — public)*

- [ ] 📦 Octopus plushie rack
- [ ] 📦 shark plushie rack
- [ ] 🔘 Postcard stand (spins)

---

### WC *(optional — public)*

- [ ] 📦 Wet floor sign (placeable anywhere)

---

### Medical Bay *(optional — public)*

- [ ] 📦 Stethoscope — OCT-05 tries it on a tentacle

---

### Chemistry Lab *(optional — researcher card)*

- [ ] 🔘 Fume hood (fan on)
- [ ] 🔘 Centrifuge (place sample tube → spin)

---

### Workshop *(critical — researcher card)*

- [ ] 📦 Screwdriver
- [ ] 🔘 Measuring tape
- [ ] 📦 3D printed parts of the robot
- [ ] 📦 Coffee mug
- [ ] projector on the shelf, if light is off - can see photos of station building 

---

### Energy Lab *(critical — researcher card)*

- [ ] 🔘 Half-finished robot (complete via 3D printer)

---

### Wet Room *(exit)*

- [ ] 🔑 Card reader (Mykhailo's card)
- [ ] 🔑 Hatch code pad (dive lock code)
- [ ] 💬 Dive log board
- [ ] 🎬 Moon pool (escape sequence)
