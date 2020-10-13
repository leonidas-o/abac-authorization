import Vapor


public struct ABACAuthorizationPersistenceRepoFactory {
    var make: ((Request) -> ABACAuthorizationPersistenceRepo)?
    mutating func use(_ make: @escaping ((Request) -> ABACAuthorizationPersistenceRepo)) {
        self.make = make
    }
}



extension Application {
    private struct ABACAuthorizationPersistenceRepoKey: StorageKey {
        typealias Value = ABACAuthorizationPersistenceRepoFactory
    }

    var abacAuthorizationRepoFactory: ABACAuthorizationPersistenceRepoFactory {
        get {
            self.storage[ABACAuthorizationPersistenceRepoKey.self] ?? .init()
        }
        set {
            self.storage[ABACAuthorizationPersistenceRepoKey.self] = newValue
        }
    }
}



extension Request {
    public var abacAuthorizationRepo: ABACAuthorizationPersistenceRepo {
        self.application.abacAuthorizationRepoFactory.make!(self)
    }
}
