import Vapor
import Fluent
import FluentPostgresDriver
import ABACAuthorization


struct ABACAuthorizationPostgreSQLRepo: ABACAuthorizationPersistenceRepo {
    
    let db: Database
    
    
    
    // MARK: - AuthorizationPolicy
    
    func save(_ policy: ABACAuthorizationPolicyModel) -> EventLoopFuture<Void> {
        return policy.save(on: db)
    }
    
    
    func saveBulk(_ policies: [ABACAuthorizationPolicyModel]) -> EventLoopFuture<Void> {
        
        let policySaveResults = policies.map { $0.save(on: db) }
        return policySaveResults.flatten(on: db.eventLoop)
    }
    
    
    func getAllWithConditions() -> EventLoopFuture<[ABACAuthorizationPolicyModel]> {
        return ABACAuthorizationPolicyModel.query(on: db).with(\.$conditions).all()
    }
    
    
    func _get(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<ABACAuthorizationPolicyModel?> {
        return ABACAuthorizationPolicyModel.find(policyId, on: db)
    }
    
    
    func getWithConditions(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<ABACAuthorizationPolicyModel?> {
        return ABACAuthorizationPolicyModel.query(on: db).with(\.$conditions).filter(\.$id == policyId).first()
    }
    
    
    func update(_ policy: ABACAuthorizationPolicyModel, updatedPolicy: ABACAuthorizationPolicy) -> EventLoopFuture<Void> {
           
        policy.roleName = updatedPolicy.roleName
        policy.actionOnResourceKey = updatedPolicy.actionOnResourceKey
        policy.actionOnResourceValue = updatedPolicy.actionOnResourceValue
        
        return policy.save(on: db)
    }
    
    
    func delete(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<Void> {
        return ABACAuthorizationPolicyModel.query(on: db).filter(\.$id == policyId).delete()
    }
    
    
    func delete(_ policy: ABACAuthorizationPolicyModel) -> EventLoopFuture<Void> {
        return policy.delete(on: db)
    }
    
    
    func delete(_ policies: [ABACAuthorizationPolicyModel]) -> EventLoopFuture<Void> {
        let authPolicyDeleteResults = policies.map { policy in
            policy.delete(on: db)
        }
        return authPolicyDeleteResults.flatten(on: db.eventLoop)
    }
    
    
    func delete(actionOnResourceKeys: [String]) -> EventLoopFuture<Void> {
        let authPolicyDeleteResults = actionOnResourceKeys.map { key in
            return ABACAuthorizationPolicyModel.query(on: db).filter(\.$actionOnResourceKey == key).delete()
        }
        return authPolicyDeleteResults.flatten(on: db.eventLoop)
    }
    
    
    
    // MARK: - Conditions
    
    func saveCondition(_ condition: ABACConditionModel) -> EventLoopFuture<Void> {
        condition.save(on: db)
    }
    
    
    func _getCondition(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<ABACConditionModel?> {
        return ABACConditionModel.find(conditionId, on: db)
    }
    
    
    func getConditionWithPolicy(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<ABACConditionModel?> {
        return ABACConditionModel.query(on: db).with(\.$authorizationPolicy).filter(\.$id == conditionId).first()
    }
    
    
    func updateCondition(_ condition: ABACConditionModel, updatedCondition: ABACCondition) -> EventLoopFuture<Void> {
        
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
    
    
    func deleteCondition(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<Void> {
        return ABACConditionModel.query(on: db).filter(\.$id == conditionId).delete()
    }
    
    
    func deleteCondition(_ condition: ABACConditionModel) -> EventLoopFuture<Void> {
        return condition.delete(on: db)
    }
    
    
    
    // MARK: - Relations
    
    func getAllConditions(_ authPolicy: ABACAuthorizationPolicyModel) -> EventLoopFuture<[ABACConditionModel]> {
        authPolicy.$conditions.query(on: db).all()
    }
    
    
    func getConditionPolicy(_ condition: ABACConditionModel) -> EventLoopFuture<ABACAuthorizationPolicyModel> {
        return condition.$authorizationPolicy.get(on: db)
    }
    
}
