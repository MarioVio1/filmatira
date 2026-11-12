#!/usr/bin/env python3
"""QA del progetto Filmatura: sintassi Swift di base, struttura, asset."""
import re
import sys
from pathlib import Path

ROOT = Path("/home/z/my-project")
errors = []

REQUIRED_SWIFT = [
    "Filmatura/App/FilmaturaApp.swift",
    "Filmatura/Support/Theme.swift",
    "Filmatura/Support/CIImage+Filmatura.swift",
    "Filmatura/LUT/LUTPreset.swift",
    "Filmatura/LUT/CUBEParser.swift",
    "Filmatura/LUT/LUTStore.swift",
    "Filmatura/Camera/CameraController.swift",
    "Filmatura/Camera/PreviewRenderer.swift",
    "Filmatura/Camera/VideoRecorder.swift",
    "Filmatura/Camera/CameraScreen.swift",
    "Filmatura/Editor/PhotoEditorScreen.swift",
    "Filmatura/Face/FaceAnalyzer.swift",
    "Filmatura/Face/FaceRenderer.swift",
    "Filmatura/Face/FaceEditScreen.swift",
    "Filmatura/Studio/MediaStore.swift",
    "Filmatura/Studio/StudioScreen.swift",
    "Tests/LUTParserTests.swift",
]

REQUIRED_RES = [
    "Filmatura/Resources/Assets.xcassets/AppIcon.appiconset/icon1024.png",
    "Filmatura/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "Filmatura/Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
    "Filmatura/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json",
    "Filmatura/Resources/sample.jpg",
    "project.yml",
    ".github/workflows/build-ipa.yml",
    "README.md",
]

LUTS = ["proiezione", "notturno", "canyon", "acido", "criogenesi", "marte",
        "super8", "argento", "pastello90", "nebbia", "crimson", "nord"]

# 1. file richiesti
for rel in REQUIRED_SWIFT + REQUIRED_RES:
    if not (ROOT / rel).exists():
        errors.append(f"MANCANTE: {rel}")
for name in LUTS:
    p = ROOT / f"Filmatura/Resources/LUTs/lut_{name}.cube"
    if not p.exists() or p.stat().st_size < 10000:
        errors.append(f"LUT MANCANTE o vuota: {p.name}")

