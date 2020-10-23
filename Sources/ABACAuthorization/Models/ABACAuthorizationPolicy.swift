import Vapor


/// Data Transfer Object - DTO
public struct ABACAuthorizationPolicy: Codable {
    
    public var id: UUID?
    public var roleName: String
    public var actionKey: String
    public var actionValue: Bool
    public var conditions: [ABACCondition]
    // optional extra fields
    public var _csrfToken: String?
    
    
    public init(id: UUID? = nil,
                roleName: String,
                actionKey: String,
                actionValue: Bool,
                conditions: [ABACCondition] = [],
                _csrfToken: String? = nil) {
        self.id = id
        self.roleName = roleName
        self.actionKey = actionKey
        self.actionValue = actionValue
        self.conditions = conditions
        // optional extra fields
        self._csrfToken = _csrfToken
    }
}

extension ABACAuthorizationPolicy: ABACAuthorizationPolicyDefinition {}
extension ABACAuthorizationPolicy: Content {}
