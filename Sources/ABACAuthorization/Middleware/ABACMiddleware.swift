import Vapor
import Foundation

public final class ABACMiddleware<AD: ABACAccessData>: AsyncMiddleware {
    
    private let authorizationPolicyService: ABACAuthorizationPolicyService
    private let accessDataRepo: ABACAccessDataRepo
    private let protectedResources: [String]
    
    
    public init(_ type: AD.Type = AD.self, accessDataRepo: ABACAccessDataRepo, protectedResources: [String]) {
        self.authorizationPolicyService = ABACAuthorizationPolicyService.shared
        self.accessDataRepo = accessDataRepo
        self.protectedResources = protectedResources
    }
    
    
    // MARK: - Policy Enforcement Point (PEP)
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        
        let pathComponents = request.url.path.pathComponents
        let range = getPathComponentsRange(pathComponents)
        let resource = getRequestedAndProtectedResource(fromPathComponents: pathComponents[range])
        guard !resource.isEmpty else {
            // permit access as requested resource is unprotected
            return try await next.respond(to: request)
        }
        
        guard let accessTokenString = request.headers.bearerAuthorization?.token,
              let accessData = try await accessDataRepo.get(key: accessTokenString, as: AD.self) else {
            throw Abort(.unauthorized)
        }
               
        // TODO: refactor actions constant to an array
        // needed for api bulk requests, where .create and .update
        // is performed. Right now, user can update a AuthorizationPolicy
        // with only a 'create' policy over a bulk create route
        let action: ABACAPIAction
        switch request.method.string {
        case "GET":
            action = .read
        case "POST":
            action = .create
        case "PUT":
            action = .update
        case "PATCH":
            action = .update
        case "DELETE":
            action = .delete
        default:
            throw Abort(.forbidden, reason: "ABAC: HTTP request method not allowed")
        }
        
        var pdpRequests: [PDPRequest] = []
        for role in accessData.userData.roles {
            let pdpRequest = PDPRequest(role: role.name,
                                        action: action.rawValue,
                                        onResource: resource)
            pdpRequests.append(pdpRequest)
        }
        
