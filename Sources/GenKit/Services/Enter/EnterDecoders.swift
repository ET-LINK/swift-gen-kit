//
//  EnterDecoders.swift
//  swift-gen-kit
//
//  Created by Enter M1 on 2024/7/19.
//

import Foundation
import swift_enter_glass_network

extension EnterService {
    
    func decode(result: ChatStreamResult) -> Message {
        let choice = result.choices.first
        let message = choice?.delta
        
        return .init(
            id: result.id,
            role: decode(role: message?.role ?? .assistant),
            content: message?.content,
            toolCalls: message?.toolCalls?.map { decode(toolCall: $0) },
            finishReason: decode(finishReason: choice?.finishReason))
    }
    
    func decode(result: ChatStreamResult, into message: Message) -> Message {
        var message = message
        let choice = result.choices.first
        if choice?.delta.role == .assistant {
            message.content = patch(string: message.content, with: choice?.delta.content)
            message.name = result.systemFingerprint
        }
        message.id = result.id
        message.finishReason = decode(finishReason: choice?.finishReason)
        message.modified = .now
        
        // Convoluted way to add new tool calls and patch the last tool call being streamed in.
        if let toolCalls = choice?.delta.toolCalls {
            if message.toolCalls == nil {
                message.toolCalls = []
            }
            for toolCall in toolCalls {
                let newToolCall = decode(toolCall: toolCall)
                message.toolCalls?.append(newToolCall)

                
            }
        }
        return message
    }

    func decode(role: Chat.Role) -> Message.Role {
        switch role {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        }
    }

    func decode(finishReason: String?) -> Message.FinishReason? {
        switch finishReason {
        case "stop": .stop
        case "length": .length
        case "tool_calls": .toolCalls
        case "content_filter": .contentFilter
        default: nil
        }
    }

    func decode(toolCall: Chat.ToolCall) -> ToolCall {
        .init(
            type: toolCall.type ?? "",
            function: .init(
                name: toolCall.function.name ?? "",
                arguments: toolCall.function.arguments ?? ""
            )
        )
    }
}
