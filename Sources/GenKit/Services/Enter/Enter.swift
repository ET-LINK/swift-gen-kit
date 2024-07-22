//
//  DifyEncoder.swift
//  swift-gen-kit
//
//  Created by Enter M1 on 2024/7/19.
//

import Foundation
import OSLog
import swift_enter_glass_network

private let logger = Logger(subsystem: "EnterService", category: "GenKit")
public final class EnterService {
    
    private var client: EGChatTask
    
    public init() {
        self.client = EGChatTask()
        logger.info("Enter Service")
    }
    private func makeChatRequest(request: ChatServiceRequest) -> Chat {
        return .init(auid: request.model, conversationID: request.messages.first?.name, role: .user, content: request.messages.first?.content, name: request.messages.first?.name, toolCalls: nil, toolCallID: nil)
    }
}

extension EnterService: ChatService {
    public func completion(request: ChatServiceRequest) async throws -> Message {
        let payload = makeChatRequest(request: request)
        var message = Message(role: .assistant)
        for try await result in client.chatsStream(query: payload) {
            message = decode(result: result, into: message)
            
        }
        return message
    }
    public func completionStream(request: ChatServiceRequest, update: (Message) async -> Void) async throws {
        let payload = makeChatRequest(request: request)
        var message = Message(role: .assistant)
        for try await result in client.chatsStream(query: payload) {
            message = decode(result: result, into: message)
            await update(message)
        }
    }
    
}
