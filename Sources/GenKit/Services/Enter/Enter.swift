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
    private func makeRequest(model: String, messages: [Message], conversation: String? = nil, tools: Set<Tool> = [], toolChoice: Tool? = nil, stream: Bool = false) -> ChatRequest {
        let (system, messages) = encode(messages: messages)
        return .init(
            model: model,
            messages: messages,
            conversationId: conversation,
            system: system,
            tools: encode(tools: tools),
            toolChoice: (toolChoice != nil) ? .init(type: .tool, name: toolChoice!.function.name) : nil,
            stream: stream
        )
    }
}
extension EnterService: ChatService {
    
    public func completion(request: ChatServiceRequest) async throws -> Message {
        let model = request.model
        let conversationId = request.conversationId
        let payload = makeRequest(model: model, messages: request.messages, conversation: conversationId, tools: request.tools)
        let result = try await client.chat(payload)
        if let error = result.error { throw error }
        return decode(result: result)
    }
    
    public func completionStream(request: ChatServiceRequest, update: (Message) async -> Void) async throws {
        
        let model = request.model
        let conversationId = request.conversationId
        
        let payload = makeRequest(model: model, messages: request.messages, conversation: conversationId, tools: request.tools)
        var message = Message(role: .assistant)
        for try await result in client.chatStream(payload) {
            if let error = result.error { throw error }
     
            message = decode(result: result, into: message)
      
            await update(message)
        }
    }
}

extension EnterService: ModelService {
    
    public func models() async throws -> [Model] {
        let result = try await client.models()
        return result.models.map { Model(id: $0, owner: "enter") }
    }
}


extension EnterService: VisionService {
    
    public func completion(request: VisionServiceRequest) async throws -> Message {
        let model = request.model
        let payload = makeRequest(model: request.model, messages: request.messages)
        let result = try await client.chat(payload)
        return decode(result: result)
    }
    
    public func completionStream(request: VisionServiceRequest, update: (Message) async -> Void) async throws {
        let model = request.model
        let conversationId = request.conversationId
        let payload = makeRequest(model: model, messages: request.messages, conversation: conversationId)
        var message = Message(role: .assistant)
        for try await result in client.chatStream(payload) {
            if let error = result.error { throw error }
            message = decode(result: result, into: message)
            await update(message)
        }
    }
}
