import XCTest
@testable import Filmatura

/// Test del parser CUBE: ordine dei canali, conversione RGBA, errori.
final class LUTParserTests: XCTestCase {

    private let sample = """
    TITLE "Test LUT"
    LUT_3D_SIZE 2
    DOMAIN_MIN 0.0 0.0 0.0
    DOMAIN_MAX 1.0 1.0 1.0
    0 0 0
    1 0 0
    0 1 0
    1 1 0
    0 0 1
    1 0 1
    0 1 1
    1 1 1
    """

    func testParsesDimensionsAndOrder() throws {
        let parsed = try CUBEParser.parse(text: sample)
        XCTAssertEqual(parsed.dimension, 2)
        XCTAssertEqual(parsed.rgbaData.count, 8 * 4 * MemoryLayout<Float>.size)

        let floats = parsed.rgbaData.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        // prima voce: nero, alpha 1
        XCTAssertEqual(floats[0], 0)
        XCTAssertEqual(floats[1], 0)
        XCTAssertEqual(floats[2], 0)
        XCTAssertEqual(floats[3], 1)
        // seconda voce: rosso pieno (ordine .cube: rosso piu' veloce)
        XCTAssertEqual(floats[4], 1)
        XCTAssertEqual(floats[5], 0)
        XCTAssertEqual(floats[6], 0)
        XCTAssertEqual(floats[7], 1)
        // terza voce: verde pieno
        XCTAssertEqual(floats[8], 0)
        XCTAssertEqual(floats[9], 1)
        XCTAssertEqual(floats[10], 0)
    }

    func testRejectsIncompleteCube() {
        let broken = "LUT_3D_SIZE 2\n0 0 0\n1 1 1\n"
        XCTAssertThrowsError(try CUBEParser.parse(text: broken)) { error in
            XCTAssertTrue(error is CUBEParser.CUBEError)
        }
    }

    func testRejectsNonCubeFormat() {
        let oneD = "LUT_1D_SIZE 256\n0 0 0\n1 1 1\n"
        XCTAssertThrowsError(try CUBEParser.parse(text: oneD))
    }

    func testCatalogIntegrity() {
        XCTAssertEqual(LUTCatalog.packs.count, 5)
        XCTAssertEqual(LUTCatalog.allPresets.count, 18)
        // id unici
        let ids = LUTCatalog.allPresets.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPackLookup() {
        XCTAssertEqual(LUTCatalog.preset(withID: "proiezione")?.packID, "classici")
        XCTAssertEqual(LUTCatalog.pack(forPresetID: "marte")?.name, "Sci-Fi & Distopia")
        XCTAssertEqual(LUTCatalog.pack(forPresetID: "crimson")?.name, "Horror & Thriller")
        XCTAssertEqual(LUTCatalog.pack(forPresetID: "aurora")?.name, "Nuove Tendenze")
        XCTAssertNil(LUTCatalog.preset(withID: "inesistente"))
    }
}
