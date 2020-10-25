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
Either conform your `CacheRepo` protocol to `ABACCacheRepo` or your real repo and implement the requirements. 


An example of a **APIResource**
A simple struct holding your resources, could look like:
```swift
struct APIResource {
    
    static let _apiEntry: String = "api"
    
    
    static let _all: [String] = Resource.allCases.map { $0.rawValue }.sorted { $0 < $1 }
    
    
    static let _allProtected: [String] = [
        APIResource.Resource.abacAuthorizationPolicies,
        APIResource.Resource.abacConditions,
        APIResource.Resource.todos,
        APIResource.Resource.users,
        APIResource.Resource.myUser,
        APIResource.Resource.roles,
    ].map { $0.rawValue }.sorted { $0 < $1 }

    
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
    }
    
}
```





### DB Seeding 
#### Admin user
```swift
struct AdminUser: Migration {
    
    enum Constant {
        static let name = "Admin"
        static let email = "webmaster@foo.com"
        static let passwordLength = 16
    }
    
    
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let random = [UInt8].random(count: Constant.passwordLength).base64
        print("\nPASSWORD: \(random)") // TODO: use logger
        let password = try? Bcrypt.hash(random)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        
        let user = UserModel(name: Constant.name,
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

### Final Steps

Open `configure.swift` 

Import the package (`import ABACAuthorization`) set the integrated PostgreSQL repository
```swift
app.abacAuthorizationRepoFactory.use { req in
    ABACAuthorizationPostgreSQLRepo(db: req.db)
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

let rules = try ABACAuthorizationPolicyModel.query(on: app.db).all().wait()
for rule in rules {
    let conditions = try rule.$conditions.query(on: app.db).all().wait()
    try app.abacAuthorizationPolicyService.addToInMemoryCollection(authPolicy: rule, conditionValues: conditions)
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
