import Foundation
import NIO
import Vapor

public protocol ABACCacheRepo {
    func get<D: Decodable>(key: String, as type: D.Type) -> EventLoopFuture<D?>
}
