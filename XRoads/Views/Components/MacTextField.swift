//
//  MacTextField.swift
//  XRoads
//
//  NSViewRepresentable wrapper for NSTextField that works reliably in sheets on macOS.
//  SwiftUI's TextField has known issues with keyboard input in modal sheets.
//
//  FIX FOR KEYBOARD INPUT BUG:
//  The root cause is that sheet windows need explicit key window activation
//  AND the field editor must be manually started when the window is a sheet.
//  We must also ensure the window accepts key events via proper configuration.
//

import SwiftUI
import AppKit

// MARK: - FocusableTextField

/// Custom NSTextField subclass that properly handles focus in sheets
/// Key fix: Explicitly starts field editor and ensures sheet window accepts keyboard
class FocusableTextField: NSTextField {
    var needsFocus: Bool = false
    var onSubmit: (() -> Void)? = nil
    private var hasStartedEditing: Bool = false

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var canBecomeKeyView: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // CRITICAL FIX: Ensure the window can receive key events
            ensureWindowAcceptsKeyboardInput()

            // Ensure cursor is visible
            NSCursor.unhide()
            NSCursor.setHiddenUntilMouseMoves(false)

            // Start editing immediately to activate field editor
            if !hasStartedEditing {
                hasStartedEditing = true
                DispatchQueue.main.async { [weak self] in
                    self?.startFieldEditing()
                }
            }

            Log.input.debug("FocusableTextField became first responder")
        } else {
            Log.input.debug("FocusableTextField FAILED to become first responder")
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        hasStartedEditing = false
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        Log.input.debug("FocusableTextField clicked")

        // CRITICAL: Ensure window accepts keyboard before handling click
        ensureWindowAcceptsKeyboardInput()

        super.mouseDown(with: event)

        // After super call, explicitly focus and start editing
        window?.makeFirstResponder(self)
        startFieldEditing()
    }

    override func keyDown(with event: NSEvent) {
        Log.input.debug("FocusableTextField keyDown: \(event.characters ?? "")")
        super.keyDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window = window else { return }

        // Configure window for keyboard input when view is added
        configureWindowForKeyboardInput(window)

        if needsFocus {
            // Use longer delay to ensure sheet animation is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.attemptFocus()
            }
        }
    }

    /// Configures the window to properly accept keyboard input (critical for sheets)
    private func configureWindowForKeyboardInput(_ window: NSWindow) {
        // CRITICAL FIX: Sheet windows need these flags to accept keyboard input
        // when the app is launched via swift run (not Xcode)

        // If this is a sheet, we need to ensure its parent knows about key status
        if let sheetParent = window.sheetParent {
            // The sheet parent should be active
            sheetParent.makeKey()
        }

        // Ensure this window accepts mouse events for clicking into fields
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
    }

    /// Ensures the containing window can accept keyboard input
    private func ensureWindowAcceptsKeyboardInput() {
        guard let window = self.window else { return }

        // CRITICAL FIX: Activate app and make window key
        // This is the key fix for the "bonk" sound issue
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        // For sheet windows, we need to make the SHEET window key, not the parent
        // But we also need to ensure the parent is the main window
        if let sheetParent = window.sheetParent {
            sheetParent.makeMain()
        }

        // Make this window key (this accepts keyboard events)
        if !window.isKeyWindow {
            window.makeKey()
        }
    }

    /// Starts the field editor to ensure keyboard input is received
    private func startFieldEditing() {
        guard let window = self.window else { return }

        // CRITICAL FIX: Get or create the field editor and configure it
        // The field editor is an NSTextView that handles actual text input
        guard let fieldEditor = window.fieldEditor(true, for: self) as? NSTextView else {
            Log.input.debug("Could not get field editor")
            return
        }

        // Ensure field editor is properly configured
        fieldEditor.isEditable = true
        fieldEditor.isSelectable = true
        fieldEditor.isFieldEditor = true

        // CRITICAL: Set the field editor as first responder's next responder
        // This ensures keyboard events flow correctly
        fieldEditor.window?.makeFirstResponder(fieldEditor)

        // Select all text for easy replacement
        fieldEditor.selectAll(nil)

        Log.input.debug("Field editor started, isEditable: \(fieldEditor.isEditable)")
        Log.input.debug("Field editor isFirstResponder: \(fieldEditor === window.firstResponder)")
    }

    func attemptFocus() {
        guard let window = self.window else { return }

        Log.input.debug("attemptFocus called, window: \(window)")
        Log.input.debug("Window isSheet: \(window.sheetParent != nil)")
        Log.input.debug("Window isKeyWindow: \(window.isKeyWindow)")

        // Ensure cursor is always visible
        NSCursor.unhide()
        NSCursor.setHiddenUntilMouseMoves(false)

        // CRITICAL FIX: Proper activation sequence for sheets
        ensureWindowAcceptsKeyboardInput()

        // Make sure the window level allows keyboard input
        // Don't use .modalPanel for sheets - it can interfere with keyboard routing
        if window.sheetParent != nil {
            window.level = .normal
        }

        // Force the field to become first responder
        let success = window.makeFirstResponder(self)

        Log.input.debug("attemptFocus: makeFirstResponder returned \(success)")

        // Start field editing regardless of makeFirstResponder result
        // because the field editor is what actually receives keyboard input
        startFieldEditing()

        needsFocus = false
    }
}

