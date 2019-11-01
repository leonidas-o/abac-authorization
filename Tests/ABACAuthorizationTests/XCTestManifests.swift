import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ABACMiddlewareTests.allTests),
        testCase(InMemoryAuthorizationPolicyTests.allTests)
    ]
}
#endif
