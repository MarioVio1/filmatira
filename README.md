# Filmatura

Fotocamera iOS con look cinematografici (LUT 3D originali), editor foto e
ritratti con strumenti volto completi — tutto **on-device**, in stile
professionale con le app di reference della categoria (camera con preset tipo
VSCO, retouch tipo FaceTune/FaceApp), costruito *clean-room*: codice, LUT e
grafica completamente originali, nessun asset o brand di terzi.

## Funzionalità

- **Fotocamera** — preview con grading live a 30 fps (Metal + Core Image),
  scatto foto a piena risoluzione con LUT applicato, **registrazione video
  H.264 con il grading in tempo reale** + audio, torcia, flash, flip, zoom,
  griglia dei terzi, slider intensità filtro.
- **18 LUT in 5 pack** (file `.cube` 33×33×33 generati dal nostro motore di
  grading):
  - *Classici di Hollywood*: Proiezione (teal & orange), Notturno (noir),
    Canyon (western ambrato)
  - *Sci-Fi & Distopia*: Acido (cyberpunk), Criogenesi (blu ghiaccio), Marte
    (rosso-arancio)
  - *Vintage & Pellicola*: Super 8, Argento (bleach bypass), Pastello '90
  - *Horror & Thriller*: Nebbia, Crimson, Nord
  - *Nuove Tendenze*: Aurora (teal & orange morbido), Citrino (oro caldo),
    Laguna (turchese fresco), Porpora (magenta notturno), Grafite (dark
    moody), Sunset (arancio rosa)
- **Editor foto** — pack, intensità, **regolazioni professionali**
  (esposizione, contrasto, saturazione, temperatura, tinta e nitidezza con
  slider bipolari -100…100), **bloom** (halation), grain pellicola,
  vignetta, confronto prima/dopo, salvataggio in app e in Fotolibra.
- **Volto (ritratti)** — ritocco pelle in stile AirBrush, tutto su
  landmark Vision: **rimozione a tocco** (tocca brufoli e macchie e spariscono,
  con annulla/azzera), **levigatura a separazione di frequenze** che leviga
  la pelle conservando pori e texture, **anti-macchie**, **tono uniforme**,
  abbronzatura, glow viso, occhiaie attenuate, occhi più luminosi e più
  grandi (warp locale), denti più bianchi, sorriso, scolpimento viso
  (viso snello, guance, pomelli, mandibola, mento, naso), luce ritratto,
  sfondo sfocato o bianco e nero, **trucco** (cipria, contouring, blush,
  ombretto, eyeliner e rossetto con 18 sfumature) con **8 look istantanei**
  (Nessuno, Nude, Pesca, Corallo, Smoky, Malva, Rosso Glam, Bronze — ricette
  complete a un tocco, modificabili poi con gli slider), **capelli**:
  **colore** con 11 tonalità (dal Nero al Blu, con fusione dedicata per
  toni scuri, chiari e fantasy via segmentazione persona + attaccatura
  stimata dal contorno) e **volume della chioma** (warp gaussiano sulla
  corona e ai lati della testa), **quattro preset
  istantanei** — «Fai bello» (ritocco completo pelle-first), «Naturale»
  (solo lucido), «Glam» (ritocco forte, occhi grandi, trucco serata) e
  «Dolce» (pelle morbida e colori caldi) — look epoca *Anni '70 / Anni '90*,
  **multi-volto** (tutti i volti o selezione singola), confronto premendo
  l'anteprima, export.
- **Corpo (reshape)** — deformazione anatomica guidata dalle articolazioni
  rilevate con Vision (VNDetectHumanBodyPoseRequest): **vita snella**,
  **corpo snello**, **gambe più lunghe** (il torso si comprime e le gambe
  si allungano dello stesso delta, testa e piedi fermi), **braccia snelle**
  lungo i segmenti reali spalla-gomito-polso e **spalle larghe**. Warp a
  kernel gaussiano scritto su misura: nessun bordo circolare nemmeno a
  intensità alte.
- **Studio** — galleria dei media dell'app, import da Fotolibra, player
  video, condivisione ed eliminazione.
- **Grafica «Liquid Glass»** — palette chiara in stile Apple: superfici
  translucide (materiali SwiftUI), bordi luminosi, angoli generosi, ombre
  soffuse; la fotocamera resta su cromie scure per la preview.

## Privacy

Nessuna connessione a rete, nessun SDK di terze parti, nessun tracciamento.
Vision e Core Image lavorano solo in locale; i media restano nella cartella
dell'app. Permessi usati: fotocamera, microfono (solo per l'audio dei video),
aggiunta in Fotolibra (solo su tua azione).

## Come ottenere l'IPA

La build iOS richiede toolchain Apple: il progetto include un workflow
**GitHub Actions** che compila su un runner macOS e produce un IPA *non
firmato* che poi firmi tu (gratuito) e installi.

### 1. Pubblica il progetto su GitHub

```bash
cd Filmatura
git init
git add .
git commit -m "Filmatura 1.0"
git branch -M main
# crea un repository vuoto su github.com, poi:
git remote add origin https://github.com/<TUO-UTENTE>/filmatura.git
git push -u origin main
```

### 2. Scarica l'IPA

