@testable import ABACAuthorization
import Foundation

extension ABACAuthorizationPolicyModel {
    static func createRules(for roleName: String, allRulesPermitsAccess permits: Bool) -> [ABACAuthorizationPolicyModel] {
        
        let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)authorization-policies"
        let readAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionOnResource: readAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)authorization-policies"
        let writeAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionOnResource: createAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let readRoleActionOnResource = "\(ABACAPIAction.read)roles"
        let readRole = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionOnResource: readRoleActionOnResource,
            actionOnResourceValue: permits)
        
        return [readAuthPolicy, writeAuthPolicy, readRole]
    }
}

extension ABACConditionModel {
    static func createConditionValues(dummyRef: String, dummyVal: String) -> [ABACConditionModel] {
        let dummyId = UUID()
        let conditionValue = ABACConditionModel(type: .string, operation: .equal, lhsType: .reference, lhs: dummyRef, rhsType: .value, rhs: dummyVal, authorizationPolicyId: dummyId)
        return [conditionValue]
    
    }
    
}
