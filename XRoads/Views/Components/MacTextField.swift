//
//  MacTextField.swift
//  XRoads
//
//  NSViewRepresentable wrapper for NSTextField that works reliably in sheets on macOS.
//  SwiftUI's TextField has known issues with keyboard input in modal sheets.
//

import SwiftUI
import AppKit

// MARK: - FocusableTextField

/// Custom NSTextField subclass that properly handles focus in sheets
class FocusableTextField: NSTextField {
    var needsFocus: Bool = false
    var onSubmit: (() -> Void)? = nil
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override var canBecomeKeyView: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        // Force app activation when becoming first responder
        NSApp.activate(ignoringOtherApps: true)
        
        let result = super.becomeFirstResponder()
        if result {
            // Ensure cursor is visible
            NSCursor.unhide()
            NSCursor.setHiddenUntilMouseMoves(false)
            
            // Select all text when becoming first responder
            currentEditor()?.selectAll(nil)
            
            #if DEBUG
            print("✅ FocusableTextField became first responder")
            #endif
        } else {
            #if DEBUG
            print("❌ FocusableTextField FAILED to become first responder")
            #endif
        }
        return result
    }
    
    override func mouseDown(with event: NSEvent) {
        #if DEBUG
        print("🖱️ FocusableTextField clicked")
        #endif
        
        // Force activation when clicked
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        #if DEBUG
        print("⌨️ FocusableTextField keyDown: \(event.characters ?? "")")
        #endif
        super.keyDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if needsFocus && window != nil {
            // Delay focus slightly to ensure window is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.attemptFocus()
            }
        }
    }

    func attemptFocus() {
        guard let window = self.window else { return }

        // Ensure cursor is always visible
        NSCursor.unhide()
        NSCursor.setHiddenUntilMouseMoves(false)

        // CRITICAL: Force the window to become key and main
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Make sure the window level is correct
        window.level = .normal

        // Force the field to become first responder
        let success = window.makeFirstResponder(self)

        #if DEBUG
        print("MacTextField attemptFocus: makeFirstResponder returned \(success)")
        #endif

        // CRITICAL: Manually start editing to activate the field editor
        if success {
            // Select all and start editing
            self.selectText(nil)

            // Ensure the field editor is properly set up
            if let fieldEditor = window.fieldEditor(true, for: self) as? NSTextView {
                fieldEditor.isEditable = true
                fieldEditor.isSelectable = true
                #if DEBUG
                print("MacTextField: Field editor activated")
                #endif
            }
        } else {
            // If that failed, try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self, let window = self.window else { return }
                NSApp.activate(ignoringOtherApps: true)
                window.makeFirstResponder(self)
                self.selectText(nil)
            }
        }

        needsFocus = false
    }
}

// MARK: - MacTextField

/// A reliable text field for macOS using AppKit's NSTextField
/// Use this instead of SwiftUI TextField when in sheets or modals
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
        
        // Enable continuous updates
        textField.isContinuous = true

        #if DEBUG
        print("MacTextField: Created text field with placeholder '\(placeholder)'")
        #endif

        return textField
    }

    func updateNSView(_ nsView: FocusableTextField, context: Context) {
        // IMPORTANT: Update coordinator's parent reference to get latest binding
        context.coordinator.parent = self
        
        // Re-attach delegate to ensure it's connected
        if nsView.delegate !== context.coordinator {
            nsView.delegate = context.coordinator
            #if DEBUG
            print("MacTextField: Re-attached delegate")
            #endif
        }
        
        // Only update text if it's different to avoid cursor jumping
        if nsView.stringValue != text {
            #if DEBUG
            print("MacTextField: Updating view from '\(nsView.stringValue)' to '\(text)'")
            #endif
            nsView.stringValue = text
        }

        // Handle first responder
        if isFirstResponder {
            nsView.needsFocus = true
            // Trigger focus on next run loop
            DispatchQueue.main.async {
                nsView.attemptFocus()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextField

        init(_ parent: MacTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            let newValue = textField.stringValue
            
            #if DEBUG
            if parent.text != newValue {
                print("MacTextField: Text changed from '\(parent.text)' to '\(newValue)'")
            }
            #endif
            
            parent.text = newValue
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
