//
//  WebSocketTransport.swift
//  swamp
//
//  Created by Yossi Abraham on 18/08/2016.
//  Copyright © 2016 Yossi Abraham. All rights reserved.
//

import Foundation
import Starscream

open class WebSocketSwampTransport: SwampTransport {

    enum WebsocketMode {
        case binary, text
    }
    
    open var delegate: SwampTransportDelegate?
    let socket: WebSocket
    let mode: WebsocketMode
    
    fileprivate var disconnectionReason: String?
    
    public init(wsEndpoint: URL){
        var request = URLRequest(url: wsEndpoint)
        let json: [String: Any] = ["protocols": ["wamp.2.json"]]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        let pinner = FoundationSecurity(allowSelfSigned: false)
        self.socket = WebSocket(request: request, certPinner: pinner)
        self.mode = .text
        socket.delegate = self
    }
    
    // MARK: Transport
    
    open func connect() {
        self.socket.connect()
    }
    
    open func disconnect(_ reason: String) {
        self.disconnectionReason = reason
        self.socket.disconnect()
    }
    
    open func sendData(_ data: Data) {
        if self.mode == .text {
            self.socket.write(string: String(data: data, encoding: String.Encoding.utf8)!)
        } else {
            self.socket.write(data: data)
        }
    }
}

extension WebSocketSwampTransport: WebSocketDelegate {

    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(_):
            delegate?.didConnect(with: JSONSwampSerializer())
        case let .disconnected(reason, code):
            delegate?.didDisconnect(with: reason, code: Int(code))
        case .text(let text):
            if let data = text.data(using: .utf8) {
                delegate?.didReceive(data: data)
            }
        case .binary(let data):
            delegate?.didReceive(data: data)
        case .pong(_):
            break
        case .ping(_):
            break
        case .error(let error):
            delegate?.didReceive(error: error)
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        }
    }
}
