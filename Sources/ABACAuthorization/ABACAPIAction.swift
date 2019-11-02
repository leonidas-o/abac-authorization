import Foundation

//enum APIAction: String, CaseIterable {
//    case read
//    case create
//    case update
//    case delete
//}

public protocol ABACAPIAction {
    var read: String { get }
    var create: String { get }
    var update: String { get }
    var delete: String { get }
}
