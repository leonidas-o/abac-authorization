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
    
    func testAddRuleWithoutConditionValues() async {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        
        // When
        let rulesCountBefore = await sut.authPolicyCollection[Constant.adminRoleName]?.count
        for (_, rule) in rules.enumerated() {
            try! await sut.addToInMemoryCollection(policy: rule, conditions: [])
        }
        let rulesCountAfter = await sut.authPolicyCollection[Constant.adminRoleName]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, nil)
        XCTAssertEqual(rulesCountAfter, 3)
        await sut.removeAllFromInMemoryCollection()
    }
    
    
    func testAddRuleWithOneConditionValue() async {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        
        // When
        let rulesCountBefore = await sut.authPolicyCollection[Constant.adminRoleName]?.count
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        let rulesCountAfter = await sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCount = await sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionKey]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, nil)
        XCTAssertEqual(rulesCountAfter, 3)
        XCTAssertEqual(conditionCount, 1)
        await sut.removeAllFromInMemoryCollection()
    }
    
    
    func testRemoveRule() async {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // When
        let rulesCountBefore = await sut.authPolicyCollection[Constant.adminRoleName]?.count
        await sut.removeFromInMemoryCollection(policy: rules[0])
        let rulesCountAfter = await sut.authPolicyCollection[Constant.adminRoleName]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, 2)
        await sut.removeAllFromInMemoryCollection()
    }
    
    
    func testRemoveConditionValueInRule() async {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // When
        let rulesCountBefore = await sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCountBefore = await sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionKey]!.count
        await sut.removeFromInMemoryCollection(condition: conditions[0], in: rules[0])
        let rulesCountAfter = await sut.authPolicyCollection[Constant.adminRoleName]!.count
        let conditionCountAfter = await sut.authPolicyCollection[Constant.adminRoleName]![rules[0].actionKey]!.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, 3)
        XCTAssertEqual(conditionCountBefore, 1)
        XCTAssertEqual(conditionCountAfter, 0)
        await sut.removeAllFromInMemoryCollection()
    }
    

    func testRemoveAllRules() async {
        // Given
        let rules = ABACAuthorizationPolicyModel.createRules(for: Constant.adminRoleName, rulesPermitsAccess: true)
        let conditions = ABACConditionModel.createConditionValues(dummyRef: "roles.0.name", dummyVal: "admin")
        for (index, rule) in rules.enumerated() {
            if index == 0 {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: conditions)
            } else {
                try! await sut.addToInMemoryCollection(policy: rule, conditions: [])
            }
        }
        
        // When
        let rulesCountBefore = await sut.authPolicyCollection[Constant.adminRoleName]!.count
        await sut.removeAllFromInMemoryCollection()
        let rulesCountAfter = await sut.authPolicyCollection[Constant.adminRoleName]?.count
        
        // Then
        XCTAssertEqual(rulesCountBefore, 3)
        XCTAssertEqual(rulesCountAfter, nil)
    }
}
