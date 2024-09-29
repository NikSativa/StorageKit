import Combine
import Foundation

internal final class StorageComposition<Value: ExpressibleByNilLiteral & Equatable>: Storage {
    private let subject: ValueSubject<Value>
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let storages: [AnyStorage<Value>]
    private var observers: [AnyCancellable] = []
    private var isSyncing: Bool = false

    var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    convenience init(storages: [any Storage<Value>]) {
        let anyStorages = storages.map {
            return $0.toAny()
        }
        self.init(storages: anyStorages)
    }

    init(storages: [AnyStorage<Value>]) {
        assert(!storages.isEmpty, "we hit a snag! maybe in runtime some Storages was filtered")

        if storages.isEmpty {
            // maybe in runtime Storages was filtered due some lack options
            // to make shure that the storage will work at any case, we are adding default InMemory storage
            self.storages = [InMemoryStorage<Value>().toAny()]
        } else {
            self.storages = storages
        }

        var found: Value = nil
        for storage in storages {
            let value = storage.value
            if value != found {
                found = value
                break
            }
        }

        self.subject = .init(found)
        self.observers = storages.map { actaul in
            return actaul.eventier.dropFirst().sink { [unowned self, unowned actaul] newValue in
                if isSyncing {
                    return
                }

                self.isSyncing = true
                for storage in self.storages {
                    if actaul !== storage {
                        storage.value = newValue
                    }
                }
                self.isSyncing = false
            }
        }
    }

    private func get() -> Value {
        let empty: Value = nil
        let found: (offset: Int, element: Value)? = storages.lazy
            .map(\.value)
            .enumerated()
            .first(where: { $0.1 != empty })

        if let found {
            // recursively set the same value to the previous storages
            // in common case this is improvement of speed via saving stored value in the inMemory storage
            for i in (0..<found.offset).reversed() {
                storages[i].value = found.element
            }
        }

        return found?.element ?? empty
    }

    private func set(_ newValue: Value) {
        for storage in storages {
            storage.value = newValue
        }

        objectWillChange.send()
        subject.send(newValue)
    }
}

#if swift(>=6.0)
extension StorageComposition: @unchecked Sendable {}
#endif
