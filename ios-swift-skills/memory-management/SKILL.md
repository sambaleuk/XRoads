---
name: memory-management
description: Swift memory management with ARC (Automatic Reference Counting), preventing retain cycles, and debugging memory leaks. Use when dealing with strong/weak/unowned references, closures capturing self, delegate patterns, timers, or when debugging memory leaks. Covers reference types vs value types, retain cycles, capture lists, and tools like Memory Graph Debugger and Instruments Leaks.
---

# Memory Management - ARC & Retain Cycles

Master Swift's automatic memory management and prevent memory leaks.

## Quick Start

### New to ARC?
1. Read [arc-basics.md](references/arc-basics.md) for ARC fundamentals
2. Read [debugging-leaks.md](references/debugging-leaks.md) for leak detection

### Common Issues

**Fix retain cycle in closure:**
```swift
// ❌ Leak
onComplete = {
    self.doSomething()
}

// ✅ Fixed
onComplete = { [weak self] in
    self?.doSomething()
}
```

**Fix delegate retain cycle:**
```swift
// ✅ Always weak
protocol MyDelegate: AnyObject { }
weak var delegate: MyDelegate?
```

## When to Use This Skill

Trigger this skill when:
- Debugging memory leaks or high memory usage
- Understanding strong/weak/unowned references
- Fixing retain cycles in closures
- Implementing delegate patterns
- Working with timers or observers
- Objects not being deallocated (deinit not called)
- Questions about ARC or memory management

## Core Concepts

### 1. ARC - Automatic Reference Counting

ARC automatically manages memory for **reference types** (classes) by counting references.

```swift
class Person {
    let name: String
    init(name: String) { self.name = name }
    deinit { print("\(name) désalloué") }
}

var person1: Person? = Person(name: "Alice")  // RC: 1
var person2 = person1   // RC: 2
var person3 = person1   // RC: 3

person1 = nil  // RC: 2
person2 = nil  // RC: 1
person3 = nil  // RC: 0 → Désallocation
// Output: "Alice désalloué"
```

### 2. Reference Types

| Type | Description | When to Use |
|------|-------------|-------------|
| **strong** | Default, increments reference count | Ownership |
| **weak** | Doesn't increment count, becomes nil | Optional references |
| **unowned** | Doesn't increment count, never nil | Guaranteed references |

### 3. Retain Cycles - The Problem

Two objects holding strong references to each other prevent deallocation.

```swift
// ❌ Retain Cycle
class Person {
    var apartment: Apartment?  // Strong
}

class Apartment {
    var tenant: Person?  // Strong
}

var john: Person? = Person()
var unit: Apartment? = Apartment()

john?.apartment = unit
unit?.tenant = john  // ❌ Cycle!

john = nil
unit = nil
// ❌ Nothing deallocated!
```

**Solution: Break cycle with weak:**

```swift
class Apartment {
    weak var tenant: Person?  // ✅ weak!
}

// Now properly deallocates
```

### 4. Closures and [weak self]

Closures capture references strongly by default.

```swift
// ❌ Retain cycle
class ViewController {
    var onTap: (() -> Void)?

    func setup() {
        onTap = {
            self.doSomething()  // ❌ self → closure → self
        }
    }
}

// ✅ Fixed with [weak self]
class ViewController {
    var onTap: (() -> Void)?

    func setup() {
        onTap = { [weak self] in
            guard let self = self else { return }
            self.doSomething()  // ✅
        }
    }
}
```

## Common Patterns

### Pattern: Delegate (Always weak)

```swift
protocol DataSourceDelegate: AnyObject {
    func didUpdate()
}

class DataSource {
    weak var delegate: DataSourceDelegate?  // ✅ Always weak!
}
```

### Pattern: Parent-Child

```swift
class Parent {
    var children: [Child] = []  // Strong - parent owns children
}

class Child {
    weak var parent: Parent?  // ✅ weak - child doesn't own parent
}
```

### Pattern: Timer (Must invalidate!)

