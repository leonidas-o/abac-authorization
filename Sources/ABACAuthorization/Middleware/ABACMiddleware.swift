import Vapor
import Foundation


public final class ABACMiddleware<AD: ABACAccessData>: Middleware {
    
    private let inMemoryAuthorizationPolicy: InMemoryAuthorizationPolicy
    private let cache: ABACCacheStore
    private let apiResource: ABACAPIResourceable
    
    
    public init(_ type: AD.Type = AD.self, cache: ABACCacheStore, apiResource: ABACAPIResourceable) {
        self.inMemoryAuthorizationPolicy = InMemoryAuthorizationPolicy.shared
        self.cache = cache
        self.apiResource = apiResource
    }
    
    
    // MARK: - Policy Enforcement Point (PEP)
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        
        guard let accessTokenString = request.http.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized)
        }
        //let accessToken = cache.get(key: accessTokenString, as: AD.self).unwrap(or: Abort(.unauthorized))
        let accessToken = cache.get(key: accessTokenString, as: AD.self)
        let pathComponents = request.http.url.pathComponents
        
        // TODO: refactor actions constant to an array needed for
        // api bulk requests, where .create and .update is performed
        // right now, user can update a AuthorizationPolicy with
        // only a 'create' policy over a bulk create route
        let action: ABACAPIAction
        switch request.http.method.string {
        case "GET":
            action = .read
        case "POST":
            action = .create
        case "PUT":
            action = .update
        case "DELETE":
            action = .delete
        default:
            throw Abort(.forbidden)
        }
        
        // TODO: Examine: What if api versioning introduced or nested resources, etc.?
        //        guard let resource = pathComponents.item(after: apiResources.apiEntry) else {
        //            throw Abort(.internalServerError)
        //        }
        let resource = try getRequestedResource(fromPathComponents: pathComponents)
        
        return accessToken.flatMap(to: Response.self){ accessToken -> EventLoopFuture<Response> in
            guard let accessToken = accessToken else {
                throw Abort(.unauthorized)
            }
            var pdpRequests: [PDPRequest] = []
            for role in accessToken.userData.roles {
                let pdpRequest = PDPRequest(role: role.name,
                                            action: action.rawValue,
                                            onResource: resource)
                pdpRequests.append(pdpRequest)
            }
            
            let decision = try self.checkPDPRequests(pdpRequests, on: accessToken.userData)
            switch decision {
            case .permit:
                return try next.respond(to: request)
            case .deny:
                throw Abort(.forbidden)
            case .indeterminate:
                throw Abort(.forbidden)
            case .notapplicable:
                throw Abort(.forbidden)
            }
        }
        
    }
    
    
    private func getRequestedResource(fromPathComponents pathComponents: [String]) throws -> String {
        let resources = Set(pathComponents).intersection(Set(apiResource.all))
        var resource: String = ""
        if resources.count == 1 {
            // default request or parent child relationship
            guard let first = resources.first else {
                throw Abort(.internalServerError)
            }
            resource = first
        } else if resources.count > 1 {
            // pivot table/ sibling relationship
            resource = resources.sorted().joined(separator: "_")
            // TODO: What if not sorted, fallback, rearrange resources?
            
        }
        return resource
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
            
            guard let policyCollection = inMemoryAuthorizationPolicy.authPolicyCollection[pdpRequest.role]?[pdpRequest.action+pdpRequest.onResource] else {
                decision = .notapplicable
                continue
            }
            
            for (_, authValues) in policyCollection {
                if authValues.actionOnResourceValue == true {
                    if try evaluateCondition(authValues.conditionValue, on: userData) {
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
        guard let conditionValue = conditionValuable else { return true }
        
        // TODO: Implement ConditionValues on Arrays
        // e.g. Conditions on userDatas 'roles.'
        // examine how userDataMirror for arrays look like
        let userDataMirror = Mirror(reflecting: userData)
        
        switch conditionValue.type {
        case .string:
            return try evaluateConditionOperation(String.self, conditionValue: conditionValue, userDataMirror: userDataMirror)
        case .int:
            return try evaluateConditionOperation(Int.self, conditionValue: conditionValue, userDataMirror: userDataMirror)
        case .double:
            return try evaluateConditionOperation(Double.self, conditionValue: conditionValue, userDataMirror: userDataMirror)
        }
    }
    
    private func evaluateConditionOperation<T: Comparable>(_ t: T.Type, conditionValue: ConditionValuable, userDataMirror: Mirror) throws -> Bool {
        switch (conditionValue.lhsType, conditionValue.rhsType) {
        case (.reference, .reference):
            guard let conditionValue = conditionValue as? InMemoryAuthorizationPolicy.ConditionValue<String, String, T> else {
                throw Abort(.internalServerError)
            }
            
            let lhsComponents: [MirrorPath] = conditionValue.lhs.components(separatedBy: ".").toMirrorPath()
            let rhsComponents: [MirrorPath] = conditionValue.rhs.components(separatedBy: ".").toMirrorPath()
            let lhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: lhsComponents)
            let rhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: rhsComponents)
            return conditionValue.operation(lhs, rhs)
        case (.reference, .value):
            guard let conditionValue = conditionValue as? InMemoryAuthorizationPolicy.ConditionValue<String, T, T> else {
                throw Abort(.internalServerError)
            }
            let lhsComponents: [MirrorPath] = conditionValue.lhs.components(separatedBy: ".").toMirrorPath()
            let lhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: lhsComponents)
            return conditionValue.operation(lhs, conditionValue.rhs)
        case (.value, .reference):
            guard let conditionValue = conditionValue as? InMemoryAuthorizationPolicy.ConditionValue<T, String, T> else {
                throw Abort(.internalServerError)
            }
            let rhsComponents: [MirrorPath] = conditionValue.rhs.components(separatedBy: ".").toMirrorPath()
            let rhs = try getValueFromMirror(T.self, mirror: userDataMirror, atPath: rhsComponents)
            return conditionValue.operation(conditionValue.lhs, rhs)
        case (.value, .value):
            guard let conditionValue = conditionValue as? InMemoryAuthorizationPolicy.ConditionValue<T, T, T> else {
                throw Abort(.internalServerError)
            }
            return conditionValue.operation(conditionValue.lhs, conditionValue.rhs)
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
