import Combine
import Foundation

public typealias ValueSubject<Value> = CurrentValueSubject<Value, Never>
public typealias ValuePublisher<Value> = AnyPublisher<Value, Never>

#if swift(>=6.0)
public protocol Storage<Value>: AnyObject, Sendable, ObservableObject {
    associatedtype Value

    var eventier: ValuePublisher<Value> { get }
    var value: Value { get set }

    func sink(receiveValue: @escaping @Sendable (Value) -> Void) -> AnyCancellable
}
#else
public protocol Storage<Value>: AnyObject, ObservableObject {
    associatedtype Value

    var eventier: ValuePublisher<Value> { get }
    var value: Value { get set }

    func sink(receiveValue: @escaping (Value) -> Void) -> AnyCancellable
}
#endif

public extension Storage {
    func sink(receiveValue: @escaping (Value) -> Void) -> AnyCancellable {
        return eventier.sink(receiveValue: receiveValue)
    }

    func combine<S: Storage>(_ a: S) -> some Storage<Value>
    where S.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), a.toAny()])
    }

    func combine<S1: Storage, S2: Storage>(_ s1: S1, s2: S2) -> some Storage<Value>
    where S1.Value == Value, S2.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), s1.toAny(), s2.toAny()])
    }

    func combine<S1: Storage, S2: Storage, S3: Storage>(_ s1: S1, s2: S2, s3: S3) -> some Storage<Value>
    where S1.Value == Value, S2.Value == Value, S3.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), s1.toAny(), s2.toAny(), s3.toAny()])
    }

    func combine<S1: Storage, S2: Storage, S3: Storage, S4: Storage>(_ s1: S1, s2: S2, s3: S3, s4: S4) -> some Storage<Value>
    where S1.Value == Value, S2.Value == Value, S3.Value == Value, S4.Value == Value, Value: ExpressibleByNilLiteral & Equatable {
        return StorageComposition(storages: [toAny(), s1.toAny(), s2.toAny(), s3.toAny(), s4.toAny()])
    }
}

@available(macOS 13, iOS 16, tvOS 16.0, watchOS 9.0, *)
@inline(__always)
public func zip<Value>(storages: [any Storage<Value>]) -> some Storage<Value>
where Value: ExpressibleByNilLiteral & Equatable {
    return StorageComposition(storages: storages).toAny()
}

@available(macOS, deprecated: 13)
@available(iOS, deprecated: 16)
@inline(__always)
public func zip<Value>(storages: [AnyStorage<Value>]) -> some Storage<Value>
where Value: ExpressibleByNilLiteral & Equatable {
    return StorageComposition(storages: storages).toAny()
}
