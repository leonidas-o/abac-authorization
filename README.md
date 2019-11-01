# ABACAuthorization

This is an attribute based access controll authorization system for the Swift Vapor Framework with FluentPostgreSQL.

## Prerequisites
- Models conforming to:
    - ABACUser
    - ABACRole
    - ABACUserData
    - ABACAccessData


## Minimal Policies
It is recommendet to create a minimal set of rules to read, create auth policies and read roles to not lock yourself out:

```swift
struct AdminAuthorizationPolicyRestricted: Migration {
    typealias Database = PostgreSQLDatabase
    
    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        
        return Role.query(on: conn).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            
            let readAuthPolicyActionOnResource = "\(APIAction.read)\(APIResource.authorizationPolicyResource.rawValue)"
            let readAuthPolicy = AuthorizationPolicy(
                roleName: role.name,
                actionOnResource: readAuthPolicyActionOnResource,
                actionOnResourceValue: true)
            
            let createAuthPolicyActionOnResource = "\(APIAction.create)\(APIResource.authorizationPolicyResource.rawValue)"
            let writeAuthPolicy = AuthorizationPolicy(
                roleName: role.name,
                actionOnResource: createAuthPolicyActionOnResource,
                actionOnResourceValue: true)
            
            let readRoleActionOnResource = "\(APIAction.read)\(APIResource.rolesResource.rawValue)"
            let readRole = AuthorizationPolicy(
                roleName: role.name,
                actionOnResource: readRoleActionOnResource,
                actionOnResourceValue: true)
            
            
            let policySaveResults: [Future<AuthorizationPolicy>] = [
                readAuthPolicy.save(on: conn),
                writeAuthPolicy.save(on: conn),
                readRole.save(on: conn)
            ]
            return policySaveResults.flatten(on: conn).transform(to: ())
        }
        
    }
    
    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return .done(on: conn)
    }
}
```

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
