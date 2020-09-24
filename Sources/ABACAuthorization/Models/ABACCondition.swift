import Foundation

/// Domain Transfer Object - DTO
public struct ABACCondition: Codable {
    
    var id: UUID?
    var key: String
    var type: ABACConditionModel.ConditionValueType
    var operation: ABACConditionModel.ConditionOperationType
    var lhsType: ABACConditionModel.ConditionType
    var lhs: String
    var rhsType: ABACConditionModel.ConditionType
    var rhs: String
    var authorizationPolicyID: UUID
    // optional extra fields
    let _csrfToken: String?
    
    internal init(id: UUID? = nil,
                  key: String,
                  type: ABACConditionModel.ConditionValueType,
                  operation: ABACConditionModel.ConditionOperationType,
                  lhsType: ABACConditionModel.ConditionType,
                  lhs: String,
                  rhsType: ABACConditionModel.ConditionType,
                  rhs: String,
                  authorizationPolicyID: UUID,
                  _csrfToken: String?) {
        self.id = id
        self.key = key
        self.type = type
        self.operation = operation
        self.lhsType = lhsType
        self.lhs = lhs
        self.rhsType = rhsType
        self.rhs = rhs
        self.authorizationPolicyID = authorizationPolicyID
        self._csrfToken = _csrfToken
    }
}


