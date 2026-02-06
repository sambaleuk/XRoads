//
//  FloatingInputWindow.swift
//  XRoads
//
//  A floating window approach for text input that bypasses SwiftUI sheet keyboard issues.
//  Uses pure AppKit with a centered modal window.
//

import SwiftUI
import AppKit

// MARK: - FloatingInputWindowController

/// Controller for presenting a floating input window that reliably accepts keyboard input.
/// This bypasses all SwiftUI sheet keyboard issues by using a pure AppKit approach.
class FloatingInputWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var completion: ((String?) -> Void)?
    private var textField: NSTextField?

    /// Shows a floating input dialog
    /// - Parameters:
    ///   - title: Window title
    ///   - prompt: Prompt text above the input field
    ///   - placeholder: Placeholder text for the input field
    ///   - initialValue: Initial value in the text field
    ///   - completion: Called with the entered text, or nil if cancelled
    func showInput(
        title: String,
        prompt: String,
        placeholder: String = "",
        initialValue: String = "",
        completion: @escaping (String?) -> Void
    ) {
        self.completion = completion

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.delegate = self
        window.level = .floating
        window.isReleasedWhenClosed = false

        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))

        // Prompt label
        let label = NSTextField(labelWithString: prompt)
        label.frame = NSRect(x: 20, y: 110, width: 360, height: 20)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(label)

        // Text field
        let textField = NSTextField(frame: NSRect(x: 20, y: 70, width: 360, height: 24))
        textField.placeholderString = placeholder
        textField.stringValue = initialValue
        textField.isEditable = true
        textField.isSelectable = true
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)
        textField.target = self
        textField.action = #selector(textFieldAction(_:))
        contentView.addSubview(textField)
        self.textField = textField

        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancelButton.frame = NSRect(x: 200, y: 20, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        contentView.addSubview(cancelButton)

        let okButton = NSButton(title: "OK", target: self, action: #selector(okAction))
        okButton.frame = NSRect(x: 290, y: 20, width: 80, height: 30)
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r" // Return
        contentView.addSubview(okButton)

        window.contentView = contentView
        self.window = window

        // Center and show
        window.center()

        // CRITICAL: Proper activation sequence
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Focus the text field
        // AppKit timing: DispatchQueue required for makeFirstResponder after window show animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let window = self.window, let textField = self.textField else { return }
            window.makeFirstResponder(textField)
            textField.selectText(nil)
        }
    }

    @objc private func textFieldAction(_ sender: NSTextField) {
        okAction()
    }

    @objc private func okAction() {
        let value = textField?.stringValue
        window?.close()
        completion?(value)
        cleanup()
    }

    @objc private func cancelAction() {
        window?.close()
        completion?(nil)
        cleanup()
    }

    private func cleanup() {
        window = nil
        textField = nil
        completion = nil
    }

    func windowWillClose(_ notification: Notification) {
        // If window is closed without OK/Cancel (e.g., red X button)
        if completion != nil {
            completion?(nil)
            cleanup()
        }
    }
}

// MARK: - WorktreeInputWindow

