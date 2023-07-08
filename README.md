# ABACAuthorization

This is an attribute based access control authorization system/ role based access control system for the Swift Vapor Framework + Fluent. The usage of attributes is not mandatory, you can specify policies based on roles only.

## Getting Started

### Setup dependencies
In your `package.swift` add the abac-authorization package (+ Fluent and your needed driver package, for example FluentPostgresDriver)
```swift
    ...
        .package(url: "https://github.com/leonidas-o/abac-authorization.git", from: "x.x.x")
    ...
    ],
    targets: [    
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"), // or any other driver
            .product(name: "Vapor", package: "vapor"),
            .product(name: "ABACAuthorization", package: "abac-authorization"),
        ])
    ...
```


### Models

#### Overview
- Setup fluent models:
    - Your *User* model conforming to `ABACUser`
    - Your *Role* model conforming to `ABACRole`
    - Your *UserData* model conforming to `ABACUserData`
    - Your *AccessData* model conforming to `ABACAccessData`
- Setup your cache repository:
    - *YourCacheRepo* conforming to `ABACCacheRepo`



#### Details

Your **User** Model 
1. No specific requirements, (model should conform to Codable)
2. Conform to `ABACUser`

Your **Role** Model
1. Needs a  `name` property (model should conform to Codable)
3. Setup the `name` property with a `unique` constraint inside your models Migration
4. Conform to `ABACRole`

Your **UserData** Model
1. Needs a `roles` property - Array of roles (model should conform to Codable)
2. Conform to `ABACUserData`

Your **AccessData** Model
1. Needs a `userData` property
2. Conform to `ABACAccessData`

Your **CacheRepo**
1. Either conform your `CacheRepo` protocol or your actual repo to `ABACCacheRepo`  and implement its requirements. 


An example of an **APIResource**
A simple struct holding your resources, could look like:
```swift
struct APIResource {
    
    static let _apiEntry: String = "api"
    
    
    static let _all: [String] = Resource.allCases.map { $0.rawValue }.sorted { $0 < $1 }
    
    
    static let _allProtected: [String] = [
        APIResource.Resource.abacAuthorizationPolicies.rawValue,
        APIResource.Resource.abacConditions.rawValue,
        APIResource.Resource.todos.rawValue,
        APIResource.Resource.users.rawValue,
        APIResource.Resource.users.rawValue+"/"+APIResource.Resource.foo.rawValue,
        APIResource.Resource.myUser.rawValue,
        APIResource.Resource.roles.rawValue,
    ].sorted { $0 < $1 }

    
    enum Resource: String, CaseIterable {
        case login = "login"
        // abac
        case abacAuthorizationPolicies = "abac-auth-policies"
        case abacAuthorizationPoliciesService = "abac-auth-policies-service"
        case abacConditions = "abac-conditions"
        // others
        case todos = "todos"
        case users = "users"
        case myUser = "my-user"
        case roles = "roles"
        case bulk = "bulk"
        case foo = "foo"
    }
    
}
```





### DB Seeding 
#### Admin user
```swift
struct AdminUser: AsyncMigration {
    
    enum Constant {
        static let name = "Admin"
        static let email = "webmaster@foo.com"
        static let passwordLength = 16
    }
    
    
    
    func prepare(on database: Database) async throws {
        let random = [UInt8].random(count: Constant.passwordLength).base64
        print("\nPASSWORD: \(random)") // TODO: use logger
        let password = try? Bcrypt.hash(random)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        
        let user = UserModel(name: Constant.name,
                             email: Constant.email,
                             password: hashedPassword)
        try await user.save(on: database)
    }
    
    func revert(on database: Database) async throws {
        try await UserModel.query(on: database).filter(\.$email == Constant.email)
            .delete()
    }
}
```

#### Minimal policy rule set
It is recommended to create a minimal set of rules to read, create auth policies and read roles to not lock yourself out

