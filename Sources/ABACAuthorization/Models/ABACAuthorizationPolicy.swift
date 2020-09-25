import Foundation

/// Data Transfer Object - DTO
public struct ABACAuthorizationPolicy: Codable {
    
    public var id: UUID?
    public var roleName: String
    public var actionOnResourceKey: String
    public var actionOnResourceValue: Bool
    public var conditions: [ABACCondition]
    // optional extra fields
    public var _csrfToken: String?
    
    
    public init(id: UUID,
                roleName: String,
                actionOnResource: String,
                actionOnResourceValue: Bool,
                conditions: [ABACCondition] = [],
                _csrfToken: String? = nil) {
        self.id = id
        self.roleName = roleName
        self.actionOnResourceKey = actionOnResource
        self.actionOnResourceValue = actionOnResourceValue
        self.conditions = conditions
        // extra fields
        self._csrfToken = _csrfToken
    }
}

extension ABACAuthorizationPolicy: ABACAuthorizationPolicyDefinition {}
