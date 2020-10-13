import Vapor

/// Data Transfer Object - DTO
public struct ABACCondition: Codable {
    
    public var id: UUID?
    public var key: String
    public var type: ABACConditionModel.ConditionValueType
    public var operation: ABACConditionModel.ConditionOperationType
    public var lhsType: ABACConditionModel.ConditionType
    public var lhs: String
    public var rhsType: ABACConditionModel.ConditionType
    public var rhs: String
    public var authorizationPolicyID: UUID
    // optional extra fields
    public let _csrfToken: String?
    
    public init(id: UUID? = nil,
                  key: String,
                  type: ABACConditionModel.ConditionValueType,
                  operation: ABACConditionModel.ConditionOperationType,
                  lhsType: ABACConditionModel.ConditionType,
                  lhs: String,
                  rhsType: ABACConditionModel.ConditionType,
                  rhs: String,
                  authorizationPolicyID: UUID,
                  _csrfToken: String? = nil) {
        self.id = id
        self.key = key
        self.type = type
        self.operation = operation
        self.lhsType = lhsType
        self.lhs = lhs
        self.rhsType = rhsType
        self.rhs = rhs
        self.authorizationPolicyID = authorizationPolicyID
        // optional extra fields
        self._csrfToken = _csrfToken
    }
}

extension ABACCondition: Content {}
