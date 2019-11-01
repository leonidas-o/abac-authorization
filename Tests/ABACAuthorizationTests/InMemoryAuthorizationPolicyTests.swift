import XCTest
@testable import ABACAuthorization

final class InMemoryAuthorizationPolicyTests: XCTestCase {
    
    
    // MARK: - Subject under test
    
    var sut: InMemoryAuthorizationPolicy!

    enum Constant {
        static let existingToken = "existing-token"
        static let adminRoleName = "admin"
    }

    
    // MARK: - Test lifecycle
    
    override func setUp() {
        super.setUp()
        sut = InMemoryAuthorizationPolicy.shared
    }

    override func tearDown() {

        super.tearDown()
    }

    
    // MARK: - Test doubles
    
    
    
    
    // MARK: - Tests
    
    func testAddRuleWithoutConditionValues() {
        // Given
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]?.count
        for (_, rule) in rules.enumerated() {
            try! sut.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
        }
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, nil)
        XCTAssertEqual(rulesCountAfter, 3)
        sut.removeAllFromInMemoryCollection()
    }
    
    func testAddRuleWithOneConditionValue() {
        // Given
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]?.count
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! sut.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCount = sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionOnResourceKey]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, nil)
        XCTAssertEqual(rulesCountAfter, 3)
        XCTAssertEqual(conditionCount, 1)
        sut.removeAllFromInMemoryCollection()
    }
    
    
    
    func testRemoveRule() {
        // Given
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! sut.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]?.count
        sut.removeFromInMemoryCollection(authPolicy: rules[0])
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, 2)
        sut.removeAllFromInMemoryCollection()
    }
    
    func testRemoveConditionValueInRule() {
        // Given
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! sut.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCountBefore = sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionOnResourceKey]!.count
        sut.removeFromInMemoryCollection(conditionValue: conditionValues[0], in: rules[0])
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCountAfter = sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionOnResourceKey]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, 3)
        XCTAssertEqual(conditionCountBefore, 1)
        XCTAssertEqual(conditionCountAfter, 0)
        sut.removeAllFromInMemoryCollection()
    }

    func testRemoveAllRules() {
        // Given
        let rules = AuthorizationPolicy.createRules(for: Constant.adminRoleName, allRulesPermitsAccess: true)
        let conditionValues = ConditionValueDB.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(
                    authPolicy: rule,
                    conditionValues: conditionValues)
            } else {
                try! sut.addToInMemoryCollection(
                authPolicy: rule,
                conditionValues: [])
            }
        }
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]!.count
        sut.removeAllFromInMemoryCollection()
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]?.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, nil)
    }
    
    

    static var allTests = [
        ("testAddRuleWithoutConditionValues", testAddRuleWithoutConditionValues),
        ("testAddRuleWithOneConditionValue" ,testAddRuleWithOneConditionValue),
        ("testRemoveRule", testRemoveRule),
        ("testRemoveConditionValueInRule", testRemoveConditionValueInRule),
        ("testRemoveAllRules", testRemoveAllRules)
    ]
}
