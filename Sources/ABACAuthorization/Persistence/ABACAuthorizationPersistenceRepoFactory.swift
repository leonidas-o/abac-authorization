import Vapor


public struct ABACAuthorizationPersistenceRepoFactory {
    var make: ((Request) -> ABACAuthorizationPersistenceRepo)?
    public mutating func use(_ make: @escaping ((Request) -> ABACAuthorizationPersistenceRepo)) {
        self.make = make
    }
    
    var makeForApp: ((Application) -> ABACAuthorizationPersistenceRepo)?
    public mutating func useForApp(_ make: @escaping ((Application) -> ABACAuthorizationPersistenceRepo)) {
        self.makeForApp = make
    }
}



extension Application {
    private struct ABACAuthorizationPersistenceRepoKey: StorageKey {
        typealias Value = ABACAuthorizationPersistenceRepoFactory
    }

    public var abacAuthorizationRepoFactory: ABACAuthorizationPersistenceRepoFactory {
        get {
            self.storage[ABACAuthorizationPersistenceRepoKey.self] ?? .init()
        }
        set {
            self.storage[ABACAuthorizationPersistenceRepoKey.self] = newValue
        }
    }
}



extension Application {
    public var abacAuthorizationRepo: ABACAuthorizationPersistenceRepo {
        self.abacAuthorizationRepoFactory.makeForApp!(self)
    }
}

extension Request {
    public var abacAuthorizationRepo: ABACAuthorizationPersistenceRepo {
        self.application.abacAuthorizationRepoFactory.make!(self)
    }
}
