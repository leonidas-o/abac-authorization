import Vapor
import Fluent
import FluentPostgresDriver


public struct ABACAuthorizationPostgreSQLRepo: ABACAuthorizationPersistenceRepo {
    
    let db: Database
    
    
    
    // MARK: - AuthorizationPolicy
    
    public func save(_ policy: ABACAuthorizationPolicyModel) -> EventLoopFuture<Void> {
        return policy.save(on: db)
    }
    
    
    public func saveBulk(_ policies: [ABACAuthorizationPolicyModel]) -> EventLoopFuture<Void> {
        
        let policySaveResults = policies.map { $0.save(on: db) }
        return policySaveResults.flatten(on: db.eventLoop)
    }
    
    
    public func getAllWithConditions() -> EventLoopFuture<[ABACAuthorizationPolicyModel]> {
        return ABACAuthorizationPolicyModel.query(on: db).with(\.$conditions).all()
    }
    
    
    public func _get(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<ABACAuthorizationPolicyModel?> {
        return ABACAuthorizationPolicyModel.find(policyId, on: db)
    }
    
    
    public func getWithConditions(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<ABACAuthorizationPolicyModel?> {
        return ABACAuthorizationPolicyModel.query(on: db).with(\.$conditions).filter(\.$id == policyId).first()
    }
    
    
    public func update(_ policy: ABACAuthorizationPolicyModel, updatedPolicy: ABACAuthorizationPolicy) -> EventLoopFuture<Void> {
           
        policy.roleName = updatedPolicy.roleName
        policy.actionOnResourceKey = updatedPolicy.actionOnResourceKey
        policy.actionOnResourceValue = updatedPolicy.actionOnResourceValue
        
        return policy.save(on: db)
    }
    
    
    public func delete(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<Void> {
        return ABACAuthorizationPolicyModel.query(on: db).filter(\.$id == policyId).delete()
    }
    
    
    public func delete(_ policy: ABACAuthorizationPolicyModel) -> EventLoopFuture<Void> {
        return policy.delete(on: db)
    }
    
    
    public func delete(_ policies: [ABACAuthorizationPolicyModel]) -> EventLoopFuture<Void> {
        let authPolicyDeleteResults = policies.map { policy in
            policy.delete(on: db)
        }
        return authPolicyDeleteResults.flatten(on: db.eventLoop)
    }
    
    
    public func delete(actionOnResourceKeys: [String]) -> EventLoopFuture<Void> {
        let authPolicyDeleteResults = actionOnResourceKeys.map { key in
            return ABACAuthorizationPolicyModel.query(on: db).filter(\.$actionOnResourceKey == key).delete()
        }
        return authPolicyDeleteResults.flatten(on: db.eventLoop)
    }
    
    
    
    // MARK: - Conditions
    
    public func saveCondition(_ condition: ABACConditionModel) -> EventLoopFuture<Void> {
        condition.save(on: db)
    }
    
    
    public func _getCondition(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<ABACConditionModel?> {
        return ABACConditionModel.find(conditionId, on: db)
    }
    
    
    public func getConditionWithPolicy(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<ABACConditionModel?> {
        return ABACConditionModel.query(on: db).with(\.$authorizationPolicy).filter(\.$id == conditionId).first()
    }
    
    
    public func updateCondition(_ condition: ABACConditionModel, updatedCondition: ABACCondition) -> EventLoopFuture<Void> {
        
        condition.key = updatedCondition.key
        condition.type = updatedCondition.type
        condition.operation = updatedCondition.operation
        condition.lhsType = updatedCondition.lhsType
        condition.lhs = updatedCondition.lhs
        condition.rhsType = updatedCondition.rhsType
        condition.rhs = updatedCondition.rhs
        //condition.authorizationPolicyID = updatedConditionValueDB.authorizationPolicyID
        
        return condition.save(on: db)
    }
    
    
    public func deleteCondition(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<Void> {
        return ABACConditionModel.query(on: db).filter(\.$id == conditionId).delete()
    }
    
    
    public func deleteCondition(_ condition: ABACConditionModel) -> EventLoopFuture<Void> {
        return condition.delete(on: db)
    }
    
    
    
    // MARK: - Relations
    
    public func getAllConditions(_ authPolicy: ABACAuthorizationPolicyModel) -> EventLoopFuture<[ABACConditionModel]> {
        authPolicy.$conditions.query(on: db).all()
    }
    
    
    public func getConditionPolicy(_ condition: ABACConditionModel) -> EventLoopFuture<ABACAuthorizationPolicyModel> {
        return condition.$authorizationPolicy.get(on: db)
    }
    
}
