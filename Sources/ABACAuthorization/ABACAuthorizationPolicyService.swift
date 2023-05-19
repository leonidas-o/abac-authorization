import Vapor
import Foundation

protocol AuthorizationValuable {
    var actionValue: Bool { get set }
    var condition: ConditionValuable? { get set}
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
        get {
            return authPolicyQueue.sync { authPolicyCollectionValue }
        }
        set(newValue) {
            authPolicyQueue.async(flags: DispatchWorkItemFlags.barrier) { self.authPolicyCollectionValue = newValue }
        }
    }
}



// MARK: - Vapor extensions

extension Application {
    public var abacAuthorizationPolicyService: ABACAuthorizationPolicyService {
        return ABACAuthorizationPolicyService.shared
    }
}

extension Request {
    public var abacAuthorizationPolicyService: ABACAuthorizationPolicyService {
        return ABACAuthorizationPolicyService.shared
    }
}



// MARK: - Structure

extension ABACAuthorizationPolicyService {
    private struct Authorization: AuthorizationValuable {
        var actionValue: Bool
        var condition: ConditionValuable?
    }
    
    struct Condition<LhsT: Comparable, RhsT: Comparable, OpsT: Comparable>: ConditionValuable {
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
    public func addToInMemoryCollection(policy: ABACAuthorizationPolicyModel, conditions: [ABACConditionModel]) throws {
        if conditions.isEmpty {
            let authValues = try prepareInMemoryAuthorizationValues(policy, condition: nil)
            add(policy: policy, conditionKey: ABACConditionModel.Constant.defaultConditionKey, authValues: authValues)
        } else {
            for condition in conditions {
                let authValues = try prepareInMemoryAuthorizationValues(policy, condition: condition)
                add(policy: policy, conditionKey: condition.key, authValues: authValues)
            }
        }
    }
    private func add(policy: ABACAuthorizationPolicyModel, conditionKey: String, authValues: Authorization) {
        if self.authPolicyCollection[policy.roleName] == nil {
            self.authPolicyCollection[policy.roleName] = [policy.actionKey:[conditionKey:authValues]]
        } else if self.authPolicyCollection[policy.roleName]![policy.actionKey] == nil {
            self.authPolicyCollection[policy.roleName]![policy.actionKey] = [conditionKey:authValues]
        } else {
            self.authPolicyCollection[policy.roleName]![policy.actionKey]![conditionKey] = authValues
        }
    }
}



extension ABACAuthorizationPolicyService {
    func removeFromInMemoryCollection(policy: ABACAuthorizationPolicyModel) {
        self.authPolicyCollection[policy.roleName]?.removeValue(forKey: policy.actionKey)
    }
    
    func removeFromInMemoryCollection(condition: ABACConditionModel, in policy: ABACAuthorizationPolicyModel) {
        self.authPolicyCollection[policy.roleName]?[policy.actionKey]?.removeValue(forKey: condition.key)
    }
    
    public func removeAllFromInMemoryCollection() {
        self.authPolicyCollection.removeAll()
    }
}



extension ABACAuthorizationPolicyService {
    private func prepareInMemoryAuthorizationValues(_ policy: ABACAuthorizationPolicyModel, condition: ABACConditionModel?) throws -> Authorization {
        
        guard let condition = condition else {
            return Authorization(actionValue: policy.actionValue, condition: nil)
        }
        
        switch condition.type {
        case .string:
            let conditionOperation = determineConditionOperation(forConditionType: String.self, fromConditionOperation: condition.operation)
            
            let condition = Condition<String, String, String>(
                type: condition.type,
                lhsType: condition.lhsType,
                lhs: condition.lhs,
                rhsType: condition.rhsType,
                rhs: condition.rhs,
                operation: conditionOperation)
            return Authorization(actionValue: policy.actionValue, condition: condition)
        case .int:
            let conditionOperation = determineConditionOperation(forConditionType: Int.self, fromConditionOperation: condition.operation)

            switch (condition.lhsType, condition.rhsType) {
            case (.reference, .reference):
                let condition = Condition<String, String, Int>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: condition.lhs,
                    rhsType: condition.rhsType,
                    rhs: condition.rhs,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            case (.reference, .value):
                guard let rhsInt = Int(condition.rhs) else { throw Abort(.internalServerError) }
                let condition = Condition<String, Int, Int>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: condition.lhs,
                    rhsType: condition.rhsType,
                    rhs: rhsInt,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            case (.value, .reference):
                guard let lhsInt = Int(condition.lhs) else { throw Abort(.internalServerError) }
                let condition = Condition<Int, String, Int>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: lhsInt,
                    rhsType: condition.rhsType,
                    rhs: condition.rhs,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            case (.value, .value):
                guard let lhsInt = Int(condition.lhs), let rhsInt = Int(condition.rhs) else { throw Abort(.internalServerError) }
                let condition = Condition<Int, Int, Int>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: lhsInt,
                    rhsType: condition.rhsType,
                    rhs: rhsInt,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            }
        case .double:
            let conditionOperation = determineConditionOperation(forConditionType: Double.self, fromConditionOperation: condition.operation)
            
            switch (condition.lhsType, condition.rhsType) {
            case (.reference, .reference):
                let condition = Condition<String, String, Double>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: condition.lhs,
                    rhsType: condition.rhsType,
                    rhs: condition.rhs,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            case (.reference, .value):
                guard let rhsDbl = Double(condition.rhs) else { throw Abort(.internalServerError) }
                let condition = Condition<String, Double, Double>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: condition.lhs,
                    rhsType: condition.rhsType,
                    rhs: rhsDbl,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            case (.value, .reference):
                guard let lhsDbl = Double(condition.lhs) else { throw Abort(.internalServerError) }
                let condition = Condition<Double, String, Double>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: lhsDbl,
                    rhsType: condition.rhsType,
                    rhs: condition.rhs,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
            case (.value, .value):
                guard let lhsDbl = Double(condition.lhs), let rhsDbl = Double(condition.rhs) else { throw Abort(.internalServerError) }
                let condition = Condition<Double, Double, Double>(
                    type: condition.type,
                    lhsType: condition.lhsType,
                    lhs: lhsDbl,
                    rhsType: condition.rhsType,
                    rhs: rhsDbl,
                    operation: conditionOperation)
                return Authorization(actionValue: policy.actionValue, condition: condition)
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