// MARK: - MacTextField

/// A reliable text field for macOS using AppKit's NSTextField
/// Use this instead of SwiftUI TextField when in sheets or modals
///
/// KEY FIX: This version properly handles keyboard input in sheet windows by:
/// 1. Ensuring the window accepts keyboard events via proper activation
/// 2. Explicitly starting the field editor when focused
/// 3. Handling the SwiftUI/AppKit coordination properly
struct MacTextField: NSViewRepresentable {
    typealias NSViewType = FocusableTextField
    let placeholder: String
    @Binding var text: String
    var isFirstResponder: Bool = false
    var onSubmit: (() -> Void)? = nil

    func makeNSView(context: Context) -> FocusableTextField {
        let textField = FocusableTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)
        textField.focusRingType = .exterior
        textField.isBordered = true
        textField.drawsBackground = true
        textField.backgroundColor = NSColor(Color.bgElevated)
        textField.textColor = NSColor(Color.textPrimary)

        // CRITICAL: Enable editing and text input
        textField.isEditable = true
        textField.isSelectable = true
        textField.allowsEditingTextAttributes = false
        textField.importsGraphics = false

        // Ensure it can become first responder
        textField.refusesFirstResponder = false

        // Set onSubmit callback
        textField.onSubmit = onSubmit

        // Enable continuous updates for responsive typing
        textField.isContinuous = true

        // Store coordinator for later access
        context.coordinator.textField = textField

        Log.input.debug("Created text field with placeholder '\(placeholder)'")

        return textField
    }

    func updateNSView(_ nsView: FocusableTextField, context: Context) {
        // IMPORTANT: Update coordinator's parent reference to get latest binding
        context.coordinator.parent = self

        // Re-attach delegate to ensure it's connected
        if nsView.delegate !== context.coordinator {
            nsView.delegate = context.coordinator
            Log.input.debug("Re-attached delegate")
        }

        // Only update text if it's different AND we're not currently editing
        // This prevents cursor jumping during typing
        let isCurrentlyEditing = nsView.currentEditor() != nil
        if nsView.stringValue != text && !isCurrentlyEditing {
            Log.input.debug("Updating view from '\(nsView.stringValue)' to '\(text)'")
            nsView.stringValue = text
        }

        // Handle first responder - use a flag to prevent repeated focus attempts
        if isFirstResponder && !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            nsView.needsFocus = true
            // Trigger focus on next run loop with delay for sheet animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                nsView.attemptFocus()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextField
        weak var textField: FocusableTextField?
        var hasFocused: Bool = false

        init(_ parent: MacTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            let newValue = textField.stringValue

            if parent.text != newValue {
                let oldValue = parent.text
                Log.input.debug("Text changed from '\(oldValue)' to '\(newValue)'")
            }

            // Update binding immediately on main thread
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = newValue
            }
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            Log.input.debug("Begin editing")
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            Log.input.debug("End editing")
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

// MARK: - MacSecureTextField

/// A secure text field for passwords using NSSecureTextField
struct MacSecureTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = NSSecureTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)

        return textField
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacSecureTextField

        init(_ parent: MacSecureTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MacTextField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MacTextField(placeholder: "Enter name...", text: .constant(""))
                .frame(height: 24)

            MacTextField(placeholder: "With text", text: .constant("Hello World"))
                .frame(height: 24)
        }
        .padding()
        .frame(width: 300)
        .background(Color.bgSurface)
    }
}
#endif
