import NIO
import Foundation

protocol ABACUser: Codable {}

protocol ABACRole: Codable {
    var name: String { get set }
}

protocol ABACUserData: Codable {
    associatedtype ABACRoleType: ABACRole
    var roles: [ABACRoleType] { get set }
}

protocol ABACAccessData: Codable {
    associatedtype UserDataType: ABACUserData
    var userData: UserDataType { get set }
}


