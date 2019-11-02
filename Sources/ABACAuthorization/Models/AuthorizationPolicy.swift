import Vapor
import FluentPostgreSQL
import Foundation

public protocol AuthPolicyDefinition {
    var id: UUID? { get set }
    var roleName: String { get set }
    var actionOnResourceKey: String { get set }
    var actionOnResourceValue: Bool { get set }
}



public final class AuthorizationPolicy: Codable {
    
    public var id: UUID?
    public var roleName: String
    public var actionOnResourceKey: String
    public var actionOnResourceValue: Bool
    
    
    public init(roleName: String, actionOnResource: String, actionOnResourceValue: Bool) {
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
    public func didUpdate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<AuthorizationPolicy> {
        return try self.conditionValues.query(on: conn).all().map{ conditionValuesDB in
            try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: self, conditionValues: conditionValuesDB)
            return self
        }
    }
    
    public func didCreate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<AuthorizationPolicy> {
        try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: self, conditionValues: [])
        return Future.map(on: conn) { self }
    }
    
    public func didDelete(on conn: PostgreSQLConnection) throws -> EventLoopFuture<AuthorizationPolicy> {
        InMemoryAuthorizationPolicy.shared.removeFromInMemoryCollection(authPolicy: self)
        return Future.map(on: conn) { self }
    }
}

extension AuthorizationPolicy: Migration {
    public static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.actionOnResourceKey)
        }
    }
}

extension AuthorizationPolicy {
    public var conditionValues: Children<AuthorizationPolicy, ConditionValueDB> {
        return children(\.authorizationPolicyID)
    }
}
