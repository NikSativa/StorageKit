import Foundation

@propertyWrapper
public struct Stored<Value> {
    private let base: AnyStorage<Value>

    public var wrappedValue: Value {
        get {
            base.value
        }
        set {
            base.value = newValue
        }
    }

    public var projectedValue: ValuePublisher<Value> {
        return base.eventier
    }

    public init(any base: AnyStorage<Value>) {
        self.base = base
    }

    public init(base: any Storage<Value>) {
        self.base = base.toAny()
    }

    @available(iOS 16.0.0, *)
    public init(storages base: [any Storage<Value>])
        where Value: ExpressibleByNilLiteral & Equatable {
        self.base = zip(storages: base).toAny()
    }

    public init(storages base: [AnyStorage<Value>])
        where Value: ExpressibleByNilLiteral & Equatable {
        self.base = zip(storages: base).toAny()
    }
}
