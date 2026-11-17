# DREAM PROTOCOL: QA and polish audit

[한국어](QA_REPORT.ko.md)

Scope: the whole campaign (bedroom → CITY → BACKROOMS → THE DEEP → COMPRESSION → ABOVE), on desktop and
the web/mobile build. No levels, mechanics, models or story were redesigned. Every fix below was tested on
its own, and the full playthrough test passes after all of them.

## How it was tested

| Tool | What it does |
|---|---|
| `tests/flow_test.tscn` (existing) | Drives the whole story, title to the door in the sky, plus every death and the wake-up. **Passes.** |
| `tests/qa_test.tscn` (new) | **Walks** the risky routes with real movement input instead of teleporting: stairs, ramps, arches, ducts, both chases, the impossible doors. Also checks objective text and save round-trips. **Passes.** |
| `tests/perf_probe.tscn` (new) | Per area: draw calls, objects, triangles, lights, shadow casters, node count. |
| `tests/perf_top.tscn` (new) | The heaviest meshes in an area. |
| Static checks | Every sound name played exists (all do). Every zone can be saved and restored. DREAD settings compared across areas. |
| Phone browser (emulated) | The touch controls with one and two fingers. |

The flow test could not have caught most of what follows: it teleports between story beats, so it never
walked the routes. The new QA test does.

---

## 1. Critical issues (all fixed)

