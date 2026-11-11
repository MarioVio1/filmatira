import Foundation

/// Modello dei preset di grading di Filmatura.
/// Le LUT sono file .cube generati dal nostro motore di grading
/// (scripts/gen_luts.py): nessun preset di terzi.
struct LUTPreset: Identifiable, Hashable {
    /// Identificatore: corrisponde al file `lut_<id>.cube` nel bundle.
    let id: String
    let name: String
    let packID: String
}

struct FilmPack: Identifiable, Hashable {
    let id: String
    let name: String
    let presets: [LUTPreset]
}

/// Catalogo statico dei pack cinematografici.
enum LUTCatalog {

    static let packs: [FilmPack] = [
        FilmPack(id: "classici", name: "Classici di Hollywood", presets: [
            LUTPreset(id: "proiezione", name: "Proiezione", packID: "classici"),
            LUTPreset(id: "notturno", name: "Notturno", packID: "classici"),
            LUTPreset(id: "canyon", name: "Canyon", packID: "classici"),
        ]),
        FilmPack(id: "scifi", name: "Sci-Fi & Distopia", presets: [
            LUTPreset(id: "acido", name: "Acido", packID: "scifi"),
            LUTPreset(id: "criogenesi", name: "Criogenesi", packID: "scifi"),
            LUTPreset(id: "marte", name: "Marte", packID: "scifi"),
        ]),
        FilmPack(id: "vintage", name: "Vintage & Pellicola", presets: [
            LUTPreset(id: "super8", name: "Super 8", packID: "vintage"),
            LUTPreset(id: "argento", name: "Argento", packID: "vintage"),
            LUTPreset(id: "pastello90", name: "Pastello '90", packID: "vintage"),
        ]),
        FilmPack(id: "horror", name: "Horror & Thriller", presets: [
            LUTPreset(id: "nebbia", name: "Nebbia", packID: "horror"),
            LUTPreset(id: "crimson", name: "Crimson", packID: "horror"),
            LUTPreset(id: "nord", name: "Nord", packID: "horror"),
        ]),
    ]

    static var allPresets: [LUTPreset] { packs.flatMap { $0.presets } }

    static func preset(withID id: String) -> LUTPreset? {
        allPresets.first { $0.id == id }
    }

    static func pack(forPresetID id: String) -> FilmPack? {
        guard let preset = preset(withID: id) else { return nil }
        return packs.first { $0.id == preset.packID }
    }
}
