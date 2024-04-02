import Foundation

public final class UserDefaultsStorage<Value>: Storage
where Value: ExpressibleByNilLiteral & Codable {
    private lazy var subject: ValueSubject<Value> = .init(get())
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let defaults: UserDefaults
    private let key: String
    private lazy var decoder: JSONDecoder = .init()
    private lazy var encoder: JSONEncoder = .init()

    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    public init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    private func get() -> Value {
        if let data = defaults.data(forKey: key),
           let result = try? decoder.decode(Value.self, from: data) {
            return result
        }
        return nil
    }

    private func set(_ newValue: Value) {
        let result: Value
        if let data = try? encoder.encode(newValue) {
            defaults.set(data, forKey: key)
            result = newValue
        } else {
            defaults.removeObject(forKey: key)
            result = nil
        }

        defaults.synchronize()
        objectWillChange.send()
        subject.send(result)
    }
}
