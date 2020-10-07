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


/// Fluent Model
public final class ABACAuthorizationPolicyModel: Model {
    
    public static let schema = "abac_authorization_policy"
    
    @ID(key: .id) public var id: UUID?
    @Field(key: "role_name") public var roleName: String
    @Field(key: "action_on_resource_key") public var actionOnResourceKey: String
    @Field(key: "action_on_resource_value") public var actionOnResourceValue: Bool
    
    @Children(for: \.$authorizationPolicy) public var conditions: [ABACConditionModel]
    
    
    public init() {}
    
    public init(id: UUID? = nil,
                roleName: String,
                actionOnResourceKey: String,
                actionOnResourceValue: Bool) {
        self.id = id
        self.roleName = roleName
        self.actionOnResourceKey = actionOnResourceKey
        self.actionOnResourceValue = actionOnResourceValue
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
                                       actionOnResourceKey: actionOnResourceKey,
                                       actionOnResourceValue: actionOnResourceValue,
                                       conditions: [])
    }
}

extension ABACAuthorizationPolicy {
    public func convertToABACAuthorizationPolicyModel() -> ABACAuthorizationPolicyModel {
        return ABACAuthorizationPolicyModel(id: id,
                                            roleName: roleName,
                                            actionOnResourceKey: actionOnResourceKey,
                                            actionOnResourceValue: actionOnResourceValue)
    }
}



// MARK: - Migration

public struct ABACAuthorizationPolicyModelMigration: Migration {
    
    public init() {}
    
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

public struct ABACAuthorizationPolicyModelMiddleware: ModelMiddleware {
    public func update(model: ABACAuthorizationPolicyModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.update(model, on: db).map {
            // after operation
            _ = model.$conditions.query(on: db).all().flatMapThrowing { conditionValuesDB in
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
