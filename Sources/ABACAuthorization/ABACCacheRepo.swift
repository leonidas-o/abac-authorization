import Foundation
import NIO

public protocol ABACCacheRepo {
    func get<D>(key: String, as type: D.Type) async throws -> D? where D: Decodable
}
