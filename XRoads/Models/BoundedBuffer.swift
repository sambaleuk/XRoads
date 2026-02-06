import Foundation

// MARK: - BoundedBuffer

/// A FIFO buffer that automatically evicts the oldest elements when capacity is exceeded.
/// Used to prevent unbounded memory growth in long-running orchestration sessions (CR-001).
struct BoundedBuffer<Element> {
    private var storage: [Element]

    /// Maximum number of elements before FIFO eviction kicks in.
    let capacity: Int

    /// Creates an empty bounded buffer with the given capacity.
    init(capacity: Int) {
        precondition(capacity > 0, "BoundedBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = []
    }

    /// Creates a bounded buffer pre-filled with existing elements, evicting oldest if over capacity.
    init(capacity: Int, elements: [Element]) {
        precondition(capacity > 0, "BoundedBuffer capacity must be positive")
        self.capacity = capacity
        if elements.count > capacity {
            self.storage = Array(elements.suffix(capacity))
        } else {
            self.storage = elements
        }
    }

    // MARK: - Mutation

    /// Appends an element, evicting the oldest if at capacity.
    mutating func append(_ element: Element) {
        storage.append(element)
        evictIfNeeded()
    }

    /// Appends a sequence of elements, evicting the oldest if at capacity.
    mutating func append<S: Sequence>(contentsOf elements: S) where S.Element == Element {
        storage.append(contentsOf: elements)
        evictIfNeeded()
    }

    /// Inserts an element at the given position, evicting the oldest if at capacity.
    mutating func insert(_ element: Element, at index: Int) {
        storage.insert(element, at: index)
        evictIfNeeded()
    }

    /// Removes all elements from the buffer.
    mutating func removeAll() {
        storage.removeAll()
    }

    /// Removes the last `k` elements from the buffer.
    mutating func removeLast(_ k: Int) {
        storage.removeLast(k)
    }

    /// The number of elements currently in the buffer.
    var count: Int { storage.count }

    /// Whether the buffer is empty.
    var isEmpty: Bool { storage.isEmpty }

    /// The last element, if any.
    var last: Element? { storage.last }

    /// The first element, if any.
    var first: Element? { storage.first }

    /// Returns the contents as a plain Array.
    var elements: [Element] { storage }

    // MARK: - Private

    private mutating func evictIfNeeded() {
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }
}
