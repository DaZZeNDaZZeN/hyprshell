#!/usr/bin/env python3
"""Print the single dominant accent colour of an image as #rrggbb (stdlib + ImageMagick)."""
import colorsys, subprocess, sys

path = sys.argv[1]
try:
    out = subprocess.run(["magick", path + "[0]", "-resize", "96x96", "-depth", "8", "txt:-"],
                         capture_output=True, text=True, timeout=20).stdout
except Exception:
    print("#7aa2f7"); sys.exit(0)

buckets = {}
for line in out.splitlines()[1:]:
    try:
        h = line.split("#")[1][:6]
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    except Exception:
        continue
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    if vv < 0.25 or ss < 0.18:      # skip near-black / grey pixels
        continue
    key = int(hh * 24) % 24          # 24 hue buckets
    w = ss * (0.4 + vv)
    n, sh, sv, ssum = buckets.get(key, (0, 0.0, 0.0, 0.0))
    buckets[key] = (n + w, sh + hh * w, sv + vv * w, ssum + ss * w)

if not buckets:
    print("#7aa2f7"); sys.exit(0)
n, sh, sv, ss = max(buckets.values(), key=lambda t: t[0])
hh, vv, ss = sh / n, sv / n, ss / n
# normalise to a pleasant, readable highlight colour
ss = min(max(ss, 0.45), 0.85)
vv = min(max(vv, 0.70), 0.95)
r, g, b = colorsys.hsv_to_rgb(hh, ss, vv)
print("#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255)))
