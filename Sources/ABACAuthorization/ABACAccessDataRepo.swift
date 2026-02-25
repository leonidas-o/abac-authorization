import Foundation
import NIO

public protocol ABACAccessDataRepo: Sendable {
    func get<D>(key: String, as type: D.Type) async throws -> D? where D: Decodable
}
