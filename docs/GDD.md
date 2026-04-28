🐙

**GONE EXPLORING**

*Game Design Document  •  Living Draft*

*Smart. Curious. Always watching.*

| Game Title | Gone Exploring |
| :---- | :---- |
| **Engine** | Godot 4 (3D) |
| **Platform** | iPad, PC, Mac |
| **Developer** | 2-person indie team |
| **Tone** | Cute, curious, grounded — Stray underwater |
| **Title** | Gone Exploring |
| **Stage** | Active development |

## **Contents**

- [Vision](#vision)
- [Core Concept](#core-concept)
- [Octo](#octo)
- [World Bible](#world-bible)
- [The Station](#the-station)
- [Blue Current Research Facility (Room & Space Reference)](#blue-current-research-facility-room--space-reference)
- [Story](#story)
- [Game Design](#game-design)
- [Game Loop](#game-loop)
- [Mechanics](#mechanics)
- [Controls](#controls)
- [Aesthetic Direction](#aesthetic-direction)
- [Development Roadmap](#development-roadmap)

# **Vision**

## **Core Concept**

*A curious octopus escapes her research tank on a Friday evening and explores an underwater science station — solving puzzles, avoiding the skeleton crew, and eventually reaching a final cutscene escape to open ocean.*

Inspired by Stray: the player inhabits a small, intelligent creature in a world built for someone else. No handholding. No combat. Just observation, curiosity, and the satisfaction of figuring things out.

Puzzles emerge from mechanics, not arbitrary logic. The octopus's arms are the puzzle — how you use them, in what order, and what state they end up in. Every room has a way forward. Finding it is the game.

## **Octo**

*No name. No dialogue. Just a real animal doing real animal things — and the player feels every bit of her intelligence.*

### **Personality**

* Smart and observant — studies a room before acting, notices everything

* Deeply curious — will investigate something interesting even if it has nothing to do with escaping

* Unhurried — moves with purpose, not panic. This is a Friday evening adventure, not a thriller.

* Has preferences — drawn to certain objects, colours, textures for no puzzle reason. Lingers. Has opinions.

### **Identity**

She has no formal name — she is a research subject. Her tank is labelled OCT-05. The scientists call her Octo out loud, which the player hears in the opening scene. It's informal, affectionate, unofficial. It suits her.

Her colour shifts tell her story. Octopuses shift colour as emotional expression — curious, alert, pleased, startled. No dialogue needed.

### **Relationship with Humans**

The scientists are not enemies. They're busy, absorbed in their work, entirely oblivious. If they notice Octo outside her tank they simply pick her up and return her — mildly inconvenient, no drama, no punishment. They're not unkind. They just don't notice.

*Getting caught is a mild indignity, not a fail state. Octo gets returned to the tank and tries again — exactly as real octopuses do.*

When caught: world state is preserved (doors opened, items moved stay as they are), no cooldown before Octo can escape again, but progress within the current room resets — any partial puzzle state or arm configuration is lost.

# **World Bible**

## **The Station**

An underwater research station studying climate change, ocean currents, and local marine life. Not secretive or sinister — just normal scientists doing normal science in an unusual place. The kind of facility that runs public tours on weekday mornings.

### **Blue Current Research Facility (Room & Space Reference)**

#### **Layout Overview**

A flattened octagonal pressure hull at 38 meters depth, divided into four zones: the Central Core, the Restricted Zone (staff only), the Lab Zone (partially open to visitors), and the Public Zone near the exit. Total staff: 30-50 people across permanent crew and rotating researchers.

The outer ring corridor runs between the rooms and the hull - lower-ceilinged than the rooms it connects, functional and plainly finished. Because it sits below the full room height, most rooms have skylights or high windows above the corridor roofline looking up into open water. The corridor itself has strip windows at eye level along the outer wall. Only the Observation Lounge and Galley sit directly against the hull and have full ocean-facing windows. Prep rooms, the Systems Room, and the Exit Corridor have no windows.

Most crew work weekday shifts and return to the surface for the weekend. A skeleton crew of 6-8 remains at all times - life support engineers, a duty scientist, and the resident medic. On weekends the facility is noticeably different: corridors empty, most labs dark, the cleaning robots audible from further away than usual.

Cleaning is handled entirely by a fleet of eight small autonomous disc-shaped robots on scheduled rotations, with docking bays in the Core, Systems Room, and Galley.

#### **Zone Mapping (Narrative vs Physical Layout)**

The story zones in Story -> The Journey are pacing layers, while the Blue Current zones below are the literal architecture of the station.

| Story Journey Zone (Story -> The Journey) | Closest Physical Area(s) in Blue Current |
| :---- | :---- |
| Zone 1 - Back Lab | Restricted Zone (Data Office / OCT-05), adjacent lab back corridors |
| Zone 2 - Work Area | Lab Zone, Systems Room, maintenance-heavy corridors |
| Zone 3 - Common Areas | Central Core, Observation Lounge, Galley |
| Zone 4 - Public Facilities | Public Zone (Gift Shop, Exit Corridor, visitor-facing entries) |
| Zone 5 - Final Cutscene Escape | Wet Room / Dive Airlock used only for the ending cinematic |

#### **Zone 1 - Central Core**

##### **Core (Central Atrium)**

**What's here:**

A double-height atrium with full-spectrum daylight lamps cycling through morning, afternoon, and evening light. A small garden fills the centre - a ficus, a dwarf palm, ground plants, moss between stones, benches. The soil is always slightly damp and the facility hum is quieter here. Around the perimeter: a notice board, research posters, ocean temperature maps, energy output charts, two drinking fountains. A pass-through space where people linger anyway.

**Windows:**

Skylights set into the upper walls and ceiling - columns of shifting blue-green light fall across the garden throughout the day. The most naturally lit space in the facility.

**Usual occupancy:**

5-10 people on weekdays - the most reliably busy space in the facility. On weekends, with only the skeleton crew present, it can be completely empty for hours. The garden does not notice.

**Cleaning robot dock:**

One bay tucked behind the garden, partially hidden by the ficus.

**Doors to:**

Chemistry Lab, Energy Lab, Workshop, Observation Lounge, Medical Bay, Quarters (keycard), Systems Room (keycard), Data Office (keycard).

##### **Medical Bay**

**What's here:**

Two examination beds, a locked medication cabinet, a defibrillator, basic surgical equipment, and a diagnostic station. Clean, slightly over-lit, smells of antiseptic. Emergency protocol sheets laminated and pinned by every entrance.

**Windows:**

One interior panel window into the corridor - no ocean view.

**Usual occupancy:**

1 medic on duty. Part of the permanent weekend skeleton crew.

**Doors to:**

Central Core.

#### **Zone 2 - Restricted Zone**

Staff-only spaces, keycard access from the Core. Quieter than the rest of the facility, especially on weekends.

##### **Quarters**

**What's here:**

Six bunk rooms along a short corridor - four assigned to the permanent skeleton crew, two kept for visiting researchers on extended postings. Each room has a bunk, a bolted-down desk, a locker. Most of the facility's staff commute from the surface and are not assigned a bunk.

**Bathroom & showers:**

Shared block at the end of the corridor: two shower stalls, toilets, sinks.

**Windows:**

Each bunk room has a high skylight - a narrow panel looking up into open water. Dim, shifting light. The closest thing to a private ocean view in the facility.

**Usual occupancy:**

4-6 people on weekdays, skeleton crew only on weekends.

**Doors to:**

Central Core (keycard).

##### **Systems Room**

**What's here:**

Life support, water filtration, communications array, backup power units, and server infrastructure. Loud, warm, floor slightly vibrating. Warning labels on almost everything. Two standing desks for maintenance checks.

**Windows:**

None. No skylights - too much equipment packed against every wall.

**Usual occupancy:**

1-2 engineers at all times. Always staffed - part of the weekend skeleton crew.

**Cleaning robot dock:**

One bay - the robot here runs more frequent cycles due to equipment heat.

**Doors to:**

Central Core (keycard), Data Office.

##### **Data Office**

**What's here:**

The quietest room in the facility. The primary sensor relay console runs along the main wall - live feeds from buoys and seabed sensors across a 200 km radius. Two data scientists work here among monitors, stacked hard drives, and printed graphs covering every surface. In the corner, half-hidden behind equipment cases, is a single research tank labelled OCT-05 - one octopus, recovering from sensor array entanglement, officially temporary, here for six weeks. The tank light runs a little longer in the evenings than it strictly needs to.

**Windows:**

One skylight above the OCT-05 tank. Natural light shifts across the water outside throughout the day.

**Usual occupancy:**

2 data scientists on weekdays. Monitored remotely on weekends - the room is often empty.

**Doors to:**

Systems Room, Chemistry Lab (back corridor, staff only).

#### **Zone 3 - Lab Zone**

Three lab units - Chemistry, Energy, and Workshop - each divided into a main working space and a prep/storage room at the back. Visitor access is limited to the front section of each main lab. Labs connect to each other via an internal corridor and to the Restricted Zone through the back. On weekdays all three labs are active; on weekends only essential monitoring continues.

##### **Chemistry Lab**

Water composition - collecting, processing, and analysing samples from the sensor network. 4-6 staff on weekdays.

**Main Lab (visitor-accessible front)**

**What's here:**

Wet lab and primary analysis space. Benches for sample handling - salinity, acidity, dissolved oxygen, microplastic concentration. Refrigerated sample rack, centrifuge, mass spectrometer, fume cupboard. The visitor-facing front section has a live water chemistry display and explanatory panels - researchers work in full view.

**Windows:**

Two skylights in the upper wall - columns of blue light fall across the benches. No direct ocean view, but the light shifts with the water above.

**Doors to:**

Central Core, Prep Room, Energy Lab (internal corridor).

**Prep & Storage Room**

**What's here:**

Sample intake, labelling, and cold storage. A sealed intake port connects to the exterior for direct water sampling. Shelving of reagents and consumables. A dry analysis workstation with two monitors for running data against archived readings. Staff only.

**Windows:**

None.

**Doors to:**

Main Lab, Data Office (back corridor).

##### **Energy Lab**

Prototype testing and power systems research. Also houses the live control panel for the facility's own energy grid. 3-5 staff and rotating research fellows on weekdays.

**Main Lab (visitor-accessible front)**

**What's here:**

Scaled prototypes of tidal turbines and thermal exchange systems on reinforced benches, wired to monitoring equipment. A materials testing chamber for anti-corrosion and pressure-resistance experiments. The facility's power grid control panel - live, functional, treated as a point of pride. Visitor front section has a viewing window and a display explaining how the facility powers itself.

**Windows:**

Two skylights - if visibility is good, the exterior tidal turbine array is faintly visible in the water above.

**Doors to:**

Central Core, Prep Room, Chemistry Lab, Workshop (internal corridor).

**Prep & Storage Room**

**What's here:**

Component storage, materials samples, and a dry computing station for modelling and simulation. Shelves of test components in various states - labelled, catalogued, some clearly failed. A small whiteboard covered in formulas nobody has erased in months.

**Windows:**

None.

**Doors to:**

Main Lab.

##### **Workshop**

Fabrication, repair, and ROV maintenance. 2-4 operations engineers and ROV pilots on weekdays.

**Main Workshop (visitor window at front)**

**What's here:**

Workbenches with vices, a drill press, welding equipment, a 3D printer, shelving of components and cable. The ROV pilots maintain and modify the remotely operated vehicles here - there is almost always one in pieces on the central bench. Whiteboard covered in diagrams and crossed-out measurements. Visitors observe through a small window at the front without entering.

**Windows:**

One large skylight - the workshop is the brightest of the labs during the day, natural light useful for detail work.

**Doors to:**

Central Core, Prep Room, Energy Lab (internal corridor).

**Prep & Storage Room**

**What's here:**

Spare parts, raw materials, tools, and a dry workstation for schematics and maintenance records. A locked cabinet holds hazardous materials - solvents, welding gases, pressure canisters. Used as overflow when a large repair job takes over the main floor.

**Windows:**

None.

**Doors to:**

Main Workshop.

#### **Zone 4 - Public Zone**

The visitor-facing end of the facility, near the exit. These spaces flow loosely into each other - less a series of separate rooms, more one continuous area with shifting atmosphere.

##### **Observation Lounge**

**What's here:**

Floor-to-ceiling pressure glass along the entire outer hull wall - an unobstructed view of the surrounding seabed. Comfortable seating in loose arrangements, low lighting, a perpetually half-drunk pot of coffee. One unwritten rule: no work talk, no screens. Never broken. Tour groups stop here; children always ask if they can go outside.

**Windows:**

The entire outer wall is glass - the largest and most dramatic window in the facility. The only room with a true panoramic ocean view at depth.

**Usual occupancy:**

2-6 people on breaks. More during tours. Skeleton crew members often end up here on weekend evenings.

**Doors to:**

Central Core, Chemistry Lab corridor (visitor entry to labs), Galley.

##### **Galley**

**What's here:**

Industrial coffee machine, two ovens, a large fridge, communal tables for thirty. The social centre of the facility. A corkboard holds shift notes, announcements, a school group's drawing, and a passive-aggressive note about the coffee machine now considered permanent decor. A small overflow bunk for visiting researchers is through a door at the back.

**Windows:**

Three large windows set into the outer hull wall - the same ocean-facing aspect as the Observation Lounge, but at table height. Natural light shifts blue and dim through meals; by evening the water outside is nearly black.

**Usual occupancy:**

5-15 at mealtimes, 1-3 between meals. On weekends the skeleton crew gathers here more than anywhere else.

**Cleaning robot dock:**

One bay near the kitchen entrance - the busiest dock in the facility.

**Doors to:**

Observation Lounge, Gift Shop.

##### **Gift Shop**

**What's here:**

Ocean science books, facility merchandise, educational kits, conservation organisation items, and a shelf of soft toy marine animals - fish, rays, sharks, the occasional cephalopod. Small, taken seriously - proceeds fund the visitor program. Staffed on tour days, closed otherwise.

**Windows:**

One interior panel window into the corridor. No ocean view - the corridor light here is enough.

**Usual occupancy:**

1 staff member on tour days. Empty on weekends.

**Doors to:**

Galley, Exit Corridor.

##### **Wet Room / Dive Airlock**

**What's here:**

A small but essential chamber adjacent to the Exit Corridor. This is where divers and ROV operators suit up and enter the water directly - separate from the main surface access shaft. Drysuits and diving equipment hang on wall racks. A bench for suiting up. A pressure equalisation chamber with a floor hatch opening directly to the sea. The floor is always slightly wet. A log on the wall records every dive entry and return.

**Windows:**

A small reinforced porthole in the floor hatch cover, looking straight down into open water.

**Usual occupancy:**

ROV pilots and divers when deploying or recovering equipment. Empty otherwise - but the hatch log means someone always knows who went in and when.

**Doors to:**

Exit Corridor.

##### **Exit Corridor / Surface Access**

**What's here:**

A pressurised corridor leading to the vertical shaft and airlock connecting to the surface platform. Emergency equipment at intervals: oxygen masks, a stretcher, fire suppression panels. Lights slightly brighter and bluer than the rest of the facility.

**Windows:**

None. A transition space - the last sealed stretch before the surface.

**Doors to:**

Gift Shop, Wet Room, Surface (airlock).

#### **Infrastructure Notes**

##### **Outer Ring Corridor**

Lower-ceilinged than the rooms it connects - functional, plainly finished, deliberately utilitarian. Non-slip flooring, cable management along the walls, emergency lighting strips at ankle height. Coloured lines on the floor mark zones. Strip windows at eye level along the outer hull run the full length of the ring, so the ocean is always visible while moving between rooms. The contrast between the corridor's low ceiling and the full-height rooms it leads into is immediately felt.

##### **Skylights**

Most rooms sit above the corridor roofline and have skylights or high windows looking up into open water. The light they admit is always blue-shifted and moves slowly - shadows of currents, the occasional passing creature. In the labs this light falls across workbenches. In the quarters it falls across bunks. It is never quite still.

##### **Cleaning Robot Fleet**

Eight autonomous disc-shaped units. They navigate by sensor, avoid active workstations, and return to docking bays in the Core, Systems Room, and Galley. On weekends, with fewer people around, they cover more ground undisturbed. No official names. Several unofficial ones.


### **Atmosphere**

Sterile and functional in the working areas, lived-in and personal in the common spaces. Sticky notes, coffee mugs, half-eaten Friday lunches, photos on desks. The station has texture and history that rewards curious players without blocking anyone.

Time of day shifts across the game — Friday afternoon light fading to evening, then night. The outdoor sections especially feel different as it gets darker.

## **Story**

### **Opening**

*No tutorial text. The entire setup is delivered through overheard dialogue.*

Friday afternoon. Two scientists wrap up for the weekend. The player watches from inside the tank — Octo's POV, glass faintly distorting the room.

* Scientist A: "It's Friday\! Finally. You good to lock up?"

* Scientist B: "Yep — oh, do you remember the new security code?"

* Scientist A: "I wrote it on my desk, just grab it before you leave."

* They wave at the tank. "Bye Octo\!" — and they're gone.

The station goes quiet. Octo looks at the tank wall. Looks at the desk, visible through the glass. The first puzzle is already in front of her.

*The desk note is the first code. The whole game loop is demonstrated before the player touches a single button.*

### **The Journey**

Octo moves through the station from back to front — from the most private and restricted spaces toward the public-facing ones.

These are narrative progression zones, not literal architecture labels (see World Bible -> The Station -> Zone Mapping (Narrative vs Physical Layout)).

* Zone 1 — The Back Lab: Octo's tank. Someone's personal office and research space. Cluttered, intimate. First puzzles, tutorial energy without being a tutorial.

* Zone 2 — The Work Area: Shared workstations, server room, equipment storage, maintenance corridors. The station's infrastructure. Vents appear.

* Zone 3 — Common Areas: Break room, meeting rooms, lounge. Personal and lived-in — leftovers in the fridge, a book on the couch, a corkboard of photos.

* Zone 4 — Public Facilities: Reception, cafeteria, gift shop. Cheesy educational posters. A little plushie octopus on the gift shop shelf. Octo walks past it.

* Zone 5 — Final Cutscene Escape: The Wet Room / Dive Airlock trigger for the ending cinematic.

*Scope: the Blue Current Research Facility as described in the World Bible is the source of truth for rooms and layout. Small enough to ship, deep enough to be satisfying.*

### **The Ending**

*No fanfare. Octo swims out into open water — and finds she is not alone.*

Another octopus. Wild, free, curious. They meet. They exchange objects — small, interesting things — the way octopuses actually do. A gesture of curiosity and connection.

The whole game has been about Octo interacting with objects. The ending recontextualises all of it. She wasn't just solving puzzles. She was practicing a language she finally gets to use with someone who speaks it.

* The 'fancy things' Octo collected for no puzzle reason become the emotional payload of the ending

* A player who carried something beautiful the whole way, and offers it here, gets the full moment

Objects are either actionable (can be used to solve something) or not — the distinction is communicated visually, not through UI. Fancy things are carried in Octo's arms like any other object, occupying the same slots. No separate inventory.

### **Epilogue**

Monday morning. A scientist walks in with coffee. Sees the empty tank. Pulls up the security camera recording and watches what happened. Stands there a moment. Then smiles — sticks a sticky note on the glass. 'Gone exploring.' Roll credits.

# **Game Design**

## **Game Loop**

When Octo enters a new space the loop is natural and player-driven. There is no objective marker, no waypoint — just a room to read.

* Orient — What is this room? Is there anyone here? Where does it lead?

* Observe — How does the exit open? What's written on the walls? What's interesting?

* Plan — What's needed to proceed? Where might the code be? Which arms are free?

* Execute — Gather useful items, find the code, open the way forward.

* Move on — and detour for anything interesting along the way.

*Not every room is a puzzle. Some doors are unlocked. Some rooms are just rooms. Breathing space makes the actual puzzles feel earned.*

The game autosaves on entering each new room. Players can quit and resume from the last room reached.

### **Optional Moments**

Curious players are rewarded. None of it is required — all of it is delightful:

* A vending machine openable with coins found under a bench

* Lore in the environment — evacuation posters, staff schedules, a whiteboard with half-erased notes

* Objects with no puzzle purpose that are simply interesting to pick up and carry

* Small interactions that exist purely because Octo would do them

## **Mechanics**

### **The Arm System**

Octo has 8 arms for carrying and game logic constraints, but visual interaction is intentionally simple. When interacting, Octo gives a small directional movement toward the object instead of full arm contact animation. The exact arm specialisation is handled as gameplay state, not explicit per-arm animation.

### **Code & Sequence Puzzles**

Every room has a way forward — usually a locked door or hatch. Opening it requires a code: a sequence or combination discovered through exploration, then executed physically with arms.

* Discovery phase: find the code through observation — a note on a desk, a pattern on the wall, something a fish is doing, a sequence visible on a screen

* Execution phase: use arms to input the code — which arm goes where matters

Code variety keeps rooms distinct:

* Hold 3 points simultaneously while a 4th arm pulls a lever

* Press a sequence in order — which arm you use last determines what's free next

* Timed inputs combined with specific arm positions

* Environmental patterns — lights flickering in sequence, water flow, animal behaviour

### **Object Carrying**

*One object per arm. Fill all arms and Octo cannot move. Physical, believable, occasionally very funny.*

* Primary arms occupied \= all interaction falls to multipurpose arms — clumsier and less precise

* Heavy objects require two arms — immediately halves available interactions

* Setting objects down matters — placement has consequences for what comes next

* Objects persist exactly where left, across all rooms and zones — the station is one connected space

Design rules for persistence:

* Nothing droppable somewhere Octo cannot return to — no permanent losses

* Required objects have subtle visual distinction so players treat them carefully without being told to

### **Light Switches**

Octo can turn room lights on and off. Simple interaction, deep combinations:

* Lights off: humans react — creates temporary movement opportunities

* Lights on: reveals hidden things — codes on walls, patterns on floors

* Screen glare: some codes only readable on monitors with room lights off

* Chain reaction: lights off → human goes to check the switch → Octo slips through while the route is clear

### **Interactable Devices**

Octo can operate computers, terminals, intercoms, and lab equipment:

* Computers: door controls, staff notes with codes, disable cameras

* Security panels: override locks, check camera feeds

* Intercoms and speakers: audio distractions that move humans to other rooms

* Phones and tablets on desks: messages between scientists often contain codes or hints

*Device interactions should require arm management — a computer might need two arms simultaneously (keyboard \+ cursor), creating natural coordination pressure.*

### **Human Presence**

It's a weekend. The station is nearly empty — a skeleton crew at most. Not a military base. Just scientists who went home for the weekend.

* A security guard making slow, predictable rounds

* A researcher who forgot something and came back

* A night janitor working through the building

Because humans are rare, each encounter is an event, not a routine obstacle. Their reactions are predictable and can be chained:

* Intercom in the break room → researcher wanders over → their desk is clear

* Open a far door → guard goes to investigate → corridor unblocked

### **Station-Only Traversal**

Gameplay traversal stays entirely inside Blue Current as a single-building experience. Open water is only used in the final cutscene.

## **Controls**

*Current target: PC. iPad/Mac input will be reviewed separately once the PC build is stable.*

### **Movement & Camera**

* Click or tap to move — Octo walks to that point relative to the current camera view (inside the station)

* Player-controlled camera — click-drag to rotate freely, Stray-style

* Camera locked from clipping through walls or floor — Godot collision handles this

* Tight spaces and vents: camera automatically switches to a fixed angle — returns to free control when Octo exits

### **Interaction**

* Click or tap an object to interact — automatic arm selection, with a subtle body/arm-direction nudge toward the target (no full touch animation)

* All interactable objects are highlighted (subtle glow or dot) — the player decides what is worth picking up or using

* Scroll wheel to zoom — examine codes on notes, labels on equipment

### **Arm State — No UI Needed**

Arm status is communicated through Octo's body language, not an interface panel:

* Arms visibly occupied when holding objects — the player can see what each arm is doing

* All arms busy: Octo nudges her head slightly toward the tap point — 'I see it, I just can't reach it'

* This keeps the screen clean and the feedback characterful

### **Catch Reset**

*Getting caught has a soft mechanical cost: you lose your room-level progress and have to retry. No punishment screen — just a quiet reset.*

### **Object Placement**

* Tap/click a surface to place a held object there

* Tapping empty water or a wall with an object: nothing happens — Octo holds on

## **Aesthetic Direction**

### **Visual Style**

* Bright, saturated but grounded — not candy-coloured, more like a beautifully lit aquarium

* Chunky, readable geometry — works well at tablet scale, no tiny details that need a mouse to spot

* Reference: Stray (atmosphere, small creature / big world), Caravan Sandwich (tech details, colors)

* The research station feels functional and real — beauty comes from light and water, not decoration

### **Octo's Animation**

* Big, expressive eyes — react to discovering a code, noticing something interesting, and key puzzle progress

* Colour shifts for mood: curious (warm), startled (pale flash), pleased (deep rich hue)

* Interaction animation is minimal and readable — slight directional movement toward objects rather than full contact choreography

### **Sound**

* Ambient underwater texture throughout — present but not intrusive

* Satisfying tactile clicks and sounds for interactions

* Humans have muffled, distant voices — heard but not understood, the way Octo hears them

* Music: ambient only, no melody. The soundscape is texture, not score. Swells reserved for the very end.

## **Development Roadmap**

*First 3D game in Godot — prototype mechanics before building any rooms or story. The core feel must work in grey boxes first.*

* Step 1 — Basic 3D movement: a blob navigating a flat space  ✅

* Step 2 — Click-to-move with camera follow  ✅

* Step 3 — Subtle interaction motion toward a tap target (no detailed arm touch animation)

* Step 4 — Multiple arms, observe spatial behaviour

* Step 5 — Arm holds an object: pick up, carry, set down

* Step 6 — First interactable: an arm presses a button

* Step 7 — Simple code lock: tap A, then B, then C to open a door

By step 7 the core game exists. Everything after is content and refinement.

### **Key Godot Technology to Research Early**

* SpringArm3D for camera collision — use from the start, retrofitting is painful

* AnimationTree for body and eye expression

* Touch input handling on iPad via Godot's `InputEventScreenTouch` — defer until post-PC

*— Gone Exploring  •  Game Design Document  •  Living draft —*
