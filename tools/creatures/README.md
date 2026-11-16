# tools/creatures: custom creature models (Blender, bpy)

Procedural generators for DREAM PROTOCOL's creatures, written against Blender's Python API.
They build real polygon meshes (lofted anatomy, curved horns, ribs, spines, fin membranes,
sunken eye sockets, cloth folds), generate their textures (albedo, tangent-space normal maps,
emission markings) with numpy, rig what needs to move, and export **GLB / glTF 2.0** into `models/`.

This folder is separate from the game: nothing here is loaded by Godot. The game only sees the
exported `.glb` files, through the optional-model slots in `models/README.md`.

| Creature | Output | In game | Triangles | Notes |
|---|---|---|---|---|
| `leviathan` | `models/creatures/leviathan.glb` | THE DEEP, the seabed | ~35k (Godot adds LODs on import) | skinned: 34 spine bones + jaw |
| `observer` | `models/observer.glb` | everywhere he appears | ~12.5k | static; the game turns him black and glitchy |
| `draped` | `models/creatures/draped.glb` | not used yet | ~9k | the sheeted figures of COMPRESSION's drying room (wiring them in means editing that level's script) |

## Running it

```
python3 -m venv .bpy && .bpy/bin/pip install bpy        # Blender as a Python module (bpy 5.x needs Python 3.13)
.bpy/bin/python tools/creatures/build.py                  # build everything
.bpy/bin/python tools/creatures/build.py leviathan        # one creature
.bpy/bin/python tools/creatures/build.py --preview=/tmp/previews   # also render studio previews (Cycles, CPU)
```

Or with a Blender install: `blender --background --python tools/creatures/build.py -- leviathan`.
Generation is deterministic (fixed seeds), so rebuilding gives the same models.

## Layout

```
build.py        entry point: which creatures, where they go, preview cameras
leviathan.py    the leviathan (anatomy, textures, rig)
observer.py     the Observer (skin-modifier skeleton -> subdivided, roughened, decimated)
draped.py       the sheeted figure (lofted cloth over a body profile)
dp/geo.py       MeshBuilder: lofts, tubes along curves, membranes, skin weights, UVs -> Blender mesh
dp/tex.py       numpy textures: value noise, fBm, Worley cells, normal maps from height
dp/scene.py     glTF-compatible materials, armatures, modifiers, GLB export
dp/preview.py   studio renders for checking silhouettes
```

## The leviathan's rig contract (keep in sync with `scripts/npc/leviathan.gd`)

- Bones `spine_00` ... `spine_33`, unparented. `spine_i` rests at Godot `z = i * 2.4`
  (Blender `y = -i * 2.4`): exactly where the game's body segment `i` sits when the creature is straight.
- Bone `jaw`, child of `spine_00`; rotating it about its X axis opens the mouth.
- Built facing Godot -Z (Blender +Y) at `thickness` 1.0.

Each frame the game moves every spine bone onto its segment (and scales it by the creature's
`thickness`), so the continuous mesh follows the existing movement, chase and blocking code without
any change to it. Delete the `.glb` and the game falls back to its built-in procedural creature.

## Materials

Plain Principled BSDF networks the glTF exporter maps 1:1 to glTF PBR: base colour texture, normal
map (Normal Map node, tangent space), emission texture + strength (`KHR_materials_emissive_strength`),
roughness, double-sided for membranes and cloth. Godot imports them as StandardMaterial3D.
