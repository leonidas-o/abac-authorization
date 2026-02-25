import Vapor

public struct ABACAuthorizationPersistenceRepoFactory: Sendable {
    var make: (@Sendable (Request) -> any ABACAuthorizationPersistenceRepo)?
    public mutating func use(_ make: @escaping @Sendable (Request) -> any ABACAuthorizationPersistenceRepo) {
        self.make = make
    }
    
    var makeForApp: (@Sendable (Application) -> any ABACAuthorizationPersistenceRepo)?
    public mutating func useForApp(_ make: @escaping @Sendable (Application) -> any ABACAuthorizationPersistenceRepo) {
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
    public var abacAuthorizationRepo: any ABACAuthorizationPersistenceRepo {
        self.abacAuthorizationRepoFactory.makeForApp!(self)
    }
}

extension Request {
    public var abacAuthorizationRepo: any ABACAuthorizationPersistenceRepo {
        self.application.abacAuthorizationRepoFactory.make!(self)
    }
}
