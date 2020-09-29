import Foundation
import NIO

public protocol ABACCacheRepo {
    func get<D: Decodable>(key: String, as type: D.Type) -> EventLoopFuture<D?>
}
