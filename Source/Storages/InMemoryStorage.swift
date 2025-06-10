import Foundation

/// A storage backend that retains values in memory only, without persistent storage.
///
/// `InMemoryStorage` provides a lightweight solution for temporary or test values.
/// It supports observation via Combine and is suitable for scenarios where persistence is not needed.
///
/// The value is stored in RAM and reset when the application restarts.
public final class InMemoryStorage<Value>: Storage {
    private lazy var subject: ValueSubject<Value> = .init(value)
    /// A publisher that emits the current value and all future changes.
    ///
    /// This publisher reflects updates to the stored value and supports reactive bindings.
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

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

#if swift(>=6.0)
extension InMemoryStorage: @unchecked Sendable {}
#endif
