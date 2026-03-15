import Combine
import Foundation

/// A property wrapper that forwards reads and writes to a storage backend.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
@propertyWrapper
public struct Stored<Value> {
    private let base: AnyStorage<Value>

    /// The current value from the underlying storage.
    public var wrappedValue: Value {
        get {
            base.value
        }
        set {
            base.value = newValue
        }
    }

    /// A publisher that emits storage value updates.
    public var projectedValue: AnyPublisher<Value, Never> {
        return base.eventier
    }

    /// Creates a wrapper from a type-erased storage.
    ///
    /// - Parameter base: The underlying storage.
    public init(any base: AnyStorage<Value>) {
        self.base = base
    }

    /// Creates a wrapper from a storage implementation.
    ///
    /// - Parameter base: The underlying storage.
    public init(base: any Storage<Value>) {
        self.base = base.toAny()
    }

    /// Creates a wrapper that synchronizes multiple storages.
    ///
    /// - Parameter base: Storages to combine into one synchronized storage.
    public init(storages base: [any Storage<Value>]) throws
        where Value: ExpressibleByNilLiteral & Equatable {
        self.base = try zip(storages: base).toAny()
    }
}

#if swift(>=6.0)
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Stored: @unchecked Sendable {}
#endif