        let decision = try checkPDPRequests(pdpRequests, on: accessData.userData)
        switch decision {
        case .permit:
            return try await next.respond(to: request)
        case .deny:
            throw Abort(.forbidden, reason: "ABAC: Request denied")
        case .indeterminate:
            throw Abort(.forbidden, reason: "ABAC: Request indeterminate")
        case .notapplicable:
            throw Abort(.forbidden, reason: "ABAC: Request not applicable")
        }
    }
    
    private func getPathComponentsRange(_ pathComponents: [PathComponent]) -> Range<Int> {
        var startIndex = 0
        for path in pathComponents {
            if !protectedResources.contains(path.description) {
                startIndex += 1
            } else {
                return (startIndex..<pathComponents.endIndex)
            }
        }
        return (startIndex..<pathComponents.endIndex)
    }
    
    private func getRequestedAndProtectedResource(fromPathComponents pathComponents: ArraySlice<PathComponent>) -> String {
        var protectedResource: String = ""
        
        for index in 0..<pathComponents.count {
            guard pathComponents.count-index >= 1 else { break }
            let joined = pathComponents[pathComponents.startIndex..<(pathComponents.endIndex-index)].string
//            let joined = pathComponents.string
            if matchesPattern(joined, in: protectedResources) {
                protectedResource = joined
            }
        }
        return protectedResource
    }
    /// wildcard matching for string arrays
    private func matchesPattern(_ target: String, in patterns: [String]) -> Bool {
        let targetComps = target.abacPathComponents
        
        return patterns.contains { pattern in
            let patternComps = pattern.abacPathComponents
            
            // Handle recursive wildcard "**" at the end
            if let last = patternComps.last, last == "**" {
                // Ensure all prefix components match (up to "**")
                let prefixPatternComps = patternComps.dropLast()
                guard prefixPatternComps.count <= targetComps.count else { return false }
                
                return zip(targetComps, prefixPatternComps).allSatisfy { targetComp, patternComp in
                    patternComp == "*" ? targetComp.isURLSafe : targetComp == patternComp
                }
            }
            
            // Non-"**" patterns require exact component count match
            guard patternComps.count == targetComps.count else { return false }
            
            return zip(targetComps, patternComps).allSatisfy { targetComp, patternComp in
                patternComp == "*" ? targetComp.isURLSafe : targetComp == patternComp
            }
        }
    }
    
    
    
    
    
    // MARK: - Policy Decision Point (PDP)
    
    /// PDP - Policy Decision Point
    /// policy = role + action + condition
    ///
    /// condition: On cached data, starting from within 'UserData' Model,
    /// specify a path using dot notation.
    /// condition example: 'user.additionalName', 'roles.0.name'
    ///
    /// returns decision:
    /// 'permit' - approved,
    /// 'deny' - access denied,
    /// 'indeterminate' - error at the PDP,
    /// 'notapplicable' - some attribute missing in the request or no policy match.
    private func checkPDPRequests<T: ABACUserData>(_ pdpRequests: [PDPRequest], on userData: T) throws -> Decision {
        
        // TODO: log decisions e.g. like the audit log of selinux
        // right now, only the last denied/not applicable decision
        // will be returned
        var decision = Decision.notapplicable
        for pdpRequest in pdpRequests {
            
            let targetPath = pdpRequest.action+pdpRequest.onResource
            guard let collection = authorizationPolicyService.authPolicyCollection[pdpRequest.role],
                  let policyCollection = valueForMatchingPattern(targetPath, in: collection) else {
                decision = .notapplicable
                continue
            }
            
            for (_, authValues) in policyCollection {
                if authValues.actionValue == true {
                    if try evaluateCondition(authValues.condition, on: userData) {
                        return .permit
                    } else {
                        decision = .deny
                        continue
                    }
                } else {
                    decision = .deny
                    continue
                }
            }
        }
        return decision
    }
    /// wildcard search in authPolicyCollection dictionary
    private func valueForMatchingPattern(_ target: String, in resourcesCollection: [String: [String: any AuthorizationValuable]]) -> [String: any AuthorizationValuable]? {
        let targetComps = target.abacPathComponents
        
        for (pattern, value) in resourcesCollection {
            let patternComps = pattern.abacPathComponents
            
            // Handle recursive wildcard "**" at the end
            if let last = patternComps.last, last == "**" {
                let prefixPatternComps = patternComps.dropLast()
                guard prefixPatternComps.count <= targetComps.count else { continue }
                
                if zip(targetComps, prefixPatternComps).allSatisfy({ targetComp, patternComp in
                    patternComp == "*" ? targetComp.isURLSafe : targetComp == patternComp
                }) {
                    return value
                }
            }
            // Non-"**" patterns require exact component count match
            else if patternComps.count == targetComps.count,
                    zip(targetComps, patternComps).allSatisfy({ targetComp, patternComp in
                        patternComp == "*" ? targetComp.isURLSafe : targetComp == patternComp
                    }) {
                return value
            }
        }
        return nil
    }
    
    private func evaluateCondition<T: ABACUserData>(_ conditionValuable: ConditionValuable?, on userData: T) throws -> Bool {
        guard let condition = conditionValuable else { return true }
        
        // TODO: Implement ConditionValues on Arrays
        // e.g. Conditions on userDatas 'roles.'
        // examine how userDataMirror for arrays look like
        let userDataMirror = Mirror(reflecting: userData)
        
        switch condition.type {
        case .string:
            return try evaluateConditionOperation(String.self, condition: condition, userDataMirror: userDataMirror)
        case .int:
            return try evaluateConditionOperation(Int.self, condition: condition, userDataMirror: userDataMirror)
        case .double:
            return try evaluateConditionOperation(Double.self, condition: condition, userDataMirror: userDataMirror)
        }
    }
    
    private func evaluateConditionOperation<T: Comparable>(_ t: T.Type, condition: ConditionValuable, userDataMirror: Mirror) throws -> Bool {
        switch (condition.lhsType, condition.rhsType) {
        case (.reference, .reference):
            guard let condition = condition as? ABACAuthorizationPolicyService.Condition<String, String, T> else {
                throw Abort(.internalServerError)
            }
            
            let lhsComponents: [MirrorPath] = condition.lhs.components(separatedBy: ".").toMirrorPath()
            let rhsComponents: [MirrorPath] = condition.rhs.components(separatedBy: ".").toMirrorPath()
            let lhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: lhsComponents)
            let rhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: rhsComponents)
            return condition.operation(lhs, rhs)
        case (.reference, .value):
            guard let condition = condition as? ABACAuthorizationPolicyService.Condition<String, T, T> else {
                throw Abort(.internalServerError)
            }
            let lhsComponents: [MirrorPath] = condition.lhs.components(separatedBy: ".").toMirrorPath()
            let lhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: lhsComponents)
            return condition.operation(lhs, condition.rhs)
        case (.value, .reference):
            guard let condition = condition as? ABACAuthorizationPolicyService.Condition<T, String, T> else {
                throw Abort(.internalServerError)
            }
            let rhsComponents: [MirrorPath] = condition.rhs.components(separatedBy: ".").toMirrorPath()
            let rhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: rhsComponents)
            return condition.operation(condition.lhs, rhs)
        case (.value, .value):
            guard let condition = condition as? ABACAuthorizationPolicyService.Condition<T, T, T> else {
                throw Abort(.internalServerError)
            }
            return condition.operation(condition.lhs, condition.rhs)
        }
    }
    
    
    private func getValueFromMirror<T>(_ t: T.Type, mirror: Mirror, atPath path: [MirrorPath]) throws -> T {
        switch path.count {
        case 1:
            guard let value = mirror.descendant(path[0]) as? T else { throw Abort(.internalServerError) }
            return value
        case 2:
            guard let value = mirror.descendant(path[0], path[1]) as? T else { throw Abort(.internalServerError) }
            return value
        case 3:
            guard let value = mirror.descendant(path[0], path[1], path[2]) as? T else { throw Abort(.internalServerError) }
             return value
        case 4:
            guard let value = mirror.descendant(path[0], path[1], path[2], path[3]) as? T else { throw Abort(.internalServerError) }
            return value
        case 5:
            guard let value = mirror.descendant(path[0], path[1], path[2], path[3], path[4]) as? T else { throw Abort(.internalServerError) }
            return value
        default:
             throw Abort(.internalServerError)
        }
    }
    
}



