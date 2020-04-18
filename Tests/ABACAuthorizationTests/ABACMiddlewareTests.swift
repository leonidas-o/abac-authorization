import XCTest
@testable import ABACAuthorization
import Vapor
import Foundation

final class ABACMiddlewareTests: XCTestCase {
    
    // MARK: - Subject under test
    
    var sut: ABACMiddleware<AccessData>!
    
    var app: Application!
    var request: Request!
    var responder: Responder!
    var apiResource: APIResource!
    
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

    
    // MARK: - Test lifecycle
    
    override func setUp() {
        super.setUp()
        
        app = try! Application.testable()        
        let cache = ABACCacheStoreSpy(container: app)
        apiResource = APIResource()
        sut = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        request = Request(using: app)
        responder = ResponderSpy(container: app)
    }

    override func tearDown() {
        try? app.syncShutdownGracefully()
        super.tearDown()
    }

    
    // MARK: - Test doubles
    
    class ContainerSpy: Container {
        var config: Config
        var environment: Environment
        var services: Services
        var serviceCache: ServiceCache
        
        init() {
            self.config = Config.default()
            self.environment = Environment.testing
            self.services = Services.default()
            self.serviceCache = ServiceCache()
        }
    }

    class ABACCacheStoreSpy: ABACCacheStore {
        let container: Container
        var getAccessDataCalled = false
        
        init(container: Container) {
            self.container = container
        }
        
        func get<D>(key: String, as type: D.Type) -> EventLoopFuture<D?> where D : Decodable {
            getAccessDataCalled = true
            
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
                return container.future(accessDataDecoded)
            case Constant.missingToken:
                return container.future(accessDataDecoded)
            default:
                return container.future(accessDataDecoded)
            }
        }
    }
    
    class ResponderSpy: Responder {
        let container: Container
        init(container: Container) {
            self.container = container
        }
        
        func respond(to req: Request) throws -> EventLoopFuture<Response> {
            let response = Response(using: container)
            return container.future(response)
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
        // If the token is undefined, it doesn't matter if there are any rules
        // or not. Any request has to have a valid token.
        
        // Given
        let bearer = BearerAuthorization(token: Constant.missingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.test.com/\(apiResource.apiEntry)/authorization-policies")
        request.http.url = url!
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.unauthorized)
        } catch {
            if let abortError = error as? AbortError {
                XCTAssertEqual(abortError.status, HTTPStatus.unauthorized)
            }
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }

    
    
    func testGetUndefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed() {
        // No rules exist for that resource
        
        // Given
        let bearer = BearerAuthorization(token: Constant.existingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.foo.com/\(apiResource.apiEntry)/any-undefined-resource")
        request.http.url = url!
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.forbidden)
        } catch {
            if let abortError = error as? AbortError {
                XCTAssertEqual(abortError.status, HTTPStatus.forbidden)
            }
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }
    
    
    
    func testGetDefResourceWithDefTokenWithWithDefRuleWithUndefConditionIsAllowed() {
        
        // Given
        let bearer = BearerAuthorization(token: Constant.existingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.foo.com/\(apiResource.apiEntry)/authorization-policies")
        request.http.url = url!
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (_, rule) in rules.enumerated() {
            try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.ok)
        } catch {
            XCTAssertTrue(false, "Error thrown, unexpected response status")
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }
    func testGetDefResourceWithDefTokenWithWithDefBlockingRuleWithUndefConditionIsDisallowed() {
        // Given
        let bearer = BearerAuthorization(token: Constant.existingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.foo.com/\(apiResource.apiEntry)/authorization-policies")
        request.http.url = url!
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: false)
        for (_, rule) in rules.enumerated() {
            try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.forbidden)
        } catch {
            if let abortError = error as? AbortError {
                XCTAssertEqual(abortError.status, HTTPStatus.forbidden)
            }
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }
    
    
    
    func testGetDefResourceWithDefTokenWithDefRuleWithDefConditionIsAllowed() {
        // Given
        let bearer = BearerAuthorization(token: Constant.existingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.foo.com/\(apiResource.apiEntry)/authorization-policies")
        request.http.url = url!
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! inMemAuthPolicy.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
                
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.ok)
        } catch {
            XCTAssertTrue(false, "Error thrown, unexpected response status")
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }
    func testGetDefResourceWithDefTokenWithDefBlockingRuleWithDefConditionIsAllowed() {
        // Given
        let bearer = BearerAuthorization(token: Constant.existingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.foo.com/\(apiResource.apiEntry)/authorization-policies")
        request.http.url = url!
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: false)
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! inMemAuthPolicy.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
                
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.forbidden)
        } catch {
            if let abortError = error as? AbortError {
                XCTAssertEqual(abortError.status, HTTPStatus.forbidden)
            }
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }
    
    
    
    func testGetDefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed() {
        // Even though we've defined a condition, it have to be disallowed
        // The here defined condition is part of the rule, only if the whole rule matches
        // the request is granted.
        // It would allow the request if role.0.name would be 'admin'
        // But as the condition says, the first role name has to be coach, the request
        // will be denied as there is no existing rule which permits the current request.
        
        // Given
        let bearer = BearerAuthorization(token: Constant.existingToken)
        request.http.headers.bearerAuthorization = bearer
        request.http.method = HTTPMethod.GET
        let url = URL(string: "https://www.foo.com/\(apiResource.apiEntry)/authorization-policies")
        request.http.url = url!
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "coach")
        
        // When
        let inMemAuthPolicy = InMemoryAuthorizationPolicy.shared
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! inMemAuthPolicy.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! inMemAuthPolicy.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
                
        // Then
        do {
            let response = try sut.respond(to: request, chainingTo: responder).wait()
            XCTAssertEqual(response.http.status, HTTPStatus.forbidden)
        } catch {
            if let abortError = error as? AbortError {
                XCTAssertEqual(abortError.status, HTTPStatus.forbidden)
            }
        }
        inMemAuthPolicy.removeAllFromInMemoryCollection()
    }
    
    
    
    
    static var allTests = [
        ("testGetDefResourceWithUndefTokenIsDisallowed", testGetDefResourceWithUndefTokenIsDisallowed),
        ("testGetUndefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed", testGetUndefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed),
        ("testGetDefResourceWithDefTokenWithWithDefRuleWithUndefConditionIsAllowed", testGetDefResourceWithDefTokenWithWithDefRuleWithUndefConditionIsAllowed),
        ("testGetDefResourceWithDefTokenWithWithDefBlockingRuleWithUndefConditionIsDisallowed", testGetDefResourceWithDefTokenWithWithDefBlockingRuleWithUndefConditionIsDisallowed),
        ("testGetDefResourceWithDefTokenWithDefRuleWithDefConditionIsAllowed", testGetDefResourceWithDefTokenWithDefRuleWithDefConditionIsAllowed),
        ("testGetDefResourceWithDefTokenWithDefBlockingRuleWithDefConditionIsAllowed", testGetDefResourceWithDefTokenWithDefBlockingRuleWithDefConditionIsAllowed),
        ("testGetDefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed", testGetDefResourceWithDefTokenWithUndefRuleWithUndefConditionIsDisallowed)
    ]

}
