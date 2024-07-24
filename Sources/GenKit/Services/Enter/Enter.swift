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
        let separator = "|"
        let splitArray = request.model.components(separatedBy: separator)
        let model = splitArray.first ?? ""
        var conversationId: String?
        if splitArray.count > 1 {
            conversationId = splitArray.last
        }
        let payload = makeRequest(model: model, messages: request.messages, conversation: conversationId, tools: request.tools)
        let result = try await client.chat(payload)
        if let error = result.error { throw error }
        return decode(result: result)
    }
    
    public func completionStream(request: ChatServiceRequest, update: (Message) async -> Void) async throws {
        let separator = "|"
        let splitArray = request.model.components(separatedBy: separator)
        let model = splitArray.first ?? ""
        var conversationId: String?
        if splitArray.count > 1 {
            conversationId = splitArray.last
        }
        let payload = makeRequest(model: model, messages: request.messages, conversation: conversationId, tools: request.tools)
        var message = Message(role: .assistant)
        for try await result in client.chatStream(payload) {
            if let error = result.error { throw error }
            print(result)
            message = decode(result: result, into: message)
            print(message)
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
