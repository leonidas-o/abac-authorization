@testable import ABACAuthorization
import Foundation


extension ABACAuthorizationPolicyModel {
    static func createRules(for roleName: String, rulesPermitsAccess permits: Bool) -> [ABACAuthorizationPolicyModel] {
        
        let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)\(ABACMiddlewareTests.APIResource.Resource.abacAuthorizationPolicies.rawValue)"
        let readAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionKey: readAuthPolicyActionOnResource,
            actionValue: permits)
        
        let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)\(ABACMiddlewareTests.APIResource.Resource.abacAuthorizationPolicies.rawValue)"
        let writeAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionKey: createAuthPolicyActionOnResource,
            actionValue: permits)
        
        let readRoleActionOnResource = "\(ABACAPIAction.read)\(ABACMiddlewareTests.APIResource.Resource.roles.rawValue)"
        let readRole = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionKey: readRoleActionOnResource,
            actionValue: permits)
        
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
