# Recon map — Filmatura (iOS camera + film grading + face edit)

Clean-room replica of the *category* of apps exemplified by VSCO (camera with
film-style presets), FaceTune and FaceApp (selfie editing). We rebuild
**functionality and UX patterns only**: no code, assets, presets, logos,
names or copy from any of them. All LUTs in this app are generated from
scratch by our own grading engine; all face tools are our own Vision +
CoreImage implementation.

## Scope
- Platform: iOS 16+, iPhone portrait, SwiftUI.
- Core loop: scatti o registri con un look cinematografico → ritocchi →
  esporti in Foto / condividi.
- UI language: Italian.

## Screen inventory
| id | screen | states |
|----|--------|--------|
| S01 | Fotocamera (preview Metal + carousel pack + intensità + scatto/registrazione) | permesso negato, torcia, flip, griglia, REC, flash |
| S02 | Studio (griglia media: foto + video, import da Foto, condividi, elimina) | vuota, loading |
| S03 | Editor foto (pack, intensità, grain, vignetta, confronta, salva) | elaborazione |
| S04 | Volto (analisi Vision, strumenti + slider, target volto, look epoca, confronta, esporta) | nessun volto, elaborazione |
| S05 | Player video (AVKit) | — |

## Core flows
1. Fotocamera → scegli pack → slider intensità → scatto (foto) o REC (video
   con grading live) → salvataggio in Studio/Foto.
2. Studio → foto → Editor → regolazioni → salva in Foto / condividi.
3. Studio → ritratto → Volto → strumenti → esporta.

## Feature matrix (see features.csv)
Camera: preview LUT live 30fps, foto full-res con LUT, video H.264 con LUT
live + audio, torcia, flash, flip, zoom, tap-to-focus, griglia, intensità.
Editor: 12 LUT in 4 pack, intensità, grain, vignetta, confronto, export.
Volto: rilevamento landmark, pelle liscia, occhi, denti, pomelli, mandibola,
labbra, luce ritratto, sfondo sfocato, look epoca '70/'90, multi-volto.

## Data model (on-device)
- `MediaItem`: id, tipo (foto/video), path, data, preset applicato.
- `LUTPreset`: id, nome, pack, LUT 33³.
- Persistenza: file system (Documents/Media) + UserDefaults preferenze.
- Privacy: nessuna rete, nessun tracciamento; Vision gira on-device.
