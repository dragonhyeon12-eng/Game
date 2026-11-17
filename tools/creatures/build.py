"""Build the game's custom creature models with Blender's Python API and export them as GLB.

    python tools/creatures/build.py                 # everything
    python tools/creatures/build.py leviathan       # one creature

Needs Blender's Python module (`pip install bpy`, Python 3.13 for bpy 5.x), or run it inside Blender:
    blender --background --python tools/creatures/build.py -- leviathan

Output goes to models/ (see models/README.md); the game picks the files up automatically.
Nothing here is imported by the game.
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401  (must come first: it makes mathutils/bmesh importable)

import leviathan  # noqa: E402
import observer   # noqa: E402
import draped     # noqa: E402
import player     # noqa: E402
import foliage    # noqa: E402
import kit        # noqa: E402

CREATURES = {
    "leviathan": (leviathan.build, "models/creatures/leviathan.glb"),
    "observer": (observer.build, "models/observer.glb"),
    "draped": (draped.build, "models/creatures/draped.glb"),
    "player": (player.build, "models/player.glb"),
    "foliage": (foliage.build, "models/props"),
    "kit": (kit.build, "models/props"),
}


PREVIEWS = {   # label, camera, target, lens (Blender coords: +Y forward, +Z up)
    "leviathan": [("side", (95, -40, 3), (0, -40, 0), 24), ("front34", (14, 16, 5), (0, 1, 0), 35),
                  ("head_side", (12, 1.5, 1), (0, 1.5, 0), 40), ("front", (0, 16, 2), (0, 0, 0.5), 30)],
    "observer": [("front", (0, -6, 1.2), (0, 0, 1.1), 50), ("side", (6, 0, 1.2), (0, 0, 1.1), 50)],
    "draped": [("front", (0, -5, 1.1), (0, 0, 0.95), 50), ("side34", (3.5, -3.5, 1.3), (0, 0, 0.95), 50)],
    "foliage": [("tree", (14, -14, 5), (0, 0, 4), 35)],
    "player": [("front", (0, 5, 1.0), (0, 0, 0.9), 45), ("side34", (3.2, 3.2, 1.3), (0, 0, 0.9), 45),
               ("back", (0, -5, 1.0), (0, 0, 0.9), 45)],
}


def main(argv):
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    preview_dir = None
    for a in argv:
        if a.startswith("--preview="):
            preview_dir = a.split("=", 1)[1]
    names = [a for a in argv if not a.startswith("-") and not a.endswith(".py")] or list(CREATURES)
    for name in names:
        fn, rel = CREATURES[name]
        t0 = time.time()
        print(f"building {name}")
        fn(os.path.join(ROOT, rel))
        print(f"  done in {time.time() - t0:.1f}s")
        if preview_dir:
            from dp import preview
            for p in preview.render_views(preview_dir, name, PREVIEWS[name]):
                print("  preview", p)


if __name__ == "__main__":
    main(sys.argv[1:])
