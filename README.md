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

#### Overview
- Setup fluent models:
    - *YourUserModel* conforming to `ABACUser`
    - *YourRoleModel* conforming to `ABACRole`
    - *YourUserDataModel* conforming to `ABACUserData`
    - *YourAccessDataModel* conforming to `ABACAccessData`
- Setup your cache store/repository:
    - *YourCacheStore* conforming to `ABACCacheStore`
- Setup a resources collection struct:
    - *APIResource* conforming to `ABACAPIResourceable`


#### Details
**YourUserMode** 
1. No specific requirements, (model should conform to Codable)
2. Conform to `ABACUser`
**YourRoleModel**
1. Needs a  `name` property (model should conform to Codable)
3. Setup the `name` property with a `unique` constraint inside your models Migration
4. Conform to `ABACRole`
**YourUserDataModel**
1. Needs a `roles` property - Array of roles (model should conform to Codable)
2. Conform to `ABACUserData`
// TODO


**APIResource**
A simple struct holding your resources, could look like:
```swift
struct APIResource {
    
    static let _apiEntry: String = "api"
    
    static let _all: [String] = Resource.allCases.map { $0.rawValue }.sorted { $0 < $1 }
    
    // contains all resources
    enum Resource: String, CaseIterable {
        case auth = "auth"
        case login = "login"
        case logout = "logout" 
        case accessData = "access-data"
        case registration = "registration"
        case authorizationPolicies = "authorization-policies"
        case users = "users"
        case myUser = "my-user"
        case roles = "roles"
        case conditions = "conditions"
    }
    
    init() {}
}

// contains all protected resources where
// ABACAuthorization is used
extension APIResource {
    public static let _allProtected: [String] = [
        APIResource.Resource.authorizationPolicies,
        APIResource.Resource.auth,
        APIResource.Resource.conditions,
        APIResource.Resource.users
    ].map { $0.rawValue }.sorted { $0 < $1 }
}
```

Example `APIResource` conforming to `ABACAPIResourceable`
```swift
extension APIResource: ABACAPIResourceable {
    
    public var apiEntry: String {
        return APIResource._apiEntry
    }
    
    public var protectedResources: [String] {
        return APIResource._allProtected
    }
}

```




### Define 
#### Admin user
```swift
struct AdminUser: Migration {
    
    enum Constant {
        static let isEnabled = true
        static let firstName = "Admin"
        static let lastName = "Admin"
        static let email = "webmaster@nuvariant.com"
        static let passwordLength = 16
    }
    
    
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let random = [UInt8].random(count: Constant.passwordLength).base64
        print("\nPASSWORD: \(random)") // TODO: use logger
        let password = try? Bcrypt.hash(random)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        
        let user = UserModel(isEnabled: Constant.isEnabled,
                             firstName: Constant.firstName,
                             lastName: Constant.lastName,
                             email: Constant.email,
                             password: hashedPassword)
        return user.save(on: database)
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        UserModel.query(on: database).filter(\.$email == Constant.email)
            .delete()
    }
}
```

#### Minimal policy rule set
It is recommended to create a minimal set of rules to read, create auth policies and read roles to not lock yourself out

```swift
struct AdminAuthorizationPolicyRestricted: Migration {
    
    let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.authorizationPolicies.rawValue)"
    let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)\(APIResource.Resource.authorizationPolicies.rawValue)"
    let readRoleActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.rolesInternal.rawValue)"
    let readAuthActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.auth.rawValue)"
    
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            let readAuthPolicy = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionOnResource: readAuthPolicyActionOnResource,
                actionOnResourceValue: true)
            
            let writeAuthPolicy = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionOnResource: createAuthPolicyActionOnResource,
                actionOnResourceValue: true)
            
            let readRole = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionOnResource: readRoleActionOnResource,
                actionOnResourceValue: true)
            
            let readAuth = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionOnResource: readAuthActionOnResource,
                actionOnResourceValue: true)
            
            
            let policySaveResults: [EventLoopFuture<Void>] = [
                readAuthPolicy.save(on: database),
                writeAuthPolicy.save(on: database),
                readRole.save(on: database),
                readAuth.save(on: database)
            ]
            return policySaveResults.flatten(on: database.eventLoop)
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            let deleteResults = [
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionOnResourceKey == readAuthPolicyActionOnResource)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionOnResourceKey == createAuthPolicyActionOnResource)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionOnResourceKey == readRoleActionOnResource)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionOnResourceKey == readAuthActionOnResource)
                    .delete(),
            ]
            deleteResults.flatten(on: database.eventLoop)
        }
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
