import Vapor
import Fluent
import FluentPostgresDriver
import Foundation


public protocol ABACAuthorizationPolicyDefinition {
    var id: UUID? { get set }
    var roleName: String { get set }
    var actionOnResourceKey: String { get set }
    var actionOnResourceValue: Bool { get set }
}



public final class ABACAuthorizationPolicyModel: Model {
    
    public static let schema = "abac_authorization_policy"
    
    @ID(key: .id) public var id: UUID?
    @Field(key: "role_name") public var roleName: String
    @Field(key: "action_on_resource_key") public var actionOnResourceKey: String
    @Field(key: "action_on_resource_value") public var actionOnResourceValue: Bool
    
    @Children(for: \.$authorizationPolicy) public var conditionValues: [ABACConditionModel]
    
    
    public init() {}
    
    public init(roleName: String, actionOnResource: String, actionOnResourceValue: Bool) {
        self.roleName = roleName
        self.actionOnResourceKey = actionOnResource
        self.actionOnResourceValue = actionOnResourceValue
    }
}



// MARK: - Conformances
extension ABACAuthorizationPolicyModel: ABACAuthorizationPolicyDefinition {}

extension ABACAuthorizationPolicyModel: Content {}



// MARK: - Migration

public struct AuthorizationPolicyMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_authorization_policy")
        .id()
        .field("role_name", .string, .required)
        .field("action_on_resource_key", .string, .required)
        .field("action_on_resource_value", .bool, .required)
        .unique(on: "role_name", "action_on_resource_key")
        .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_authorization_policy")
        .delete()
    }
}



// MARK: - ModelMiddleware

public struct AuthorizationPolicyMiddleware: ModelMiddleware {
    public func update(model: ABACAuthorizationPolicyModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.update(model, on: db).map {
            // after operation
            _ = model.$conditionValues.query(on: db).all().flatMapThrowing { conditionValuesDB in
                try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(authPolicy: model, conditionValues: conditionValuesDB)
            }
        }
    }
    
    public func create(model: ABACAuthorizationPolicyModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.create(model, on: db).flatMapThrowing {
            // after operation
            try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(authPolicy: model, conditionValues: [])
        }
    }
    
    public func delete(model: ABACAuthorizationPolicyModel, force: Bool, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.delete(model, force: force, on: db).map {
            // after operation
            ABACAuthorizationPolicyService.shared.removeFromInMemoryCollection(authPolicy: model)
        }
        
    }
}
