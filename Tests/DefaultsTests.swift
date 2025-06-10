import Combine
import Foundation
import StorageKit
import XCTest

@MainActor
final class DefaultsTests: XCTestCase {
    fileprivate struct Custom: Codable, Equatable {
        let value: Int
    }

    func test_int() {
        run_test_value_type(Int.self, defaultValue: 1, values: [2, 3, 4, 5], userDefaults: nil)
        run_test_value_type(Int.self, defaultValue: 1, values: [2, 3, 4, 5], userDefaults: .standard)
    }

    func test_double() {
        run_test_value_type(Double.self, defaultValue: 1, values: [2, 3, 4, 5], userDefaults: nil)
        run_test_value_type(Double.self, defaultValue: 1, values: [2, 3, 4, 5], userDefaults: .standard)
    }

    func test_string() {
        run_test_value_type(String.self, defaultValue: "1", values: ["2", "3", "4", "5"], userDefaults: nil)
        run_test_value_type(String.self, defaultValue: "1", values: ["2", "3", "4", "5"], userDefaults: .standard)
    }

    func test_custom() {
        run_test_value_type(Custom.self, defaultValue: .init(value: 1), values: [2, 3, 4, 5].map(Custom.init(value:)), isPropertyListType: false, userDefaults: nil)
        run_test_value_type(Custom.self, defaultValue: .init(value: 1), values: [2, 3, 4, 5].map(Custom.init(value:)), isPropertyListType: false, userDefaults: .standard)
    }

    // MARK: - arrays

    func test_array_of_int() {
        run_test_value_type([Int].self, defaultValue: [], values: [[2], [3], [4], [5]], userDefaults: nil)
        run_test_value_type([Int].self, defaultValue: [], values: [[2], [3], [4], [5]], userDefaults: .standard)
    }

    func test_array_of_double() {
        run_test_value_type([Double].self, defaultValue: [], values: [[2], [3], [4], [5]], userDefaults: nil)
        run_test_value_type([Double].self, defaultValue: [], values: [[2], [3], [4], [5]], userDefaults: .standard)
    }

    func test_array_of_string() {
        run_test_value_type([String].self, defaultValue: [], values: [["2"], ["3"], ["4"], ["5"]], userDefaults: nil)
        run_test_value_type([String].self, defaultValue: [], values: [["2"], ["3"], ["4"], ["5"]], userDefaults: .standard)
    }

    func test_array_of_custom() {
        run_test_value_type([Custom].self, defaultValue: [], values: [[2], [3], [4], [5]].map { $0.map(Custom.init(value:)) }, isPropertyListType: false, userDefaults: nil)
        run_test_value_type([Custom].self, defaultValue: [], values: [[2], [3], [4], [5]].map { $0.map(Custom.init(value:)) }, isPropertyListType: false, userDefaults: .standard)
    }

    // MARK: - optionals

    func test_optional_int() {
        run_test_value_type(Int?.self, defaultValue: nil, values: [2, nil, 4, 5], isPropertyListType: false, userDefaults: nil)
        run_test_value_type(Int?.self, defaultValue: nil, values: [2, nil, 4, 5], isPropertyListType: false, userDefaults: .standard)
    }

    func test_optional_double() {
        run_test_value_type(Double?.self, defaultValue: nil, values: [2, 3, nil, 5], isPropertyListType: false, userDefaults: nil)
        run_test_value_type(Double?.self, defaultValue: nil, values: [2, 3, nil, 5], isPropertyListType: false, userDefaults: .standard)
    }

    func test_optional_string() {
        run_test_value_type(String?.self, defaultValue: nil, values: ["2", "3", "4", nil], isPropertyListType: false, userDefaults: nil)
        run_test_value_type(String?.self, defaultValue: nil, values: ["2", "3", "4", nil], isPropertyListType: false, userDefaults: .standard)
    }

    func test_optional_custom() {
        run_test_value_type(Custom?.self, defaultValue: nil, values: [2, 3, 4, nil].map { $0.map(Custom.init(value:)) }, isPropertyListType: false, userDefaults: nil)
        run_test_value_type(Custom?.self, defaultValue: nil, values: [2, 3, 4, nil].map { $0.map(Custom.init(value:)) }, isPropertyListType: false, userDefaults: .standard)
    }

    func test_convenience_init() {
        @Defaults("intValue")
        var intValue: Int?
        XCTAssertEqual(intValue, nil)

        @Defaults("arrValue")
        var arrValue: [Int]
        XCTAssertEqual(arrValue, [])

        @Defaults("dictValue")
        var dictValue: [String: Int]
        XCTAssertEqual(dictValue, [:])
    }
}

extension DefaultsTests {
    private func run_test_value_type<T>(_ type: T.Type,
                                        defaultValue: T,
                                        values: [T],
                                        isPropertyListType: Bool = true, // UserDefaults error: Attempt to insert non-property list object
                                        userDefaults: UserDefaults?,
                                        file: StaticString = #filePath,
                                        line: UInt = #line)
    where T: Codable & Equatable & SafeSendable {
        let key = String(describing: T.self)
        let userDefaults: UserDefaults = userDefaults ?? .init(suiteName: "DefaultsTests_\(key)")!
        // clean user defaults before use
        userDefaults.set(nil, forKey: key)

        var results: [T] = []
        let encoder = JSONEncoder()
        var observers: Set<AnyCancellable> = []

        @Defaults(key: key, userDefaults: userDefaults)
        var varValue: T = defaultValue

        $varValue.sink { new in
            results.append(new)
        }
        .store(in: &observers)

        XCTAssertEqual(varValue, defaultValue, "default value", file: file, line: line)

        for v in values {
            varValue = v
            XCTAssertEqual(varValue, v, "direct access", file: file, line: line)
        }

        // sink adding first value
        let expected = [defaultValue] + values
        XCTAssertEqual(results, expected, "linear usage", file: file, line: line)

        if isPropertyListType {
            // synchronizing 'value' with setting value from some other place of app
            results = []
            for v in values {
                userDefaults.set(v, forKey: key)
            }

            XCTAssertEqual(results, values, "synchronizing 'value'", file: file, line: line)
        }

        // synchronizing 'data' with setting value from some other place of app
        results = []
        for v in values {
            userDefaults.set(try! encoder.encode(v), forKey: key)
        }

        XCTAssertEqual(results, values, "synchronizing 'data'", file: file, line: line)

        // synchronize 'data' with setting value from some other place of app (not main thread)
        let exp = expectation(description: "other thread")
        results = []
        let unsafeSendable = UnsafeSendable(value: userDefaults)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            for v in values {
                unsafeSendable.value.set(try! encoder.encode(v), forKey: key)
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1)

        XCTAssertEqual(results, values, "synchronize 'data' from other thread", file: file, line: line)
    }
}

#if swift(>=6.0)
private protocol SafeSendable: Sendable {}
private struct UnsafeSendable<Value>: @unchecked Sendable {
    let value: Value
}
#else
private protocol SafeSendable {}
private struct UnsafeSendable<Value> {
    let value: Value
}
#endif

extension Int: SafeSendable {}
extension Double: SafeSendable {}
extension String: SafeSendable {}
extension DefaultsTests.Custom: SafeSendable {}
extension Array: SafeSendable where Element: SafeSendable {}
extension Optional: SafeSendable where Wrapped: SafeSendable {}
