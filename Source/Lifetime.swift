import Foundation

/// A type that defines how long a value remains valid before it expires.
///
/// Use `Lifetime` with the `Expirable` property wrapper to automatically invalidate a value
/// after a specified duration. This type supports custom time intervals, predefined constants,
/// and conformance to numeric literals.
public struct Lifetime: Equatable {
    /// A lifetime that never expires.
    ///
    /// Use this for values that should persist indefinitely.
    public static let infinite = Lifetime()
    /// A predefined lifetime of one hour (3600 seconds).
    public static let oneHour = Lifetime(expiresInSeconds: 3600)
    /// A predefined lifetime of four hours (14,400 seconds).
    public static let fourHours = Lifetime(expiresInSeconds: 3600 * 4)
    /// A predefined lifetime of 24 hours (86,400 seconds).
    public static let twentyFourHours = Lifetime(expiresInSeconds: 3600 * 24)

    /// The time interval, in seconds, that defines the duration of the lifetime.
    public let interval: TimeInterval

    /// A Boolean value indicating whether the lifetime is infinite (i.e., never expires).
    public var isInfinite: Bool {
        return interval < 0
    }

    /// Creates an infinite lifetime.
    public init() {
        self.interval = -1
    }

    /// Creates a lifetime with a specific expiration duration in seconds.
    ///
    /// - Parameter interval: The number of seconds before the value expires.
    public init(expiresInSeconds interval: TimeInterval) {
        self.interval = interval
    }

    /// Indicates whether the lifetime has expired relative to a given start date and current time.
    ///
    /// - Parameters:
    ///   - date: The date the value was last updated.
    ///   - currentDate: The current date used for comparison.
    /// - Returns: `true` if the duration has passed and the value is expired; otherwise, `false`.
    public func hasExpired(from date: Date, currentDate: Date) -> Bool {
        if isInfinite {
            return false
        }

        return currentDate.timeIntervalSince(date) > interval
    }
}

extension Lifetime: ExpressibleByFloatLiteral {
    /// Creates a `Lifetime` instance from a float literal.
    ///
    /// - Parameter value: A floating-point number representing seconds.
    public init(floatLiteral value: Float) {
        self.init(expiresInSeconds: TimeInterval(value))
    }
}

extension Lifetime: ExpressibleByIntegerLiteral {
    /// Creates a `Lifetime` instance from an integer literal.
    ///
    /// - Parameter value: An integer representing seconds.
    public init(integerLiteral value: Int) {
        self.init(expiresInSeconds: TimeInterval(value))
    }
}

extension Lifetime: Comparable {
    /// Returns a Boolean value indicating whether the left-hand lifetime is shorter than the right-hand one.
    public static func <(lhs: Lifetime, rhs: Lifetime) -> Bool {
        return lhs.interval < rhs.interval
    }
}

extension Lifetime: AdditiveArithmetic {
    /// A `Lifetime` instance representing a duration of zero seconds.
    public static var zero: Lifetime {
        return Lifetime(expiresInSeconds: 0)
    }

    /// Returns the sum of two lifetimes.
    public static func +(lhs: Lifetime, rhs: Lifetime) -> Lifetime {
        return Lifetime(expiresInSeconds: lhs.interval + rhs.interval)
    }

    /// Returns the difference between two lifetimes.
    public static func -(lhs: Lifetime, rhs: Lifetime) -> Lifetime {
        return Lifetime(expiresInSeconds: lhs.interval - rhs.interval)
    }
}

/// Returns a `Lifetime` by multiplying the lifetime’s duration by the given factor.
public func *(lhs: Lifetime, rhs: Double) -> Lifetime {
    return Lifetime(expiresInSeconds: lhs.interval * rhs)
}

/// Returns a `Lifetime` by multiplying the lifetime’s duration by the given factor.
public func *(lhs: Double, rhs: Lifetime) -> Lifetime {
    return Lifetime(expiresInSeconds: rhs.interval * lhs)
}

/// Returns a `Lifetime` by dividing the lifetime’s duration by the given divisor.
public func /(lhs: Lifetime, rhs: Double) -> Lifetime {
    return Lifetime(expiresInSeconds: lhs.interval / rhs)
}

extension Lifetime: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let interval = try container.decode(TimeInterval.self)
        self.init(expiresInSeconds: interval)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(interval)
    }
}

#if swift(>=6.0)
extension Lifetime: Sendable {}
#endif
