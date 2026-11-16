# DREAM PROTOCOL

First-person psychological horror about lucid dreaming, unstable reality and subconscious fear.
Made with **Godot 4.7** (free, open source, no account needed). Runs on Mac, Windows and Linux.

Playable now: bedroom → tutorial video → notebook → summer dream city (ice cream, people, the Observer)
→ falling into the yellow maze → **THE DEEP** (aquaphobia) → **COMPRESSION** (claustrophobia)
→ **ABOVE** (fear of heights). Every area has an **objectives** list in the top-right corner.

---

## How to play it (Mac)

1. Download **Godot 4.7** (the normal version, not ".NET"): https://godotengine.org/download/macos/
   Unzip it and drag **Godot.app** into *Applications*.
2. Download this project: on GitHub click **Code → Download ZIP** (branch `claude/dream-protocol-dev-eom8wy`), and unzip it.
3. Open Godot. The first time macOS may say it can't verify the app: right-click Godot.app → **Open** → **Open**.
4. In the Project Manager click **Import**, choose the `project.godot` file inside the unzipped folder, then **Import & Edit**.
   The first import takes about a minute.
5. Press **▶ (Run Project)** at the top right, or **⌘B**.

That's it. No other downloads, no Xcode.

**If it runs slowly** (older or Intel Macs): Pause → MENU → SETTINGS → *Graphics quality* → **LOW**.
It takes effect when you enter the next area.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / look | WASD / mouse | sticks |
| Run / crouch / jump | Shift / Ctrl or C / Space | L3 / R3 / A |
| Interact, continue dialogue | E | X |
| Dialogue choice | 1–5 or click | |
| Picture (manifest) something | hold **Q** | LB |
| Bite / let go | left / right mouse | RT / LT |
| Picture something else | mouse wheel | D-pad ← → |
| Try to wake up | hold **T** | D-pad ↑ |
| Notebook | **N** or Tab | Back |
| Pause | Esc or P | Start |

## What's in the slice

- **Bedroom, 3 AM.** Watch *"HOW TO LUCID DREAM TONIGHT! (100% WORKING)"* on the PC; the five rules
  get written into your notebook. Take the notebook. Go to bed.
- **The summer city.** Bright, warm and peaceful on purpose. Hold Q to picture an ice cream. Talk to
  Mina (the ice cream vendor with no ice cream), Mr. Halvorsen and his pigeons, Theo and his kite, the jogger.
  Some questions break the notebook's rules. The **Observer** stands at the far end of the avenue.
  He never moves while you watch him. Hold T to wake up.
- **THE DEEP** (aquaphobia). The maze's exit door leads to a night-time swimming complex.
  1. The PUMP ROOM door is jammed. Swim through the dark hole under the water at the far end of the main pool.
  2. The DRAIN lever's handle has been snapped off. It's lying on the bottom of the main pool (dive for it).
  3. Pull the DRAIN lever. The water only goes down **while you watch the well** - look away and it refills.
  4. The deep pool is fenced off and padlocked. The key is in locker 13. There are twelve lockers.
  5. Unlock the gate and step into the empty well. It has no bottom: below it is an
     impossibly vast sea, a trench walled by cliffs, where leviathans circle. **Looking down fills DREAD fast.**
     Near the sea floor, black hands come up and pull you under (if DREAD overwhelms you here, they kill you).
  6. **The seabed** (part two): pitch dark, you walk slowly. Hold Q to picture a flashlight. The path is
     invisible - only glowing stones mark it. Stray from it and the leviathan comes for you.
  7. At the cliff, get into the sea cave before it catches you - it can't fit through. Step through the glowing doorway.
- **COMPRESSION** (claustrophobia). A basement under a building: narrow corridors, low ceilings, bare bulbs.
  The way you came in turns into wall. Tight spaces raise DREAD by themselves. The freight elevator needs 3 fuses:
  1. **The vent** - crouch (C / Ctrl) and crawl. Something breathes behind you. Fingers come through the slats.
  2. **The press** - the walls move in whenever you're *not* looking at them. Look left, look right, keep going.
  3. **The drying room** - sheets on lines, and shapes under three of them that come closer while you look away.
  Put the fuses in the box, call the elevator (max 1 person), get in. It gets smaller on the way up.
