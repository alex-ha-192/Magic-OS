#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generates Magic's colour schemes and wallpapers, one per accent.

    python3 tools/gen-theme.py        (writes into system_files/)

Accents are defined once here and mirrored in the installer UI, Magic
Settings and firstboot. Lime is the default.
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "system_files")

# key: (display name, fill, text tint, wallpaper tint)
ACCENTS = {
    "lime":    ("Lime",    "#4d7c0f", "#bef264", "#26390d"),
    "ember":   ("Ember",   "#c2410c", "#ff8a4c", "#4b2412"),
    "magenta": ("Magenta", "#c4125f", "#ff5fa2", "#4a1236"),
    "teal":    ("Teal",    "#0f766e", "#5eead4", "#0c3b3a"),
    "blue":    ("Blue",    "#1d5fc4", "#7db3ff", "#10305f"),
    "violet":  ("Violet",  "#6d3fc0", "#b79cff", "#2d1a58"),
}
DEFAULT = "lime"

# Charcoal greys from the mockups.
BG = "#171514"        # windows, taskbar
VIEW = "#1f1c1a"      # lists, text fields
ALT = "#262220"
BUTTON = "#2b2725"
TEXT = "#ece7e4"
MUTE = "#b5aeaa"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def c(h):
    return ",".join(str(x) for x in rgb(h))


def scheme(key):
    name, ac, at, _ = ACCENTS[key]
    fg = {
        "ForegroundActive": at, "ForegroundInactive": MUTE, "ForegroundLink": at,
        "ForegroundNegative": "#ff786e", "ForegroundNeutral": "#f6c450", "ForegroundNormal": TEXT,
        "ForegroundPositive": "#6ee7a1", "ForegroundVisited": at,
    }

    def group(title, bg, alt, fgs=fg, deco=at):
        lines = [f"[Colors:{title}]", f"BackgroundAlternate={c(alt)}", f"BackgroundNormal={c(bg)}",
                 f"DecorationFocus={c(deco)}", f"DecorationHover={c(deco)}"]
        lines += [f"{k}={c(v)}" for k, v in fgs.items()]
        return "\n".join(lines)

    sel_fg = {k: "#ffffff" for k in fg}
    out = [
        "[ColorEffects:Disabled]\nColor=56,56,56\nColorAmount=0\nColorEffect=0\nContrastAmount=0.65\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2",
        "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=112,111,110\nColorAmount=0.025\nColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\nEnable=false\nIntensityAmount=0\nIntensityEffect=0",
        group("Button", BUTTON, ALT),
        group("Complementary", BG, VIEW),
        group("Header", BG, VIEW),
        "[Colors:Header][Inactive]\n" + "\n".join(group("x", BG, VIEW).split("\n")[1:]),
        group("Selection", ac, ac, sel_fg, at),
        group("Tooltip", "#12100f", BG),
        group("View", VIEW, ALT),
        group("Window", BG, VIEW),
        f"[General]\nColorScheme=Magic{name}\nName=Magic {name}\nshadeSortColumn=true",
        "[KDE]\ncontrast=4",
        f"[WM]\nactiveBackground={c(BG)}\nactiveBlend={c(TEXT)}\nactiveForeground={c(TEXT)}\n"
        f"inactiveBackground={c('#12100f')}\ninactiveBlend={c(MUTE)}\ninactiveForeground={c(MUTE)}",
    ]
    return "\n\n".join(out) + "\n"


def wallpaper(key, path, w=3840, h=2160):
    import numpy as np
    from PIL import Image
    _, _, _, wp = ACCENTS[key]
    a = np.array(rgb("#161311"), dtype=np.float32)
    b = np.array(rgb(wp), dtype=np.float32)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((xs / w * 0.62 + ys / h * 0.38), 0, 1) ** 1.35
    img = a[None, None, :] * (1 - t[..., None]) + b[None, None, :] * t[..., None]
    # Two slanted light bands, as in the mockups (scaled from a 1440x900 board).
    sx, sy = w / 1440.0, h / 900.0

    def band(top_l, top_r, bot_r, bot_l, alpha):
        # Inside the parallelogram: between the left and right slanted edges.
        y = ys / sy
        left = top_l + (bot_l - top_l) * (y / 900.0)
        right = top_r + (bot_r - top_r) * (y / 900.0)
        x = xs / sx
        m = ((x >= left) & (x <= right)).astype(np.float32)
        return m * alpha

    light = band(900, 1120, 640, 420, 0.04) + band(1180, 1340, 980, 800, 0.05)
    img = img * (1 - light[..., None]) + 255.0 * light[..., None]
    img += np.random.default_rng(7).normal(0, 1.1, img.shape)  # grain: no banding
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(path, "JPEG", quality=90, optimize=True)


def main():
    cs = os.path.join(ROOT, "usr/share/color-schemes")
    os.makedirs(cs, exist_ok=True)
    for f in os.listdir(cs):
        if f.startswith("Magic"):
            os.remove(os.path.join(cs, f))
    for key, (name, *_rest) in ACCENTS.items():
        with open(os.path.join(cs, f"Magic{name}.colors"), "w") as f:
            f.write(scheme(key))
        if "--no-wallpapers" in sys.argv:
            continue
        wd = os.path.join(ROOT, f"usr/share/wallpapers/Magic{name}")
        os.makedirs(os.path.join(wd, "contents/images"), exist_ok=True)
        json.dump({"KPlugin": {"Authors": [{"Name": "Magic OS"}], "Id": f"Magic{name}",
                               "License": "CC-BY-SA-4.0", "Name": f"Magic {name}"}},
                  open(os.path.join(wd, "metadata.json"), "w"), indent=2)
        wallpaper(key, os.path.join(wd, "contents/images/3840x2160.jpg"))
    # System-wide default colours: the full default scheme, so every KDE app
    # gets Magic's colours even before anyone opens Settings.
    xdg = os.path.join(ROOT, "etc/xdg")
    os.makedirs(xdg, exist_ok=True)
    base = scheme(DEFAULT)
    head = (
        "# Magic OS system defaults. Generated by tools/gen-theme.py. People can change all of this.\n"
        "[General]\n"
        f"ColorScheme=Magic{ACCENTS[DEFAULT][0]}\n"
        "MagicAccent=" + DEFAULT + "\n"
        "font=Open Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\n"
        "menuFont=Open Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\n"
        "toolBarFont=Open Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\n"
        "smallestReadableFont=Open Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\n"
        "\n[KDE]\nLookAndFeelPackage=org.magicos.desktop\nSingleClick=false\nwidgetStyle=Breeze\ncontrast=4\n"
        "\n[Icons]\nTheme=breeze-dark\n\n"
    )
    body = "\n\n".join(p for p in base.split("\n\n") if not p.startswith("[General]") and not p.startswith("[KDE]"))
    with open(os.path.join(xdg, "kdeglobals"), "w") as f:
        f.write(head + body)
    # Accent table for the shell scripts and apps.
    os.makedirs(os.path.join(ROOT, "usr/share/magic-os"), exist_ok=True)
    json.dump({"default": DEFAULT, "order": list(ACCENTS), "accents": {k: {"name": v[0], "fill": v[1], "text": v[2], "wallpaper": v[3]}
                                                for k, v in ACCENTS.items()}},
              open(os.path.join(ROOT, "usr/share/magic-os/accents.json"), "w"), indent=2)


if __name__ == "__main__":
    main()
