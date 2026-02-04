//
//  ComponentContextTests.swift
//  XRoadsTests
//
//  Created by Nexus on 2026-02-04.
//  US-V4-026: Unit tests for Component Context Injection
//

import XCTest
@testable import XRoadsLib

final class ComponentContextTests: XCTestCase {

    func test_componentSectionInjectedIntoAgents() throws {
        let projectURL = try makeTemporaryProject()
        let agentsURL = projectURL.appendingPathComponent("AGENTS.md")
        try writeAgentsTemplate(to: agentsURL)
        try writeComponentFile(named: "PrimaryButton", in: projectURL)
        try writeArtBible(
            components: [
                ("PrimaryButton", "Main CTA", ["accent.primary", "radius.md"])
            ],
            to: projectURL
        )

        let builder = ComponentContextBuilder()
        try builder.updateAgentsFile(at: agentsURL, projectURL: projectURL)

        let content = try String(contentsOf: agentsURL, encoding: .utf8)
        XCTAssertTrue(content.contains("## Available Components"))
        XCTAssertTrue(content.contains("PrimaryButton"))
        XCTAssertTrue(content.contains("Usage: `PrimaryButton"))
    }

    func test_missingComponentTriggersWarning() throws {
        let projectURL = try makeTemporaryProject()
        let agentsURL = projectURL.appendingPathComponent("AGENTS.md")
        try writeAgentsTemplate(to: agentsURL)
        try writeArtBible(
            components: [
                ("Card", "Container", ["background.secondary", "radius.lg"])
            ],
            to: projectURL
        )

        let builder = ComponentContextBuilder()
        let context = try builder.buildContext(projectURL: projectURL)
        let section = builder.renderSection(for: context)

        XCTAssertTrue(section.contains("Warnings"))
        XCTAssertTrue(section.contains("Missing component: `Card`"))
    }

    func test_componentsIncludeUsageExamples() throws {
        let projectURL = try makeTemporaryProject()
        let agentsURL = projectURL.appendingPathComponent("AGENTS.md")
        try writeAgentsTemplate(to: agentsURL)
        try writeComponentFile(named: "ModalPanel", in: projectURL)

        let builder = ComponentContextBuilder()
        let context = try builder.buildContext(projectURL: projectURL)
        let section = builder.renderSection(for: context)

        XCTAssertTrue(section.contains("ModalPanel"))
        XCTAssertTrue(section.contains("Usage: `ModalPanel"))
    }

    // MARK: - Helpers

    private func makeTemporaryProject() throws -> URL {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        return baseURL
    }

    private func writeAgentsTemplate(to url: URL) throws {
        let template = """
        # AGENTS.md

        Project instructions.

        ## XRoads Skills (Auto-Injected)
        <!-- placeholder -->
        ## End XRoads Skills
        """
        try template.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeComponentFile(named name: String, in projectURL: URL) throws {
        let directory = projectURL.appendingPathComponent("XRoads/Views/Components", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(name).swift")
        try "// \(name)\n".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func writeArtBible(
        components: [(String, String, [String])],
        to projectURL: URL
    ) throws {
        let componentJSON = components.map { component in
            """
            {
              "name": "\(component.0)",
              "description": "\(component.1)",
              "tokens": \(jsonArray(component.2))
            }
            """
        }.joined(separator: ",\n")

        let json = """
        {
          "project": "Temp",
          "version": "1.0.0",
          "components": [
            \(componentJSON)
          ]
        }
        """

        let url = projectURL.appendingPathComponent("art-bible.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
    }

    private func jsonArray(_ values: [String]) -> String {
        let encoded = values.map { "\"\($0)\"" }.joined(separator: ", ")
        return "[\(encoded)]"
    }
}
