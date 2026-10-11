#!/usr/bin/env python3
"""Hero Art V1 review sheets (docs/HERO_POSE_BRIEF_V1.md).

1. 01_current_silhouettes.jpg — the approved hero PNGs, their silhouettes and the
   overlap of all four (why they read alike).
2. 02_pose_blueprints.png — gesture blueprints for the commissioned final art:
   line of action, mannequin and silhouette envelope per hero, with the measured
   pairwise IoU. Blueprints are pose references only, never game assets.

Usage (repository root): python3 tools/art/hero_pose_review.py [output_dir]
Default output: docs/visual_review/hero_v1. Requires Pillow only.
"""
import itertools
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hero_silhouette_report as report  # noqa: E402

FONT = "assets/ui/visual_alpha/fonts/NotoSerif-SemiBold.ttf"
STONE = (232, 226, 215)
INK = (34, 43, 46)
GOLD = (183, 155, 85)
MUTED = (104, 114, 118)
HEROES = {
    "kezharyn": ("КЕЖАРИН", "Ашравайль", (152, 81, 70), (226, 120, 60)),
    "vhorazel": ("ВХОРАЗЕЛЬ", "Неркатен", (52, 128, 128), (119, 211, 215)),
    "syrraveth": ("СИРРАВЕТ", "Думорисс", (110, 88, 140), (186, 150, 230)),
    "tazhyrion": ("ТАЖИРИОН", "Кеваруун", (64, 92, 128), (216, 194, 124)),
}
PANEL = (600, 900)

# Gesture blueprints in a 600x900 panel, ground line y=860.
# limbs: (joint points, width); polys: filled body/cloth/prop shapes; lines: props.
POSES = {
    "kezharyn": {
        "keywords": "наклон вперёд · выпад · диагональ · клинок отведён назад",
        "head": (372, 150, 40),
        "polys": [
            [(275, 215), (385, 232), (350, 475), (262, 465)],
            [(282, 222), (232, 214), (130, 236), (40, 300), (150, 300), (262, 290)],
            [(440, 830), (515, 845), (512, 860), (440, 860)],
            [(100, 808), (142, 822), (122, 858), (80, 858)],
        ],
        "limbs": [
            ([(345, 190), (330, 222)], 30),
            ([(335, 470), (425, 630), (455, 835)], 42),
            ([(272, 462), (195, 640), (118, 815)], 40),
            ([(380, 240), (445, 305), (510, 288)], 28),
            ([(285, 228), (222, 305), (242, 382)], 28),
        ],
        "lines": [([(245, 390), (92, 560)], 10), ([(225, 372), (266, 410)], 8)],
        "hands": [(520, 285, 16), (245, 390, 15)],
        "action": [(95, 855), (250, 470), (372, 150)],
        "fx": [("dots", [(110, 545), (150, 500), (60, 600), (470, 820), (520, 800), (95, 520)])],
    },
    "vhorazel": {
        "keywords": "вертикаль · неподвижность · рука над головой · вторая скрыта",
        "head": (300, 118, 36),
        "polys": [
            [(258, 200), (342, 196), (332, 470), (268, 470)],
            [(262, 440), (338, 440), (392, 860), (208, 860)],
            [(336, 330), (380, 330), (374, 445), (330, 445)],
        ],
        "limbs": [
            ([(300, 150), (300, 188)], 26),
            ([(258, 205), (206, 165), (188, 92)], 24),
            ([(342, 203), (362, 320), (352, 410)], 28),
        ],
        "lines": [([(364, 140), (364, 860)], 8)],
        "hands": [(186, 82, 13), (360, 410, 15)],
        "action": [(300, 860), (300, 60)],
        "fx": [("orb", (182, 44, 22)), ("ring", (364, 130, 14))],
    },
    "syrraveth": {
        "keywords": "разворот 3/4 · S-изгиб · левая рука искажает · правая уравновешивает",
        "head": (318, 138, 34),
        "polys": [
            [(276, 200), (346, 208), (328, 362), (292, 362)],
            [(292, 360), (328, 360), (352, 465), (272, 452)],
            [(272, 452), (352, 465), (400, 700), (372, 860), (250, 860), (286, 700)],
        ],
        "limbs": [
            ([(312, 170), (305, 200)], 22),
            ([(346, 210), (428, 250), (500, 212)], 20),
            ([(278, 205), (215, 290), (170, 352)], 20),
        ],
        "lines": [],
        "hands": [(510, 208, 13), (165, 360, 12)],
        "action": [(330, 860), (382, 650), (300, 400), (318, 120)],
        "fx": [("ellipses", (510, 208, [(40, 26), (66, 44), (92, 62)]))],
    },
    "tazhyrion": {
        "keywords": "широкая стойка · монументальность · щит перед корпусом · вес",
        "head": (300, 165, 40),
        "polys": [
            [(205, 232), (395, 232), (365, 478), (235, 478)],
            [(110, 830), (178, 832), (180, 860), (106, 860)],
            [(426, 832), (494, 830), (498, 860), (422, 860)],
            [(380, 250), (452, 300), (452, 500), (380, 555), (308, 500), (308, 300)],
        ],
        "limbs": [
            ([(300, 205), (300, 234)], 36),
            ([(242, 470), (185, 650), (150, 845)], 54),
            ([(358, 470), (415, 650), (450, 845)], 54),
            ([(395, 240), (430, 360), (372, 395)], 34),
            ([(205, 240), (160, 340), (150, 430)], 34),
        ],
        "lines": [([(150, 440), (150, 605)], 10), ([(118, 470), (188, 452)], 10)],
        "hands": [(150, 440, 18)],
        "circles": [(205, 242, 34), (395, 242, 34)],
        "action": [(150, 845), (300, 165), (450, 845)],
        "fx": [("hex", (380, 402, 1.12))],
    },
}


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size)


