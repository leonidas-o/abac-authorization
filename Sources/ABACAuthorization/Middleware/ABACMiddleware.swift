import Vapor


public final class ABACMiddleware<AD: ABACAccessData>: Middleware {
    
    private let authorizationPolicyService: ABACAuthorizationPolicyService
    private let cache: ABACCacheRepo
    private let protectedResources: [String]
    
    
    public init(_ type: AD.Type = AD.self, cache: ABACCacheRepo, protectedResources: [String]) {
        self.authorizationPolicyService = ABACAuthorizationPolicyService.shared
        self.cache = cache
        self.protectedResources = protectedResources
    }
    
    
    // MARK: - Policy Enforcement Point (PEP)
    
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        
        // TODO: Examine: What if api versioning introduced or nested resources, etc.?
        //        guard let resource = pathComponents.item(after: apiResources.apiEntry) else {
        //            throw Abort(.internalServerError)
        //        }
        let pathComponents = request.url.path.pathComponents
        let resource = self.getRequestedAndProtectedResource(fromPathComponents: pathComponents)
        guard !resource.isEmpty else {
            // permit access as requested resource is unprotected
            return next.respond(to: request)
        }
        
        guard let accessTokenString = request.headers.bearerAuthorization?.token else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        return cache.get(key: accessTokenString, as: AD.self).unwrap(or: Abort(.unauthorized)).flatMap { accessToken in
               
            // TODO: refactor actions constant to an array needed for
            // api bulk requests, where .create and .update is performed.
            // right now, user can update a AuthorizationPolicy with
            // only a 'create' policy over a bulk create route
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
                return request.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "ABAC: HTTP request method not allowed"))
            }
            
            
//        return accessToken.flatMap { accessToken -> EventLoopFuture<Response> in
//            guard let accessToken = accessToken else {
//                return request.eventLoop.makeFailedFuture(Abort(.unauthorized))
//            }
            
            
            var pdpRequests: [PDPRequest] = []
            for role in accessToken.userData.roles {
                let pdpRequest = PDPRequest(role: role.name,
                                            action: action.rawValue,
                                            onResource: resource)
                pdpRequests.append(pdpRequest)
            }
            
            var decision = Decision.notapplicable
            do {
                decision = try self.checkPDPRequests(pdpRequests, on: accessToken.userData)
            } catch {
                return request.eventLoop.makeFailedFuture(error)
            }
            switch decision {
            case .permit:
                return next.respond(to: request)
            case .deny:
                return request.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "ABAC: Request denied"))
            case .indeterminate:
                return request.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "ABAC: Request indeterminate"))
            case .notapplicable:
                return request.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "ABAC: Request not applicable"))
            }
        }
        
    }
    
    
    private func getRequestedAndProtectedResource(fromPathComponents pathComponents: [PathComponent]) -> String {
        var lastProtectedResource: String = ""
        for path in pathComponents.reversed() {
            if protectedResources.contains(path.description) {
                lastProtectedResource = path.description
                break
            }
        }
        return lastProtectedResource
        
//        let resources = Set(pathComponents).intersection(Set(apiResource.all))
//
//        var resource: String = ""
//        if resources.count == 1 {
//            // default request or parent child relationship
//            guard let first = resources.first else {
//                throw Abort(.internalServerError)
//            }
//            resource = first
//        } else if resources.count > 1 {
//            // pivot table/ sibling relationship, Parent-child everything with more than one resource
//            resource = resources.sorted().joined(separator: "_")
//        }
//        return resource
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
            
            guard let policyCollection = authorizationPolicyService.authPolicyCollection[pdpRequest.role]?[pdpRequest.action+pdpRequest.onResource] else {
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
