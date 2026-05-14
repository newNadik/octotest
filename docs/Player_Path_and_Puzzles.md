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

# Light Switch Dialogue Sequence
# Character: Sleeping crew member (night shift worker)
# Trigger: Player toggles lights in quarters
//LightSwitchDialogue_Neil(orus)

## FIRST LIGHT ON:
// light_switch_on_1.mp3
"Mike, I told you... I have night shift. Please"
"Майк, я ж казав... У мене нічна зміна. Будь ласка"

## LIGHT OFF:
// light_switch_off_1.mp3
"Thank you"
"Дякую"
## SECOND LIGHT ON:
// light_switch_on_2.mp3
"Seriously? I need to sleep"
"Серйозно? Мені треба спати"

## LIGHT OFF:
// light_switch_off_2.mp3
*grumbles* "...fine"
*буркоче* "...добре"

## THIRD LIGHT ON:
// light_switch_on_3.mp3
"Are you kidding me right now?"
"Ти що, жартуєш?"

## LIGHT OFF:
// light_switch_off_3.mp3
*heavy sigh* "...thank you"
*важко зітхає* "...дякую"

## FOURTH LIGHT ON:
// light_switch_on_4.mp3
"Mike! What is WRONG with you?!"
"Майк! Та що з тобою не так?!"

## FIFTH LIGHT ON:
// light_switch_on_5.mp3
"I swear to god, Mike... I'm putting in a complaint"
"Богом клянусь, Майк... Я подам скаргу"

## LIGHT OFF:
// light_switch_off_5.mp3
"Unbelievable... every single time... ridiculous..."
"Не можу повірити... кожного разу... абсурдно..."

## SIXTH LIGHT ON:
// light_switch_on_6.mp3
"THAT'S IT. I'm writing this down. Date, time, EVERYTHING"
"ВСЕ. Я все записую. Дата, час, ВСЕ"

## SEVENTH LIGHT ON:
// light_switch_on_7.mp3
"You know what? Fine. FINE. You win. Hope you're happy"
"Знаєш що? Добре. ДОБРЕ. Ти переміг. Сподіваюся, ти задоволений"

## EIGHTH LIGHT ON:
// light_switch_on_8.mp3
"You are being CHILDISH. I won't speak to you ever again. We're done. DONE"
"Ти поводишся ЯК ДИТИНА. Я більше ніколи з тобою не розмовлятиму. Все. ВСЕ"

## ANY SUBSEQUENT LIGHT TOGGLES:
*no response - he's given up*

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
