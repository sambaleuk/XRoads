# Swift Language Fundamentals

## Variables & Constants

```swift
// Variables (mutable)
var name: String = "John"
var age = 25  // Type inference

// Constants (immutable) - Preferred when value won't change
let pi = 3.14159
let appName: String = "MyApp"
```

**Best practice**: Use `let` by default, only use `var` when mutation is necessary.

## Optionals

Optionals represent a value that might be absent. This prevents null pointer crashes.

```swift
// Declaration
var email: String?  // Can be String or nil
var age: Int? = nil

// Unwrapping methods
// 1. Optional binding (safe, recommended)
if let unwrappedEmail = email {
    print("Email: \(unwrappedEmail)")
} else {
    print("No email")
}

// 2. Guard statement (early exit)
guard let email = email else {
    print("No email provided")
    return
}
print("Email: \(email)")

// 3. Nil coalescing (provide default)
let displayEmail = email ?? "No email"

// 4. Optional chaining
let uppercasedEmail = email?.uppercased()

// 5. Force unwrapping (use sparingly, can crash!)
let forcedEmail = email!  // ⚠️ Crashes if nil
```

## String Interpolation

```swift
let name = "Alice"
let age = 30
let greeting = "Hello, \(name)! You are \(age) years old."

// Complex expressions
let message = "Next year you'll be \(age + 1)"
```

## Collections

### Arrays
```swift
// Declaration
var numbers: [Int] = [1, 2, 3, 4, 5]
var fruits = ["Apple", "Banana", "Orange"]

// Common operations
numbers.append(6)
numbers.insert(0, at: 0)
numbers.remove(at: 2)
let firstNumber = numbers.first  // Optional: Int?
let count = numbers.count

// Iteration
for number in numbers {
    print(number)
}

for (index, number) in numbers.enumerated() {
    print("\(index): \(number)")
}

// Functional methods
let doubled = numbers.map { $0 * 2 }
let evens = numbers.filter { $0 % 2 == 0 }
let sum = numbers.reduce(0, +)
```

### Dictionaries
```swift
// Declaration
var person: [String: Any] = [
    "name": "Bob",
    "age": 28,
    "isStudent": false
]

// Access (returns optional)
let name = person["name"] as? String
person["email"] = "bob@example.com"

// Iteration
for (key, value) in person {
    print("\(key): \(value)")
}
```

### Sets
```swift
var uniqueNumbers: Set<Int> = [1, 2, 3, 3, 4]  // Duplicates removed
uniqueNumbers.insert(5)
uniqueNumbers.contains(3)  // true
```

## Functions

```swift
// Basic function
func greet(name: String) -> String {
    return "Hello, \(name)!"
}

// Multiple parameters
func add(a: Int, b: Int) -> Int {
    return a + b
}

// No return value (Void)
func printMessage(message: String) {
    print(message)
}

// Argument labels
func greet(person name: String, from hometown: String) -> String {
    return "Hello \(name) from \(hometown)!"
}
// Call: greet(person: "Alice", from: "Paris")

// Default parameters
func increment(value: Int, by amount: Int = 1) -> Int {
    return value + amount
}

// Variadic parameters
func sum(numbers: Int...) -> Int {
    return numbers.reduce(0, +)
}

// Inout parameters (pass by reference)
func doubleValue(_ value: inout Int) {
    value *= 2
}
var number = 5
doubleValue(&number)  // number is now 10
```

## Closures

Closures are self-contained blocks of functionality (like lambdas or anonymous functions).

```swift
// Full syntax
let multiply = { (a: Int, b: Int) -> Int in
    return a * b
}

// Shorthand
let add: (Int, Int) -> Int = { $0 + $1 }

// As function parameters
func performOperation(a: Int, b: Int, operation: (Int, Int) -> Int) -> Int {
    return operation(a, b)
}

let result = performOperation(a: 5, b: 3, operation: { $0 + $1 })

// Trailing closure syntax
let doubled = [1, 2, 3].map { $0 * 2 }

// Capturing values
func makeIncrementer(incrementAmount: Int) -> () -> Int {
    var total = 0
    return {
        total += incrementAmount
        return total
    }
}

let incrementByTwo = makeIncrementer(incrementAmount: 2)
incrementByTwo()  // 2
incrementByTwo()  // 4
```

## Enumerations

```swift
// Simple enum
enum Direction {
    case north
    case south
    case east
    case west
}

let direction = Direction.north

// With associated values
enum NetworkResponse {
    case success(data: Data)
    case failure(error: Error)
}

// With raw values
enum StatusCode: Int {
    case ok = 200
    case notFound = 404
    case serverError = 500
}

// Pattern matching
switch direction {
case .north:
    print("Going north")
case .south:
    print("Going south")
default:
    print("Going east or west")
}
```

## Structures

