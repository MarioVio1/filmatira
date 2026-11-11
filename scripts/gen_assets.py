#!/usr/bin/env python3
"""Icona app Filmatura + immagine campione per le miniature LUT.

Disegno vettoriale originale (zero asset di terzi): charcoale scuro,
fascia diagonale teal->arancio evocante il grading, glifo di fotogramma
cinematografico bianco.
"""
import numpy as np
from PIL import Image, ImageDraw
from pathlib import Path

RES = Path("/home/z/my-project/Filmatura/Filmatura/Resources")
ASSETS = RES / "Assets.xcassets"
SS = 4  # supersampling

W = 1024 * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


TEAL = (14, 116, 134)
ORANGE = (234, 129, 48)
DARK = (17, 19, 26)

img = Image.new("RGB", (W, W), DARK)
d = ImageDraw.Draw(img)

# sfondo con leggera vignettatura radiale
yy, xx = np.mgrid[0:W, 0:W]
cx = cy = W / 2
dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (W * 0.72)
vig = (1 - 0.22 * dist ** 1.6).clip(0, 1)
base = np.zeros((W, W, 3))
for c in range(3):
    base[..., c] = DARK[c] * vig
img = Image.fromarray(base.astype(np.uint8))
d = ImageDraw.Draw(img)

# fascia diagonale teal->arancio (angolo basso-sx verso alto-dx)
band = 210 * SS
for i in range(W):
    t = i / W
    col = lerp(TEAL, ORANGE, t)
    d.line([(i, W), (0, W - i)], fill=col, width=band // 2)  # semipiano basso
# clip della fascia: manteniamo solo una banda diagonale usando overlay scuro
overlay = Image.new("RGB", (W, W), DARK)
od = ImageDraw.Draw(overlay)
gap = 500 * SS  # larghezza banda visibile
od.polygon([(0, W), (gap * 2, W), (W, W - gap * 2), (W, W)], fill=None)
od.polygon([(0, W), (0, W - gap), (W - gap, 0), (W, 0), (W, gap * 0.2)], fill=DARK)
od.polygon([(0, W), (0, 0), (gap * 0.35, 0), (gap * 1.4, W)], fill=DARK)
od.polygon([(W * 0.45, W), (W, W * 0.45), (W, W)], fill=DARK)
img = Image.composite(img, overlay, Image.new("L", (W, W), 255))
# semplificazione: ridisegniamo la banda in modo controllato
img = Image.new("RGB", (W, W), DARK)
d = ImageDraw.Draw(img)
step = 6 * SS
for i in range(-W, 2 * W, step):
    t = np.clip((i + W / 2) / (2 * W), 0, 1)
    col = lerp(TEAL, ORANGE, t)
    x0, y0, x1, y1 = i, W, i + W, 0  # diagonale 45 gradi
    d.line([(x0, y0), (x1, y1)], fill=col, width=step)
# maschera: solo una banda diagonale centrale larga
mask = Image.new("L", (W, W), 0)
md = ImageDraw.Draw(mask)
band_w = 560 * SS
md.polygon([(0, W), (W, 0), (W + band_w, 0 + band_w), (band_w, W + band_w)], fill=255)
dark_layer = Image.new("RGB", (W, W), DARK)
img = Image.composite(img, dark_layer, mask)
# lieve scurimento verso i bordi
img_np = np.asarray(img).astype(np.float32)
img_np *= vig[..., None]
img = Image.fromarray(img_np.clip(0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)

# glifo: fotogramma cinematografico bianco con fori trasversali
frame_w, frame_h = 520 * SS, 400 * SS
fx, fy = (W - frame_w) // 2, (W - frame_h) // 2
white = (245, 245, 247)
hole = DARK
# bordo fotogramma
d.rounded_rectangle([fx, fy, fx + frame_w, fy + frame_h], radius=36 * SS, outline=white, width=26 * SS)
# fori pellicola colonna sinistra e destra
hw = 34 * SS
n_holes = 4
col_x = [fx + 62 * SS, fx + frame_w - 62 * SS]
for cxp in col_x:
    for k in range(n_holes):
        hy = fy + 70 * SS + k * (frame_h - 140 * SS) / (n_holes - 1)
        d.rounded_rectangle([cxp - hw // 2, hy - hw // 2, cxp + hw // 2, hy + hw // 2],
                            radius=10 * SS, fill=hole, outline=None)
# "obiettivo": cerchio centrale con pupilla
ccx, ccy, R = W // 2, W // 2, 118 * SS
d.ellipse([ccx - R, ccy - R, ccx + R, ccy + R], outline=white, width=26 * SS)
R2 = 58 * SS
d.ellipse([ccx - R2, ccy - R2, ccx + R2, ccy + R2], fill=white)

# export 1024
icon = img.resize((1024, 1024), Image.LANCZOS)
appiconset = ASSETS / "AppIcon.appiconset"
appiconset.mkdir(parents=True, exist_ok=True)
icon.save(appiconset / "icon1024.png")
print("AppIcon OK", appiconset / "icon1024.png")

# immagine campione per miniature LUT (paesaggio astratto ad alta dinamicita')
w, h = 480, 640
xs = np.linspace(0, 1, w)
ys = np.linspace(0, 1, h)
xx, yy = np.meshgrid(xs, ys)
smp = np.zeros((h, w, 3))
smp[..., 0] = 0.95 - 0.75 * yy + 0.15 * np.sin(xx * 9)
smp[..., 1] = 0.30 + 0.45 * np.cos((xx + yy) * 4)
smp[..., 2] = 0.20 + 0.70 * yy * (1 - yy) * 3.2
# sole + terreno scuro per alti contrasti
sun = ((xx - 0.68) ** 2 + ((yy - 0.28) / 1.3) ** 2) < 0.008
smp[sun] = [1.0, 0.93, 0.80]
ground = yy > 0.72
smp[ground] = [0.16, 0.13, 0.11] * (1 - 0.35 * np.random.rand(int(ground.sum()), 1))
sample = Image.fromarray((np.clip(smp, 0, 1) * 255).astype(np.uint8))
sample.save(RES / "sample.jpg", quality=92)
print("sample.jpg OK")
