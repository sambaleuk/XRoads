---
name: swift-language
description: Swift 5.x fundamentals including syntax, optionals, closures, generics, protocols, extensions, and error handling. Use when learning Swift basics, writing Swift code, understanding Swift patterns, or building macOS/iOS apps. Covers value vs reference types, collections, functions, enums, structs, classes, and modern Swift features. Includes macOS-specific patterns (AppKit interop, window management, menu bars).
---

# Swift Language Fundamentals

Master Swift 5.x language fundamentals for building macOS and iOS applications.

## Quick Start

### New to Swift?
1. Read [fundamentals.md](references/fundamentals.md) for core language concepts
2. For macOS apps, see [macos-specifics.md](references/macos-specifics.md)
3. Use the model generator script to create data models quickly

### Common Tasks

**Generate a data model:**
```bash
python3 scripts/generate_model.py --name User --properties "name:String,age:Int,email:String?"
```

**Start a new macOS app:**
Use the template in `assets/macos-app-template.swift` as a starting point.

## When to Use This Skill

Trigger this skill when:
- Writing or learning Swift code
- Understanding Swift syntax, optionals, closures, protocols
- Creating data models with Codable
- Building macOS apps with SwiftUI
- Questions about Swift language features
- Need Swift code templates or boilerplate

## Core Concepts Overview

### 1. Optionals & Safety
Swift uses optionals to handle absence of values safely, preventing null pointer crashes.

```swift
var email: String?  // Can be String or nil

// Safe unwrapping (recommended)
if let email = email {
    print("Email: \(email)")
}

// Guard statement (early exit pattern)
guard let email = email else {
    return
}

// Nil coalescing (provide default)
let displayEmail = email ?? "No email"
```

**Key principle**: Use `let` by default, `var` only when mutation is needed.

### 2. Value vs Reference Types

**Structs (value types)** - Copied when assigned
```swift
struct Person {
    var name: String
    var age: Int
}

var person1 = Person(name: "Alice", age: 25)
var person2 = person1  // Copy created
person2.age = 26       // person1.age still 25
```

**Classes (reference types)** - Passed by reference
```swift
class Account {
    var balance: Double
    init(balance: Double) {
        self.balance = balance
    }
}

let account1 = Account(balance: 100)
let account2 = account1  // Same reference
account2.balance = 200   // account1.balance also 200
```

**When to use which:**
- Structs: Default choice, data models, value semantics
- Classes: When you need inheritance, reference semantics, or OOP patterns

### 3. Protocols & Extensions

Protocols define contracts; extensions add functionality.

```swift
protocol Drawable {
    func draw()
}

struct Circle: Drawable {
    var radius: Double

    func draw() {
        print("Drawing circle with radius \(radius)")
    }
}

// Add functionality to existing types
extension String {
    var isEmail: Bool {
        return self.contains("@")
    }
}

"test@example.com".isEmail  // true
```

### 4. Closures & Functional Programming

```swift
// Closure syntax
let multiply: (Int, Int) -> Int = { $0 * $1 }

// Higher-order functions
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map { $0 * 2 }        // [2, 4, 6, 8, 10]
let evens = numbers.filter { $0 % 2 == 0 }  // [2, 4]
let sum = numbers.reduce(0, +)              // 15

// Trailing closure syntax
UIView.animate(withDuration: 0.3) {
    view.alpha = 0
}
```

### 5. Error Handling

```swift
enum NetworkError: Error {
    case badURL
    case noConnection
}

func fetchData(from url: String) throws -> Data {
    guard url.starts(with: "https://") else {
        throw NetworkError.badURL
    }
    // Fetch data...
    return Data()
}

// Handle errors
do {
    let data = try fetchData(from: "invalid")
} catch NetworkError.badURL {
    print("Invalid URL")
} catch {
    print("Other error: \(error)")
}

// Try? returns optional (nil on error)
let data = try? fetchData(from: "https://api.example.com")
```

