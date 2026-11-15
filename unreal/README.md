# DREAM PROTOCOL

First-person psychological horror about lucid dreaming, unstable reality and subconscious fear.
Unreal Engine 5 (C++). PC.

This repository holds **Milestone 1: the vertical slice**. It covers the bedroom, the tutorial video, the notebook, the summer dream city, manifestation, NPC dialogue, the Observer, the fall into the yellow maze, DREAD, the pause-menu horror, the death sequence and checkpoints.

> **Status: written but not yet compiled.** The code was written without access to an Unreal Engine install, so it has never been built. It targets the UE 5.4–5.6 API. Expect a few compile errors on the first build, most likely small API-signature differences. Fix those before you judge the gameplay. See [Known risks](#known-risks).

---

## 1. Setup (about 5 minutes)

1. Install **Unreal Engine 5.5** (5.4 or 5.6 should also work) and Visual Studio 2022 with the *Game development with C++* workload.
2. Right-click `DreamProtocol.uproject` → **Generate Visual Studio project files**.
3. Open `DreamProtocol.sln` and build **DreamProtocolEditor | Development Editor | Win64**.
4. Open the project. When it asks about the missing startup map, continue.
5. **Create the one required map:** File → New Level → **Empty Level** (it must be empty, with no lights or sky), then save it as `Content/Maps/DreamSlice`.
6. Press **Play**. For the most accurate behaviour use *Play → Standalone Game*, because in the editor **Esc** stops PIE. **P** also opens the pause menu.

Everything else is generated at runtime. That covers geometry, lights, sky, fog, post-processing, audio, UI and characters. **No binary assets are needed**, so the whole game can be diffed and reviewed as text.

`GlobalDefaultGameMode` is set to `DPGameMode`, so any empty level works.

## 2. Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / look | WASD / mouse | Left / right stick |
| Run, crouch, jump | Shift, Ctrl or C, Space | L3, R3, A |
| Interact / continue dialogue | E (or F) | X |
| Dialogue choice | 1–4 or click | — |
| Manifest (hold) | Q | LB |
| Bite / let go of held object | Left mouse / right mouse | RT / LT |
| Picture something else | Mouse wheel | D-pad left/right |
| Try to wake up (hold) | T | D-pad up |
| Notebook | N or Tab | View |
| Pause | Esc or P | Menu |

## 3. What's playable

1. **Title**, drawn over the bedroom at night.
2. **Bedroom.** Watch *"HOW TO LUCID DREAM TONIGHT! (100% WORKING)"* on the PC. The player writes the five rules into the notebook as the video plays. Take the notebook, then go to bed.
3. **Summer city.** A 5×5-block sunny city with a park, fountain, trees, cars, birdsong and sky with volumetric clouds.
   - Hold **Q** to summon an ice cream cone. Bite it, toss it, or give it to Mina.
   - The balloon and beach ball unlock after your first manifestation.
   - NPCs: **Mina** (ice cream vendor with no ice cream), **Mr. Halvorsen** (bench, pigeons), **Theo** (kite) and a jogger who calls out one-liners as he passes.
   - Some dialogue choices break the notebook's rules. Each break lowers dream stability and draws the Observer nearer.
   - **The Observer** stands near a bus stop at the far end of the avenue. He never moves while watched, and you never quite reach him.
   - Hold **T** to wake up. You fall through the floor instead.
4. **Yellow maze.** A seeded office-maze under fluorescent light.
   - Walls outside the spanning tree open and close while unobserved, so the maze is always solvable. Lights die. The chair keeps turning up. A picture of a summer street appears on a wall.
   - The Observer appears at the end of corridors behind you.
   - The notebook now has **rule 6: "NEVER READ THIS NOTEBOOK TWICE."** Reading it again breaks it.
   - Later, someone else writes in the notebook. You only hear the page.
   - The exit is where the hum is loudest. Reaching it ends the slice.
5. **DREAD 100 in a nightmare** plays the death sequence: you wake in the bedroom, hear a sound behind you, black hands grab your shoulders, a red flash, then *"You woke up." / "Didn't you?"* You return to the last checkpoint.
6. **Pause menu horror.** At high DREAD the menu can become `RESUME / RESUME / RESUME – WHY ARE YOU HIDING?`. All three entries resume, and **Esc** gives the real menu. Very rarely the game unpauses itself, at most once per session. Both behaviours can be turned off in Settings.

## 4. Architecture

```
Source/DreamProtocol/
  Core/          DPGameMode (story flow, zones, checkpoints, sequences)
                 DPCharacter (FP controller, camera, holds, foley, shoulder-grab hands)
                 DPPlayerController (Enhanced Input built in code, UI modes, pause logic)
                 DPData (JSON loader)  DPEffects (data-driven effect strings)
                 DPObservation ("is the player looking at this?")
                 DPShapes (runtime geometry helpers)  DPSaveGame  DPSettings  DPGameInstance
  Dread/         DPDreadComponent (FEAR + STABILITY, look-behind detection, stages)
                 DPDreadDirector (post-process, drone, distant knocks, per-zone hook)
  Anomaly/       DPAnomalySubsystem (registry of reusable "changes while unobserved" events)
  Notebook/      DPNotebookSubsystem (rule state: write / reveal / hide / rewrite / break / reread)
  Dialogue/      DPDialogueSubsystem (node graph with conditions + effects)
  NPC/           DPNPC (friendly dream characters)  DPObserver (the silhouette)
  Manifestation/ DPManifestationComponent  DPManifestedObject
  Audio/         DPSynthSound (procedural synth: room tone, city, water, hum, drone, foley)
  World/         DPZone (base) -> DPBedroomZone, DPSummerCityZone, DPMazeZone
  UI/            DPHUD + Slate widgets (menus, notebook, tutorial video)
Content/Data/    Dialogue.json  Notebook.json  Manifestations.json  Tutorial.json
```

**Key ideas**

- **One zone at a time.** A *zone* is a self-contained realm: geometry, lighting, audio, NPCs, anomalies and its own dream rules (fear gain, fear floor, anomaly pacing, whether manifestation works). Adding THE DEEP means writing a new `ADPZone` subclass. No core system changes.
- **Unobserved change** is a shared primitive. `DPObservation` tests the camera frustum (with a safety margin) and occlusion. `DPAnomalySubsystem` decides *when* any registered anomaly may change, using dream stability. Each zone only says *what* can change. When the player later sees a change, it counts as a discovered inconsistency and adds fear.
- **The DREAD loop.** Fear rises, stability falls toward (100 − fear), anomalies speed up, and more gets discovered. Fear decays after calm periods; stability recovers slowly. The city damps fear gains to 35%, so the opening stays comforting. A single look over the shoulder is never punished; only *repeatedly* checking behind is.
- **Data-driven content.** Dialogue, rules (including variants and break consequences), manifestable objects and the tutorial script are JSON. Effects are strings such as `fear:+10`, `rule:break:rule_tell`, `notebook:rewrite:rule_scary:spiral` and `observer:closer`. **New Game reloads the JSON**, so you can edit content while the editor is running.
- **Art hooks.** Everything is built from engine primitives with a coloured material. If an artist creates `/Game/DreamProtocol/Materials/M_ObserverVoid` (an unlit black material), the Observer and the hands use it automatically. More overrides can follow the same `DPShapes::FindArtOverride` pattern.

## 5. Accessibility

Settings (title or Pause → MENU → SETTINGS) are stored separately from progress:

- mouse sensitivity, invert look, field of view
- head bob, camera jolts
- **visual intensity**: scales vignette, grain, desaturation, colour fringe, light-flicker depth and the red flash
- **horror audio intensity**, master volume
- text size, DREAD meter on/off
- menu corruption on/off, self-unpause on/off

## 6. Known risks

These parts were written from API knowledge and could not be verified:

- **API signatures** that changed across UE 5.x, for example `USoundWaveProcedural::OnGeneratePCMAudio`/`SetSampleRate`, Slate `FillWidth(TAttribute<float>)` and some fog/light setters. Any compile errors should be shallow fixes.
- **TextRender facing.** The `EXIT` sign, the monitor title and the cart sign assume `UTextRenderComponent` faces +X. If they read mirrored, rotate them 180°.
- **Look and tuning.** Light intensities and exposure were chosen blind and will need an in-editor pass. The same goes for DREAD balancing: fear values, decay and anomaly pacing are grouped at the top of `DPDreadComponent.cpp` and in each zone.
- **Basic-shape visuals.** Geometry is primitive placeholder art. With Lumen it should read as stylised, not finished.

## 7. Not in this milestone (by design)

- The fear realms (THE DEEP, COMPRESSION, ABOVE, BLACKOUT, STILL LIFE, OPEN SPACE, PATTERN, THE QUIET).
- Mirrors and reflection horror.
- THE DESTINATION, both endings and THE CORE.
- Realm leakage beyond the single summer picture in the maze.
