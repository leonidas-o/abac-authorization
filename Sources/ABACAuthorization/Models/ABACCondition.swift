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
    let csrfToken: String?
}


