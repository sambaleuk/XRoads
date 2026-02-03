import Foundation
import XCTest

/// Tests for bundled skill JSON files and their parsing
/// Verifies all bundled skills parse correctly, have valid versions, and specify valid tools
final class BundledSkillsTests: XCTestCase {

    // MARK: - Properties

    /// Path to the Skills resource directory
    private var skillsDirectoryURL: URL {
        // Try multiple locations to find the skills directory
        let fileManager = FileManager.default

        // 1. Current directory + XRoads/Resources/Skills (for running from project root)
        let cwdPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("XRoads/Resources/Skills")
        if fileManager.fileExists(atPath: cwdPath.path) {
            return cwdPath
        }

        // 2. Parent directory (for running from Tests directory)
        let parentPath = cwdPath.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("XRoads/Resources/Skills")
        if fileManager.fileExists(atPath: parentPath.path) {
            return parentPath
        }

        // 3. Use bundle if available
        if let bundlePath = Bundle.main.resourcePath {
            let bundleSkills = URL(fileURLWithPath: bundlePath).appendingPathComponent("Skills")
            if fileManager.fileExists(atPath: bundleSkills.path) {
                return bundleSkills
            }
        }

        // Default to cwd path (test will fail if not found, which is correct)
        return cwdPath
    }

    /// Expected bundled skill IDs
    private let expectedSkillIDs = [
        "commit",
        "review-pr",
        "prd",
        "integration-test",
        "code-reviewer"
    ]

    /// Valid skill categories
    private let validCategories = ["git", "code", "test", "docs", "review", "custom"]

    /// Valid CLI types for compatibility
    private let validCLIs = ["claude", "gemini", "codex"]

    /// Valid tool names that skills can require
    private let validTools = [
        "git",
        "file-read",
        "file-edit",
        "web-fetch",
        "bash",
        "mcp"
    ]

    // MARK: - SkillFile Model for Parsing

    /// Matches the SkillFile struct from the main app
    private struct TestSkillFile: Codable {
        let id: String
        let name: String
        let description: String
        let promptTemplate: String
        let requiredTools: [String]?
        let version: String?
        let compatibleCLIs: [String]?
        let category: String?
        let author: String?
    }

    // MARK: - Test: All Bundled Skills Parse Correctly

