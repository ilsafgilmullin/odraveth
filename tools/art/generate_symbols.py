#!/usr/bin/env python3
"""Writes the ODRAVETH Visual Alpha symbol candidates as monochrome SVG.

Geometry mirrors scripts/ui/visual/nulmeris_emblems.gd so the in-game procedural
drawing and the scalable files agree. Output (art-pack ASSET_MANIFEST paths):
  assets/ui/brand/odraveth_o_mark.svg
  assets/ui/world/seal_of_nulmeris.svg
  assets/ui/factions/{ashravael,nerqathen,dumoryss,khevaruun}.svg
Status: CANDIDATE (not approved). Single colour, silhouettes readable without colour.
Run from the repository root: python3 tools/art/generate_symbols.py
"""
import math
from pathlib import Path

INK = "#222b2e"
SIZE = 512
C = SIZE / 2


def pt(x, y, r=200.0, off=(0.0, 0.0), f=1.0):
    return (C + (x * f + off[0]) * r, C + (y * f + off[1]) * r)


def poly(points):
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points) + " Z"


def band(r_in, r_out, a0, a1, steps=24, center=(C, C)):
    cx, cy = center
    out = [(cx + math.cos(a0 + (a1 - a0) * i / steps) * r_out, cy + math.sin(a0 + (a1 - a0) * i / steps) * r_out)
           for i in range(steps + 1)]
    inn = [(cx + math.cos(a0 + (a1 - a0) * i / steps) * r_in, cy + math.sin(a0 + (a1 - a0) * i / steps) * r_in)
           for i in range(steps, -1, -1)]
    return poly(out + inn)


def svg(title, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">\n'
            f'  <title>{title}</title>\n{defs}{body}</svg>\n')


def path(d, extra=""):
    return f'  <path d="{d}" fill="{INK}"{extra}/>\n'


def o_mark():
    r = 200.0
    top = -math.pi / 2
    span = math.tau / 10
    body = ""
    for i in range(10):
        a0 = top + span * (i - 0.5) + 0.028
        a1 = top + span * (i + 0.5) - 0.028
        body += path(band(r * 0.60, r * 1.07, a0, a1, 8) if i == 0 else band(r * 0.62, r, a0, a1, 8))
    body += f'  <circle cx="{C}" cy="{C}" r="{r * 0.52:.1f}" fill="none" stroke="{INK}" stroke-width="{r * 0.03:.1f}"/>\n'
    return svg("ODRAVETH O-mark (candidate)", body)


def seal():
    r = 200.0
    top = -math.pi / 2
    body = path(band(r * 0.86, r, top + 0.24, top + math.pi, 30))
    body += path(band(r * 0.86, r, top + math.pi, top + math.tau - 0.24, 30))
    body += path(band(r * 0.60, r * 0.70, top + 0.42, top + math.pi - 0.30, 24))
    body += path(band(r * 0.60, r * 0.70, top + math.pi + 0.30, top + math.tau - 0.42, 24))
    body += path(poly([pt(-0.075, 0.80), pt(0.075, 0.80), pt(0.050, -0.92), pt(0.0, -1.12), pt(-0.050, -0.92)]))
    body += path(poly([pt(-0.40, 0.74), pt(0.40, 0.74), pt(0.40, 0.84), pt(-0.40, 0.84)]))
    body += path(poly([pt(-0.56, 0.86), pt(0.56, 0.86), pt(0.56, 0.97), pt(-0.56, 0.97)]))
    return svg("Seal of Nulmeris (candidate, in-world symbol, not the app icon)", body)


def ashravael():
    r = 200.0
    crown = poly([pt(*p) for p in [(-0.66, 0.16), (-0.86, -0.30), (-0.56, -0.10), (-0.50, -0.64), (-0.28, -0.22),
                                   (-0.18, -0.50), (0.0, -0.24), (0.18, -0.50), (0.28, -0.22), (0.50, -0.64),
                                   (0.56, -0.10), (0.86, -0.30), (0.66, 0.16), (0.40, 0.30), (0.0, 0.20),
                                   (-0.40, 0.30)]])
    o = (0.045, 0.03)
    upper = poly([pt(0, -1.0), pt(0.12, -0.74), pt(0.10, -0.14), pt(-0.10, -0.03), pt(-0.12, -0.74)])
    lower = poly([pt(0.10, 0.07, off=o), pt(-0.10, 0.18, off=o), pt(-0.09, 0.60, off=o), pt(0.09, 0.60, off=o)])
    guard = poly([pt(-0.34, 0.60, off=o), pt(0.34, 0.60, off=o), pt(0.30, 0.69, off=o), pt(-0.30, 0.69, off=o)])
    grip = poly([pt(-0.05, 0.69, off=o), pt(0.05, 0.69, off=o), pt(0.05, 0.90, off=o), pt(-0.05, 0.90, off=o)])
    pommel = poly([pt(0, 0.88, off=o), pt(0.08, 0.96, off=o), pt(0, 1.04, off=o), pt(-0.08, 0.96, off=o)])
    defs = ('  <defs><mask id="cut"><rect width="512" height="512" fill="white"/>\n'
            f'    <path d="{upper} {lower}" fill="black" stroke="black" stroke-width="16" stroke-linejoin="round"/>\n'
            '  </mask></defs>\n')
    body = f'  <path d="{crown}" fill="{INK}" mask="url(#cut)"/>\n'
    for d in (upper, lower, guard, grip, pommel):
        body += path(d)
    return svg("Ashravael: broken blade through an angular flame crown (candidate)", body, defs)