## macOS Development Patterns

### Basic App Structure

```swift
import SwiftUI

@main
struct MyMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Actions") {
                Button("Do Something") {
                    // Action
                }
                .keyboardShortcut("d", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
```

### Sidebar Navigation

```swift
NavigationView {
    // Sidebar
    List(selection: $selection) {
        NavigationLink("Home", tag: "home", selection: $selection) {
            HomeView()
        }
        NavigationLink("Settings", tag: "settings", selection: $selection) {
            SettingsView()
        }
    }
    .listStyle(.sidebar)

    // Detail view
    Text("Select an item")
}
```

### File Operations

```swift
// Open file picker
let panel = NSOpenPanel()
panel.allowedContentTypes = [.text, .json]
if panel.runModal() == .OK, let url = panel.url {
    let content = try? String(contentsOf: url)
}

// Save file picker
let panel = NSSavePanel()
panel.allowedContentTypes = [.text]
if panel.runModal() == .OK, let url = panel.url {
    try? content.write(to: url, atomically: true, encoding: .utf8)
}
```

## Resources

### references/
- **fundamentals.md** - Complete Swift language reference (variables, optionals, collections, functions, closures, enums, structs, classes, protocols, extensions, generics, error handling, property wrappers, common patterns)
- **macos-specifics.md** - macOS-specific development (SwiftUI vs AppKit, window management, menu bars, toolbars, sidebars, file operations, preferences, keyboard shortcuts, sandboxing, AppKit interop, status bar apps, alerts, drag & drop)

Read these files when you need detailed information about specific Swift features or macOS patterns.

### scripts/
- **generate_model.py** - Generate Swift struct models with Codable conformance from property specifications

Example:
```bash
# Basic model
python3 scripts/generate_model.py --name User --properties "name:String,age:Int,email:String?"

# With Identifiable
python3 scripts/generate_model.py --name Product --properties "id:UUID,name:String,price:Double" --identifiable

# Include example usage
python3 scripts/generate_model.py --name Config --properties "apiKey:String,timeout:Int" --example
```

### assets/
- **macos-app-template.swift** - Complete macOS app template with sidebar navigation, menu commands, settings window, and best practices. Copy and customize for new projects.

## Common Patterns & Best Practices

### Property Observers
```swift
struct User {
    var name: String {
        didSet {
            print("Name changed to \(name)")
        }
    }
}
```

### Computed Properties
```swift
struct Rectangle {
    var width: Double
    var height: Double

    var area: Double {
        return width * height
    }
}
```

### Type Aliases
```swift
typealias Coordinate = (x: Double, y: Double)
let point: Coordinate = (x: 10, y: 20)
```

### Result Type
```swift
func loadUser(id: Int) -> Result<User, Error> {
    if success {
        return .success(user)
    } else {
        return .failure(error)
    }
}
```

### Guard-Let Early Exit
```swift
func process(user: User?) {
    guard let user = user else {
        return
    }
    // Continue with unwrapped user
}
```

### Defer Statement
```swift
func processFile() {
    let file = openFile()
    defer {
        closeFile(file)  // Always executed before return
    }
    // Process file...
}
```

## Next Steps

After mastering Swift fundamentals:
1. **swift-concurrency** - async/await, actors, structured concurrency
2. **memory-management** - ARC, retain cycles, weak/unowned references
3. **swiftui** - Building modern declarative UIs
4. **mvvm-architecture** - Structuring larger applications

## Learning Path for Beginners

1. **Start here**: Variables, constants, optionals, basic types
2. **Collections**: Arrays, dictionaries, sets, iteration
3. **Functions**: Parameters, return values, closures
4. **Structs & Classes**: Value vs reference types
5. **Protocols & Extensions**: Protocol-oriented programming
6. **Error Handling**: Throwing and catching errors
7. **Generics**: Writing flexible, reusable code
8. **macOS UI**: SwiftUI basics, navigation, file operations
