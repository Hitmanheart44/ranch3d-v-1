"""Download Sketchfab models (CC licenses) as glTF using the owner's API token (~/.config/sketchfab_token).
python3 tools/assets/sketchfab.py uid:name [uid:name ...]   -> assets/sketchfab/<name>/ (+ CREDITS line in assets/sketchfab/CREDITS.txt)
"""
import io
import json
import os
import sys
import urllib.request
import zipfile

OUT = os.path.join(os.path.dirname(__file__), "../../assets/sketchfab")
TOKEN = open(os.path.expanduser("~/.config/sketchfab_token")).read().strip()


def get(url, auth=True):
    h = {"User-Agent": "Mozilla/5.0"}
    if auth:
        h["Authorization"] = "Token " + TOKEN
    return urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=300).read()


for arg in sys.argv[1:]:
    uid, name = arg.split(":")
    d = os.path.join(OUT, name)
    if os.path.isdir(d) and any(f.endswith(".gltf") or f.endswith(".glb") for _, _, fs in os.walk(d) for f in fs):
        print("HAVE", name)
        continue
    try:
        info = json.loads(get("https://api.sketchfab.com/v3/models/" + uid, auth=False))
        dl = json.loads(get("https://api.sketchfab.com/v3/models/%s/download" % uid))
        url = (dl.get("gltf") or dl.get("glb"))["url"]
        data = get(url, auth=False)
        os.makedirs(d, exist_ok=True)
        if data[:2] == b"PK":
            zipfile.ZipFile(io.BytesIO(data)).extractall(d)
        else:
            open(os.path.join(d, name + ".glb"), "wb").write(data)
        lic = (info.get("license") or {}).get("label", "?")
        with open(os.path.join(OUT, "CREDITS.txt"), "a") as f:
            f.write('"%s" by %s (%s) https://sketchfab.com/3d-models/%s\n' % (info["name"], info["user"]["displayName"], lic, uid))
        print("GOT", name, lic, flush=True)
    except Exception as e:
        print("FAIL", name, e, flush=True)
