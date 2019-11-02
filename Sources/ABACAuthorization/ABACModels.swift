import NIO
import Foundation

public protocol ABACUser: Codable {}

public protocol ABACRole: Codable {
    var name: String { get set }
}

public protocol ABACUserData: Codable {
    associatedtype ABACRoleType: ABACRole
    var roles: [ABACRoleType] { get set }
}

public protocol ABACAccessData: Codable {
    associatedtype UserDataType: ABACUserData
    var userData: UserDataType { get set }
}


