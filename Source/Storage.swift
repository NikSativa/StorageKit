import Combine
import Foundation

/// A subject that emits values of type `Value` and never fails.
///
/// This is a type-safe alias for `CurrentValueSubject<Value, Never>`, commonly used in reactive storage.
public typealias ValueSubject<Value> = CurrentValueSubject<Value, Never>

/// A type-erased publisher that emits values of type `Value` and never fails.
///
/// This is a common output type for observing storage value changes.
public typealias ValuePublisher<Value> = AnyPublisher<Value, Never>

#if swift(>=6.0)
/// A protocol that defines a reactive storage interface for reading and writing values.
///
/// `Storage` abstracts the concept of value persistence with support for Combine-based observation.
/// It defines a consistent API for reading, writing, and reacting to value changes.
///
/// - Note: This protocol conforms to `Sendable` starting in Swift 6.0.
/// - Important: All implementations must be reference types (`AnyObject`) to ensure identity semantics.
public protocol Storage<Value>: AnyObject, Sendable, ObservableObject {
    associatedtype Value

    /// A Combine publisher that emits the current value and all future updates.
    ///
    /// Use this to observe value changes reactively.
    var eventier: ValuePublisher<Value> { get }

    /// The currently stored value.
    ///
    /// Assigning to this property updates the storage and notifies observers.
    var value: Value { get set }

    /// Subscribes to value updates and receives them via the provided closure.
    ///
    /// - Parameter receiveValue: A closure that receives each emitted value.
    /// - Returns: An `AnyCancellable` that can be used to cancel the subscription.
    func sink(receiveValue: @escaping @Sendable (Value) -> Void) -> AnyCancellable
}
#else
/// A protocol that defines the interface for storing and retrieving values.
/// Storage implementations provide a way to persist and observe changes to values.
///
/// The protocol combines Combine's `ObservableObject` with a value storage mechanism,
/// allowing for reactive updates when values change.
public protocol Storage<Value>: AnyObject, ObservableObject {
    associatedtype Value

    /// A publisher that emits the current value and any subsequent changes.
    var eventier: ValuePublisher<Value> { get }

    /// The current value stored in the storage.
    var value: Value { get set }

    /// Subscribes to value changes and returns a cancellable subscription.
    /// - Parameter receiveValue: A closure that is called with the new value whenever it changes.
    /// - Returns: A cancellable subscription that can be used to stop receiving updates.
    func sink(receiveValue: @escaping (Value) -> Void) -> AnyCancellable
}
#endif

public extension Storage {
    /// Default implementation of `sink(receiveValue:)` that forwards to the `eventier` publisher.
    func sink(receiveValue: @escaping (Value) -> Void) -> AnyCancellable {
        return eventier.sink(receiveValue: receiveValue)
    }

    /// Combines this storage with other storages to form a unified storage.
    ///
    /// The resulting storage synchronizes values across all underlying storages.
    ///
    /// - Parameters: One or more storages to combine with.
    /// - Returns: A new storage that integrates the provided storages.
    /// - Note: The value type must conform to both `ExpressibleByNilLiteral` and `Equatable`.
    func combine<S: Storage>(_ a: S) -> some Storage<Value>
    where S.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), a.toAny()])
    }

    /// Combines this storage with other storages to form a unified storage.
    ///
    /// The resulting storage synchronizes values across all underlying storages.
    ///
    /// - Parameters: One or more storages to combine with.
    /// - Returns: A new storage that integrates the provided storages.
    /// - Note: The value type must conform to both `ExpressibleByNilLiteral` and `Equatable`.
    func combine<S1: Storage, S2: Storage>(_ s1: S1, s2: S2) -> some Storage<Value>
    where S1.Value == Value, S2.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), s1.toAny(), s2.toAny()])
    }

    /// Combines this storage with other storages to form a unified storage.
    ///
    /// The resulting storage synchronizes values across all underlying storages.
    ///
    /// - Parameters: One or more storages to combine with.
    /// - Returns: A new storage that integrates the provided storages.
    /// - Note: The value type must conform to both `ExpressibleByNilLiteral` and `Equatable`.
    func combine<S1: Storage, S2: Storage, S3: Storage>(_ s1: S1, s2: S2, s3: S3) -> some Storage<Value>
    where S1.Value == Value, S2.Value == Value, S3.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), s1.toAny(), s2.toAny(), s3.toAny()])
    }

    /// Combines this storage with other storages to form a unified storage.
    ///
    /// The resulting storage synchronizes values across all underlying storages.
    ///
    /// - Parameters: One or more storages to combine with.
    /// - Returns: A new storage that integrates the provided storages.
    /// - Note: The value type must conform to both `ExpressibleByNilLiteral` and `Equatable`.
    func combine<S1: Storage, S2: Storage, S3: Storage, S4: Storage>(_ s1: S1, s2: S2, s3: S3, s4: S4) -> some Storage<Value>
    where S1.Value == Value, S2.Value == Value, S3.Value == Value, S4.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), s1.toAny(), s2.toAny(), s3.toAny(), s4.toAny()])
    }
}

/// Combines multiple storages into a unified storage instance.
///
/// Use this to group and synchronize values across multiple storage layers.
/// Available on iOS 16.0+, macOS 13+, tvOS 16.0+, and watchOS 9.0+.
///
/// - Parameter storages: An array of storages to combine.
/// - Returns: A new `Storage` that reflects the combined state.
@available(macOS 13, iOS 16, tvOS 16.0, watchOS 9.0, *)
@inline(__always)
public func zip<Value: ExpressibleByNilLiteral & Equatable>(storages: [any Storage<Value>]) -> some Storage<Value> {
    return StorageComposition(storages: storages).toAny()
}

/// Combines multiple type-erased storages into a unified storage instance.
///
/// - Parameter storages: An array of `AnyStorage` instances to combine.
/// - Returns: A new `Storage` that reflects the combined state.
/// - Important: Deprecated in iOS 16.0 and later. Use the non-deprecated version with `any Storage<Value>`.
@available(macOS, deprecated: 13)
@available(iOS, deprecated: 16)
@inline(__always)
public func zip<Value: ExpressibleByNilLiteral & Equatable>(storages: [AnyStorage<Value>]) -> some Storage<Value> {
    return StorageComposition(storages: storages).toAny()
}
