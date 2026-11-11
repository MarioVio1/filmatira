#!/usr/bin/env python3
"""Generatore di LUT 3D originali (.cube 33x33x33) per Filmatura.

Ogni preset e' definito da parametri di grading (curve per canale,
temperatura, saturazione, contrasto, split-toning, fade) applicati dal
nostro motore: nessun dato estratto da prodotti o film terzi.
Ordine di scrittura conforme alla specifica .cube: rosso varia piu' veloce,
poi verde, poi blu (compatibile con CIColorCube di Core Image).
"""
import numpy as np
from pathlib import Path

N = 33
OUT = Path("/home/z/my-project/Filmatura/Filmatura/Resources/LUTs")

# ---------- motore di grading ----------

def s_curve(x, amount):
    """Curva a S contrasto: amount 0 = identita'."""
    x = np.clip(x, 0, 1)
    # sigmoid centrata su 0.5
    k = amount * 8.0
    y = 1.0 / (1.0 + np.exp(-k * (x - 0.5)))
    return x * (1 - amount) + y * amount

def lgg(x, shadows=0.0, mids=0.0, highs=0.0):
    """Correzione lift/gamma/gain per valore luminoso (offset3-zone)."""
    lo = shadows * (1 - x) ** 3
    mid = mids * 4 * x * (1 - x)
    hi = highs * x ** 3
    return x + lo + mid + hi

def temperature_tint(x, temp=0.0, tint=0.0):
    """temp >0 caldo (R+ B-), tint >0 magenta (G-)."""
    out = x.copy()
    out[..., 0] += temp * 0.5
    out[..., 2] -= temp * 0.5
    out[..., 1] -= tint * 0.5
    return out

