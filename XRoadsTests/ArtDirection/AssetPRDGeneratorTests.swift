//
//  AssetPRDGeneratorTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-025: Unit tests for Asset PRD generation
//

import XCTest
@testable import XRoadsLib

final class AssetPRDGeneratorTests: XCTestCase {

    func test_prdFromArtBibleContainsComponents() throws {
        let artBible = try loadSampleArtBible()
        let generator = AssetPRDGenerator()
        let document = try generator.generateDocument(from: artBible)

        XCTAssertEqual(document.userStories.count, 2)

        let titles = document.userStories.map(\.title)
        XCTAssertTrue(titles.contains(where: { $0.contains("PrimaryButton") }))
        XCTAssertTrue(titles.contains(where: { $0.contains("Card") }))
    }

    func test_eachStoryHasUnitTest() throws {
        let artBible = try loadSampleArtBible()
        let generator = AssetPRDGenerator()
        let document = try generator.generateDocument(from: artBible)

        for story in document.userStories {
            XCTAssertNotNil(story.unitTest, "Expected unit test spec for \(story.id)")
            XCTAssertFalse(story.unitTest?.file.isEmpty ?? true)
        }
    }

    func test_exportProducesValidJSON() throws {
        let artBible = try loadSampleArtBible()
        let generator = AssetPRDGenerator()
        let document = try generator.generateDocument(from: artBible)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("prd-assets.json")
        try generator.export(document: document, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        guard let dict = jsonObject as? [String: Any] else {
            XCTFail("Exported PRD should be a JSON object")
            return
        }

        XCTAssertEqual(dict["feature_name"] as? String, document.featureName)
        XCTAssertNotNil(dict["user_stories"] as? [Any])
    }

    private func loadSampleArtBible() throws -> ArtBible {
        let json = """
        {
          "project": "XRoads",
          "version": "1.0.0",
          "design_tokens": {
            "colors": {
              "background": { "primary": "#0d1117" }
            }
          },
          "components": [
            { "name": "PrimaryButton", "description": "Main CTA", "tokens": ["accent.primary", "radius.md"] },
            { "name": "Card", "description": "Container", "tokens": ["background.secondary", "radius.lg"] }
          ]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArtBible.self, from: data)
    }
}
