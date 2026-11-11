import Foundation

/// Parser per file .cube (specifica Iridas/Resolve, LUT 3D).
/// Il file elenca N^3 triplette RGB con l'indice rosso che varia piu' veloce,
/// poi verde, poi blu. Valori in [0,1].
enum CUBEParser {

    enum CUBEError: LocalizedError {
        case invalidFormat
        case sizeMismatch(expected: Int, found: Int)
        case unsupportedDomain

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "File .cube non valido."
            case .sizeMismatch(let expected, let found):
                return "LUT_3D_SIZE \(expected) ma trovate \(found) voci."
            case .unsupportedDomain:
                return "Dominio della LUT non supportato (attesi 0-1)."
            }
        }
    }

    struct ParsedLUT {
        let dimension: Int
        /// Valori RGBA Float32 interlacciati, pronti per CIColorCube.
        let rgbaData: Data
    }

    static func parse(contentsOf url: URL) throws -> ParsedLUT {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(text: text)
    }

    static func parse(text: String) throws -> ParsedLUT {
        var dimension = 0
        var values: [Float] = []
        values.reserveCapacity(33 * 33 * 33 * 3)

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("TITLE") || line.hasPrefix("title") { continue }

            if line.hasPrefix("LUT_3D_SIZE") || line.hasPrefix("lut_3d_size") {
                let token = line.split(separator: " ").last ?? "0"
                guard let size = Int(token), size >= 2 else { throw CUBEError.invalidFormat }
                dimension = size
                continue
            }
            if line.hasPrefix("DOMAIN") || line.hasPrefix("domain") {
                // accettiamo solo dominio 0..1
                let nums = line.split(separator: " ").dropFirst().compactMap { Float($0) }
                if nums.count == 6, !(nums.prefix(3).allSatisfy { $0 == 0 } &&
                                      nums.suffix(3).allSatisfy { $0 == 1 }) {
                    throw CUBEError.unsupportedDomain
                }
                continue
            }
            if line.hasPrefix("LUT_1D_SIZE") {
                throw CUBEError.invalidFormat
            }
            // riga di dati: tre o quattro float
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count == 3 || parts.count == 4 {
                let rgb = parts.prefix(3).compactMap { Float($0) }
                guard rgb.count == 3 else { continue }
                values.append(contentsOf: rgb)
            }
        }

        guard dimension >= 2 else { throw CUBEError.invalidFormat }
        guard values.count == dimension * dimension * dimension * 3 else {
            throw CUBEError.sizeMismatch(expected: dimension * dimension * dimension,
                                         found: values.count / 3)
        }

        // converte RGB -> RGBA interlacciato (alpha 1.0), Float32 little-endian
        var rgba = [Float]()
        rgba.reserveCapacity(values.count / 3 * 4)
        for i in stride(from: 0, to: values.count, by: 3) {
            rgba.append(values[i])
            rgba.append(values[i + 1])
            rgba.append(values[i + 2])
            rgba.append(1.0)
        }
        let data = rgba.withUnsafeBufferPointer { Data(buffer: $0) }
        return ParsedLUT(dimension: dimension, rgbaData: data)
    }
}
