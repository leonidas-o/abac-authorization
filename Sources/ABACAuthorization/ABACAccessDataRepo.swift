import Foundation
import NIO

public protocol ABACAccessDataRepo {
    func get<D>(key: String, as type: D.Type) async throws -> D? where D: Decodable
}
