import Foundation
import NIO

public protocol ABACCacheStore {
    func get<D: Decodable>(key: String, as type: D.Type) -> EventLoopFuture<D?>
}
