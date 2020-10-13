@testable import ABACAuthorization
import Foundation


extension ABACAuthorizationPolicyModel {
    static func createRules(for roleName: String, rulesPermitsAccess permits: Bool) -> [ABACAuthorizationPolicyModel] {
        
        let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)\(ABACMiddlewareTests.APIResource.Resource.abacAuthorizationPolicy.rawValue)"
        let readAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionOnResourceKey: readAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)\(ABACMiddlewareTests.APIResource.Resource.abacAuthorizationPolicy.rawValue)"
        let writeAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionOnResourceKey: createAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let readRoleActionOnResource = "\(ABACAPIAction.read)\(ABACMiddlewareTests.APIResource.Resource.roles.rawValue)"
        let readRole = ABACAuthorizationPolicyModel(
            roleName: roleName,
            actionOnResourceKey: readRoleActionOnResource,
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
