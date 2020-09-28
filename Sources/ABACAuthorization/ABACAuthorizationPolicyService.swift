import Vapor
import Foundation

protocol AuthorizationValuable {
    var actionOnResourceValue: Bool { get set }
    var conditionValue: ConditionValuable? { get set}
}

protocol ConditionValuable {
    var type: ABACConditionModel.ConditionValueType { get set }
    var lhsType: ABACConditionModel.ConditionType { get set }
    var rhsType: ABACConditionModel.ConditionType { get set }
}



public final class ABACAuthorizationPolicyService {
    
    static let shared = ABACAuthorizationPolicyService()
    
    private init() {}
    
    
    private let authPolicyQueue = DispatchQueue(
        label: "abacAuthorization.authPolicyQueue",
        qos: DispatchQoS.default,
        attributes: DispatchQueue.Attributes.concurrent)
    /// structure overview: [role:[actionOnResource:[condition: VALUES ]]]
    private var authPolicyCollectionValue: [String:[String:[String:AuthorizationValuable]]] = [:]
    var authPolicyCollection: [String:[String:[String:AuthorizationValuable]]] {
        get{
            return authPolicyQueue.sync { authPolicyCollectionValue }
        }
        set(newValue){
            authPolicyQueue.async(flags: DispatchWorkItemFlags.barrier) { self.authPolicyCollectionValue = newValue }
        }
    }
}


extension Application {
    public var authorizationPolicyService: ABACAuthorizationPolicyService {
        return ABACAuthorizationPolicyService.shared
    }
}




// MARK: - Structure

extension ABACAuthorizationPolicyService {
    struct AuthorizationValues: AuthorizationValuable {
        var actionOnResourceValue: Bool
        var conditionValue: ConditionValuable?
    }
    
    struct ConditionValue<LhsT: Comparable, RhsT: Comparable, OpsT: Comparable>: ConditionValuable {
        var type: ABACConditionModel.ConditionValueType
        var lhsType: ABACConditionModel.ConditionType
        var lhs: LhsT
        var rhsType: ABACConditionModel.ConditionType
        var rhs: RhsT
        var operation: ((OpsT, OpsT) -> Bool)
    }
}





// MARK: - Helper Methods

extension ABACAuthorizationPolicyService {
    public func addToInMemoryCollection(authPolicy: ABACAuthorizationPolicyModel, conditionValues: [ABACConditionModel]) throws {
        if conditionValues.isEmpty {
            let authValues = try prepareInMemoryAuthorizationValues(authPolicy, conditionValue: nil)
            add(authPolicy: authPolicy, conditionKey: ABACConditionModel.Constant.defaultConditionKey, authValues: authValues)
        } else {
            for conditionValue in conditionValues {
                let authValues = try prepareInMemoryAuthorizationValues(authPolicy, conditionValue: conditionValue)
                add(authPolicy: authPolicy, conditionKey: conditionValue.key, authValues: authValues)
            }
        }
    }
    
    private func add(authPolicy: ABACAuthorizationPolicyModel, conditionKey: String, authValues: AuthorizationValues) {
        if self.authPolicyCollection[authPolicy.roleName] == nil {
            self.authPolicyCollection[authPolicy.roleName] = [authPolicy.actionOnResourceKey:[conditionKey:authValues]]
        }
        if self.authPolicyCollection[authPolicy.roleName]![authPolicy.actionOnResourceKey] == nil {
            self.authPolicyCollection[authPolicy.roleName]![authPolicy.actionOnResourceKey] = [conditionKey:authValues]
        }
        self.authPolicyCollection[authPolicy.roleName]![authPolicy.actionOnResourceKey]![conditionKey] = authValues
    }
}



extension ABACAuthorizationPolicyService {
    func removeFromInMemoryCollection(authPolicy: ABACAuthorizationPolicyModel) {
        self.authPolicyCollection[authPolicy.roleName]?.removeValue(forKey: authPolicy.actionOnResourceKey)
    }
    
    func removeFromInMemoryCollection(conditionValue: ABACConditionModel, in authPolicy: ABACAuthorizationPolicyModel) {
        self.authPolicyCollection[authPolicy.roleName]?[authPolicy.actionOnResourceKey]?.removeValue(forKey: conditionValue.key)
    }
    
    func removeAllFromInMemoryCollection() {
        self.authPolicyCollection.removeAll()
    }
}



extension ABACAuthorizationPolicyService {
    private func prepareInMemoryAuthorizationValues(_ authPolicy: ABACAuthorizationPolicyModel, conditionValue: ABACConditionModel?) throws -> AuthorizationValues {
        
        guard let conditionValue = conditionValue else {
            return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: nil)
        }
        
