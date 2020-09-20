@testable import ABACAuthorization
import Foundation

extension AuthorizationPolicy {
    static func createRules(for roleName: String, allRulesPermitsAccess permits: Bool) -> [AuthorizationPolicy] {
        
        let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)authorization-policies"
        let readAuthPolicy = AuthorizationPolicy(
            roleName: roleName,
            actionOnResource: readAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)authorization-policies"
        let writeAuthPolicy = AuthorizationPolicy(
            roleName: roleName,
            actionOnResource: createAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let readRoleActionOnResource = "\(ABACAPIAction.read)roles"
        let readRole = AuthorizationPolicy(
            roleName: roleName,
            actionOnResource: readRoleActionOnResource,
            actionOnResourceValue: permits)
        
        return [readAuthPolicy, writeAuthPolicy, readRole]
    }
}

extension ConditionValueDB {
    static func createConditionValues(dummyRef: String, dummyVal: String) -> [ConditionValueDB] {
        let dummyId = UUID()
        let conditionValue = ConditionValueDB(type: .string, operation: .equal, lhsType: .reference, lhs: dummyRef, rhsType: .value, rhs: dummyVal, authorizationPolicyId: dummyId)
        return [conditionValue]
    
    }
    
}
