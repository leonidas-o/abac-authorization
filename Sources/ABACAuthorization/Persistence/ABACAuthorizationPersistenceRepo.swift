import NIO

public protocol ABACAuthorizationPersistenceRepo {
    // ABACAuthorizationPolicies
    func save(_ policy: ABACAuthorizationPolicyModel) async throws -> Void
    func saveBulk(_ policies: [ABACAuthorizationPolicyModel]) async throws
    func getAllWithConditions() async throws -> [ABACAuthorizationPolicyModel]
    func get(_ policyId: ABACAuthorizationPolicyModel.IDValue) async throws -> ABACAuthorizationPolicyModel?
    func getWithConditions(_ policyId: ABACAuthorizationPolicyModel.IDValue) async throws -> ABACAuthorizationPolicyModel?
    func update(_ policy: ABACAuthorizationPolicyModel, updatedPolicy: ABACAuthorizationPolicy) async throws
    func delete(_ policyId: ABACAuthorizationPolicyModel.IDValue) async throws
    func delete(_ policy: ABACAuthorizationPolicyModel) async throws
    func delete(_ policies: [ABACAuthorizationPolicyModel]) async throws
    func delete(actionOnResourceKeys: [String]) async throws
    // ABACConditions
    func saveCondition(_ condition: ABACConditionModel) async throws
    func getCondition(_ conditionId: ABACConditionModel.IDValue) async throws -> ABACConditionModel?
    func getConditionWithPolicy(_ conditionId: ABACConditionModel.IDValue) async throws -> ABACConditionModel?
    func updateCondition(_ condition: ABACConditionModel, updatedCondition: ABACCondition) async throws
    func deleteCondition(_ conditionId: ABACConditionModel.IDValue) async throws
    func deleteCondition(_ condition: ABACConditionModel) async throws
    // Relations
    func getAllConditions(_ authPolicy: ABACAuthorizationPolicyModel) async throws -> [ABACConditionModel]
    func getConditionPolicy(_ condition: ABACConditionModel) async throws -> ABACAuthorizationPolicyModel
}
