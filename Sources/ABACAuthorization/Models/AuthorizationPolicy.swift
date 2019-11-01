import Vapor
import FluentPostgreSQL
import Foundation

protocol AuthPolicyDefinition {
    var id: UUID? { get set }
    var roleName: String { get set }
    var actionOnResourceKey: String { get set }
    var actionOnResourceValue: Bool { get set }
}



final class AuthorizationPolicy: Codable {
    
    var id: UUID?
    var roleName: String
    var actionOnResourceKey: String
    var actionOnResourceValue: Bool
    
    
    init(roleName: String, actionOnResource: String, actionOnResourceValue: Bool) {
        self.roleName = roleName
        self.actionOnResourceKey = actionOnResource
        self.actionOnResourceValue = actionOnResourceValue
    }
}

extension AuthorizationPolicy: AuthPolicyDefinition {}
extension AuthorizationPolicy: PostgreSQLUUIDModel {}
extension AuthorizationPolicy: Content {}
extension AuthorizationPolicy: Parameter {}

extension AuthorizationPolicy {
    func didUpdate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<AuthorizationPolicy> {
        return try self.conditionValues.query(on: conn).all().map{ conditionValuesDB in
            try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: self, conditionValues: conditionValuesDB)
            return self
        }
    }
    
    func didCreate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<AuthorizationPolicy> {
        try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: self, conditionValues: [])
        return Future.map(on: conn) { self }
    }
    
    func didDelete(on conn: PostgreSQLConnection) throws -> EventLoopFuture<AuthorizationPolicy> {
        InMemoryAuthorizationPolicy.shared.removeFromInMemoryCollection(authPolicy: self)
        return Future.map(on: conn) { self }
    }
}

extension AuthorizationPolicy: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.actionOnResourceKey)
        }
    }
}

extension AuthorizationPolicy {
    var conditionValues: Children<AuthorizationPolicy, ConditionValueDB> {
        return children(\.authorizationPolicyID)
    }
}