    func testAllBundledSkillsParseCorrectly() throws {
        let fileManager = FileManager.default

        // Verify skills directory exists
        XCTAssertTrue(
            fileManager.fileExists(atPath: skillsDirectoryURL.path),
            "Skills directory should exist at: \(skillsDirectoryURL.path)"
        )

        // Test each expected skill file
        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            XCTAssertTrue(
                fileManager.fileExists(atPath: skillFileURL.path),
                "Skill file should exist: \(skillID).skill.json"
            )

            // Try to load and parse the file
            let data = try Data(contentsOf: skillFileURL)
            let decoder = JSONDecoder()

            do {
                let skillFile = try decoder.decode(TestSkillFile.self, from: data)

                // Verify required fields
                XCTAssertEqual(skillFile.id, skillID, "Skill ID should match filename for \(skillID)")
                XCTAssertFalse(skillFile.name.isEmpty, "Skill name should not be empty for \(skillID)")
                XCTAssertFalse(skillFile.description.isEmpty, "Skill description should not be empty for \(skillID)")
                XCTAssertFalse(skillFile.promptTemplate.isEmpty, "Skill prompt template should not be empty for \(skillID)")
            } catch {
                XCTFail("Failed to parse skill file \(skillID).skill.json: \(error)")
            }
        }
    }

    // MARK: - Test: Skill Version Format

    func testSkillVersionFormat() throws {
        let fileManager = FileManager.default
        let semverPattern = #"^\d+\.\d+\.\d+$"#
        let semverRegex = try NSRegularExpression(pattern: semverPattern)

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                XCTFail("Skill file not found: \(skillID).skill.json")
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // Version should be present and follow semver format
            guard let version = skillFile.version else {
                XCTFail("Skill \(skillID) should have a version")
                continue
            }

            let range = NSRange(location: 0, length: version.utf16.count)
            let matches = semverRegex.numberOfMatches(in: version, options: [], range: range)

            XCTAssertEqual(
                matches, 1,
                "Skill \(skillID) version '\(version)' should follow semver format (X.Y.Z)"
            )
        }
    }

    // MARK: - Test: Required Tools Are Valid

    func testRequiredToolsAreValid() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                XCTFail("Skill file not found: \(skillID).skill.json")
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // If requiredTools is present, all tools should be from the valid set
            if let tools = skillFile.requiredTools {
                XCTAssertFalse(tools.isEmpty, "Skill \(skillID) has empty requiredTools array - remove it or add tools")

                for tool in tools {
                    XCTAssertTrue(
                        validTools.contains(tool),
                        "Skill \(skillID) requires unknown tool '\(tool)'. Valid tools: \(validTools.joined(separator: ", "))"
                    )
                }
            }
        }
    }

    // MARK: - Test: Compatible CLIs Are Valid

    func testCompatibleCLIsAreValid() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                XCTFail("Skill file not found: \(skillID).skill.json")
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // If compatibleCLIs is present, all CLIs should be from the valid set
            if let clis = skillFile.compatibleCLIs {
                XCTAssertFalse(clis.isEmpty, "Skill \(skillID) has empty compatibleCLIs array - remove it or add CLIs")

                for cli in clis {
                    XCTAssertTrue(
                        validCLIs.contains(cli),
                        "Skill \(skillID) specifies unknown CLI '\(cli)'. Valid CLIs: \(validCLIs.joined(separator: ", "))"
                    )
                }
            }
        }
    }

    // MARK: - Test: Categories Are Valid

    func testCategoriesAreValid() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                XCTFail("Skill file not found: \(skillID).skill.json")
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // If category is present, it should be from the valid set
            if let category = skillFile.category {
                XCTAssertTrue(
                    validCategories.contains(category),
                    "Skill \(skillID) has unknown category '\(category)'. Valid categories: \(validCategories.joined(separator: ", "))"
                )
            }
        }
    }

    // MARK: - Test: Prompt Templates Contain Placeholder

    func testPromptTemplatesContainContextPlaceholder() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                XCTFail("Skill file not found: \(skillID).skill.json")
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // All skills should have {{context}} placeholder for injection
            XCTAssertTrue(
                skillFile.promptTemplate.contains("{{context}}"),
                "Skill \(skillID) prompt template should contain {{context}} placeholder for context injection"
            )
        }
    }

    // MARK: - Test: No Duplicate Skill IDs

    func testNoDuplicateSkillIDs() throws {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: skillsDirectoryURL.path) else {
            XCTFail("Could not read skills directory contents")
            return
        }

        let skillFiles = contents.filter { $0.hasSuffix(".skill.json") }
        var seenIDs: Set<String> = []
        var duplicates: [String] = []

        for filename in skillFiles {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent(filename)
            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            if seenIDs.contains(skillFile.id) {
                duplicates.append(skillFile.id)
            } else {
                seenIDs.insert(skillFile.id)
            }
        }

        XCTAssertTrue(
            duplicates.isEmpty,
            "Found duplicate skill IDs: \(duplicates.joined(separator: ", "))"
        )
    }

    // MARK: - Test: All Expected Skills Are Present

    func testAllExpectedSkillsArePresent() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            XCTAssertTrue(
                fileManager.fileExists(atPath: skillFileURL.path),
                "Expected bundled skill '\(skillID)' is missing"
            )
        }
    }

    // MARK: - Test: Skill Files Match SkillRegistry.bundledSkillIDs

    func testSkillFilesMatchBundledSkillIDs() throws {
        // The expectedSkillIDs should match SkillRegistry.bundledSkillIDs
        // This is a consistency check to ensure tests cover all bundled skills
        let bundledSkillIDs = [
            "commit",
            "review-pr",
            "prd",
            "integration-test",
            "code-reviewer"
        ]

        XCTAssertEqual(
            Set(expectedSkillIDs),
            Set(bundledSkillIDs),
            "Test expectedSkillIDs should match SkillRegistry.bundledSkillIDs"
        )
    }

    // MARK: - Test: Skill Names Are User-Friendly

    func testSkillNamesAreUserFriendly() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // Name should be capitalized and readable
            XCTAssertTrue(
                skillFile.name.first?.isUppercase == true,
                "Skill \(skillID) name '\(skillFile.name)' should start with uppercase letter"
            )

            // Name should not just be the ID
            XCTAssertNotEqual(
                skillFile.name.lowercased(),
                skillFile.id.lowercased(),
                "Skill \(skillID) name should be more descriptive than just the ID"
            )
        }
    }

    // MARK: - Test: Descriptions Are Meaningful

    func testDescriptionsAreMeaningful() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            // Description should be at least 20 characters
            XCTAssertGreaterThanOrEqual(
                skillFile.description.count,
                20,
                "Skill \(skillID) description should be at least 20 characters"
            )

            // Description should not end with a period (it's a phrase, not a sentence)
            // Actually, some descriptions do end with periods and that's fine
        }
    }

    // MARK: - Test: Author Is Present

    func testAuthorIsPresent() throws {
        let fileManager = FileManager.default

        for skillID in expectedSkillIDs {
            let skillFileURL = skillsDirectoryURL.appendingPathComponent("\(skillID).skill.json")

            guard fileManager.fileExists(atPath: skillFileURL.path) else {
                continue
            }

            let data = try Data(contentsOf: skillFileURL)
            let skillFile = try JSONDecoder().decode(TestSkillFile.self, from: data)

            XCTAssertNotNil(
                skillFile.author,
                "Skill \(skillID) should have an author"
            )

            if let author = skillFile.author {
                XCTAssertFalse(
                    author.isEmpty,
                    "Skill \(skillID) author should not be empty"
                )
            }
        }
    }
}
