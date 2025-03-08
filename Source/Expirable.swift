import Foundation

public struct Lifetime: Codable, Equatable {
    public static let infinite = Lifetime()
    public static let oneHour = Lifetime(expiresInSeconds: 3600)
    public static let fourHours = Lifetime(expiresInSeconds: 3600 * 4)
    public static let twentyFourHours = Lifetime(expiresInSeconds: 3600 * 24)

    private let interval: TimeInterval
    public var isInfinite: Bool {
        return interval < 0
    }

    public init() {
        self.interval = -1
    }

    public init(expiresInSeconds interval: TimeInterval) {
        self.interval = interval
    }

    public func hasExpired(from date: Date, currentDate: Date) -> Bool {
        if isInfinite {
            return false
        }

        return currentDate.timeIntervalSince(date) > interval
    }
}

// MARK: - ExpressibleByFloatLiteral

extension Lifetime: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Float) {
        self.init(expiresInSeconds: TimeInterval(value))
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Lifetime: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(expiresInSeconds: TimeInterval(value))
    }
}

@propertyWrapper
public struct Expirable<Value: ExpressibleByNilLiteral> {
    private var _value: Value
    private let lifetime: Lifetime
    private var savedDate = Date()

    private var hasExpired: Bool {
        return lifetime.hasExpired(from: savedDate, currentDate: Date())
    }

    public var wrappedValue: Value {
        get {
            return hasExpired ? nil : _value
        }
        set {
            savedDate = Date()
            _value = newValue
        }
    }

    public init(wrappedValue: Value = nil,
                lifetimeInterval interval: TimeInterval) {
        self.lifetime = Lifetime(expiresInSeconds: interval)
        self._value = wrappedValue
    }

    public init(wrappedValue: Value = nil,
                lifetime: Lifetime) {
        self.lifetime = lifetime
        self._value = wrappedValue
    }
}

extension Expirable: Codable where Value: Codable {}
extension Expirable: Equatable where Value: Equatable {}

#if swift(>=6.0)
extension Lifetime: Sendable {}
extension Expirable: @unchecked Sendable {}
#endif
