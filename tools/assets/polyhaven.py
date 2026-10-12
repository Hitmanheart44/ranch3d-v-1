"""Download CC0 models from Poly Haven (free for any use, no attribution required) as glTF with 1k textures.
python3 tools/assets/polyhaven.py id [id ...]   -> assets/polyhaven/<id>/<id>.gltf (+ .bin + textures)
"""
import json
import os
import sys
import urllib.request

OUT = os.path.join(os.path.dirname(__file__), "../../assets/polyhaven")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "spirit-in-the-machine-asset-fetch"})
    return urllib.request.urlopen(req, timeout=120).read()


for aid in sys.argv[1:]:
    d = os.path.join(OUT, aid)
    if os.path.exists(os.path.join(d, aid + ".gltf")):
        print("HAVE", aid)
        continue
    try:
        files = json.loads(get("https://api.polyhaven.com/files/" + aid))
        g = files["gltf"]
        res = "1k" if "1k" in g else sorted(g)[0]
        entry = g[res]["gltf"]
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, aid + ".gltf"), "wb").write(get(entry["url"]))
        for rel, inc in entry.get("include", {}).items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "wb").write(get(inc["url"]))
        print("GOT", aid, res, flush=True)
    except Exception as e:
        print("FAIL", aid, e, flush=True)