// MARK: - Extensions

extension ABACMiddleware {
    
    struct PDPRequest {
        let role: String
        let action: String
        let onResource: String
    }
        
    enum Decision {
        /// Approved
        case permit
        /// Denied
        case deny
        /// Error at the PDP
        case indeterminate
        /// Some attribute missing in the request or no policy match.
        case notapplicable
    }
}


extension Collection where Iterator.Element: Equatable {
    typealias Element = Self.Iterator.Element
    
    func safeIndex(after index: Index) -> Index? {
        let nextIndex = self.index(after: index)
        return (nextIndex < self.endIndex) ? nextIndex : nil
    }
    
    func index(afterWithWrapAround index: Index) -> Index {
        return self.safeIndex(after: index) ?? self.startIndex
    }
    
    func item(after item: Element) -> Element? {
        return self.firstIndex(of: item)
            .flatMap(self.safeIndex(after:))
            .map{ self[$0] }
    }
    
    func item(afterWithWrapAround item: Element) -> Element? {
        return self.firstIndex(of: item)
            .map(self.index(afterWithWrapAround:))
            .map{ self[$0] }
    }
}


extension BidirectionalCollection where Iterator.Element: Equatable {
    typealias Element = Self.Iterator.Element
    
    func safeIndex(before index: Index) -> Index? {
        let previousIndex = self.index(before: index)
        return (self.startIndex <= previousIndex) ? previousIndex : nil
    }
    
    func index(beforeWithWrapAround index: Index) -> Index {
        return self.safeIndex(before: index) ?? self.index(before: self.endIndex)
    }
    
    func item(before item: Element) -> Element? {
        return self.firstIndex(of: item)
            .flatMap(self.safeIndex(before:))
            .map{ self[$0] }
    }
    
    func item(beforeWithWrapAround item: Element) -> Element? {
        return self.firstIndex(of: item)
            .map(self.index(beforeWithWrapAround:))
            .map{ self[$0] }
    }
}


extension Array where Element == String {
    func toMirrorPath() -> [MirrorPath] {
        self.map { path in
            if let numPath = Int(path) {
                return numPath
            } else {
                return path
            }
        }
    }
}


extension String {
    var abacPathComponents: [String] {
        components(separatedBy: "/").filter { !$0.isEmpty }
    }
    var isURLSafe: Bool {
        let urlSafeCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        return unicodeScalars.allSatisfy { urlSafeCharacters.contains($0) }
    }
}