- **ABOVE** (fear of heights). A rooftop above the clouds at night; the towers go down forever.
  1. Walk out along the plank over the drop to get the key at the end.
  2. Cross the steel beam to the next roof. **When the wind comes, crouch** or it pushes you off. The beam won't be there behind you.
  3. Use the key on the bridge controls, cross to the last roof, climb the mast, touch the light.
  Looking down fills DREAD. Sometimes, far away, someone falls.
  Swimming: Space up, C dive, watch your breath. Space at the surface next to the edge climbs out.
- **Dream journal** (title screen, or Pause > MENU): an entry for every part of the dream you have made it through.
- **The yellow maze.** You fall through the floor instead. Fluorescent hum, stained carpet, a maze that
  is always solvable but rearranges itself when you aren't looking. Your notebook has a sixth rule now.
- **The Observer** glitches - slices of him shear and drop out. Spotting him raises DREAD by 25, and he
  glitches out of existence a second or two later.
- **DREAD** (fear + dream stability) drives vignette, desaturation, grain, flickering lights, a low drone,
  knocks behind you, how often the maze changes and when the Observer appears.
- **The pause menu** may not be entirely a pause menu at very high DREAD.
- **If DREAD reaches 100** you wake up in your bedroom. Probably.
- **Checkpoints** at the start of each area; **Continue** on the title screen.

## Accessibility (Settings)

Mouse sensitivity, invert look, field of view, head bob, camera jolts, **visual intensity** (flicker,
vignette, distortion, red flash), **horror audio intensity**, master volume, text size, DREAD meter,
menu corruption on/off, self-unpause on/off, show objectives, graphics quality, and **super duper shaders** (global illumination,
reflections, volumetric fog, anti-aliasing - needs a strong GPU).

## Project layout

```
project.godot            Godot project (open this)
scenes/main.tscn         entry point - everything else is built in code (no binary assets)
models/                  OPTIONAL real art: drop a .glb here to replace a built-in person, the Observer,
                         an object or a surface texture (see models/README.md - no Blender needed)
data/                    dialogue, notebook rules, manifestable objects, tutorial script (JSON)
scripts/autoload/        Game (story flow, zones, checkpoints, sequences, DREAD director)
                         Settings, Data, Sfx (procedural audio), Notebook, Dialogue, Anomalies
scripts/core/            Observation ("is the player looking at this?"), Effects, Shapes, Interactable,
                         Models (finds, sizes and animates optional model files)
scripts/player/          Player controller (incl. swimming/breath), FPHands, Dread, Manifestation, ManifestedObject
scripts/world/           Zone (base + geometry builder), BedroomZone, CityZone, MazeZone, DeepZone, SeabedZone,
                         CompressionZone, AboveZone, water shader
data/Objectives.json     the objective list for every area
scripts/npc/             Human (procedural people), ModelBody (people from model files), NPC,
                         Observer (+ glitch shader)
scripts/ui/              HUD, menus, notebook, tutorial video, DREAD post-process shader
tests/flow_test.tscn     automated playthrough of everything, title to the top of ABOVE
tests/gallery.tscn       renders review screenshots of each area
unreal/                  the earlier Unreal Engine 5 version (archived, ignored by Godot)
```

**Key ideas**
- **Zones.** Each realm is a `Zone` subclass with its own geometry, light, audio, characters, anomalies
  and dream rules (fear gain, fear floor, anomaly pacing, whether manifestation works). Adding THE DEEP
  later means adding one new zone script.
- **Unobserved change** is a shared system: zones register anomalies ("this wall may toggle", "this light
  may die"); `Anomalies` decides when, based on dream stability, and only while nobody is looking.
- **Data-driven story.** Dialogue, rules, objects and the video script are JSON. Effects are strings like
  `fear:+10`, `rule:break:rule_tell`, `notebook:rewrite:rule_scary:spiral`, `observer:closer`.
  New Game reloads the JSON, so you can edit the story and test immediately.
- **No assets.** Geometry is built from primitives with procedural surface textures (tiles, wallpaper, wood,
  carpet, concrete, fabric), people are articulated procedural bodies with faces, the first-person hands are
  procedural too, all audio and music is synthesised at startup, all UI is code.
  Everything can be read, diffed and reviewed as text.
- **Real art is optional.** Put a model in `models/` (e.g. `models/people/mina.glb`, `models/observer.glb`,
  `models/textures/wood/`) and it replaces the built-in version, sized and animated automatically.
  Remove it and the built-in version is back. See **models/README.md**.

## Testing

Run the automated playthrough (it plays the whole slice and prints `FLOW TEST PASSED`):
open `tests/flow_test.tscn` in the editor and press **F6**, or from a terminal:

```
godot --path . res://tests/flow_test.tscn
```
