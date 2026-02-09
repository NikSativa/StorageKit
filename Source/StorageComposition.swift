import Combine
import Foundation

/// A composite storage that synchronizes a value across multiple underlying storage instances.
///
/// `StorageComposition` allows combining several `Storage` backends into one logical unit.
/// It observes all underlying storages and propagates changes bidirectionally. When one storage changes,
/// the update is applied to the others to maintain consistency.
///
/// This class is useful for scenarios such as layered storage with fallback behavior (e.g., memory + disk).
internal final class StorageComposition<Value: ExpressibleByNilLiteral & Equatable>: Storage {
    private let subject: ValueSubject<Value>
    /// A publisher that emits the current value and any future changes across the combined storages.
    ///
    /// Use this publisher to observe updates from any of the underlying storages.
    private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let storages: [AnyStorage<Value>]
    private var observers: [AnyCancellable] = []
    private var isSyncing: Bool = false

    /// The current value shared by all combined storages.
    ///
    /// Reading this property returns the first non-nil value found across storages.
    /// Setting it writes the value to all storages and notifies observers.
    var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    /// Creates a `StorageComposition` by combining storages conforming to `Storage<Value>`.
    ///
    /// - Parameter storages: An array of storages to be combined.
    /// - Note: This initializer is available only on platforms supporting generalized existential types.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    convenience init(storages: [any Storage<Value>]) {
        let anyStorages = storages.map {
            return $0.toAny()
        }
        self.init(storages: anyStorages)
    }

    /// Creates a `StorageComposition` from an array of type-erased storages.
    ///
    /// - Parameter storages: The list of underlying storages.
    ///
    /// If the array is empty, an in-memory fallback storage is automatically added.
    init(storages: [AnyStorage<Value>]) {
        assert(!storages.isEmpty, "we hit a snag! maybe in runtime some Storages was filtered")

        if storages.isEmpty {
            // storages might have been filtered at runtime due to missing options
            // to ensure the storage always works, we are adding a default InMemory storage
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
        self.observers = storages.map { actual in
            return actual.eventier.dropFirst().sink { [unowned self, unowned actual] newValue in
                if isSyncing {
                    return
                }

                self.isSyncing = true
                for storage in self.storages {
                    if actual !== storage {
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
