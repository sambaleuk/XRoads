//
//  ModalPanel.swift
//  XRoads
//
//  AppKit-based modal panel that properly handles keyboard input.
//  Use this instead of SwiftUI .sheet() when TextField input is required.
//

import SwiftUI
import AppKit

// MARK: - ModalPanelController

/// Controller that manages an NSPanel for modal dialogs
///
/// KEYBOARD INPUT FIX:
/// - Removed .nonactivatingPanel from styleMask (this was blocking keyboard input)
/// - Panel is configured to properly become key and accept keyboard events
class ModalPanelController<Content: View>: NSObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<Content>?

    func show(content: Content, size: CGSize, title: String = "") {
        // Create panel - CRITICAL FIX: Do NOT use .nonactivatingPanel
        // .nonactivatingPanel prevents the panel from receiving keyboard events
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = title
        // CRITICAL FIX: Panel must NOT be floating for keyboard input to work
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Use .normal level instead of .modalPanel for better keyboard handling
        panel.level = .normal
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .managed]

        // Create hosting view
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        panel.contentView = hostingView

        // Center on screen
        panel.center()

        // Store references
        self.panel = panel
        self.hostingView = hostingView

        // CRITICAL FIX: Proper activation sequence
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Run modal session
        NSApp.runModal(for: panel)
    }

    func close() {
        NSApp.stopModal()
        panel?.close()
        panel = nil
        hostingView = nil
    }
}

// MARK: - WindowSheetPresenter

/// Presents SwiftUI content as a native macOS sheet attached to the main window
/// This properly handles keyboard input unlike SwiftUI's .sheet() when running via swift run
///
/// KEYBOARD INPUT FIX:
/// - Sheet window is configured to accept keyboard events
/// - Proper activation sequence ensures keyboard focus works
/// - First responder is set after sheet presentation completes
class WindowSheetPresenter: ObservableObject {
    private var sheetWindow: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var onDismiss: (() -> Void)?

    /// Present content as a sheet on the key window
    func presentSheet<Content: View>(
        content: Content,
        size: CGSize = CGSize(width: 480, height: 520),
        onDismiss: @escaping () -> Void
    ) {
        guard let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow else {
            Log.modal.warning("No parent window found")
            return
        }

        self.onDismiss = onDismiss

        // Create the sheet window with proper style mask
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // CRITICAL FIX: Configure window for keyboard input
        sheetWindow.acceptsMouseMovedEvents = true
        sheetWindow.ignoresMouseEvents = false

        // Wrap content with dismiss environment
        let wrappedContent = content
            .environment(\.dismissSheet, DismissSheetAction { [weak self] in
                self?.dismissSheet()
            })

        let hostingView = NSHostingView(rootView: AnyView(wrappedContent))
        hostingView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        sheetWindow.contentView = hostingView

        self.sheetWindow = sheetWindow
        self.hostingView = hostingView

        // CRITICAL FIX: Ensure app is active before presenting sheet
        NSApp.activate(ignoringOtherApps: true)

        // Present as sheet
        parentWindow.beginSheet(sheetWindow) { [weak self] response in
            self?.onDismiss?()
            self?.cleanup()
        }

        // CRITICAL FIX: After sheet is presented, ensure it can receive keyboard input
        // The delay allows the sheet animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let sheetWindow = self?.sheetWindow else { return }

            // Make sure the sheet window is key
            sheetWindow.makeKey()

            Log.modal.debug("Sheet presented, isKeyWindow: \(sheetWindow.isKeyWindow)")

            // Find the first NSTextField and focus it
            self?.focusFirstTextField(in: sheetWindow)
        }
    }

    /// Finds and focuses the first editable text field in the window
    private func focusFirstTextField(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        func findFirstTextField(in view: NSView) -> NSTextField? {
            // Check if this is an editable text field
            if let textField = view as? NSTextField, textField.isEditable {
                return textField
            }
            // Recursively search subviews
            for subview in view.subviews {
                if let found = findFirstTextField(in: subview) {
                    return found
                }
            }
            return nil
        }

        if let textField = findFirstTextField(in: contentView) {
            // CRITICAL: Make the text field first responder to enable keyboard input
            let success = window.makeFirstResponder(textField)
            Log.modal.debug("Focused first text field: \(success)")
        }
    }

    /// Dismiss the current sheet
    func dismissSheet() {
        guard let sheetWindow = sheetWindow,
              let parentWindow = sheetWindow.sheetParent else {
            return
        }
        parentWindow.endSheet(sheetWindow)
    }

    private func cleanup() {
        sheetWindow = nil
        hostingView = nil
        onDismiss = nil
    }
}

// MARK: - DismissSheet Environment

/// Action to dismiss a sheet presented via WindowSheetPresenter
struct DismissSheetAction {
    let dismiss: () -> Void

    func callAsFunction() {
        dismiss()
    }
}

struct DismissSheetKey: EnvironmentKey {
    static let defaultValue = DismissSheetAction { }
}

extension EnvironmentValues {
    var dismissSheet: DismissSheetAction {
        get { self[DismissSheetKey.self] }
        set { self[DismissSheetKey.self] = newValue }
    }
}

// MARK: - ModalPresenter

/// Environment key for modal presenter
struct ModalPresenterKey: EnvironmentKey {
    static let defaultValue: ModalPresenter = ModalPresenter()
}

