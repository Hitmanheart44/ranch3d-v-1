#!/usr/bin/env python3
"""After vetting: moves KEPT items to ~/Projects/ranch3d_vault/ (same relative paths, plus the .import/texture siblings),
and everything else that was asset-like (the shortlist's trash/maybe/unseen AND the pre-trashed generic assets) to
~/Projects/ranch3d_trash/. Nothing is deleted; both folders can be restored by moving files back.
  python3 tools/vet/apply_vet.py            # dry run, prints the plan
  python3 tools/vet/apply_vet.py --go
Not touched: code (core/, combat/, ranch/, monsters/, ui/ ...), data/*.tres, fonts, addons, tools/."""
import glob, json, os, shutil, sys
ROOT = os.path.expanduser("~/Projects/ranch3d")
VAULT = os.path.expanduser("~/Projects/ranch3d_vault")
TRASH = os.path.expanduser("~/Projects/ranch3d_trash")
marks = json.load(open(os.path.expanduser("~/.local/share/Ranch3D/vet.json")))
os.chdir(ROOT)
kept = {p for p, v in marks.items() if v in ("keep", "maybe")}   # maybe = fix-and-keep (buildings, some music)
# the adventure kit (owner praised the cave): scanned rocks and ferns plus the cave floor textures
kept |= {"assets/props/ph/" + n + ".glb" for n in ["boulder_01", "rock_07", "rock_09", "rock_moss_set_01", "rock_moss_set_02", "stone_01", "fern_02"]}
kept |= {"assets/tex/%s_%s.jpg" % (a, b) for a in ["rock030", "ground037"] for b in ["color", "normal"]}
pool = []
for pat in ["assets/models/*", "assets/props/**/*", "assets/audio/*", "assets/ui/*", "assets/tex/*", "assets/terrain/**/*", "assets/video/*"]:
    pool += [f for f in glob.glob(pat, recursive=True) if os.path.isfile(f)]

def base(f):  # the "owner" file a sibling belongs to (x.glb.import, x_texture.jpg ...)
    return f[:-7] if f.endswith(".import") else f

def stem_of(f):
    return os.path.splitext(os.path.basename(base(f)))[0]

keep_stems = {(os.path.dirname(p), os.path.splitext(os.path.basename(p))[0]) for p in kept}
plan = {"vault": [], "trash": []}
for f in sorted(pool):
    d, s = os.path.dirname(f), stem_of(f)
    sib = any(d == kd and (s == ks or s.startswith(ks + "_")) for kd, ks in keep_stems)
    plan["vault" if (base(f) in kept or sib) else "trash"].append(f)
print("vault:", len(plan["vault"]), " trash:", len(plan["trash"]))
for f in plan["vault"]:
    print("  KEEP", f) if not f.endswith(".import") else None
if "--go" in sys.argv:
    for dest, key in [(VAULT, "vault"), (TRASH, "trash")]:
        for f in plan[key]:
            t = os.path.join(dest, f)
            os.makedirs(os.path.dirname(t), exist_ok=True)
            shutil.move(f, t)
    print("done")
