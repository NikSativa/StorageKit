import Foundation

/// A type-erased wrapper for any storage instance.
///
/// `AnyStorage` allows you to abstract over different `Storage` implementations
/// while maintaining a consistent interface for value access and observation.
public final class AnyStorage<Value>: Storage {
    private let _get: () -> Value
    private let _set: (Value) -> Void
    private let _publisher: () -> ValuePublisher<Value>

    /// The current value in the storage.
    ///
    /// Assigning a new value propagates it to the underlying storage.
    /// Reading returns the most recent stored value.
    public var value: Value {
        get {
            return _get()
        }
        set {
            objectWillChange.send()
            _set(newValue)
        }
    }

    /// Creates a type-erased storage from the given base storage.
    ///
    /// - Parameter base: A concrete storage instance to wrap.
    public init<U: Storage>(_ base: U) where U.Value == Value {
        self._get = {
            return base.value
        }

        self._set = {
            base.value = $0
        }

        self._publisher = {
            return base.eventier
        }
    }

    /// A publisher that emits the current value and all future changes.
    ///
    /// Delegates to the underlying storage's Combine publisher.
    public var eventier: ValuePublisher<Value> {
        return _publisher()
    }
}

/// Extension to convert any `Storage` instance into a type-erased `AnyStorage`.
public extension Storage {
    /// Converts the current storage to a type-erased `AnyStorage`.
    ///
    /// - Returns: An `AnyStorage` instance wrapping the current storage.
    /// - Note: If the storage is already type-erased, it is returned directly.
    func toAny() -> AnyStorage<Value> {
        if let self = self as? AnyStorage<Value> {
            return self
        }

        return AnyStorage(self)
    }
}

#if swift(>=6.0)
extension AnyStorage: @unchecked Sendable {}
#endif
