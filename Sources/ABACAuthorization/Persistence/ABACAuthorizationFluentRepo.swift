import Vapor
import Fluent

public struct ABACAuthorizationFluentRepo: ABACAuthorizationPersistenceRepo {
    
    let db: Database
    let dbRo: Database?
    
    public init(db: Database, dbRo: Database? = nil) {
        self.db = db
        self.dbRo = dbRo
    }
    
    
    
    // MARK: - AuthorizationPolicy
    
    public func save(_ policy: ABACAuthorizationPolicyModel) async throws {
        return try await policy.save(on: db)
    }
    
    
    public func saveBulk(_ policies: [ABACAuthorizationPolicyModel]) async throws {
        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for policy in policies {
                taskGroup.addTask {
                    try await policy.save(on: db)
                }
            }
        }
    }
    
    
    public func getAllWithConditions() async throws -> [ABACAuthorizationPolicyModel] {
        return try await ABACAuthorizationPolicyModel.query(on: dbRo ?? db).with(\.$conditions).all()
    }
    
    
    public func get(_ policyId: ABACAuthorizationPolicyModel.IDValue) async throws -> ABACAuthorizationPolicyModel? {
        return try await ABACAuthorizationPolicyModel.find(policyId, on: dbRo ?? db)
    }
    
    
    public func getWithConditions(_ policyId: ABACAuthorizationPolicyModel.IDValue) async throws -> ABACAuthorizationPolicyModel? {
        return try await ABACAuthorizationPolicyModel.query(on: dbRo ?? db).with(\.$conditions).filter(\.$id == policyId).first()
    }
    
    
    public func update(_ policy: ABACAuthorizationPolicyModel, updatedPolicy: ABACAuthorizationPolicy) async throws {
        policy.roleName = updatedPolicy.roleName
        policy.actionKey = updatedPolicy.actionKey
        policy.actionValue = updatedPolicy.actionValue
        return try await policy.save(on: db)
    }
    
    
    public func delete(_ policyId: ABACAuthorizationPolicyModel.IDValue) async throws {
        return try await ABACAuthorizationPolicyModel.query(on: db).filter(\.$id == policyId).delete()
    }
    
    
    public func delete(_ policy: ABACAuthorizationPolicyModel) async throws {
        return try await policy.delete(on: db)
    }
    
    
    public func delete(_ policies: [ABACAuthorizationPolicyModel]) async throws {
        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for policy in policies {
                taskGroup.addTask {
                    try await policy.delete(on: db)
                }
            }
        }
    }
    
    
    public func delete(actionOnResourceKeys: [String]) async throws {
        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for key in actionOnResourceKeys {
                taskGroup.addTask {
                    try await ABACAuthorizationPolicyModel.query(on: db).filter(\.$actionKey == key).delete()
                }
            }
        }
    }
    
    
    
    // MARK: - Conditions
    
    public func saveCondition(_ condition: ABACConditionModel) async throws {
        return try await condition.save(on: db)
    }
    
    
    public func getCondition(_ conditionId: ABACConditionModel.IDValue) async throws -> ABACConditionModel? {
        return try await ABACConditionModel.find(conditionId, on: dbRo ?? db)
    }
    
    
    public func getConditionWithPolicy(_ conditionId: ABACConditionModel.IDValue) async throws -> ABACConditionModel? {
        return try await ABACConditionModel.query(on: dbRo ?? db).with(\.$authorizationPolicy).filter(\.$id == conditionId).first()
    }
    
    
    public func updateCondition(_ condition: ABACConditionModel, updatedCondition: ABACCondition) async throws {
        condition.key = updatedCondition.key
        condition.type = updatedCondition.type
        condition.operation = updatedCondition.operation
        condition.lhsType = updatedCondition.lhsType
        condition.lhs = updatedCondition.lhs
        condition.rhsType = updatedCondition.rhsType
        condition.rhs = updatedCondition.rhs
        //condition.authorizationPolicyID = updatedConditionValueDB.authorizationPolicyID
        return try await condition.save(on: db)
    }
    
    
    public func deleteCondition(_ conditionId: ABACConditionModel.IDValue) async throws {
        return try await ABACConditionModel.query(on: db).filter(\.$id == conditionId).delete()
    }
    
    
    public func deleteCondition(_ condition: ABACConditionModel) async throws {
        return try await condition.delete(on: db)
    }
    
    
    
    // MARK: - Relations
    
    public func getAllConditions(_ authPolicy: ABACAuthorizationPolicyModel) async throws -> [ABACConditionModel] {
        return try await authPolicy.$conditions.query(on: dbRo ?? db).all()
    }
    
    
    public func getConditionPolicy(_ condition: ABACConditionModel) async throws -> ABACAuthorizationPolicyModel {
        return try await condition.$authorizationPolicy.get(on: dbRo ?? db)
    }
    
}
