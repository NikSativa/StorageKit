import Foundation
import StorageKit
import XCTest

final class StorageTests: XCTestCase {
    func test_storages() {
        storageTesting(InMemoryStorage(value: 1))
        storageTesting(FileStorage(fileName: "TestFile.txt"))
        storageTesting(UserDefaultsStorage(key: "MyKey"))

        storageTesting(InMemoryStorage(value: 1).toAny())
        storageTesting(InMemoryStorage<Int?>(value: 1).combine(UserDefaultsStorage(key: "MyKey")))
        storageTesting(InMemoryStorage<Int?>(value: 1).combine(UserDefaultsStorage(key: "MyKey")).toAny())

        if #available(iOS 16, macOS 13, tvOS 16.0, watchOS 9.0, *) {
            storageTesting(zip(storages: [
                InMemoryStorage<Int?>(value: 1),
                UserDefaultsStorage(key: "MyKey")
            ]))

            storageTesting(zip(storages: [
                InMemoryStorage<Int?>(value: 1),
                UserDefaultsStorage(key: "MyKey")
            ]).toAny())
        } else {
            storageTesting(zip(storages: [
                InMemoryStorage<Int?>(value: 1).toAny(),
                UserDefaultsStorage(key: "MyKey").toAny()
            ]))

            storageTesting(zip(storages: [
                InMemoryStorage<Int?>(value: 1).toAny(),
                UserDefaultsStorage(key: "MyKey").toAny()
            ]).toAny())
        }

//        Testing the Keychain - OSStatus error -34018
//        https://stackoverflow.com/questions/22082996/testing-the-keychain-osstatus-error-34018
//        storageTesting(KeychainStorage(key: "MyKey", configuration: .init(service: Bundle.main.bundleIdentifier ?? "MyService")))
    }

    private func storageTesting<S: Storage>(_ subject: S, file: StaticString = #filePath, line: UInt = #line)
    where S.Value == Int? {
        var actual: [Int?] = []
        var actual2: [Int?] = []
        var subscribers: [Any] = []

        let s1 = subject.eventier.dropFirst().sink { new in
            actual.append(new)
        }
        subscribers.append(s1)

        let s2 = subject.objectWillChange.sink { _ in
            actual2.append(0)
        }
        subscribers.append(s2)

        subject.value = 1
        subject.value = 2
        subject.value = 3
        subject.value = 4

        XCTAssertEqual(actual.count, actual2.count, file: file, line: line)
        XCTAssertEqual(actual, [1, 2, 3, 4], file: file, line: line)
        XCTAssertEqual(actual2, [0, 0, 0, 0], file: file, line: line)
        XCTAssertEqual(subscribers.count, 2, file: file, line: line)
    }
}
