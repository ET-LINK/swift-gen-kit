//
//  EnterEncoders.swift
//  swift-gen-kit
//
//  Created by Enter M1 on 2024/7/19.
//

import Foundation
import EnterGlassNetwork
import SharedKit

extension EnterService {
    
    // Extract all system messages and combine into one because Anthropic accepts a single system prompt as part of the
    // chat request instead of system messages. Combine multiple user messages so we always have alternating user and
    // assistant messages.
    func encode(messages: [Message]) -> (String?, [ChatRequest.Message]) {
        let messagesFiltered = messages
            .filter { $0.role == .user }
        
        var lastArray: [ChatRequest.Message] = []
        if let last = messagesFiltered.last {
            lastArray.append(encode(message: last))
        }
        
        let messagesCleaned = lastArray.reduce(into: [ChatRequest.Message]()) { result, message in
            if let lastMessage = result.last {
                if lastMessage.role == .user && message.role == .user {
                    result[result.count - 1].content += message.content
                } else {
                    result.append(message)
                }
            } else {
                result.append(message)
            }
        }
        return (nil, messagesCleaned)
    }
    
    func encode(message: Message) -> ChatRequest.Message {
        var out = ChatRequest.Message(role: encode(role: message.role), content: [])
        
        // Prepare all the image assets attached to the message
        let assets: [Asset] = message.visionImages
        out.content += assets.map { (asset) -> ChatRequest.Message.Content? in
            switch asset.location {
            case .none:
                guard let data = asset.data else { return nil }
                return .init(type: .image, source: .init(type: .base64, mediaType: .png, data: data))
            default:
                return nil
            }
        }.compactMap { $0 }
        
        
        // Handle tool responses or append message content
        if message.role == .tool {
            out.content.append(.init(type: .tool_result, content: [.init(type: .text, text: message.content)], toolUseID: message.toolCallID))
        } else {
            if let text = message.content {
                let chat = swift_enter_glass_network.ChatRequest.Message.Content.init(type: .text, text: text, input: message.input)
                out.content.append(chat)
            }
        }
        return out
    }
    
    func encode(role: Message.Role) -> Role {
        switch role {
        case .system, .user, .tool: .user
        case .assistant: .assistant
        }
    }
    
    func encode(tools: Set<Tool>) -> [ChatRequest.Tool]? {
        guard !tools.isEmpty else { return nil }
        return tools.map { encode(tool: $0) }
    }
    
    func encode(tool: Tool) -> ChatRequest.Tool {
        .init(
            name: tool.function.name,
            description: tool.function.description,
            inputSchema: tool.function.parameters
        )
    }
}
