# ABACAuthorization

This is an attribute based access control authorization system for the Swift Vapor Framework with FluentPostgreSQL.

## Getting Started

### Setup dependencies
In your `package.swift` add the abac-authorization package
```swift
    ...
        .package(url: "https://github.com/leonidas-o/abac-authorization.git", from: "x.x.x")
    ...
    ],
    targets: [    
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Vapor", package: "vapor"),
            .product(name: "ABACAuthorization", package: "abac-authorization"),
        ])
    ...
```

### Setup and conform Models
- Vapor Models conforming to:
    - ABACUser
    - ABACRole
    - ABACUserData
    - ABACAccessData
- Cache store conforming to:
    - ABACCacheStore
- APIResource conforming to:
    - ABACAPIResourceable


### Define 
#### Admin user
```swift
struct AdminUser: Migration {
    
    enum Constant {
        static let firstName = "Admin"
        static let lastName = "Admin"
        static let additionalName = "Admin"
        static let email = "webmaster@foo.com"
    }
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let randomPassword = (try? CryptoRandom().generateData(count: 16).base64EncodedString())!
        print("\nPASSWORD: \(randomPassword)")
        let password = try? BCrypt.hash(randomPassword)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        let user = User(
            name: Constant.lastName,
            email: Constant.email,
            passwordHash: hashedPassword)
        user.save(on: database)
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        User.query(on: database)
        .filter(\.$email == Constant.email)
        .delete()
    }
}
```

#### Minimal policy rule set
It is recommended to create a minimal set of rules to read, create auth policies and read roles to not lock yourself out

```swift
struct AdminAuthorizationPolicyRestricted: Migration {
    
    func prepare(on conn: Database) -> EventLoopFuture<Void> {
        
        Role.query(on: conn).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
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
            policySaveResults.flatten(on: conn).transform(to: ())
        }
        
    }
    
    func revert(on conn: Database) -> EventLoopFuture<Void> {
        AuthorizationPolicy.query(on: database)
        .filter(\.$roleName == role.name)
        .filter(\(.$actionOnResource) == "\(APIAction.read)\(APIResource.authorizationPolicyResource.rawValue)")
        .delete()
        
        AuthorizationPolicy.query(on: database)
        .filter(\.$roleName == role.name)
        .filter(\(.$actionOnResource) == "\(APIAction.create)\(APIResource.authorizationPolicyResource.rawValue)")
        .delete()
        
        AuthorizationPolicy.query(on: database)
        .filter(\.$roleName == role.name)
        .filter(\(.$actionOnResource) == "\(APIAction.read)\(APIResource.rolesResource.rawValue)")
        .delete()
    }
}
```

In `configure.swift` add your AdminAuthorizationPolicy migration with the minimal set of rules
```swift
// If it is only for testing environment otherwise just use the body
if (app.environment != .testing) {
    app.migrations.use(AdminAuthorizationPolicyRestricted(), on: .psql)
}
```


### Load persisted rules
In `boot.swift` load saved policies
```swift
let conn = try app.newConnection(to: .psql).wait()

// MARK: Authorization

let rules = try AuthorizationPolicy.query(on: conn).all().wait()
let authorizationPolicyService = try app.authorizationPolicyService
for rule in rules {
    let conditionValues = try rule.conditionValues.query(on: conn).all().wait()
    try authorizationPolicyService.addToInMemoryCollection(authPolicy: rule, conditionValues: conditionValues)
}
```


### High availability usage
tbd


### Demo Project
Here you can find an quick and dirty example project for testing purposes, it should show how ABACAuthorization can be used. Not all routes/ handlers are fully implemented, sometimes you have the api functionality but not the frontend part:

https://github.com/leonidas-o/abac-authorization-web

> When creating new policies, it should be done from the API point of view. That means e.g. if you want to show all users, it's a "read users" policy as you need to read the "user" table. If you want to add a role to a user, you need to have a "create update role_user" policy because it has a pivot table, adding a role means creating an entry in here.




## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
