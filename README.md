# DREAM PROTOCOL

First-person psychological horror about lucid dreaming, unstable reality and subconscious fear.
Made with **Godot 4.5** (free, open source, no account needed). Runs on Mac, Windows and Linux.

This is **Milestone 1: the vertical slice**: bedroom → tutorial video → notebook → summer dream city
(ice cream, people, the Observer) → falling into the yellow maze → DREAD → the ending of the slice.

---

## How to play it (Mac)

1. Download **Godot 4.5** (the normal version, not ".NET"): https://godotengine.org/download/macos/
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
- **The yellow maze.** You fall through the floor instead. Fluorescent hum, stained carpet, a maze that
  is always solvable but rearranges itself when you aren't looking. Your notebook has a sixth rule now.
- **DREAD** (fear + dream stability) drives vignette, desaturation, grain, flickering lights, a low drone,
  knocks behind you, how often the maze changes and when the Observer appears.
- **The pause menu** may not be entirely a pause menu at very high DREAD.
- **If DREAD reaches 100** you wake up in your bedroom. Probably.
- **Checkpoints** at the start of each area; **Continue** on the title screen.

## Accessibility (Settings)

Mouse sensitivity, invert look, field of view, head bob, camera jolts, **visual intensity** (flicker,
vignette, distortion, red flash), **horror audio intensity**, master volume, text size, DREAD meter,
menu corruption on/off, self-unpause on/off, graphics quality.

## Project layout

```
project.godot            Godot project (open this)
scenes/main.tscn         entry point - everything else is built in code (no binary assets)
data/                    dialogue, notebook rules, manifestable objects, tutorial script (JSON)
scripts/autoload/        Game (story flow, zones, checkpoints, sequences, DREAD director)
                         Settings, Data, Sfx (procedural audio), Notebook, Dialogue, Anomalies
scripts/core/            Observation ("is the player looking at this?"), Effects, Shapes, Interactable
scripts/player/          Player controller, Dread, Manifestation, ManifestedObject
scripts/world/           Zone (base + geometry builder), BedroomZone, CityZone, MazeZone
scripts/npc/             NPC, Observer
scripts/ui/              HUD, menus, notebook, tutorial video, DREAD post-process shader
tests/flow_test.tscn     automated playthrough of the whole slice
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
- **No assets.** Geometry is built from primitives, all audio is synthesised at startup, all UI is code.
  Everything can be read, diffed and reviewed as text. Real art can replace pieces later.

## Testing

Run the automated playthrough (it plays the whole slice and prints `FLOW TEST PASSED`):
open `tests/flow_test.tscn` in the editor and press **F6**, or from a terminal:

```
godot --path . res://tests/flow_test.tscn
```
