#!/usr/bin/env python3
"""Print the single dominant accent colour of an image as #rrggbb (stdlib + ImageMagick)."""
import colorsys, subprocess, sys

path = sys.argv[1]
try:
    raw = subprocess.run(["magick", path + "[0]", "-resize", "64x64", "-depth", "8", "rgb:-"],
                         capture_output=True, timeout=15).stdout
except Exception:
    print("#7aa2f7"); sys.exit(0)

buckets = {}
inv255 = 1.0 / 255.0
for i in range(0, len(raw) - 2, 3):
    r = raw[i] * inv255
    g = raw[i + 1] * inv255
    b = raw[i + 2] * inv255
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
