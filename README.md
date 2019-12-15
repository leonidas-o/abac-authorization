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

- APIResource conforming to:
    - ABACAPIResourceable


### Define 
#### Admin user
```swift
struct AdminUser: Migration {
    typealias Database = SQLiteDatabase
    
    enum Constant {
        static let firstName = "Admin"
        static let lastName = "Admin"
        static let additionalName = "Admin"
        static let email = "webmaster@foo.com"
    }
    
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        let randomPassword = (try? CryptoRandom().generateData(count: 16).base64EncodedString())!
        print("\nPASSWORD: \(randomPassword)") // TODO: use logger
        let password = try? BCrypt.hash(randomPassword)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        let user = User(
            name: Constant.lastName,
            email: Constant.email,
            passwordHash: hashedPassword)
        return user.save(on: connection).transform(to: ())
    }
    
    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return .done(on: connection)
    }
}
```

#### Minimal policy rule set
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
let conn = try app.newConnection(to: .psql).wait()

// MARK: Authorization

let rules = try AuthorizationPolicy.query(on: conn).all().wait()
let inMemoryAuthorizationPolicy = try app.make(InMemoryAuthorizationPolicy.self)
for rule in rules {
    let conditionValues = try rule.conditionValues.query(on: conn).all().wait()
    try inMemoryAuthorizationPolicy.addToInMemoryCollection(authPolicy: rule, conditionValues: conditionValues)
}
```



### Demo Project
Here you can find an quick and dirty example project for testing purposes, it should show how ABACAuthorization can be used. Not all routes/ handlers are fully implemented, sometimes you have the api functionality but not the frontend part:


> When creeating new policies, it should be done from the API point of view. That means e.g. if you want to show all users, it's a "read users" policy as you need to read the "user" table. If you want to add a role to a user, you need to have a "create update role_user" policy because it has a pivot table, adding a role means creating an entry in here.




## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