```swift
struct Person {
    let name: String
    var age: Int

    // Computed property
    var isAdult: Bool {
        return age >= 18
    }

    // Method
    mutating func haveBirthday() {
        age += 1
    }

    // Static method
    static func random() -> Person {
        return Person(name: "Random", age: Int.random(in: 0...100))
    }
}

var person = Person(name: "Alice", age: 17)
print(person.isAdult)  // false
person.haveBirthday()
print(person.isAdult)  // true
```

**Key point**: Structs are **value types** (copied when assigned or passed).

## Classes

```swift
class Animal {
    let species: String
    var age: Int

    init(species: String, age: Int) {
        self.species = species
        self.age = age
    }

    func makeSound() {
        print("Some generic sound")
    }
}

class Dog: Animal {
    let breed: String

    init(breed: String, age: Int) {
        self.breed = breed
        super.init(species: "Canine", age: age)
    }

    override func makeSound() {
        print("Woof!")
    }
}

let dog = Dog(breed: "Golden Retriever", age: 3)
dog.makeSound()  // "Woof!"
```

**Key point**: Classes are **reference types** (passed by reference, not copied).

## Protocols

Protocols define a blueprint of methods, properties, and requirements.

```swift
protocol Drawable {
    var color: String { get set }
    func draw()
}

struct Circle: Drawable {
    var color: String
    var radius: Double

    func draw() {
        print("Drawing a \(color) circle with radius \(radius)")
    }
}

// Protocol as type
func render(shape: Drawable) {
    shape.draw()
}

// Protocol composition
protocol Named {
    var name: String { get }
}

func describe(item: Drawable & Named) {
    print("\(item.name) with color \(item.color)")
}
```

## Extensions

Add functionality to existing types without inheritance.

```swift
extension String {
    var isEmail: Bool {
        return self.contains("@")
    }

    func reversedString() -> String {
        return String(self.reversed())
    }
}

"test@example.com".isEmail  // true
"Hello".reversedString()    // "olleH"

// Conform to protocol via extension
extension Int: Drawable {
    var color: String {
        get { "numeric" }
        set { }
    }

    func draw() {
        print("Drawing number: \(self)")
    }
}
```

## Generics

Write flexible, reusable functions and types that work with any type.

```swift
// Generic function
func swap<T>(_ a: inout T, _ b: inout T) {
    let temp = a
    a = b
    b = temp
}

// Generic type
struct Stack<Element> {
    private var items: [Element] = []

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element? {
        return items.popLast()
    }
}

var intStack = Stack<Int>()
intStack.push(1)
intStack.push(2)

// Type constraints
func findIndex<T: Equatable>(of value: T, in array: [T]) -> Int? {
    for (index, item) in array.enumerated() {
        if item == value {
            return index
        }
    }
    return nil
}
```

## Error Handling

```swift
enum NetworkError: Error {
    case badURL
    case noConnection
    case timeout
}

// Throwing function
func fetchData(from url: String) throws -> Data {
    guard url.starts(with: "https://") else {
        throw NetworkError.badURL
    }
    // Fetch data...
    return Data()
}

// Calling throwing functions
do {
    let data = try fetchData(from: "invalid")
    print("Data received")
} catch NetworkError.badURL {
    print("Invalid URL")
} catch {
    print("Other error: \(error)")
}

// Try? (returns optional)
let data = try? fetchData(from: "https://api.example.com")

// Try! (force try, crashes on error)
let forcedData = try! fetchData(from: "https://api.example.com")
```

## Property Wrappers

```swift
@propertyWrapper
struct Clamped {
    private var value: Int
    private let range: ClosedRange<Int>

    var wrappedValue: Int {
        get { value }
        set { value = min(max(range.lowerBound, newValue), range.upperBound) }
    }

    init(wrappedValue: Int, _ range: ClosedRange<Int>) {
        self.range = range
        self.value = min(max(range.lowerBound, wrappedValue), range.upperBound)
    }
}

struct Game {
    @Clamped(0...100) var health = 100
}

var game = Game()
game.health = 150  // Clamped to 100
game.health = -10  // Clamped to 0
```

## Common Swift Patterns

### Result Type
```swift
func loadUser(id: Int) -> Result<User, Error> {
    // Load user...
    if success {
        return .success(user)
    } else {
        return .failure(error)
    }
}

switch loadUser(id: 1) {
case .success(let user):
    print("Loaded user: \(user.name)")
case .failure(let error):
    print("Error: \(error)")
}
```

### Guard-Let Pattern
```swift
func processUser(user: User?) {
    guard let user = user else {
        print("No user provided")
        return
    }

    // Continue with unwrapped user
    print(user.name)
}
```

### Defer Statement
```swift
func processFile() {
    let file = openFile()
    defer {
        closeFile(file)  // Always executed before function exits
    }

    // Process file...
    if error {
        return  // File still closed thanks to defer
    }
}
```
