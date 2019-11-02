import Vapor
import FluentPostgreSQL
import Foundation

public final class ConditionValueDB: Codable {
    
    public enum Constant {
        static let defaultConditionKey = "default"
    }
    
    public enum ConditionValueType: String, Codable, PostgreSQLRawEnum {
        case string
        case int
        case double
    }
    
    public enum ConditionLhsRhsType: String, Codable, PostgreSQLRawEnum {
        case value
        case reference
    }
    
    public enum ConditionOperationType: String, Codable, PostgreSQLRawEnum {
        case equal = "=="
        case notEqual = "!="
        case greaterThan = ">"
        case lessThan = "<"
        case greaterOrEqualThan = ">="
        case lessOrEqualThan = "<="
    }
    
    
    public var id: UUID?
    public var key: String
    public var type: ConditionValueType
    public var operation: ConditionOperationType
    public var lhsType: ConditionLhsRhsType
    public var lhs: String
    public var rhsType: ConditionLhsRhsType
    public var rhs: String
    var authorizationPolicyID: AuthorizationPolicy.ID
    
    init(key: String = Constant.defaultConditionKey,
         type: ConditionValueType,
         operation: ConditionOperationType,
         lhsType: ConditionLhsRhsType,
         lhs: String,
         rhsType: ConditionLhsRhsType,
         rhs: String,
         authorizationPolicyID: AuthorizationPolicy.ID) {
        self.key = key
        self.type = type
        self.operation = operation
        self.lhsType = lhsType
        self.lhs = lhs
        self.rhsType = rhsType
        self.rhs = rhs
        self.authorizationPolicyID = authorizationPolicyID
    }
}
extension ConditionValueDB: PostgreSQLUUIDModel {}
extension ConditionValueDB: Content {}
extension ConditionValueDB: Parameter {}

extension ConditionValueDB {
    public var authorizationPolicy: Parent<ConditionValueDB, AuthorizationPolicy> {
        return parent(\.authorizationPolicyID)
    }
}


extension ConditionValueDB: Migration {
    public static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.authorizationPolicyID, to: \AuthorizationPolicy.id)
            builder.unique(on: \.key, \.authorizationPolicyID)
        }
    }
}


extension ConditionValueDB {
    public func didUpdate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<ConditionValueDB> {
        return self.authorizationPolicy.get(on: conn).flatMap{ authPolicy in
            return try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: authPolicy, conditionValues: conditionValues)
                return self
            }
        }
    }
    
    public func didCreate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<ConditionValueDB> {
        return self.authorizationPolicy.get(on: conn).flatMap{ authPolicy in
            return try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: authPolicy, conditionValues: conditionValues)
                return self
            }
        }
    }
    
    public func didDelete(on conn: PostgreSQLConnection) throws -> EventLoopFuture<ConditionValueDB> {
        return self.authorizationPolicy.get(on: conn).map{ authPolicy in
            InMemoryAuthorizationPolicy.shared.removeFromInMemoryCollection(conditionValue: self, in: authPolicy)
            return self
        }
    }
    
}