def nerqathen():
    r = 200.0
    top = -math.pi / 2
    span = math.tau / 6
    body = ""
    for i in range(6):
        mid = top + span * (i + 0.5)
        body += path(band(r * 0.72, r, mid - span * 0.5 + 0.10, mid + span * 0.5 - 0.10, 10))
        d = (math.cos(mid), math.sin(mid))
        s = (-d[1], d[0])
        body += path(poly([(C + d[0] * r * 0.66 + s[0] * r * 0.13, C + d[1] * r * 0.66 + s[1] * r * 0.13),
                           (C + d[0] * r * 0.36, C + d[1] * r * 0.36),
                           (C + d[0] * r * 0.66 - s[0] * r * 0.13, C + d[1] * r * 0.66 - s[1] * r * 0.13)]))
    body += f'  <circle cx="{C}" cy="{C}" r="{r * 0.24:.1f}" fill="none" stroke="{INK}" stroke-width="{r * 0.03:.1f}"/>\n'
    return svg("Nerqathen: segmented circle with an empty core (candidate)", body)


def dumoryss():
    r = 200.0
    body = path(band(r * 0.66, r * 0.94, math.pi * 0.5 + 0.16, math.pi * 1.5 - 0.16, 26))
    body += path(band(r * 0.66, r * 0.94, -math.pi * 0.5 + 0.16, math.pi * 0.5 - 0.16, 26, (C + r * 0.10, C - r * 0.10)))
    fracture = [pt(0.06, -0.86), pt(-0.09, -0.44), pt(0.08, -0.12), pt(-0.07, 0.20), pt(0.09, 0.50), pt(-0.03, 0.88)]
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in fracture)
    body += f'  <path d="{d}" fill="none" stroke="{INK}" stroke-width="{r * 0.08:.1f}" stroke-linejoin="round"/>\n'
    return svg("Dumoryss: displaced broken ring with a central fracture (candidate)", body)


def khevaruun():
    r = 200.0
    plate = [(0, -0.86), (0.42, -0.64), (0.42, 0.14), (0, 0.86), (-0.42, 0.14), (-0.42, -0.64)]
    left = poly([pt(x, y, off=(-0.46, 0.10), f=0.78) for x, y in plate])
    right = poly([pt(x, y, off=(0.46, 0.10), f=0.78) for x, y in plate])
    front = poly([pt(x, y) for x, y in plate])
    defs = ('  <defs><mask id="cut"><rect width="512" height="512" fill="white"/>\n'
            f'    <path d="{front}" fill="black" stroke="black" stroke-width="18" stroke-linejoin="round"/>\n'
            '  </mask>\n'
            '  <mask id="ribs"><rect width="512" height="512" fill="white"/>\n'
            f'    <polyline points="{C - r * 0.34},{C - r * 0.30} {C},{C - r * 0.04} {C + r * 0.34},{C - r * 0.30}" fill="none" stroke="black" stroke-width="{r * 0.06:.1f}" stroke-linejoin="miter"/>\n'
            f'    <polyline points="{C - r * 0.34},{C + r * 0.02} {C},{C + r * 0.28} {C + r * 0.34},{C + r * 0.02}" fill="none" stroke="black" stroke-width="{r * 0.04:.1f}" stroke-linejoin="miter"/>\n'
            '  </mask></defs>\n')
    body = f'  <path d="{left} {right}" fill="{INK}" mask="url(#cut)"/>\n'
    body += f'  <path d="{front}" fill="{INK}" mask="url(#ribs)"/>\n'
    return svg("Khevaruun: interlocking geometric shield plates (candidate)", body, defs)


OUTPUTS = {
    "assets/ui/brand/odraveth_o_mark.svg": o_mark,
    "assets/ui/world/seal_of_nulmeris.svg": seal,
    "assets/ui/factions/ashravael.svg": ashravael,
    "assets/ui/factions/nerqathen.svg": nerqathen,
    "assets/ui/factions/dumoryss.svg": dumoryss,
    "assets/ui/factions/khevaruun.svg": khevaruun,
}

if __name__ == "__main__":
    for target, build in OUTPUTS.items():
        out = Path(target)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(build())
        print("wrote", target)
