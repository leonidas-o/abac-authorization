//
//  File.swift
//  
//
//  Created by Leonid Orsulic on 26.10.19.
//

@testable import ABACAuthorization
import Vapor
import Foundation


extension Application {
    static func testable(envArgs: [String]? = nil) throws -> Application {
        let services = Services.default()
        let config = Config.default()
        let app = try Application(config: config, services: services)
        return app
    }
}