```swift
import ABACAuthorization

struct RestrictedABACAuthorizationPoliciesMigration: AsyncMigration {
    
    let readAuthPolicies = "\(ABACAPIAction.read)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let createAuthPolicies = "\(ABACAPIAction.create)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let readRoles = "\(ABACAPIAction.read)\(APIResource.Resource.roles.rawValue)"
    let readAuths = "\(ABACAPIAction.read)\(APIResource.Resource.auth.rawValue)"
    
    
    func prepare(on database: Database) async throws {
        guard let role = try await RoleModel.query(on: database).first() else {
            thorw Abort(.internalServerError)
        }
            
        let readAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: role.name,
            actionKey: readAuthPolicies,
            actionValue: true)
        
        let writeAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: role.name,
            actionKey: createAuthPolicies,
            actionValue: true)
        
        let readRole = ABACAuthorizationPolicyModel(
            roleName: role.name,
            actionKey: readRoles,
            actionValue: true)
        
        let readAuth = ABACAuthorizationPolicyModel(
            roleName: role.name,
            actionKey: readAuths,
            actionValue: true)
            
        async let readAuthPolicyResponse: () = readAuthPolicy.save(on: database)
        async let writeAuthPolicyResponse: () = writeAuthPolicy.save(on: database)
        async let readRoleResponse: () = readRole.save(on: database)
        async let readAuthResponse: () = readAuth.save(on: database)
        _ = try await (readAuthPolicyResponse, writeAuthPolicyResponse, readRoleResponse, readAuthResponse)
    }
    
    func revert(on database: Database) async throws {
        guard let role =  try await RoleModel.query(on: database).first() else {
            throw Abort(.internalServerError)
        }
        
        async let readAuthPolicyResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == role.name)
            .filter(\.$actionKey == readAuthPolicies)
            .delete()
        async let writeAuthPolicyResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == role.name)
            .filter(\.$actionKey == createAuthPolicies)
            .delete()
        async let readRoleResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == role.name)
            .filter(\.$actionKey == readRoles)
            .delete()
        async let readAuthResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == role.name)
            .filter(\.$actionKey == readAuths)
            .delete()
        _ = try await (readAuthPolicyResponse, writeAuthPolicyResponse, readRoleResponse, readAuthResponse)
    }
}
```

### Final Steps

Open `configure.swift` 

Import the package (`import ABACAuthorization`) set the integrated Fluent repository
```swift
app.abacAuthorizationRepoFactory.use { req in
    ABACAuthorizationFluentRepo(db: req.db)
}
```

Hook into the models lifecycle events
```swift
app.databases.middleware.use(ABACAuthorizationPolicyModelMiddleware())
app.databases.middleware.use(ABACConditionModelMiddleware())
```

Prepare the models
```swift
app.migrations.add(ABACAuthorizationPolicyModelMigration())
app.migrations.add(ABACConditionModelMigration())
```

and add your AdminAuthorizationPolicy migration with the minimal set of rules
```swift
app.migrations.use(AdminAuthorizationPolicyRestricted(), on: .psql)
```


To Load the persisted rules on startup go to `boot.swift`
```swift
// MARK: Authorization

if let sql = app.db as? SQLDatabase {
    let query = SQLQueryString("SELECT EXISTS (SELECT FROM pg_tables where tablename  = '" + ABACAuthorizationPolicyModel.schema + "');")
    let abacPolicySchema = try sql.raw(query).first(decoding: [String:Bool].self).wait()
    if abacPolicySchema?.first?.value == true {
        let policies = try app.abacAuthorizationRepo.getAllWithConditions().wait()
        for policy in policies {
            try app.abacAuthorizationPolicyService.addToInMemoryCollection(policy: policy, conditions: policy.conditions)
        }
    }
}
```


### Horizontal scaling

To achieve a fast decision making process for the evaluation if a request should be permitted or denied, all ABAC policies are stored in memory. This approach leads to some extra work to keep all instances, their in-memory policies, in sync.
See the demo projects README for further information how to make this package horizontally scalable.



### Demo Project
Here you can find an quick and dirty example project for testing purposes, it should show how ABACAuthorization can be used. Not all routes/ handlers are fully implemented, sometimes you have the api functionality but not the frontend part:

https://github.com/leonidas-o/abac-authorization-web

> When creating new policies, it should be done from the API point of view. That means e.g. if you want to show all users, it's a "read users" policy as you need to read the "user" table. If you want to add a role to a user, you need to have a "create update role_user" policy because it has a pivot table, adding a role means creating an entry in here.




## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
