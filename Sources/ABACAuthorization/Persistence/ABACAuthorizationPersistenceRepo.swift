import ABACAuthorization
import NIO


protocol ABACAuthorizationPersistenceRepo {
    // ABACAuthorizationPolicies
    func save(_ policy: ABACAuthorizationPolicyModel) -> EventLoopFuture<Void>
    func saveBulk(_ policies: [ABACAuthorizationPolicyModel]) -> EventLoopFuture<Void>
    func getAllWithConditions() -> EventLoopFuture<[ABACAuthorizationPolicyModel]>
    func _get(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<ABACAuthorizationPolicyModel?>
    func getWithConditions(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<ABACAuthorizationPolicyModel?>
    func update(_ policy: ABACAuthorizationPolicyModel, updatedPolicy: ABACAuthorizationPolicy) -> EventLoopFuture<Void>
    func delete(_ policyId: ABACAuthorizationPolicyModel.IDValue) -> EventLoopFuture<Void>
    func delete(_ policy: ABACAuthorizationPolicyModel) -> EventLoopFuture<Void>
    func delete(_ policies: [ABACAuthorizationPolicyModel]) -> EventLoopFuture<Void>
    func delete(actionOnResourceKeys: [String]) -> EventLoopFuture<Void>
    // ABACConditions
    func saveCondition(_ condition: ABACConditionModel) -> EventLoopFuture<Void>
    func _getCondition(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<ABACConditionModel?>
    func getConditionWithPolicy(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<ABACConditionModel?>
    func updateCondition(_ condition: ABACConditionModel, updatedCondition: ABACCondition) -> EventLoopFuture<Void>
    func deleteCondition(_ conditionId: ABACConditionModel.IDValue) -> EventLoopFuture<Void>
    func deleteCondition(_ condition: ABACConditionModel) -> EventLoopFuture<Void>
    // Relations
    func getAllConditions(_ authPolicy: ABACAuthorizationPolicyModel) -> EventLoopFuture<[ABACConditionModel]>
    func getConditionPolicy(_ condition: ABACConditionModel) -> EventLoopFuture<ABACAuthorizationPolicyModel>
}
