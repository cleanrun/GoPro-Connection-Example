//
//  NetworkBufferProcessor.swift
//  EnableWiFiDemo
//
//  Created by cleanmac on 01/12/24.
//

import Foundation
import Network

protocol NetworkBufferProcessorDelegate: AnyObject {
    func bufferProcessor(_ processor: NetworkBufferProcessor, didReceive data: Data)
}

final class NetworkBufferProcessor: AnyBufferProcessor {
    weak var delegate: NetworkBufferProcessorDelegate?
    
    private var listener: NWListener?
    private var connection: NWConnection?
    private var listenerQueue = DispatchQueue(label: "listener-queue", qos: .userInitiated)
    private var connectionQueue = DispatchQueue(label: "connection-queue", qos: .userInitiated)
    private var isReady: Bool = false
    private var listening: Bool = true
    
    convenience init(on port: Int) {
        self.init(on: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)))
    }
    
    init(on port: NWEndpoint.Port) {
        let params = NWParameters.udp
        params.allowFastOpen = true
        
        self.listener = try? NWListener(using: params, on: port)
        self.listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isReady = true
                print("\(#function); Listener connected to port \(port)")
            case .failed, .cancelled:
                self?.listening = false
                self?.isReady = false
                print("\(#function); Listener disconnected to port \(port)")
            default:
                print("\(#function); Listener connecting to port \(port)")
            }
        }
        
        self.listener?.newConnectionHandler = { [weak self] connection in
            print("\(#function); Listener receiving new message")
            self?.createConnection(connection)
        }
        
        self.listener?.start(queue: listenerQueue)
    }
    
    init(host: String = goProDefaultIPAddress, port: Int) {
        let params = NWParameters.udp
        //params.allowFastOpen = true
        
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: UInt16(port))!, using: params)
        createConnection(connection)
    }
    
    func sendRTSPSetupMessage() {
        let setupMessage = """
        OPTIONS rtsp://\(goProDefaultIPAddress)/live RTSP/1.0
        CSeq: 1
        
        """.data(using: .utf8)
        
        connection?.send(content: setupMessage, completion: .contentProcessed({ error in
            if let error {
                print("\(#function); Error: \(error.localizedDescription)")
            }
        }))
    }
    
    func cancel() {
        listening = false
        connection?.cancel()
    }
}

private extension NetworkBufferProcessor {
    func createConnection(_ connection: NWConnection) {
        self.connection = connection
        self.connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("\(#function); Connection connected to remote peer")
                self.receive()
            case .failed, .cancelled:
                self.listener?.cancel()
                self.listening = false
            default:
                break
            }
        }
        
        self.connection?.start(queue: connectionQueue)
    }
    
    func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, context, isComplete, error in
            
//            if let error {
//                print("Error receiving data: \(error)")
//                return
//            }
            
            print("\(#function): Received data of size \(data?.count)")
            
            if let data {
                self.delegate?.bufferProcessor(self, didReceive: data)
            }
            
            self.receive() // Continue receiving
        }
    }
}