def draw_figure(draw: ImageDraw.ImageDraw, pose: dict, fill, scale: float = 1.0, offset=(0, 0)) -> None:
    def p(point):
        return (offset[0] + point[0] * scale, offset[1] + point[1] * scale)

    for poly in pose["polys"]:
        draw.polygon([p(q) for q in poly], fill=fill)
    for points, width in pose["limbs"] + pose["lines"]:
        pts = [p(q) for q in points]
        draw.line(pts, fill=fill, width=max(1, round(width * scale)), joint="curve")
        for q in pts:
            r = width * scale / 2
            draw.ellipse((q[0] - r, q[1] - r, q[0] + r, q[1] + r), fill=fill)
    for x, y, r in pose.get("hands", []) + pose.get("circles", []):
        c = p((x, y))
        draw.ellipse((c[0] - r * scale, c[1] - r * scale, c[0] + r * scale, c[1] + r * scale), fill=fill)
    x, y, r = pose["head"]
    c = p((x, y))
    draw.ellipse((c[0] - r * scale, c[1] - r * scale, c[0] + r * scale, c[1] + r * scale), fill=fill)


def blueprint_mask(pose: dict) -> Image.Image:
    mask = Image.new("L", PANEL, 0)
    draw_figure(ImageDraw.Draw(mask), pose, 255)
    path = Path("/tmp") / "odraveth_blueprint_mask.png"
    rgba = Image.new("RGBA", PANEL, (0, 0, 0, 0))
    rgba.putalpha(mask)
    rgba.save(path)
    return report.silhouette(path)


