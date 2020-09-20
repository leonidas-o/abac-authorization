import Vapor
import Fluent
import FluentPostgresDriver
import Foundation

public protocol AuthPolicyDefinition {
    var id: UUID? { get set }
    var roleName: String { get set }
    var actionOnResourceKey: String { get set }
    var actionOnResourceValue: Bool { get set }
}



public final class AuthorizationPolicy: Codable, Model {
    
    public static let schema = "authorization_policy"
    
    @ID(key: .id)
    public var id: UUID?
    @Field(key: "role_name")
    public var roleName: String
    @Field(key: "action_on_resource_key")
    public var actionOnResourceKey: String
    @Field(key: "action_on_resource_value")
    public var actionOnResourceValue: Bool
    
    @Children(for: \.$authorizationPolicy)
    public var conditionValues: [ConditionValueDB]
    
    
    
    public init() {}
    
    public init(roleName: String, actionOnResource: String, actionOnResourceValue: Bool) {
        self.roleName = roleName
        self.actionOnResourceKey = actionOnResource
        self.actionOnResourceValue = actionOnResourceValue
    }
}



// MARK: - Conformances
extension AuthorizationPolicy: AuthPolicyDefinition {}

extension AuthorizationPolicy: Content {}



// MARK: - Migration

public struct AuthorizationPolicyMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("authorization_policy")
        .unique(on: "role_name", "action_on_resource_key")
        .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("authorization_policy")
        .delete()
    }
}



// MARK: - ModelMiddleware

public struct AuthorizationPolicyMiddleware: ModelMiddleware {
    public func update(model: AuthorizationPolicy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.update(model, on: db).map {
            // after operation
            _ = model.$conditionValues.query(on: db).all().flatMapThrowing { conditionValuesDB in
                try AuthorizationPolicyService.shared.addToInMemoryCollection(authPolicy: model, conditionValues: conditionValuesDB)
            }
        }
    }
    
    public func create(model: AuthorizationPolicy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.create(model, on: db).flatMapThrowing {
            // after operation
            try AuthorizationPolicyService.shared.addToInMemoryCollection(authPolicy: model, conditionValues: [])
        }
    }
    
    public func delete(model: AuthorizationPolicy, force: Bool, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.delete(model, force: force, on: db).map {
            // after operation
            AuthorizationPolicyService.shared.removeFromInMemoryCollection(authPolicy: model)
        }
        
    }
}