def saturation(x, s):
    lum = (x * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    return lum + (x - lum) * s

def split_tone(x, shadow_color, highlight_color, strength=1.0, balance=0.5):
    """Tinta dei toni alti e bassi: mix additivo-soft pesato per luminanza."""
    lum = (x * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    w_hi = np.clip((lum - balance) / (1 - balance + 1e-6), 0, 1) ** 1.4
    w_sh = np.clip((balance - lum) / (balance + 1e-6), 0, 1) ** 1.4
    sh = np.asarray(shadow_color) * w_sh * strength
    hi = np.asarray(highlight_color) * w_hi * strength
    return x + sh * (1 - x) + hi * x

def fade_blacks(x, lift, lift_color=(0, 0, 0)):
    """Alza i neri (look sbiadito) verso un colore."""
    col = np.asarray(lift_color)
    return lift * col + (1 - lift) * x

def clip_whites(x, gain_top):
    return x * (1 - gain_top * x ** 2)

def grade(rgb, p):
    """Applica la ricetta di grading a rgb (..., 3) in [0,1] (spazio sRGB)."""
    x = rgb.copy()
    x = temperature_tint(x, p.get("temp", 0), p.get("tint", 0))
    channel_lift = p.get("ch", [(0, 0, 0)] * 3)
    for i, c in enumerate(channel_lift):
        x[..., i] = lgg(x[..., i], shadows=c[0], mids=c[1], highs=c[2])
    if p.get("contrast", 0):
        x = s_curve(x, p["contrast"])
    if p.get("sat", 1.0) != 1.0:
        x = saturation(x, p["sat"])
    if p.get("st_sh") or p.get("st_hi"):
        x = split_tone(x, p.get("st_sh", (0, 0, 0)), p.get("st_hi", (0, 0, 0)),
                       p.get("st_strength", 1.0), p.get("st_balance", 0.5))
    if p.get("fade", 0):
        x = fade_blacks(x, p["fade"], p.get("fade_col", (0, 0, 0)))
    if p.get("clip", 0):
        x = clip_whites(x, p["clip"])
    return np.clip(x, 0, 1)

# ---------- 12 preset originali ----------

PRESETS = {
    # --- Pack: Classici di Hollywood ---
    "proiezione": dict(  # blockbuster teal & orange
        temp=0.085, contrast=0.42, sat=1.12,
        st_sh=(0.00, 0.09, 0.13), st_hi=(0.16, 0.06, 0.00), st_strength=1.15, st_balance=0.52,
        ch=[(0.00, -0.015, 0.02), (0.00, 0.00, 0.00), (0.02, 0.015, 0.00)],
    ),
    "notturno": dict(  # noir: bianco e nero ad alto contrasto
        contrast=0.55, sat=0.02, st_strength=0.0,
        ch=[(0.01, 0.01, 0.00), (0.01, 0.00, 0.00), (0.00, -0.01, 0.00)],
        fade=0.035, fade_col=(0.02, 0.02, 0.03), clip=0.18,
    ),
    "canyon": dict(  # western ambrato
        temp=0.14, contrast=0.30, sat=0.92,
        st_sh=(0.05, 0.02, 0.00), st_hi=(0.18, 0.10, 0.00), st_strength=1.0, st_balance=0.5,
        ch=[(0.02, 0.02, 0.02), (0.00, 0.005, 0.0), (-0.02, -0.01, -0.02)],
        fade=0.07, fade_col=(0.10, 0.07, 0.03),
    ),
    # --- Pack: Sci-Fi & Distopia ---
    "acido": dict(  # cyberpunk verde acido / magenta
        temp=-0.06, tint=-0.05, contrast=0.45, sat=1.35,
        st_sh=(0.00, 0.10, 0.02), st_hi=(0.12, 0.00, 0.10), st_strength=1.25, st_balance=0.48,
        ch=[(0.00, -0.01, 0.00), (0.03, 0.03, 0.02), (-0.01, 0.00, 0.03)],
        clip=0.10,
    ),
    "criogenesi": dict(  # blu ghiaccio distopico
        temp=-0.16, tint=0.04, contrast=0.32, sat=0.80,
        st_sh=(0.00, 0.03, 0.10), st_hi=(0.06, 0.10, 0.14), st_strength=1.1, st_balance=0.5,
        fade=0.06, fade_col=(0.02, 0.04, 0.07),
    ),
    "marte": dict(  # rosso-arancio marziano
        temp=0.20, tint=-0.03, contrast=0.38, sat=1.05,
        st_sh=(0.06, 0.01, 0.00), st_hi=(0.20, 0.08, 0.00), st_strength=1.2, st_balance=0.45,
        ch=[(0.02, 0.01, 0.01), (0.00, 0.00, 0.00), (-0.04, -0.02, -0.03)],
        clip=0.08,
    ),
    # --- Pack: Vintage & Pellicola ---
    "super8": dict(  # super 8 caldo sbiadito
        temp=0.12, tint=0.03, contrast=0.18, sat=0.88,
        st_sh=(0.02, 0.00, 0.00), st_hi=(0.14, 0.09, 0.02), st_strength=0.9, st_balance=0.5,
        fade=0.14, fade_col=(0.12, 0.09, 0.06),
    ),
    "argento": dict(  # bleach bypass: argento ad alto contrasto
        contrast=0.52, sat=0.55, st_strength=0.0,
        ch=[(0.00, 0.01, 0.02), (0.00, 0.01, 0.02), (0.00, 0.01, 0.02)],
        clip=0.22, fade=0.05, fade_col=(0.05, 0.05, 0.05),
    ),
    "pastello90": dict(  # rom-com anni '90
        temp=0.04, tint=0.02, contrast=-0.12, sat=0.94,
        st_sh=(0.03, 0.02, 0.04), st_hi=(0.10, 0.08, 0.06), st_strength=0.7, st_balance=0.5,
        fade=0.16, fade_col=(0.10, 0.09, 0.10),
    ),
    # --- Pack: Horror & Thriller ---
    "nebbia": dict(  # verde putrido horror
        temp=-0.05, tint=-0.07, contrast=0.42, sat=0.85,
        st_sh=(0.00, 0.07, 0.02), st_hi=(0.04, 0.09, 0.01), st_strength=1.15, st_balance=0.55,
        ch=[(-0.01, 0.00, 0.00), (0.02, 0.02, 0.01), (0.00, 0.01, 0.00)],
        fade=0.05, fade_col=(0.02, 0.05, 0.02),
    ),
    "crimson": dict(  # rosso sangue thriller
        temp=0.10, tint=-0.06, contrast=0.50, sat=1.02,
        st_sh=(0.04, 0.00, 0.00), st_hi=(0.18, 0.02, 0.00), st_strength=1.3, st_balance=0.42,
        ch=[(0.01, 0.00, 0.00), (0.00, 0.00, 0.00), (-0.05, -0.02, -0.02)],
        clip=0.12,
    ),
    "nord": dict(  # bianco ghiaccio nordico, arioso
        temp=-0.08, tint=0.01, contrast=-0.05, sat=0.82,
        st_sh=(0.00, 0.02, 0.05), st_hi=(0.05, 0.08, 0.11), st_strength=0.8, st_balance=0.5,
        fade=0.10, fade_col=(0.07, 0.08, 0.10), clip=-0.05,
    ),
}

PACKS = {
    "proiezione": "Classici di Hollywood",
    "notturno": "Classici di Hollywood",
    "canyon": "Classici di Hollywood",
    "acido": "Sci-Fi & Distopia",
    "criogenesi": "Sci-Fi & Distopia",
    "marte": "Sci-Fi & Distopia",
    "super8": "Vintage & Pellicola",
    "argento": "Vintage & Pellicola",
    "pastello90": "Vintage & Pellicola",
    "nebbia": "Horror & Thriller",
    "crimson": "Horror & Thriller",
    "nord": "Horror & Thriller",
}


def build_cube(preset):
    b, g, r = np.meshgrid(
        np.linspace(0, 1, N), np.linspace(0, 1, N), np.linspace(0, 1, N),
        indexing="ij")
    # griglia con blu varia piu' veloce all'interno; riscriviamo in ordine
    # .cube: per ogni b, per ogni g, per ogni r  -> rosso piu' veloce
    coords = np.stack([r, g, b], axis=-1).reshape(-1, 3)
    graded = grade(coords, preset)
    return coords, graded


def write_cube(name, preset):
    coords, graded = build_cube(preset)
    lines = [f'TITLE "{name} (Filmatura original LUT)"',
             "LUT_3D_SIZE 33",
             "DOMAIN_MIN 0.0 0.0 0.0",
             "DOMAIN_MAX 1.0 1.0 1.0", ""]
    # ordine .cube: r esterno piu' veloce => per b, per g, per r
    # coords e' costruito reshape(r,g,b) con indexing ij => indice = b*N*N + g*N + r
    # che corrisponde esattamente all'ordine richiesto (r varia piu' veloce).
    for row in graded:
        lines.append(f"{row[0]:.6f} {row[1]:.6f} {row[2]:.6f}")
    (OUT / f"lut_{name}.cube").write_text("\n".join(lines) + "\n")
    return coords, graded


def verify(name, coords, graded):
    """Verifica ordine e conteggi: la riga k deve avere r = k % N."""
    k = np.arange(coords.shape[0])
    assert coords.shape == (N ** 3, 3)
    assert np.allclose(coords[:, 0], (k % N) / (N - 1)), "ordine rosso errato"
    assert np.allclose(coords[:, 2], (k // (N * N)) / (N - 1)), "ordine blu errato"
    assert graded.min() >= 0 and graded.max() <= 1
    # identita' preservata agli estremi? nero resta scuro, bianco chiaro
    assert graded[0].max() < 0.4 or name in (), f"nero non scuro {name}: {graded[0]}"
    assert graded[-1].min() > 0.4, f"bianco non chiaro {name}: {graded[-1]}"


def preview_strip(presets):
    """Applica ogni preset a un'immagine di prova e salva una striscia PNG."""
    from PIL import Image
    w, h = 160, 120
    xs = np.linspace(0, 1, w)
    ys = np.linspace(0, 1, h)
    xx, yy = np.meshgrid(xs, ys)
    # immagine di prova: cieli caldi->freddi + soggetto con abiti colorati
    img = np.zeros((h, w, 3))
    img[..., 0] = 0.9 - 0.55 * xx          # rosso
    img[..., 1] = 0.35 + 0.25 * np.cos(xx * 6)  # verde
    img[..., 2] = 0.15 + 0.75 * xx          # blu
    # quadrato incandescente (pelle) + quadrato scuro (ombra)
    skin = (xx > 0.30) & (xx < 0.50) & (yy > 0.30) & (yy < 0.62)
    img[skin] = [0.82, 0.62, 0.50]
    shadow = (xx > 0.60) & (xx < 0.78) & (yy > 0.30) & (yy < 0.62)
    img[shadow] = [0.18, 0.20, 0.24]
    tiles = []
    for name in presets:
        graded = np.clip(grade(img, PRESETS[name]), 0, 1)
        tiles.append(Image.fromarray((graded * 255).astype(np.uint8)))
    strip = Image.new("RGB", (w * len(tiles), h))
    for i, t in enumerate(tiles):
        strip.paste(t, (i * w, 0))
    strip.save("/home/z/my-project/Filmatura/scripts/lut_preview.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, preset in PRESETS.items():
        coords, graded = write_cube(name, preset)
        verify(name, coords, graded)
        size = (OUT / f"lut_{name}.cube").stat().st_size
        print(f"OK lut_{name}.cube  ({size/1024:.0f} KB)  pack: {PACKS[name]}")
    preview_strip(PRESETS)
    print("Striscia di verifica: scripts/lut_preview.png")
