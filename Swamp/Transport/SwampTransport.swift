//
//  Transport.swift
//  swamp
//
//  Created by Yossi Abraham on 18/08/2016.
//  Copyright © 2016 Yossi Abraham. All rights reserved.
//

import Foundation

public protocol SwampTransportDelegate: class {
    func didConnect(with serializer: SwampSerializer)
    func didDisconnect(with reason: String, code: Int)
    func didReceive(data: Data)
    func didReceive(error: Error?)
}

public protocol SwampTransport {
    var delegate: SwampTransportDelegate? { get set }
    func connect()
    func disconnect(_ reason: String)
    func sendData(_ data: Data)
}
