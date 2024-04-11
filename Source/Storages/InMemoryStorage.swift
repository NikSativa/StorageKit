import Foundation

public final class InMemoryStorage<Value>: Storage {
    private lazy var subject: ValueSubject<Value> = .init(value)
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    public var value: Value {
        willSet {
            objectWillChange.send()
        }
        didSet {
            subject.send(value)
        }
    }

    public init(value: Value) {
        self.value = value
    }
}

public extension InMemoryStorage where Value: ExpressibleByNilLiteral {
    convenience init() {
        self.init(value: nil)
    }
}