| # | Issue | Effect | Fix |
|---|---|---|---|
| C1 | **ABOVE: the floating stairs could not be climbed.** The player has no step-up, the 25 cm risers were bare boxes, and tower D's parapet ran across the foot of the stairs. | Hard softlock in stage 4 of ABOVE. | An invisible ramp under each step (the steps look the same) and a gap in the parapet. Verified by walking from tower D to the construction site. |
| C2 | **COMPRESSION: the collapse corridor's floor stopped 1.9 m short of the shaft room** (the segment count was rounded down). | A sprinting player fell out of the world at the very end of the chase, forever (this area has no fall death). | The floor segment count is rounded up. Verified by sprinting the corridor. |
| C3 | **THE DEEP: the "door you can't look at" was inverted.** The wall was solid while you weren't looking and passable while you were. | The puzzle was broken (you could just walk through it while looking). | Solid while looked at, a door while not. It never closes on a player standing in the doorway. The objective ticks however you cross. |
| C4 | **THE DEEP: the exit door in the cliff was an open gap.** | Running through it carried you past the level and into the trench (death). | Rock behind the glowing door. |
| C5 | **COMPRESSION's exit could start twice.** An old exception in `_realm_transition` let a double press re-trigger the move to ABOVE. | Possible double transition or broken state. | Exception removed; the door works once. |
| C6 | **THE DEEP's sea surface was 6.5 million triangles** (2 subdivisions per metre over 900 × 900 m). | Very heavy on any GPU, crippling on web and mobile. | Subdivision capped at 96 per side. The area dropped from 6.8M to about 0.4M triangles with no visible change. |
| C7 | **The web build broke the host's 15 MB per-file limit** once the glove models were added. | The browser version would not have published or loaded. | The build script now splits the data into as many parts as needed and writes the matching numbers into the page. |
| C8 | **Phone touch: dragging the move stick also turned the view, and moving while looking flung the view at the sky.** | The game was barely playable on phones. | Browser mouse events from fingers are ignored during play. Looking uses each finger's own movement. Verified in an emulated phone. |
| C9 | **A broken commit made during this audit** (a constant name clash with the maze's `CELL`). | The zones didn't compile. | Caught by the performance probe before any release and fixed (renamed). |

## 2. Gameplay improvements

Fixed:
- **Objectives showed raw placeholders**, such as "Change something in the dream ({changes}/2)", until the first count, and "5.0" after loading a save. Counters now always show as whole numbers, starting from 0.
- **ABOVE: wind gusts reached the new narrow sections** (floating stairs, crane girder, path tiles). One gust pushes about 2 m sideways and sends you back to the first roof. Gusts are now limited to the first rooftops and the beam, where they were designed and hinted ("crouch").
- **Journal and notebook milestones** were chained with `elif`, so a flag that unlocked both would have silently lost the notebook line. Both are now always processed.
- **Saves from an unknown area** (after a future rename) fell into an empty scene. Continue now starts a new game instead.
- **Touch now has an equivalent for everything:**
  - tap a thing to use it (like E);
  - ◀ ▶ to change what you picture;
  - SKIP for deaths you've seen;
  - JUMP and CROUCH count as held while touched, for swimming up and down.
  - Hints and objectives name the touch buttons instead of keys.

Recommended (not done: these change behaviour, so they need your approval):
1. **Checkpoints inside the long areas.** You save only on entering an area. Dying at ABOVE's skyway (stage 6 of 7) sends you back to the first roof; the abyss and the tenement have the same problem in a smaller way. Proposal: a checkpoint at each stage (after the lift, the stairs, the crane; after the bulkhead and the beacons; after floor 7). This needs the save to record a stage and each area to rebuild that stage's state, which is moderate work.
2. **DREAD while climbing.** Looking down fills fear fast (by design), but during the scripted mast climb and on the floating stairs, players naturally look down. Consider halving fear gain during climbs so the Observer death doesn't trigger mid-ascent.
3. **The tutorial video can't be skipped on touch** (Esc only). Add a SKIP while it plays.
4. **A generic out-of-bounds safety net**, as a quiet respawn, for areas without a fall death (bedroom, city, tenement), in case geometry is ever changed and a hole slips in again.
5. **The leviathan chase is tight.** Sprinting, you reach the door about 7 m ahead of it; walking, it catches you. That is the intended tension, but it's worth playtesting on phones, where sprint is a toggle.

## 3. Visual and audio polish

- **Gloves (new):** hazmat (Backrooms), diving (THE DEEP), work (COMPRESSION), leather (ABOVE), bare elsewhere; each swaps in when you enter the area.
  - Knuckle folds are a little regular.
  - The leather grain is strong close up.
  - The bare hand's nails are small.
  - A second pass in `tools/creatures/hands.py` could vary the folds.
- **Web renderer:** the browser build uses Godot's Compatibility renderer. There's no subsurface scattering on skin and no volumetric fog, and the lights per object are limited, so some of the 43 lights in the Backrooms may drop in the browser. Worth a visual check of every area in a real browser.
- **Audio:** all 65 synthesized sounds exist and every reference resolves. Looping sounds played as one-shots (grind, motor, static, breath, wind) are now played through once instead of looping forever.
  - Recommended: a loudness pass across stingers.
  - Recommended: optional captions for important sounds (knocks, breathing, the leviathan), for accessibility and for players without sound on mobile.

## 4. Performance

Measured from each area's start, averaged over 30 frames. Triangles include shadow passes.

| Area | Draws | Triangles (before) | Triangles (after) | Lights (shadowed) |
|---|---|---|---|---|
| Bedroom | 44 | 28k | 28k | 4 (2) |
| City | 592 | 4.6M | 4.6M | 0 |
| Backrooms | 139 | 134k | 134k | 43 (4) |
| THE DEEP (pool) | 203 | **6.8M** | **0.39M** | 34 (5) |
| Seabed | 52 | 155k | 155k | 27 (1) |
| Abyss | 89 | 71k | 71k | 28 (0) |
| Compression | 169 | 131k | 131k | 17 (3) |
| Tenement | 57 | 47k | 47k | 30 (2) |
| ABOVE | 158 | 1.0M | 1.0M | 17 (2) |

Also done: small scattered things (grass) are split into cells the camera can cull, and fade out beyond 70 m.

Recommended:
1. **City: the facades are the cost.** There are 2.9M triangles in the scene, mostly 5,360 skyline bay modules plus ~6,500 bays on nearby buildings, which also cast shadows. That becomes 4.6M rendered once shadow passes are counted.
   - Splitting the facades into culled cells cut triangles by half but almost doubled draw calls, so it was reverted until it can be measured on a real GPU.
   - Better options:
     - merge each skyline building into one low-poly mesh (an impostor);
     - stop skyline modules casting shadows;
     - limit shadow casters to nearby blocks.
2. **ABOVE:** 1.0M rendered from 174k in the scene. The shadow cascades multiply the skyline towers; the same remedy applies.
3. **Web download is 47 MB** (31 MB of it textures). Recommended:
   - halve distant-surface textures for the web build;
   - use compressed texture formats for web;
   - reduce the glove maps to 512 px (they're seen close, but 1024 px × 5 variants is about 13 MB).
4. CPU time in the probe is from a software renderer and isn't meaningful. Profile on a mid-range phone and a low-end laptop before release.

## 5. Release-readiness recommendations

1. **Run all three tests before every build:** `flow_test` (story), `qa_test` (walkable routes, chases, saves) and `perf_probe` (budgets).
   - Add a check to `qa_test` whenever a new route is built; this audit's critical bugs were all places the story test teleports past.
2. **Playtest on real devices:** a phone (touch, performance, audio unlock), a tablet, and a low-end laptop with the web build. The emulated phone confirms the controls, not the frame rate.
3. **Decide on the mid-area checkpoints** (gameplay item 1). It's the biggest remaining quality-of-life gap.
4. **Version the save format.** It is version 1 with no migration. Before release, add a migration step, or at least keep the new "unknown area → new game" guard.
5. **Commit or document the export setup.** `export_presets.cfg` is git-ignored, so the web export depends on a local file. Document it in `tools/web/build.sh` (partly done) or commit a template.
6. **Credits and licences** for any third-party assets (Quaternius models) should be listed in the game and in the README.
