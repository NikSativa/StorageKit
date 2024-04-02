import Foundation

public final class AnyStorage<Value>: Storage {
    private let _get: () -> Value
    private let _set: (Value) -> Void
    private let _publisher: () -> ValuePublisher<Value>

    public var value: Value {
        get {
            return _get()
        }
        set {
            objectWillChange.send()
            _set(newValue)
        }
    }

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

    public var eventier: ValuePublisher<Value> {
        return _publisher()
    }
}

public extension Storage {
    func toAny() -> AnyStorage<Value> {
        if let self = self as? AnyStorage<Value> {
            return self
        }

        return AnyStorage(self)
    }
}