- Apri il repository → scheda **Actions** → workflow *Build IPA Filmatura*.
- Alla fine del run (5–10 minuti), in **Artifacts** trovi `Filmatura-ipa`
  con dentro `Filmatura-unsigned.ipa`.
- Puoi rilanciare la build in qualsiasi momento con *Run workflow*.

### 3. Firma e installa (scegli una via)

| metodo | richiede | durata firma | note |
| --- | --- | --- | --- |
| **Sideloadly** (Windows/Mac) | Apple ID gratuito | 7 giorni, ri-firmi a scadenza | la via più semplice: colleghi l'iPhone, trascini l'IPA, inserisci l'Apple ID |
| **AltStore / SideStore** | Apple ID gratuito | 7 giorni | si ri-firma da solo sul Wi-Fi |
| **Xcode sul Mac** | Apple ID gratuito | 7 giorni | apri `Filmatura.xcodeproj` generato con `xcodegen generate`, target iPhone, Run |
| **Apple Developer Program** (99 $/anno) | account sviluppatore | 1 anno | firma ad hoc o TestFlight |

> **Perché non firmino io l'IPA?** Ogni IPA iOS deve essere firmato con un
> certificato Apple legato a un Apple ID: è un requisito di sistema, nessuna
> build senza firma si installa su iPhone. Con Sideloadly/AltStore usi il tuo
> Apple ID gratuito, senza pagare.

### Build locale su Mac (alternativa)

```bash
brew install xcodegen
cd Filmatura
xcodegen generate      # genera Filmatura.xcodeproj
open Filmatura.xcodeproj
# seleziona il target iPhone e Run; per l'IPA: Product → Archive → Export
```

## Struttura del progetto

```
Filmatura/
├── project.yml                    # definizione XcodeGen del progetto
├── .github/workflows/build-ipa.yml
├── Filmatura/
│   ├── App/                       # entry point, tab, stato condiviso
│   ├── Camera/                    # sessione AVFoundation, preview Metal,
│   │                              # recorder H.264 con LUT live, UI camera
│   ├── Editor/                    # editor foto (LUT, grain, vignetta)
│   ├── Face/                      # Vision landmark + CoreImage retouch
│   ├── Studio/                    # galleria media, player, import
│   ├── LUT/                       # parser .cube, catalogo pack, store
│   ├── Support/                   # tema, estensioni Core Image
│   └── Resources/
│       ├── Assets.xcassets        # icona, accent color, launch
│       └── LUTs/*.cube            # 18 LUT originali 33³
├── Tests/                         # test unitari parser e catalogo
├── scripts/                       # generatori LUT/icona (Python)
└── replica/                       # mappa funzionale e feature matrix
```

## Rigenerare le LUT (opzionale)

Le LUT sono ricette di grading nostre (curve lift/gamma/gain per canale,
temperatura, split-toning, fade). Per modificarle o aggiungerne:

```bash
pip install numpy pillow
python3 scripts/gen_luts.py     # riscrive i .cube in Filmatura/Resources/LUTs
python3 scripts/gen_assets.py   # rigenera icona e immagine campione
```

Poi aggiorna il catalogo in `Filmatura/LUT/LUTPreset.swift`.

## Note tecniche

- **Ordine LUT / CIColorCube**: i file `.cube` (specifica: rosso varia più
  veloce) e `CIColorCube` condividono questo ordine, con alpha aggiunta dal
  parser. In caso estremo di colori «invertiti» su un dispositivo futuro,
  rigenera i cubi invertendo gli indici in `scripts/gen_luts.py`
  (funzione `build_cube`).
- **Video**: i buffer di cattura vengono elaborati dal grading e scritti con
  `AVAssetWriter` (H.264 1080×1920 ~9 Mbps + AAC). Se il microfono non è
  autorizzato, il video parte senza audio.
- **Volto**: le maschere (pelle, occhiaie, denti, labbra) sono poligoni
  disegnati dai landmark e sfumati; pomelli/mandibola/viso snello usano
  `CIPinchDistortion`, gli occhi più grandi `CIBumpDistortion`; il warp è
  applicato a valle dei correttori colore.
- **UI «Liquid Glass»**: su iOS 16.4 le superfici in vetro sono ottenute con
  i materiali SwiftUI (`.ultraThinMaterial`) più bordi luminosi e ombre —
  nessuna API privata, compatibile con le release future di iOS.
- **iOS**: target 16.4+, solo iPhone verticale.

## Licenza d'uso del progetto

Tutto il contenuto di questo repository (codice Swift, script Python, LUT,
grafica) è scritto da zero per questo progetto. I nomi «VSCO», «FaceApp»,
«FaceTune» citati nelle note sono marchi dei rispettivi proprietari e servono
solo a descrivere la categoria: non vanno usati in listini, store o
comunicazione del tuo prodotto.

---

# ⚠️ Nota importante — replica del skill e uso responsabile

Il progetto è costruito secondo il metodo *clean-room* del pack
`replica-skill` (installato in `skills/replica-skill/`): si replicano
**funzionalità e flussi**, mai codice, asset, nomi o contenuti altrui. Se
deciderai di distribuire l'app, metti il tuo brand, il tuo design e le tue
LUT — già tutto originale qui — e rispetta i termini di Apple e degli store.