extension EnvironmentValues {
    var modalPresenter: ModalPresenter {
        get { self[ModalPresenterKey.self] }
        set { self[ModalPresenterKey.self] = newValue }
    }
}

/// Observable object to control modal presentation
class ModalPresenter: ObservableObject {
    private var controller: Any? // Type-erased controller

    func present<Content: View>(_ content: Content, size: CGSize = CGSize(width: 480, height: 520), title: String = "") {
        let controller = ModalPanelController<Content>()
        self.controller = controller

        DispatchQueue.main.async {
            controller.show(content: content, size: size, title: title)
        }
    }

    func dismiss() {
        if let controller = controller as? ModalPanelController<AnyView> {
            controller.close()
        }
        // For type-erased dismiss, we need to stop modal
        NSApp.stopModal()
        if let window = NSApp.modalWindow {
            window.close()
        }
        controller = nil
    }
}

// MARK: - SimpleTextField

/// NSTextField wrapper that properly handles keyboard input in sheets
///
/// KEYBOARD INPUT FIX:
/// - Ensures window is properly activated before focusing
/// - Starts field editor explicitly for keyboard input
/// - Handles the activation sequence correctly for sheet windows
struct SimpleTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    var autoFocus: Bool = false

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusableNSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: 13)
        field.isBordered = true
        field.drawsBackground = true
        field.focusRingType = .exterior
        field.cell?.sendsActionOnEndEditing = true

        // Ensure editing is enabled
        field.isEditable = true
        field.isSelectable = true
        field.refusesFirstResponder = false

        // Store coordinator reference for focus handling
        field.coordinator = context.coordinator

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Update coordinator parent reference
        context.coordinator.parent = self

        // Only update if the values differ and we're not currently editing
        // This prevents the cursor from jumping during typing
        if let field = nsView as? FocusableNSTextField {
            if !field.isEditing && nsView.stringValue != text {
                nsView.stringValue = text
            }
        } else if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // Handle auto-focus on first update
        if autoFocus, let field = nsView as? FocusableNSTextField, !field.hasFocusedOnce {
            field.hasFocusedOnce = true
            // Use delay to allow sheet animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                field.activateForKeyboardInput()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SimpleTextField
        var isEditing: Bool = false

        init(_ parent: SimpleTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isEditing = true
            if let field = notification.object as? FocusableNSTextField {
                field.isEditing = true
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            isEditing = false
            if let field = notification.object as? FocusableNSTextField {
                field.isEditing = false
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // Update binding immediately
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = field.stringValue
            }
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

/// Custom NSTextField that properly accepts first responder in sheet windows
///
/// KEYBOARD INPUT FIX:
/// The key insight is that in AppKit, NSTextField uses a shared "field editor"
/// (an NSTextView) for text input. In sheet windows, this field editor must be
/// explicitly activated AND the window must be made key for keyboard events to work.
class FocusableNSTextField: NSTextField {
    weak var coordinator: SimpleTextField.Coordinator?
    var hasFocusedOnce: Bool = false
    var isEditing: Bool = false

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        // CRITICAL: Ensure app and window are active before becoming first responder
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        let result = super.becomeFirstResponder()
        if result {
            // Ensure window is key when we become first responder
            window?.makeKey()

            // CRITICAL FIX: Start field editor for keyboard input
            DispatchQueue.main.async { [weak self] in
                self?.startFieldEditorForKeyboard()
            }

            Log.modal.debug("FocusableNSTextField becomeFirstResponder succeeded")
        }
        return result
    }

    override func mouseDown(with event: NSEvent) {
        // CRITICAL: Activate before handling mouse
        activateForKeyboardInput()
        super.mouseDown(with: event)
    }

    /// Activates the text field for keyboard input in a sheet context
    func activateForKeyboardInput() {
        guard let window = self.window else { return }

        Log.modal.debug("FocusableNSTextField activateForKeyboardInput called")
        Log.modal.debug("Window isSheet: \(window.sheetParent != nil)")

        // CRITICAL FIX: Proper activation sequence
        // 1. Activate the application
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        // 2. For sheets, ensure parent is main window
        if let sheetParent = window.sheetParent {
            sheetParent.makeMain()
        }

        // 3. Make sheet window key (receives keyboard)
        window.makeKey()

        // 4. Make this field first responder
        window.makeFirstResponder(self)

        // 5. Start field editor
        startFieldEditorForKeyboard()
    }

    /// Starts the field editor to enable keyboard input
    private func startFieldEditorForKeyboard() {
        guard let window = self.window else { return }

        // Get the field editor
        guard let fieldEditor = window.fieldEditor(true, for: self) as? NSTextView else {
            Log.modal.debug("FocusableNSTextField could not get field editor")
            return
        }

        // Configure field editor
        fieldEditor.isEditable = true
        fieldEditor.isSelectable = true
        fieldEditor.isFieldEditor = true

        // Make field editor first responder (this is what actually receives keyboard)
        window.makeFirstResponder(fieldEditor)

        // Select all for easy replacement
        fieldEditor.selectAll(nil)

        Log.modal.debug("FocusableNSTextField field editor activated")
        Log.modal.debug("Field editor isFirstResponder: \(fieldEditor === window.firstResponder)")
    }
}

// MARK: - Preview

#if DEBUG
struct ModalPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SimpleTextField(placeholder: "Test field", text: .constant(""))
                .frame(height: 24)
        }
        .padding()
        .frame(width: 300, height: 100)
    }
}
#endif
