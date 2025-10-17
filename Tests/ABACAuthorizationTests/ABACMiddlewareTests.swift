import XCTVapor
@testable import ABACAuthorization
import Vapor

final class ABACMiddlewareTests: XCTestCase {
    
    enum Constant {
        static let existingToken = "existing-token"
        static let missingToken = "missing-token"
        static let adminRoleName = "admin"
    }
    
    public struct APIResource {
        
        public var abacApiEntry: String = "api"
        public var abacProtectedResources: [String] = [
            "abac-authorization-policies",
            "roles",
            "abac-conditions"
        ]

        
        public enum Resource: String, CaseIterable {
            case authenticate = "authenticate"
            case refresh = "refresh"
            case abacAuthorizationPolicies = "abac-authorization-policies"
            case activityTags = "activity-tags"
            case users = "users"
            case myUser = "my-user"
            case roles = "roles"
            case abacConditions = "abac-conditions"
            case bulk = "bulk"
        }
    }

    
    
    // MARK: - Test doubles

    final class ABACAccessDataRepoSpy: ABACAccessDataRepo {
        
        func get<D>(key: String, as type: D.Type) async throws -> D? where D: Decodable {
            
            var accessDataDecoded: D? = nil
            switch key {
            case Constant.existingToken:
                let user = User(name: "Alice")
                let role1 = Role(name: "admin")
                let role2 = Role(name: "coach")
                let userData = UserData(user: user, roles: [role1, role2])
                let userID = UUID()
                
                do {
                    let accessData = AccessData(id: nil, token: key, userID: userID, userData: userData)
                    let accessDataEncoded = try JSONEncoder().encode(accessData)
                    accessDataDecoded = try JSONDecoder().decode(D.self, from: accessDataEncoded)
                } catch {
                    // do nothing
                }
                return accessDataDecoded
            case Constant.missingToken:
                return accessDataDecoded
            default:
                return accessDataDecoded
            }
        }
    }
    
    
    // Models
    
    struct AccessData: Codable, ABACAccessData {
        var id: UUID?
        var token: String
        var userID: UUID
        var userData: UserData
    }
    
    struct UserData: Codable, ABACUserData {
        var user: User
        var roles: [Role]
    }
    
    struct User: Codable, ABACUser {
        var name: String
    }
    
    struct Role: Codable, ABACRole {
        var name: String
    }
    
    
    
    
    // MARK: - Tests
    
    /// Keywords for the rules in InMemoryAuthPolicies collection
    /// def: Entry defined, entry can be Resource, Token, Rule, Condition, ...
    /// undef: Entry is undefined, not existing
    /// isAllowed/ isDisallowed: Outcome of the test
    func testGetProtectedResourceWithMissingTokenIsDisallowed() async throws {
        /// If the token is undefined, it doesn't matter if there are any rules
        /// or not. Any request has to have a valid token.
        
        // Given
        let app = try await Application.make(.testing)
        
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
        }
        
        // Then
        let bearer = Constant.missingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/\(APIResource.Resource.abacAuthorizationPolicies.rawValue)", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .unauthorized)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }

    
    
    func testGetUnprotectedResourceWithExistingTokenWithDefNotMatchingPolicyWithUndefConditionIsAllowed() async throws {
        /// No rules exist for that resource
        
        // Given
        let app = try await Application.make(.testing)
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        // Route in ABAC Resources undefined/ not proteced, but exists in vapor
        // and route uses ABAC Middleware
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "any-unprotected-resource") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/any-unprotected-resource", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .ok)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }
    
    
    
    func testGetProtectedResourceWithDefTokenWithDefPolicyWithUndefConditionIsAllowed() async throws {
        // Given
        let app = try await Application.make(.testing)
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/\(APIResource.Resource.abacAuthorizationPolicies.rawValue)", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .ok)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }
    func testGetProtectedResourceWithDefTokenWithWithDefBlockingPolicyWithUndefConditionIsDisallowed() async throws {
        // Given
        let app = try await Application.make(.testing)
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: false)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/\(APIResource.Resource.abacAuthorizationPolicies.rawValue)", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }
    
    
    
    func testGetProtecedResourceWithDefTokenWithDefPolicyWithDefConditionIsAllowed() async throws {
        // Given
        let app = try await Application.make(.testing)
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/\(APIResource.Resource.abacAuthorizationPolicies.rawValue)", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .ok)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }
    func testGetProtecedResourceWithDefTokenWithDefBlockingPolicyWithDefConditionIsDisallowed() async throws {
        // As the policy is already blocking the request, the conditions have no effect
        
        // Given
        let app = try await Application.make(.testing)
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: false)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/\(APIResource.Resource.abacAuthorizationPolicies.rawValue)", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }
    
    
    
    func testGetProtectedResourceWithDefTokenWithDefPolicyWithDefNotMatchingConditionIsDisallowed() async throws {
        // Even though we've defined the default rules, witch permit access option and a condition, the request has to be disallowed.
        // The here defined condition is part of the rule, only if the whole rule (policy+condition) matches the request is granted.
        // It would allow the request if 'role.0.name' would be 'admin'
        // But as the condition says, the first role name has to be author,
        // the request will be denied as there is no existing rule which permits it.
        
        // Given
        let app = try await Application.make(.testing)
        let cache = ABACAccessDataRepoSpy()
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(accessDataRepo: cache, protectedResources: apiResource.abacProtectedResources)
        app.routes.grouped(sut).get("\(apiResource.abacApiEntry)", "\(APIResource.Resource.abacAuthorizationPolicies.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "author")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! authPolicyService.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try await app.test(.GET, "\(apiResource.abacApiEntry)/\(APIResource.Resource.abacAuthorizationPolicies.rawValue)", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res async in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
        try await app.asyncShutdown()
    }
}