# 2. sintassi Swift di base: bilanciamento parentesi/graffe/stringhe
def strip_code(line):
    """Rimuove stringhe e commenti di riga per contare le parentesi."""
    out = []
    i, n = 0, len(line)
    in_str = False
    while i < n:
        c = line[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "/" and i + 1 < n and line[i + 1] == "/":
                break
            elif c == "/" and i + 1 < n and line[i + 1] == "*":
                # commento blocco su una riga
                j = line.find("*/", i + 2)
                if j == -1:
                    return "".join(out), True  # continua su altre righe
                i = j + 2
                continue
            else:
                out.append(c)
        i += 1
    return "".join(out), in_str

for rel in REQUIRED_SWIFT:
    path = ROOT / rel
    text = path.read_text()
    braces = parens = brackets = 0
    in_block = False
    in_multiline_str = False
    for raw in text.splitlines():
        if in_block:
            end = raw.find("*/")
            if end == -1:
                continue
            raw = raw[end + 2:]
            in_block = False
        if in_multiline_str:
            if raw.count('"""') % 2 == 1:
                in_multiline_str = False
            continue
        if raw.count('"""') % 2 == 1:
            in_multiline_str = True
            continue
        code, in_str_open = strip_code(raw)
        if in_str_open:
            errors.append(f"{rel}: stringa non chiusa su riga: {raw[:60]}")
        braces += code.count("{") - code.count("}")
        parens += code.count("(") - code.count(")")
        brackets += code.count("[") - code.count("]")
    if in_multiline_str:
        errors.append(f"{rel}: stringa multiline non chiusa")
    if braces != 0:
        errors.append(f"{rel}: graffe sbilanciate ({braces})")
    if parens != 0:
        errors.append(f"{rel}: parentesi tonde sbilanciate ({parens})")
    if brackets != 0:
        errors.append(f"{rel}: parentesi quadre sbilanciate ({brackets})")

# 3. placeholder e simboli vietati
PATTERNS = ["TODO", "XXX", "undefined", "NaN", "【", "___PLACEHOLDER___"]
for path in ROOT.rglob("*.swift"):
    text = path.read_text()
    for pat in PATTERNS:
        if pat in text:
            errors.append(f"{path.relative_to(ROOT)}: contiene '{pat}'")

# 4. riferimenti incrociati essenziali
app = (ROOT / "Filmatura/App/FilmaturaApp.swift").read_text()
checks = [
    (app, "AppState.Tab.camera"),
    (app, "FilmaturaApp"),
]
ctrl = (ROOT / "Filmatura/Camera/CameraController.swift").read_text()
cam = (ROOT / "Filmatura/Camera/CameraScreen.swift").read_text()
lut = (ROOT / "Filmatura/LUT/LUTStore.swift").read_text()
face = (ROOT / "Filmatura/Face/FaceRenderer.swift").read_text()
analyzer = (ROOT / "Filmatura/Face/FaceAnalyzer.swift").read_text()
face_ui = (ROOT / "Filmatura/Face/FaceEditScreen.swift").read_text()
theme = (ROOT / "Filmatura/Support/Theme.swift").read_text()
for source, token, label in [
    (cam, "appState.openStudio", "CameraScreen->AppState"),
    (cam, "ShutterButton", "CameraScreen->ShutterButton"),
    (ctrl, "AVCaptureVideoDataOutputSampleBufferDelegate", "controller delegate"),
    (ctrl, "syncGradingState", "controller grading sync"),
    (cam, "syncGradingState", "screen chiama sync"),
    (lut, "applyingCube", "store applica il cubo"),
    (face, "CIPinchDistortion", "pinch warp"),
    (face, "blendWithMask", "maschere blend"),
    (face, "CIWarpKernel", "kernel warp sorriso"),
    (face, "CIDifferenceBlendMode", "maschera macchie via differenza"),
    (face, "CIAdditionCompositing", "ricomposizione dettagli"),
    (face, "CIColorClamp", "tetti morbidi e soglie maschera"),
    (face, "CIMedianFilter", "anti-imperfezioni"),
    (face, "applySkinTone", "tono pelle uniforme"),
    (face, "applySkinBrighten", "illumina viso"),
    (face, "skinBrighten", "controllo Illumina"),
    (face, "skinTone", "controllo Tono uniforme"),
    (face, "premultipliedHalved", "aritmetica premoltiplicata sicura"),
    (face, "skinMask", "maschera pelle"),
    (face, "applyWarp", "pipeline warp"),
    (face, "radius0", "gradiente radiale legale"),
    (face, "EyeColorShade", "colore occhi"),
    (face, "CIMultiplyBlendMode", "blend trucco moltiplicato"),
    (analyzer, "VNGeneratePersonSegmentationRequest", "segmentazione persona"),
    (analyzer, "personMask", "maschera persona in FaceData"),
    (analyzer, "noseTip", "punta del naso"),
    (analyzer, "contourEdge", "punti contorno derivati"),
    (analyzer, "mouthCornerLeft", "angoli bocca"),
    (face_ui, "FaceCategory", "categorie strumenti"),
    (face_ui, "eyeColorSection", "selettore colore occhi"),
    (face_ui, "presetGrid", "preset sempre visibili"),
    (face_ui, '"Leviga"', "strumento Leviga"),
    (face_ui, '"Macchie"', "strumento Macchie"),
    (face_ui, '"Illumina"', "strumento Illumina"),
    (face_ui, '"Tono uniforme"', "strumento Tono uniforme"),
    (face_ui, "toolGlass", "bottoni strumenti Liquid Glass"),
    (face_ui, "liquidPanel", "pannello Liquid Glass"),
    (theme, "liquidPanel", "Theme: pannello liquid"),
    (theme, "toolGlass", "Theme: bottone strumento"),
]:
    if token not in source:
        errors.append(f"riferimento mancante: {label} ('{token}')")

# 4b. chiavi KVC vietate (crash runtime su CIFilter)
for rel in ["Filmatura/Face/FaceRenderer.swift",
            "Filmatura/Face/FaceAnalyzer.swift",
            "Filmatura/Support/CIImage+Filmatura.swift"]:
    src = (ROOT / rel).read_text()
    if 'inputIntensity' in src:
        errors.append(f"{rel}: chiave KVC vietata 'inputIntensity'")
    if re.search(r'setValue\([^)]*forKey:\s*"inputRadius"\)', src):
        errors.append(f"{rel}: CIRadialGradient non ha 'inputRadius' (usa radius0/1)")

# 5. i preset del catalogo devono corrispondere ai file .cube
catalog = (ROOT / "Filmatura/LUT/LUTPreset.swift").read_text()
for name in LUTS:
    if f'id: "{name}"' not in catalog:
        errors.append(f"catalogo: preset '{name}' non trovato in LUTPreset.swift")

# 6. workflow e project.yml
wf = (ROOT / ".github/workflows/build-ipa.yml").read_text()
for token in ["xcodegen generate", "upload-artifact", "generic/platform=iOS",
              "Filmatura-unsigned.ipa"]:
    if token not in wf:
        errors.append(f"workflow: manca '{token}'")
py = (ROOT / "project.yml").read_text()
for token in ["it.filmatura.app", "NSCameraUsageDescription", "UILaunchScreen",
              "FilmaturaTests", "16.4", "1.3.0"]:
    if token not in py:
        errors.append(f"project.yml: manca '{token}'")

if errors:
    print("QA FALLITO:")
    for e in errors:
        print(" -", e)
    sys.exit(1)

total_swift = sum(len((ROOT / r).read_text().splitlines()) for r in REQUIRED_SWIFT)
print(f"QA OK — {len(REQUIRED_SWIFT)} file Swift ({total_swift} righe), "
      f"12 LUT, assets, workflow, project.yml: tutto presente e coerente.")