/// Specialized input window for creating worktrees
class WorktreeInputWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var nameField: NSTextField?
    private var pathField: NSTextField?
    private var agentPicker: NSPopUpButton?
    private var completion: ((String, String, Int)?) -> Void = { _ in }

    struct Result {
        let name: String
        let repoPath: String
        let agentIndex: Int
    }

    func show(completion: @escaping ((name: String, repoPath: String, agentIndex: Int)?) -> Void) {
        self.completion = completion

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "New Worktree"
        window.delegate = self
        window.level = .floating
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 280))

        // Title
        let titleLabel = NSTextField(labelWithString: "Create a new worktree")
        titleLabel.frame = NSRect(x: 20, y: 240, width: 410, height: 24)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addSubview(titleLabel)

        // Name field
        let nameLabel = NSTextField(labelWithString: "Worktree Name:")
        nameLabel.frame = NSRect(x: 20, y: 200, width: 120, height: 20)
        contentView.addSubview(nameLabel)

        let nameField = NSTextField(frame: NSRect(x: 20, y: 170, width: 410, height: 24))
        nameField.placeholderString = "e.g., feature-auth"
        nameField.bezelStyle = .roundedBezel
        contentView.addSubview(nameField)
        self.nameField = nameField

        // Path field
        let pathLabel = NSTextField(labelWithString: "Repository Path:")
        pathLabel.frame = NSRect(x: 20, y: 135, width: 120, height: 20)
        contentView.addSubview(pathLabel)

        let pathField = NSTextField(frame: NSRect(x: 20, y: 105, width: 320, height: 24))
        pathField.placeholderString = "/path/to/repo"
        pathField.bezelStyle = .roundedBezel
        contentView.addSubview(pathField)
        self.pathField = pathField

        let browseButton = NSButton(title: "Browse", target: self, action: #selector(browseAction))
        browseButton.frame = NSRect(x: 350, y: 103, width: 80, height: 28)
        browseButton.bezelStyle = .rounded
        contentView.addSubview(browseButton)

        // Agent picker
        let agentLabel = NSTextField(labelWithString: "Agent Type:")
        agentLabel.frame = NSRect(x: 20, y: 70, width: 120, height: 20)
        contentView.addSubview(agentLabel)

        let agentPicker = NSPopUpButton(frame: NSRect(x: 20, y: 40, width: 200, height: 24))
        agentPicker.addItems(withTitles: ["Claude Code", "Gemini CLI", "Codex"])
        contentView.addSubview(agentPicker)
        self.agentPicker = agentPicker

        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancelButton.frame = NSRect(x: 260, y: 10, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let createButton = NSButton(title: "Create", target: self, action: #selector(createAction))
        createButton.frame = NSRect(x: 350, y: 10, width: 80, height: 30)
        createButton.bezelStyle = .rounded
        createButton.keyEquivalent = "\r"
        contentView.addSubview(createButton)

        window.contentView = contentView
        self.window = window

        // Center and show
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Focus name field
        // AppKit timing: DispatchQueue required for makeFirstResponder after window show animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.window?.makeFirstResponder(self?.nameField)
        }
    }

    @objc private func browseAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            pathField?.stringValue = url.path
        }
    }

    @objc private func createAction() {
        guard let name = nameField?.stringValue, !name.isEmpty,
              let path = pathField?.stringValue, !path.isEmpty else {
            NSSound.beep()
            return
        }

        let agentIndex = agentPicker?.indexOfSelectedItem ?? 0
        window?.close()
        completion((name, path, agentIndex))
        cleanup()
    }

    @objc private func cancelAction() {
        window?.close()
        completion(nil)
        cleanup()
    }

    private func cleanup() {
        window = nil
        nameField = nil
        pathField = nil
        agentPicker = nil
    }

    func windowWillClose(_ notification: Notification) {
        cleanup()
    }
}

// MARK: - SwiftUI Integration

/// Environment key for the floating input presenter
struct FloatingInputPresenterKey: EnvironmentKey {
    static let defaultValue = FloatingInputPresenter()
}

extension EnvironmentValues {
    var floatingInput: FloatingInputPresenter {
        get { self[FloatingInputPresenterKey.self] }
        set { self[FloatingInputPresenterKey.self] = newValue }
    }
}

/// Observable presenter for floating input windows
class FloatingInputPresenter: ObservableObject {
    private var controller: FloatingInputWindowController?
    private var worktreeController: WorktreeInputWindow?

    func showInput(
        title: String,
        prompt: String,
        placeholder: String = "",
        completion: @escaping (String?) -> Void
    ) {
        controller = FloatingInputWindowController()
        controller?.showInput(
            title: title,
            prompt: prompt,
            placeholder: placeholder,
            completion: { [weak self] result in
                completion(result)
                self?.controller = nil
            }
        )
    }

    func showWorktreeInput(completion: @escaping ((name: String, repoPath: String, agentIndex: Int)?) -> Void) {
        worktreeController = WorktreeInputWindow()
        worktreeController?.show { [weak self] result in
            completion(result)
            self?.worktreeController = nil
        }
    }
}
