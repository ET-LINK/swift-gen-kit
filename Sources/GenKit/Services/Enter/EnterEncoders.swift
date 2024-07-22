//
//  EnterEncoders.swift
//  swift-gen-kit
//
//  Created by Enter M1 on 2024/7/19.
//

import Foundation
import swift_enter_glass_network

extension EnterService {
    func encode(messages: [Message]) -> [Chat] {
        messages.map { encode(message: $0) }
    }
    
    func encode(message: Message) -> Chat {
        .init(
            auid: message.id,
            conversationID: message.runID,
            role: encode(role: message.role),
            content: message.content,
            name: message.name,
            toolCalls: message.toolCalls?.map { encode(toolCall: $0) },
            toolCallID: message.toolCallID
        )
    }
    
    func encode(role: Message.Role) -> Chat.Role {
        switch role {
        case .system: .system
        case .assistant: .assistant
        case .user: .user
        case .tool: .tool
        }
    }
    
    func encode(toolCalls: [ToolCall]?) -> [Chat.ToolCall]? {
        toolCalls?.map { encode(toolCall: $0) }
    }
    
    func encode(toolCall: ToolCall) -> Chat.ToolCall {
        .init(type: toolCall.type, function: encode(functionCall: toolCall.function) )
    }
    
    func encode(functionCall: ToolCall.FunctionCall) -> Chat.ToolCall.Function {
        .init(name: functionCall.name, arguments: functionCall.arguments)
    }
//    func encode(messages: [Message]) -> [EGChatCreateConversationRequest] {
//        messages
//            .filter { $0.role != .system } // Gemini doesn't support context or system messages
//            .map { encode(message: $0) }
//    }
//    
//    func encode(message: Message) -> EGChatCreateConversationRequest {
//        var request = EGChatCreateConversationRequest()
//        request.async = false
//        request.responseMode = .streaming
//        request.auid = message.id
//        request.conversationId = message.runID ?? ""
//        request.query = message.content ?? ""
//        return request
//    }
    

}
