import XCTVapor
@testable import ABACAuthorization
import Vapor

final class ABACMiddlewareTests: XCTestCase {
    
    enum Constant {
        static let existingToken = "existing-token"
        static let missingToken = "missing-token"
        static let adminRoleName = "admin"
    }
    
    public struct APIResource: ABACAPIResourceable {
        public var apiEntry: String = "api"
        public var protectedResources: [String] = Resource.allCases.map { $0.rawValue }

        public enum Resource: String, CaseIterable {
            case authenticate = "authenticate"
            case refresh = "refresh"
            case authorizationPolicy = "authorization-policies"
            case activityTags = "activity-tags"
            case users = "users"
            case myUser = "my-user"
            case roles = "roles"
            case conditionValueDB = "condition-values"
        }
    }

    
    
    // MARK: - Test doubles

    final class ABACCacheRepoSpy: ABACCacheRepo {
        let eventLoop: EventLoop
        
        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
        }
        
        func get<D>(key: String, as type: D.Type) -> EventLoopFuture<D?> where D : Decodable {
            
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
                return eventLoop.future(accessDataDecoded)
            case Constant.missingToken:
                return eventLoop.future(accessDataDecoded)
            default:
                return eventLoop.future(accessDataDecoded)
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
    func testGetDefResourceWithUndefTokenIsDisallowed() {
        /// If the token is undefined, it doesn't matter if there are any rules
        /// or not. Any request has to have a valid token.
        
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "\(APIResource.Resource.authorizationPolicy.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        let bearer = Constant.missingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/authorization-policies", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .unauthorized)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }

    
    
    func testGetUndefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed() {
        /// No rules exist for that resource
        
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "\(APIResource.Resource.authorizationPolicy.rawValue)") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        // Route in ABAC Resources undefined/ not proteced, but exists in vapor
        // and route uses ABAC Middleware
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "any-undefined-resource") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/any-undefined-resource", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }
    
    
    
    func testGetDefResourceWithDefTokenWithWithDefRuleWithUndefConditionIsAllowed() {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "authorization-policies") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/authorization-policies", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }
    func testGetDefResourceWithDefTokenWithWithDefBlockingRuleWithUndefConditionIsDisallowed() {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "authorization-policies") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: false)
        for (_, rule) in rules.enumerated() {
            try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/authorization-policies", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }
    
    
    
    func testGetDefResourceWithDefTokenWithDefRuleWithDefConditionIsAllowed() {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "authorization-policies") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        let conditionValues = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! authPolicyService.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/authorization-policies", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }
    func testGetDefResourceWithDefTokenWithDefBlockingRuleWithDefConditionIsAllowed() {
        // Given
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "authorization-policies") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: false)
        let conditionValues = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! authPolicyService.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/authorization-policies", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }
    
    
    
    func testGetDefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed() {
        // Even though we've defined one condition, the request has to be disallowed.
        // The here defined condition is part of the rule, only if the whole rule matches the request is granted.
        // It would allow the request if 'role.0.name' would be 'admin'
        // But as the condition says, the first role name has to be coach,
        // the request will be denied as there is no existing rule which permits it.
        
        let app = Application(.testing)
        defer { app.shutdown() }
        let cache = ABACCacheRepoSpy(eventLoop: app.eventLoopGroup.next())
        let apiResource = APIResource()
        let sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        app.routes.grouped(sut).get("\(apiResource.apiEntry)", "authorization-policies") { req in
            return req.eventLoop.future(HTTPStatus.ok)
        }
        
        // When
        let authPolicyService = ABACAuthorizationPolicyService.shared
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        let conditionValues = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "coach")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! authPolicyService.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! authPolicyService.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        
        // Then
        let bearer = Constant.existingToken
        do {
            try app.test(.GET, "\(apiResource.apiEntry)/authorization-policies", headers: ["Authorization": "Bearer \(bearer)"], afterResponse: { res in
                XCTAssertEqual(res.status, .forbidden)
            })
        } catch {
            XCTAssertTrue(false, "\(#function): \(error)")
        }
        authPolicyService.removeAllFromInMemoryCollection()
    }

}
