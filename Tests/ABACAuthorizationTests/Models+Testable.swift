//
//  File.swift
//  
//
//  Created by Leonid Orsulic on 26.10.19.
//

@testable import ABACAuthorization
import Foundation

extension AuthorizationPolicy {
    static func createRules(for roleName: String, allRulesPermitsAccess permits: Bool) -> [AuthorizationPolicy] {
        
        let readAuthPolicyActionOnResource = "\(ABACMiddlewareTests.Constant.apiAction.read)auth-policies"
        let readAuthPolicy = AuthorizationPolicy(
            roleName: roleName,
            actionOnResource: readAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let createAuthPolicyActionOnResource = "\(ABACMiddlewareTests.Constant.apiAction.create)auth-policies"
        let writeAuthPolicy = AuthorizationPolicy(
            roleName: roleName,
            actionOnResource: createAuthPolicyActionOnResource,
            actionOnResourceValue: permits)
        
        let readRoleActionOnResource = "\(ABACMiddlewareTests.Constant.apiAction.read)roles"
        let readRole = AuthorizationPolicy(
            roleName: roleName,
            actionOnResource: readRoleActionOnResource,
            actionOnResourceValue: permits)
        
        return [readAuthPolicy, writeAuthPolicy, readRole]
    }
}

extension ConditionValueDB {
    static func createConditionValues(dummyRef: String, dummyVal: String) -> [ConditionValueDB] {
        let dummyID = UUID()
        let conditionValue = ConditionValueDB(type: .string, operation: .equal, lhsType: .reference, lhs: dummyRef, rhsType: .value, rhs: dummyVal, authorizationPolicyID: dummyID)
        return [conditionValue]
    
    }
    
}
