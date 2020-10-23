import Vapor
import Fluent
import FluentPostgresDriver
import Foundation


public protocol ABACAuthorizationPolicyDefinition {
    var id: UUID? { get set }
    var roleName: String { get set }
    var actionKey: String { get set }
    var actionValue: Bool { get set }
}


/// Fluent Model
public final class ABACAuthorizationPolicyModel: Model {
    
    public static let schema = "abac_auth_policy"
    
    @ID(key: .id) public var id: UUID?
    @Field(key: "role_name") public var roleName: String
    @Field(key: "action_key") public var actionKey: String
    @Field(key: "action_value") public var actionValue: Bool
    
    @Children(for: \.$authorizationPolicy) public var conditions: [ABACConditionModel]
    
    
    public init() {}
    
    public init(id: UUID? = nil,
                roleName: String,
                actionKey: String,
                actionValue: Bool) {
        self.id = id
        self.roleName = roleName
        self.actionKey = actionKey
        self.actionValue = actionValue
    }
}



// MARK: - General conformances

extension ABACAuthorizationPolicyModel: ABACAuthorizationPolicyDefinition {}

extension ABACAuthorizationPolicyModel: Content {}



// MARK: - DTO conversions

extension ABACAuthorizationPolicyModel {
    public func convertToABACAuthorizationPolicy() -> ABACAuthorizationPolicy {
        return ABACAuthorizationPolicy(id: id,
                                       roleName: roleName,
                                       actionKey: actionKey,
                                       actionValue: actionValue,
                                       conditions: [])
    }
}

extension ABACAuthorizationPolicy {
    public func convertToABACAuthorizationPolicyModel() -> ABACAuthorizationPolicyModel {
        return ABACAuthorizationPolicyModel(id: id,
                                            roleName: roleName,
                                            actionKey: actionKey,
                                            actionValue: actionValue)
    }
}



// MARK: - Migration

public struct ABACAuthorizationPolicyModelMigration: Migration {
    
    public init() {}
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_auth_policy")
        .id()
        .field("role_name", .string, .required)
        .field("action_key", .string, .required)
        .field("action_value", .bool, .required)
        .unique(on: "role_name", "action_key")
        .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_auth_policy")
        .delete()
    }
}



// MARK: - ModelMiddleware

public struct ABACAuthorizationPolicyModelMiddleware: ModelMiddleware {
    public func update(model: ABACAuthorizationPolicyModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.update(model, on: db).map {
            // after operation
            _ = model.$conditions.query(on: db).all().flatMapThrowing { conditions in
                try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(policy: model, conditions: conditions)
            }
        }
    }
    
    public func create(model: ABACAuthorizationPolicyModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.create(model, on: db).flatMapThrowing {
            // after operation
            try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(policy: model, conditions: [])
        }
    }
    
    public func delete(model: ABACAuthorizationPolicyModel, force: Bool, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.delete(model, force: force, on: db).map {
            // after operation
            ABACAuthorizationPolicyService.shared.removeFromInMemoryCollection(policy: model)
        }
        
    }
}
