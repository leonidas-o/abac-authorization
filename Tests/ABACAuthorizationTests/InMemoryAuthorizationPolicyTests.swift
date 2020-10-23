import XCTest
@testable import ABACAuthorization

final class InMemoryAuthorizationPolicyTests: XCTestCase {
    
    
    // MARK: - Subject under test
    
    var sut: ABACAuthorizationPolicyService!

    enum Constant {
        static let existingToken = "existing-token"
        static let adminRoleName = "admin"
    }

    
    // MARK: - Test lifecycle
    
    override func setUp() {
        super.setUp()
        sut = ABACAuthorizationPolicyService.shared
    }

    override func tearDown() {

        super.tearDown()
    }

    
    // MARK: - Test doubles
    
    
    
    
    // MARK: - Tests
    
    func testAddRuleWithoutConditionValues() {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]?.count
        for (_, rule) in rules.enumerated() {
            try! sut.addToInMemoryCollection(policy: rule, conditions: [])
        }
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, nil)
        XCTAssertEqual(rulesCountAfter, 3)
        sut.removeAllFromInMemoryCollection()
    }
    
    
    func testAddRuleWithOneConditionValue() {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]?.count
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCount = sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionKey]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, nil)
        XCTAssertEqual(rulesCountAfter, 3)
        XCTAssertEqual(conditionCount, 1)
        sut.removeAllFromInMemoryCollection()
    }
    
    
    func testRemoveRule() {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]?.count
        sut.removeFromInMemoryCollection(policy: rules[0])
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, 2)
        sut.removeAllFromInMemoryCollection()
    }
    
    
    func testRemoveConditionValueInRule() {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // When
        let rulesCountBefore = sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCountBefore = sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionKey]!.count
        sut.removeFromInMemoryCollection(condition: conditions[0], in: rules[0])
        let rulesCountAfter = sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCountAfter = sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionKey]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, 3)
        XCTAssertEqual(conditionCountBefore, 1)
        XCTAssertEqual(conditionCountAfter, 0)
        sut.removeAllFromInMemoryCollection()
    }
    

    func testRemoveAllRules() {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! sut.addToInMemoryCollection(policy: rule, conditions: [])
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
}
