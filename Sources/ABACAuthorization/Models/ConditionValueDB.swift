import Vapor
import FluentPostgreSQL
import Foundation

final class ConditionValueDB: Codable {
    
    enum Constant {
        static let defaultConditionKey = "default"
    }
    
    enum ConditionValueType: String, Codable, PostgreSQLRawEnum {
        case string
        case int
        case double
    }
    
    enum ConditionLhsRhsType: String, Codable, PostgreSQLRawEnum {
        case value
        case reference
    }
    
    enum ConditionOperationType: String, Codable, PostgreSQLRawEnum {
        case equal = "=="
        case notEqual = "!="
        case greaterThan = ">"
        case lessThan = "<"
        case greaterOrEqualThan = ">="
        case lessOrEqualThan = "<="
    }
    
    
    var id: UUID?
    var key: String
    var type: ConditionValueType
    var operation: ConditionOperationType
    var lhsType: ConditionLhsRhsType
    var lhs: String
    var rhsType: ConditionLhsRhsType
    var rhs: String
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
    var authorizationPolicy: Parent<ConditionValueDB, AuthorizationPolicy> {
        return parent(\.authorizationPolicyID)
    }
}


extension ConditionValueDB: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.authorizationPolicyID, to: \AuthorizationPolicy.id)
            builder.unique(on: \.key, \.authorizationPolicyID)
        }
    }
}


extension ConditionValueDB {
    func didUpdate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<ConditionValueDB> {
        return self.authorizationPolicy.get(on: conn).flatMap{ authPolicy in
            return try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: authPolicy, conditionValues: conditionValues)
                return self
            }
        }
    }
    
    func didCreate(on conn: PostgreSQLConnection) throws -> EventLoopFuture<ConditionValueDB> {
        return self.authorizationPolicy.get(on: conn).flatMap{ authPolicy in
            return try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                try InMemoryAuthorizationPolicy.shared.addToInMemoryCollection(authPolicy: authPolicy, conditionValues: conditionValues)
                return self
            }
        }
    }
    
    func didDelete(on conn: PostgreSQLConnection) throws -> EventLoopFuture<ConditionValueDB> {
        return self.authorizationPolicy.get(on: conn).map{ authPolicy in
            InMemoryAuthorizationPolicy.shared.removeFromInMemoryCollection(conditionValue: self, in: authPolicy)
            return self
        }
    }
    
}
