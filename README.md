# ABACAuthorization

This is an attribute based access control authorization system for the Swift Vapor Framework with FluentPostgreSQL.

## Getting Started

### Setup dependencies
In your `package.swift` add the abac-authorization package
```swift
    ...
        .package(url: "...", from: "3.0.0")
    ...
    ],
    targets: [    
        .target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Authentication", "ABACAuthorization"])
```

### Setup and conform Models
- Vapor Models conforming to:
    - ABACUser
    - ABACRole
    - ABACUserData
    - ABACAccessData

- Cache store conforming to:
    - ABACCacheStore

- APIAction (struct) conforming to:
    - ABACAPIAction


### Define minimal policy rule set
It is recommended to create a minimal set of rules to read, create auth policies and read roles to not lock yourself out

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

In `configure.swift` add your AdminAuthorizationPolicy migration with the minimal set of rules
```swift
if (env != .testing) {
    migrations.add(migration: AdminAuthorizationPolicyRestricted.self, database: .psql)
}
```

### Register Service
In `configure.swift`  register the InMemoryAuthorizationPolicy service
```swift
services.register(InMemoryAuthorizationPolicy.self)
```

### Load persisted rules
In `boot.swift` load saved policies
```swift
// MARK: Authorization

let rules = try AuthorizationPolicy.query(on: conn).all().wait()
let inMemoryAuthorizationPolicy = try app.make(InMemoryAuthorizationPolicy.self)
for rule in rules {
    let conditionValues = try rule.conditionValues.query(on: conn).all().wait()
    try inMemoryAuthorizationPolicy.addToInMemoryCollection(authPolicy: rule, conditionValues: conditionValues)
}
```


## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
