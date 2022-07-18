import Vapor
import Fluent


/// Fluent Model
public final class ABACConditionModel: Model {
    
    public enum Constant {
        public static let defaultConditionKey = "key1"
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
    
    @Parent(key: "auth_policy_id") public var authorizationPolicy: ABACAuthorizationPolicyModel
    
    
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
    public func convertToABACCondition() -> ABACCondition {
        return ABACCondition(id: id,
                             key: key,
                             type: type,
                             operation: operation,
                             lhsType: lhsType,
                             lhs: lhs,
                             rhsType: rhsType,
                             rhs: rhs,
                             authorizationPolicyId: $authorizationPolicy.id)
    }
}


extension ABACCondition {
    public func convertToABACConditionModel() -> ABACConditionModel {
        return ABACConditionModel(id: id,
                                  key: key,
                                  type: type,
                                  operation: operation,
                                  lhsType: lhsType,
                                  lhs: lhs,
                                  rhsType: rhsType,
                                  rhs: rhs,
                                  authorizationPolicyId: authorizationPolicyId)
    }
}



// MARK: - Migration

public struct ABACConditionModelMigration: Migration {
    
    public init() {}
    
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
            .field("auth_policy_id", .uuid, .required, .references("abac_auth_policy", "id"))
            .unique(on: "key", "auth_policy_id")
            .create()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("abac_condition")
            .delete()
    }
}



// MARK: - ModelMiddleware

public struct ABACConditionModelMiddleware: ModelMiddleware {
    
    public init() {}
    
    public func update(model: ABACConditionModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.update(model, on: db).map {
            // after operation
            _ = model.$authorizationPolicy.get(on: db).flatMapThrowing { policy in
                return policy.$conditions.query(on: db).all().flatMapThrowing { conditions in
                    try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(policy: policy, conditions: conditions)
                }
            }
        }
    }
    
    public func create(model: ABACConditionModel, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.create(model, on: db).map {
            // after operation
            _ = model.$authorizationPolicy.get(on: db).flatMapThrowing { policy in
                return policy.$conditions.query(on: db).all().flatMapThrowing { conditions in
                    try ABACAuthorizationPolicyService.shared.addToInMemoryCollection(policy: policy, conditions: conditions)
                }
            }
        }
    }
    
    public func delete(model: ABACConditionModel, force: Bool, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // before operation
        return next.delete(model, force: force, on: db).map {
            // after operation
            _ = model.$authorizationPolicy.get(on: db).map { policy in
                ABACAuthorizationPolicyService.shared.removeFromInMemoryCollection(condition: model, in: policy)
            }
        }
    }
}
