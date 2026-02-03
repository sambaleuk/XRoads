---
name: swiftui
description: Modern declarative UI framework for macOS and iOS with @State, @Binding, @ObservableObject, navigation, lists, grids, and async integration. Use when building user interfaces, creating views, managing state, or working with SwiftUI components. Essential for modern macOS/iOS apps.
---

# SwiftUI - Declarative UI

Build modern, reactive user interfaces for macOS and iOS.

## Quick Start

Read [swiftui-essentials.md](references/swiftui-essentials.md) for all core concepts.

## Key Concepts

### State Management
- `@State` - Local view state
- `@StateObject` - ViewModel ownership
- `@ObservedObject` - Passed ViewModel
- `@Binding` - Two-way binding
- `@Published` - Observable properties

### Layouts
- `VStack`, `HStack`, `ZStack`
- `LazyVGrid`, `LazyHGrid`
- `List`, `ForEach`
- `ScrollView`

### Navigation
- `NavigationStack`
- `NavigationLink`
- `.sheet()`, `.alert()`

## For Maestro-like App

### Session Grid
```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
    ForEach(sessions) { session in
        SessionCard(session: session)
    }
}
```

### Terminal Output
```swift
ScrollView {
    Text(output)
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.green)
}
.background(Color.black)
```

### Status Indicator
```swift
HStack {
    Circle().fill(statusColor).frame(width: 8, height: 8)
    Text(status.rawValue)
}
```

## Resources

### references/
- **swiftui-essentials.md** - Complete guide (views, state, navigation, layouts, terminal UI, async, forms)

## Next Steps

Combine with:
1. **mvvm-architecture** - Structure your SwiftUI app
2. **swift-concurrency** - async operations in UI
3. **process-management** - Display process output
