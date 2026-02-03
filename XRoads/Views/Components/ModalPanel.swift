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
class ModalPanelController<Content: View>: NSObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<Content>?

    func show(content: Content, size: CGSize, title: String = "") {
        // Create panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = title
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Create hosting view
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        panel.contentView = hostingView

        // Center on screen
        panel.center()

        // Store references
        self.panel = panel
        self.hostingView = hostingView

        // Show panel as modal
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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
            print("WindowSheetPresenter: No parent window found")
            return
        }

        self.onDismiss = onDismiss

        // Create the sheet window
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

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

        // Present as sheet
        parentWindow.beginSheet(sheetWindow) { [weak self] response in
            self?.onDismiss?()
            self?.cleanup()
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
/// Key fix: Ensures the window becomes key and the field becomes first responder
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

        // Store coordinator reference for focus handling
        field.coordinator = context.coordinator

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
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
            DispatchQueue.main.async {
                // Ensure the window is key before making field first responder
                if let window = nsView.window {
                    window.makeKey()
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeFirstResponder(nsView)
                }
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

/// Custom NSTextField that properly accepts first responder
class FocusableNSTextField: NSTextField {
    weak var coordinator: SimpleTextField.Coordinator?
    var hasFocusedOnce: Bool = false
    var isEditing: Bool = false

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // Ensure window is key when we become first responder
            window?.makeKey()

            // Select all text for easy replacement
            if let editor = currentEditor() {
                editor.selectAll(nil)
            }
        }
        return result
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Ensure we have focus when clicked
        window?.makeFirstResponder(self)
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