        switch conditionValue.type {
        case .string:
            let conditionOperation = determineConditionOperation(forConditionType: String.self, fromConditionOperation: conditionValue.operation)
            
            let conditionValue = ConditionValue<String, String, String>(
                type: conditionValue.type,
                lhsType: conditionValue.lhsType,
                lhs: conditionValue.lhs,
                rhsType: conditionValue.rhsType,
                rhs: conditionValue.rhs,
                operation: conditionOperation)
            return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
        case .int:
            let conditionOperation = determineConditionOperation(forConditionType: Int.self, fromConditionOperation: conditionValue.operation)

            switch (conditionValue.lhsType, conditionValue.rhsType) {
            case (.reference, .reference):
                let conditionValue = ConditionValue<String, String, Int>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: conditionValue.lhs,
                    rhsType: conditionValue.rhsType,
                    rhs: conditionValue.rhs,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            case (.reference, .value):
                guard let rhsInt = Int(conditionValue.rhs) else { throw Abort(.internalServerError) }
                let conditionValue = ConditionValue<String, Int, Int>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: conditionValue.lhs,
                    rhsType: conditionValue.rhsType,
                    rhs: rhsInt,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            case (.value, .reference):
                guard let lhsInt = Int(conditionValue.lhs) else { throw Abort(.internalServerError) }
                let conditionValue = ConditionValue<Int, String, Int>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: lhsInt,
                    rhsType: conditionValue.rhsType,
                    rhs: conditionValue.rhs,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            case (.value, .value):
                guard let lhsInt = Int(conditionValue.lhs), let rhsInt = Int(conditionValue.rhs) else { throw Abort(.internalServerError) }
                let conditionValue = ConditionValue<Int, Int, Int>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: lhsInt,
                    rhsType: conditionValue.rhsType,
                    rhs: rhsInt,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            }
        case .double:
            let conditionOperation = determineConditionOperation(forConditionType: Double.self, fromConditionOperation: conditionValue.operation)
            
            switch (conditionValue.lhsType, conditionValue.rhsType) {
            case (.reference, .reference):
                let conditionValue = ConditionValue<String, String, Double>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: conditionValue.lhs,
                    rhsType: conditionValue.rhsType,
                    rhs: conditionValue.rhs,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            case (.reference, .value):
                guard let rhsDbl = Double(conditionValue.rhs) else { throw Abort(.internalServerError) }
                let conditionValue = ConditionValue<String, Double, Double>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: conditionValue.lhs,
                    rhsType: conditionValue.rhsType,
                    rhs: rhsDbl,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            case (.value, .reference):
                guard let lhsDbl = Double(conditionValue.lhs) else { throw Abort(.internalServerError) }
                let conditionValue = ConditionValue<Double, String, Double>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: lhsDbl,
                    rhsType: conditionValue.rhsType,
                    rhs: conditionValue.rhs,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            case (.value, .value):
                guard let lhsDbl = Double(conditionValue.lhs), let rhsDbl = Double(conditionValue.rhs) else { throw Abort(.internalServerError) }
                let conditionValue = ConditionValue<Double, Double, Double>(
                    type: conditionValue.type,
                    lhsType: conditionValue.lhsType,
                    lhs: lhsDbl,
                    rhsType: conditionValue.rhsType,
                    rhs: rhsDbl,
                    operation: conditionOperation)
                return AuthorizationValues(actionOnResourceValue: authPolicy.actionOnResourceValue, conditionValue: conditionValue)
            }
        }
    }
    
    private func determineConditionOperation<T: Comparable>(forConditionType type: T.Type, fromConditionOperation operation: ABACConditionModel.ConditionOperationType) -> ((T, T) -> Bool) {
                
        switch operation {
        case .equal:
            return equal
        case .notEqual:
            return notEqual
        case .greaterThan:
            return greaterThan
        case .lessThan:
            return lessThan
        case .greaterOrEqualThan:
            return greaterOrEqualThan
        case .lessOrEqualThan:
            return lessOrEqualThan
        }
    }
    
    private func equal<T: Comparable>(lhs:T, rhs:T) -> Bool { return lhs == rhs }
    private func notEqual<T: Comparable>(lhs:T, rhs:T) -> Bool { return lhs != rhs }
    private func greaterThan<T: Comparable>(lhs:T, rhs:T) -> Bool { return lhs > rhs }
    private func lessThan<T: Comparable>(lhs:T, rhs:T) -> Bool { return lhs < rhs }
    private func greaterOrEqualThan<T: Comparable>(lhs:T, rhs:T) -> Bool { return lhs >= rhs }
    private func lessOrEqualThan<T: Comparable>(lhs:T, rhs:T) -> Bool { return lhs <= rhs }
}
