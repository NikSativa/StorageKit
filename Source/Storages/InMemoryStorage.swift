import Combine
import Foundation

/// A storage backend that retains values in memory only, without persistent storage.
///
/// `InMemoryStorage` provides a lightweight solution for temporary or test values.
/// It supports observation via Combine and is suitable for scenarios where persistence is not needed.
///
/// The value is stored in RAM and reset when the application restarts.
public final class InMemoryStorage<Value>: Storage {
    private lazy var subject: CurrentValueSubject<Value, Never> = .init(value)
    /// A publisher that emits the current value and all future changes.
    ///
    /// This publisher reflects updates to the stored value and supports reactive bindings.
    public private(set) lazy var eventier: AnyPublisher<Value, Never> = subject.eraseToAnyPublisher()

    /// The current value stored in memory.
    ///
    /// Assigning a new value triggers observers and updates the published stream.
    public var value: Value {
        willSet {
            objectWillChange.send()
        }
        didSet {
            subject.send(value)
        }
    }

    /// Creates an in-memory storage instance with an initial value.
    ///
    /// - Parameter value: The value to store.
    public init(value: Value) {
        self.value = value
    }
}

/// Convenience initializer for optional or nil-literal-compatible types.
///
/// This initializer sets the initial value to `nil`.
public extension InMemoryStorage where Value: ExpressibleByNilLiteral {
    convenience init() {
        self.init(value: nil)
    }
}

/// Convenience initializer for array literal values with an empty array default.
public extension InMemoryStorage where Value: ExpressibleByArrayLiteral {
    convenience init() {
        self.init(value: [])
    }
}

/// Convenience initializer for dictionary literal values with an empty dictionary default.
public extension InMemoryStorage where Value: ExpressibleByDictionaryLiteral {
    convenience init() {
        self.init(value: [:])
    }
}

/// Convenience initializer for boolean literal values with `false` default.
public extension InMemoryStorage where Value: ExpressibleByBooleanLiteral {
    convenience init() {
        self.init(value: false)
    }
}

#if swift(>=6.0)
extension InMemoryStorage: @unchecked Sendable {}
#endif
