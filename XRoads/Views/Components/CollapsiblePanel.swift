//
//  CollapsiblePanel.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-015: Collapsible panel component for chat sidebar integration
//

import SwiftUI

// MARK: - CollapsiblePanel

/// A collapsible panel that can be shown/hidden with animation
/// Used for the orchestrator chat panel in the dashboard layout
struct CollapsiblePanel<Content: View>: View {
    /// Whether the panel is currently visible
    @Binding var isExpanded: Bool

    /// The width of the panel when expanded
    let expandedWidth: CGFloat

    /// The minimum width when resizing
    let minWidth: CGFloat

    /// The maximum width when resizing
    let maxWidth: CGFloat

    /// Whether to show a resize handle
    let resizable: Bool

    /// The edge the panel is attached to
    let edge: Edge

    /// Current width (for resizable panels)
    @Binding var width: CGFloat

    /// The content to display inside the panel
    @ViewBuilder let content: () -> Content

    @State private var isDragging: Bool = false

    init(
        isExpanded: Binding<Bool>,
        width: Binding<CGFloat>,
        expandedWidth: CGFloat = 360,
        minWidth: CGFloat = 280,
        maxWidth: CGFloat = 500,
        resizable: Bool = true,
        edge: Edge = .leading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self._width = width
        self.expandedWidth = expandedWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.resizable = resizable
        self.edge = edge
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) {
            if edge == .trailing {
                resizeHandle
            }

            content()
                .frame(width: isExpanded ? width : 0)
                .clipped()

            if edge == .leading {
                resizeHandle
            }
        }
        .frame(width: isExpanded ? width + (resizable ? 6 : 0) : 0)
        .animation(.easeInOut(duration: Theme.Animation.normal), value: isExpanded)
    }

    // MARK: - Resize Handle

    @ViewBuilder
    private var resizeHandle: some View {
        if resizable && isExpanded {
            Rectangle()
                .fill(isDragging ? Color.accentPrimary : Color.borderMuted)
                .frame(width: 6)
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDragging = true
                            let delta = edge == .leading ? value.translation.width : -value.translation.width
                            let newWidth = width + delta
                            width = min(max(newWidth, minWidth), maxWidth)
                        }
                        .onEnded { _ in
                            isDragging = false
                            // Save the width preference
                            UserDefaults.standard.set(width, forKey: UserDefaults.Keys.chatPanelWidth)
                        }
                )
        }
    }
}

// MARK: - CollapsiblePanelState

/// Manages the state for a collapsible panel with persistence
@MainActor
final class CollapsiblePanelState: ObservableObject {
    /// Whether the panel is expanded
    @Published var isExpanded: Bool {
        didSet {
            UserDefaults.standard.set(isExpanded, forKey: persistenceKey)
        }
    }

    /// Current panel width
    @Published var width: CGFloat {
        didSet {
            UserDefaults.standard.set(width, forKey: widthKey)
        }
    }

    private let persistenceKey: String
    private let widthKey: String
    private let defaultWidth: CGFloat

    init(
        persistenceKey: String,
        defaultExpanded: Bool = true,
        defaultWidth: CGFloat = 360
    ) {
        self.persistenceKey = persistenceKey
        self.widthKey = "\(persistenceKey).width"
        self.defaultWidth = defaultWidth

        // Load persisted state
        if UserDefaults.standard.object(forKey: persistenceKey) != nil {
            self.isExpanded = UserDefaults.standard.bool(forKey: persistenceKey)
        } else {
            self.isExpanded = defaultExpanded
        }

        if UserDefaults.standard.object(forKey: widthKey) != nil {
            self.width = CGFloat(UserDefaults.standard.double(forKey: widthKey))
        } else {
            self.width = defaultWidth
        }
    }

    func toggle() {
        withAnimation(.easeInOut(duration: Theme.Animation.normal)) {
            isExpanded.toggle()
        }
    }

    func expand() {
        withAnimation(.easeInOut(duration: Theme.Animation.normal)) {
            isExpanded = true
        }
    }

    func collapse() {
        withAnimation(.easeInOut(duration: Theme.Animation.normal)) {
            isExpanded = false
        }
    }

    func resetWidth() {
        withAnimation {
            width = defaultWidth
        }
        UserDefaults.standard.set(defaultWidth, forKey: widthKey)
    }
}

// MARK: - Preview

#if DEBUG
struct CollapsiblePanel_Previews: PreviewProvider {
    static var previews: some View {
        CollapsiblePanelPreviewWrapper()
            .frame(width: 800, height: 600)
    }

    struct CollapsiblePanelPreviewWrapper: View {
        @State private var isExpanded = true
        @State private var width: CGFloat = 360

        var body: some View {
            HStack(spacing: 0) {
                CollapsiblePanel(
                    isExpanded: $isExpanded,
                    width: $width,
                    edge: .leading
                ) {
                    VStack {
                        Text("Chat Panel")
                            .font(.h1)
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Button("Toggle") {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.bgSurface)
                }

                VStack {
                    Text("Main Content")
                        .font(.h1)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    HStack {
                        Button("Show Panel") {
                            withAnimation {
                                isExpanded = true
                            }
                        }
                        Button("Hide Panel") {
                            withAnimation {
                                isExpanded = false
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgApp)
            }
            .preferredColorScheme(.dark)
        }
    }
}
#endif