def dashed(draw: ImageDraw.ImageDraw, points, color, width=5, dash=18) -> None:
    for a, b in zip(points, points[1:]):
        length = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
        steps = max(1, int(length // dash))
        for i in range(0, steps, 2):
            t0, t1 = i / steps, min(1.0, (i + 1) / steps)
            draw.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                       (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=color, width=width)


def draw_fx(draw: ImageDraw.ImageDraw, pose: dict, glow) -> None:
    for kind, data in pose["fx"]:
        if kind == "dots":
            for x, y in data:
                draw.ellipse((x - 7, y - 7, x + 7, y + 7), fill=glow + (200,))
        elif kind == "orb":
            x, y, r = data
            for k in range(4, 0, -1):
                draw.ellipse((x - r * k / 2, y - r * k / 2, x + r * k / 2, y + r * k / 2), fill=glow + (40 * (5 - k),))
        elif kind == "ring":
            x, y, r = data
            draw.ellipse((x - r, y - r, x + r, y + r), outline=glow + (255,), width=4)
        elif kind == "ellipses":
            x, y, radii = data
            for rx, ry in radii:
                draw.ellipse((x - rx, y - ry, x + rx, y + ry), outline=glow + (210,), width=4)
        elif kind == "hex":
            x, y, k = data
            pts = [(x, y - 152 * k), (x + 72 * k, y - 102 * k), (x + 72 * k, y + 98 * k), (x, y + 153 * k),
                   (x - 72 * k, y + 98 * k), (x - 72 * k, y - 102 * k)]
            draw.line(pts + [pts[0]], fill=glow + (220,), width=5)


def pose_panel(hero: str) -> Image.Image:
    name, faction, tone, glow = HEROES[hero]
    pose = POSES[hero]
    panel = Image.new("RGBA", PANEL, STONE + (255,))
    over = Image.new("RGBA", PANEL, (0, 0, 0, 0))
    draw = ImageDraw.Draw(over)
    for y in range(0, PANEL[1], 60):
        draw.line([(0, y), (PANEL[0], y)], fill=MUTED + (40,), width=1)
    draw.line([(0, 860), (PANEL[0], 860)], fill=INK + (160,), width=3)
    draw_figure(draw, pose, tone + (235,))
    draw_fx(draw, pose, glow)
    dashed(draw, pose["action"], GOLD + (255,))
    panel = Image.alpha_composite(panel, over)
    text = ImageDraw.Draw(panel)
    text.text((24, 18), name, font=font(40), fill=INK)
    text.text((26, 66), faction, font=font(24), fill=tone)
    return panel


def labelled_grid(columns, title: str, subtitle: str, footer_lines) -> Image.Image:
    width = 40 + sum(c.width for c in columns) + 30 * (len(columns) - 1) + 40
    height = 150 + max(c.height for c in columns) + 60 + 40 * len(footer_lines) + 40
    sheet = Image.new("RGB", (width, height), (246, 242, 234))
    draw = ImageDraw.Draw(sheet)
    draw.text((40, 30), title, font=font(48), fill=INK)
    draw.text((42, 92), subtitle, font=font(24), fill=MUTED)
    x = 40
    for column in columns:
        sheet.paste(column, (x, 150), column if column.mode == "RGBA" else None)
        x += column.width + 30
    y = 150 + max(c.height for c in columns) + 40
    for line in footer_lines:
        draw.text((40, y), line, font=font(26), fill=INK)
        y += 40
    return sheet


def current_sheet(out: Path) -> dict:
    stats, pairs = report.report(Path("assets/heroes"))
    columns = []
    overlay = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
    for hero, (name, faction, tone, _glow) in HEROES.items():
        art = Image.open(f"assets/heroes/{hero}.png").convert("RGBA")
        art.thumbnail((360, 450))
        column = Image.new("RGBA", (380, 820), STONE + (255,))
        column.paste(art, ((380 - art.width) // 2, 70), art)
        sil = report.silhouette(Path(f"assets/heroes/{hero}.png")).resize((256, 256))
        black = Image.new("RGBA", sil.size, INK + (255,))
        column.paste(black, (62, 505), sil)
        draw = ImageDraw.Draw(column)
        draw.text((16, 12), name, font=font(34), fill=INK)
        draw.text((18, 786), "плечи %d · стопы %d · наклон %+.0f" % (stats[hero]["shoulders"], stats[hero]["feet"],
                  stats[hero]["lean"]), font=font(18), fill=MUTED)
        columns.append(column)
        tint = Image.new("RGBA", (512, 512), tone + (115,))
        overlay.paste(tint, (0, 0), sil.resize((512, 512)))
    overlay_panel = Image.new("RGBA", (560, 820), STONE + (255,))
    base = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    overlay_panel.paste(Image.alpha_composite(base, overlay), (24, 120))
    ImageDraw.Draw(overlay_panel).text((24, 12), "НАЛОЖЕНИЕ ЧЕТЫРЁХ\nСИЛУЭТОВ", font=font(32), fill=INK)
    columns.append(overlay_panel)
    footer = ["Попарное совпадение силуэтов (IoU, 1.0 = одинаковы; цель Hero Art V1 — не выше %.2f):" % report.MAX_PAIR_IOU]
    for (a, b), value in sorted(pairs.items(), key=lambda item: -item[1]):
        footer.append("   %s — %s: %.2f" % (HEROES[a][0], HEROES[b][0], value))
    sheet = labelled_grid(columns, "Герои сейчас: одна стойка на четверых",
                          "Утверждённые PNG assets/heroes · силуэт по альфа-каналу · tools/art/hero_silhouette_report.py",
                          footer)
    sheet.convert("RGB").save(out / "01_current_silhouettes.jpg", quality=84, optimize=True)
    return pairs


def blueprint_sheet(out: Path) -> dict:
    masks = {hero: report.bits(blueprint_mask(POSES[hero])) for hero in POSES}
    pairs = {(a, b): report.iou(masks[a], masks[b]) for a, b in itertools.combinations(POSES, 2)}
    columns = []
    for hero in POSES:
        panel = pose_panel(hero)
        column = Image.new("RGBA", (PANEL[0], PANEL[1] + 70), (246, 242, 234, 255))
        column.paste(panel, (0, 0))
        parts = POSES[hero]["keywords"].split(" · ")
        half = (len(parts) + 1) // 2
        ImageDraw.Draw(column).text((10, PANEL[1] + 6), " · ".join(parts[:half]) + "\n" + " · ".join(parts[half:]),
                                    font=font(20), fill=INK)
        columns.append(column)
    worst = max(pairs.values())
    footer = ["ОРИЕНТИР ПОЗЫ ДЛЯ ФИНАЛЬНОГО АРТА — НЕ ИГРОВОЙ ПОРТРЕТ. Пунктир — линия действия; светлые линии — магия героя.",
              "Совпадение силуэтов ориентиров: макс. IoU %.2f (у текущих портретов %.2f). Детали экипировки — по утверждённому канону."
              % (worst, max(report.report(Path("assets/heroes"))[1].values()))]
    sheet = labelled_grid(columns, "Hero Art V1 — четыре разные позы",
                          "Кежарин: атака · Вхоразель: власть без усилия · Сирравет: искажение · Тажирион: несокрушимость",
                          footer)
    sheet.save(out / "02_pose_blueprints.png", optimize=True)
    return pairs


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("docs/visual_review/hero_v1")
    out.mkdir(parents=True, exist_ok=True)
    current = current_sheet(out)
    blueprints = blueprint_sheet(out)
    print("current max IoU %.3f" % max(current.values()))
    for (a, b), value in sorted(blueprints.items(), key=lambda item: -item[1]):
        print("blueprint IoU %-10s %-10s %.3f" % (a, b, value))
    return 0


if __name__ == "__main__":
    sys.exit(main())