```swift
class TimerManager {
    var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()  // ✅ weak self
        }
    }

    deinit {
        timer?.invalidate()  // ✅ CRITICAL!
        timer = nil
    }
}
```

### Pattern: NotificationCenter

```swift
class Observer {
    init() {
        NotificationCenter.default.addObserver(...)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)  // ✅ Always remove!
    }
}
```

### Pattern: Async/Await

```swift
class DataLoader {
    func load() {
        Task { [weak self] in  // ✅ weak if needed
            guard let self = self else { return }
            let data = await self.fetchData()
            await self.process(data)
        }
    }
}
```

## Debugging Memory Leaks

### Tool 1: deinit Logging

```swift
class MyClass {
    deinit {
        print("✅ MyClass désalloué")
    }
}

// If never printed → Memory leak!
```

### Tool 2: Memory Graph Debugger

1. Run app in Xcode
2. Click Debug Memory Graph icon
3. Look for objects that should be deallocated
4. Objects with `!` = retain cycle detected

### Tool 3: Instruments Leaks

1. Product → Profile (⌘I)
2. Choose "Leaks"
3. Run app
4. Leaks appear in red

## Common Mistakes

### ❌ Forgetting [weak self]

```swift
// ❌ Leak
api.fetch { data in
    self.process(data)  // Retain cycle!
}

// ✅ Fixed
api.fetch { [weak self] data in
    self?.process(data)
}
```

### ❌ Strong delegate

```swift
// ❌ Leak
var delegate: MyDelegate?  // Should be weak!

// ✅ Fixed
weak var delegate: MyDelegate?
```

### ❌ Not invalidating timers

```swift
// ❌ Leak
deinit {
    // Forgot timer?.invalidate()
}

// ✅ Fixed
deinit {
    timer?.invalidate()
}
```

## Quick Reference

### When to use each reference type:

**strong (default)**:
- You own the object
- No retain cycle risk

**weak**:
- Reference might become nil
- Delegates
- Parent references in child objects
- Breaking retain cycles

**unowned**:
- Reference guaranteed not nil
- Same or shorter lifetime
- Use sparingly (can crash!)

### Capture list syntax:

```swift
// Single weak capture
{ [weak self] in ... }

// Multiple captures
{ [weak self, weak manager] in ... }

// Unowned capture
{ [unowned self] in ... }
```

## Resources

### references/
- **arc-basics.md** - Complete ARC guide (strong/weak/unowned, retain cycles, closures, delegates, timers, observers, patterns, best practices)
- **debugging-leaks.md** - Leak detection guide (Memory Graph Debugger, Instruments, deinit logging, common leak patterns, debugging workflow, checklist)

Read these files when you need detailed information about memory management or debugging leaks.

## Checklist

Before shipping, verify:

✅ [weak self] in all closures capturing self
✅ Delegates are weak
✅ Timers invalidated in deinit
✅ Observers removed in deinit
✅ deinit called for all ViewControllers/ViewModels
✅ Memory Graph shows no unexpected objects
✅ Instruments Leaks shows no leaks

## Best Practices

1. **Default to [weak self]** in closures
2. **Always weak delegates**
3. **Always invalidate timers** in deinit
4. **Always remove observers** in deinit
5. **Add deinit logging** during development
6. **Test with Memory Graph** regularly
7. **Profile with Instruments** before release

## Next Steps

After mastering memory management:
1. **swift-concurrency** - Memory management with actors and async/await
2. **swiftui** - Memory management in SwiftUI apps
3. **combine** - Memory management with publishers
4. **instruments** - Advanced profiling techniques

## Key Takeaways

✅ **ARC** manages memory automatically for classes
✅ **Retain cycles** prevent deallocation
✅ **[weak self]** breaks cycles in closures
✅ **weak delegates** prevent cycles
✅ **Invalidate timers** and remove observers
✅ **Memory Graph** and **Instruments** detect leaks
✅ **deinit logging** confirms deallocation
✅ **Test early** to catch leaks before they compound
