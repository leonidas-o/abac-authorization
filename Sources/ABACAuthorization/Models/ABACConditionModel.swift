import Vapor
import Fluent
import FluentPostgresDriver
import Foundation

/// Fluent Model
public final class ABACConditionModel: Model {
    
    public enum Constant {
        public static let defaultConditionKey = "default"
    }
    
    public enum ConditionValueType: String, Codable, CaseIterable {
        case string
        case int
        case double
    }
    
    public enum ConditionType: String, Codable, CaseIterable {
        case value
        case reference
    }
    
    public enum ConditionOperationType: String, Codable, CaseIterable {
        case equal = "=="
        case notEqual = "!="
        case greaterThan = ">"
        case lessThan = "<"
        case greaterOrEqualThan = ">="
        case lessOrEqualThan = "<="
    }
    
    
    public static let schema = "abac_condition"
    
    
    @ID(key: .id) public var id: UUID?
    @Field(key: "key") public var key: String
    @Field(key: "type") public var type: ConditionValueType
    @Field(key: "operation") public var operation: ConditionOperationType
    @Field(key: "lhs_type") public var lhsType: ConditionType
    @Field(key: "lhs") public var lhs: String
    @Field(key: "rhs_type") public var rhsType: ConditionType
    @Field(key: "rhs") public var rhs: String
    
    @Parent(key: "authorization_policy_id") public var authorizationPolicy: ABACAuthorizationPolicyModel
    
    
    public init() {}
    
    
    init(id: UUID? = nil,
         key: String = Constant.defaultConditionKey,
         type: ConditionValueType,
         operation: ConditionOperationType,
         lhsType: ConditionType,
         lhs: String,
         rhsType: ConditionType,
         rhs: String,
         authorizationPolicyId: ABACAuthorizationPolicyModel.IDValue) {
        self.id = id
        self.key = key
        self.type = type
        self.operation = operation
        self.lhsType = lhsType
        self.lhs = lhs
        self.rhsType = rhsType
        self.rhs = rhs
        self.$authorizationPolicy.id = authorizationPolicyId
    }
}



// MARK: - Conformances

extension ABACConditionModel: Content {}



// MARK: - DTO conversions

extension ABACConditionModel {
    func convertToABACCondition() -> ABACCondition? {
        if let authorizationPolicyId = authorizationPolicy.id {
            return ABACCondition(id: id,
                                 key: key,
                                 type: type,
                                 operation: operation,
                                 lhsType: lhsType,
                                 lhs: lhs,
                                 rhsType: rhsType,
                                 rhs: rhs,
                                 authorizationPolicyID: authorizationPolicyId)
        } else {
            return nil
        }
    }
}




// MARK: - Migration

public struct ConditionValueDBMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_condition")
            .id()
            .field("key", .string, .required)
            .field("type", .string, .required)
            .field("operation", .string, .required)
            .field("lhs_type", .string, .required)
            .field("lhs", .string, .required)
            .field("rhs_type", .string, .required)
            .field("rhs", .string, .required)
            .field("authorization_policy_id", .uuid, .required, .references("authorization_policy", "id"))
            .unique(on: "key", "authorization_policy_id")
            .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_condition")
            .delete()
    }
}



// MARK: - ModelMiddleware

public struct ConditionValueDBMiddleware: ModelMiddleware {
    public func update(model: ABACConditionModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.update(model, on: db).map {
            // after operation
            _ = model.$authorizationPolicy.get(on: db).flatMapThrowing { authPolicy in
                return authPolicy.$conditions.query(on: db).all().flatMapThrowing { conditionValues in
                    try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(authPolicy: authPolicy, conditionValues: conditionValues)
                }
            }
        }
    }
    
    public func create(model: ABACConditionModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.create(model, on: db).map {
            // after operation
            _ = model.$authorizationPolicy.get(on: db).flatMapThrowing { authPolicy in
                return authPolicy.$conditions.query(on: db).all().flatMapThrowing { conditionValues in
                    try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(authPolicy: authPolicy, conditionValues: conditionValues)
                }
            }
        }
    }
    
    public func delete(model: ABACConditionModel, force: Bool, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.delete(model, force: force, on: db).map {
            // after operation
            _ = model.$authorizationPolicy.get(on: db).map { authPolicy in
                ABACAuthorizationPolicyService.shared.removeFromInMemoryCollection(conditionValue: model, in: authPolicy)
            }
        }
    }
}