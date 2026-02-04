//
//  ArtDirectorSkillTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-024: Unit tests for Art Director skill integration
//

import XCTest
@testable import XRoadsLib

final class ArtDirectorSkillTests: XCTestCase {

    func test_artDirectorSkillFileExists() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let skillURL = home.appendingPathComponent(".xroads/skills/core/art-director.skill.yaml")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: skillURL.path),
            "Expected art-director.skill.yaml to exist at ~/.xroads/skills/core"
        )

        let contents = try String(contentsOf: skillURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("id: art-director"), "Skill file should declare the art-director id")
        XCTAssertTrue(contents.contains("templates:"), "Skill file should include templates")
    }

    func test_artBibleJSONValid() throws {
        let json = """
        {
          "project": "XRoads",
          "version": "1.0.0",
          "generated_at": "2026-02-04T10:00:00Z",
          "design_tokens": {
            "colors": {
              "background": { "primary": "#0d1117", "secondary": "#161b22" },
              "accent": { "primary": "#388bfd", "secondary": "#3fb950" }
            },
            "typography": {
              "fontFamily": { "ui": "SF Pro", "mono": "SF Mono" },
              "sizes": { "xs": 10, "sm": 12, "md": 14, "lg": 16, "xl": 20 }
            },
            "spacing": { "xs": 4, "sm": 8, "md": 16, "lg": 24, "xl": 32 },
            "radius": { "sm": 4, "md": 8, "lg": 12 }
          },
          "components": [
            { "name": "PrimaryButton", "tokens": ["accent.primary", "radius.md"] }
          ],
          "reference_urls": ["https://example.com/reference"],
          "input_images": ["file:///tmp/reference.png"]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let artBible = try decoder.decode(ArtBible.self, from: data)
        XCTAssertEqual(artBible.project, "XRoads")
        XCTAssertEqual(artBible.version, "1.0.0")
        XCTAssertEqual(artBible.referenceURLs?.count, 1)
        XCTAssertEqual(artBible.imageReferences?.count, 1)
        XCTAssertEqual(artBible.allComponents.count, 1)
    }

    func test_designTokensExtractable() throws {
        let json = """
        {
          "project": "XRoads",
          "version": "1.0.0",
          "design_tokens": {
            "colors": {
              "background": { "primary": "#0d1117" }
            },
            "spacing": { "md": 16 }
          }
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let artBible = try decoder.decode(ArtBible.self, from: data)

        XCTAssertEqual(artBible.designTokens?.colors?["background"]?["primary"], "#0d1117")
        XCTAssertEqual(artBible.designTokens?.spacing?["md"], 16)
    }
}
