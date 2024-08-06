//
//  EnterDecoders.swift
//  swift-gen-kit
//
//  Created by Enter M1 on 2024/7/19.
//

import Foundation
import EnterGlassNetwork
import SharedKit

extension EnterService {
    
    func decode(result: ChatResponse) -> Message {
        var message = Message(
            role: decode(role: result.role),
            finishReason: decode(finishReason: result.stopReason)
        )
        for content in result.content ?? [] {
            switch content.type {
            case .text, .text_delta:
                message.content = content.text
            case .tool_use:
                if message.toolCalls == nil {
                    message.toolCalls = []
                }
                let data = try? JSONEncoder().encode(content.input)
                message.toolCalls?.append(.init(
                    id: content.id ?? .id,
                    function: .init(
                        name: content.name ?? "",
                        arguments: (data != nil) ? String(data: data!, encoding: .utf8)! : ""
                    )
                ))
            case .input_json_delta:
                break
            case .none:
                break
            }
        }
        return message
    }
    
    func decode(result: ChatStreamResponse, into message: Message) -> Message {
        var message = message
        switch result.type {
        case .agent_thought:
            if let msg = result.message {
                message.id = msg.id ?? message.id
                message.finishReason = decode(finishReason: msg.stopReason)
                message.name = msg.type
            }
            if let contentBlock = result.contentBlock {
                switch contentBlock.type {
                case .text:
                    message.content = contentBlock.text
                case .tool_use:
                    let toolCall = Message.Component(name: contentBlock.name ?? "Unknow", json: contentBlock.partialJSON ?? "", content: contentBlock.text)
                    if let index = message.attachments.firstIndex(where: { if case .component(_) = $0 { return true } else { return false } }) {
                        message.attachments[index] = .component(toolCall)
                    } else {
                        message.attachments.append(.component(toolCall))
                    }
                default:
                    break
                }
            }
            
        case .agent_message:
            if let delta = result.delta {
                switch delta.type {
                case .text_delta:
                    message.content = patch(string: message.content, with: delta.text)
                case .input_json_delta:
                    if var existing = message.toolCalls?.last {
                        existing.function.arguments = patch(string: existing.function.arguments, with: delta.partialJSON) ?? ""
                        message.toolCalls![message.toolCalls!.count-1] = existing
                    }
                default:
                    break
                }
            }
        case .message_end:
            if message.toolCalls != nil {
                message.finishReason = .toolCalls
            } else {
                message.finishReason = .stop
            }
        case .message:
            break
        case .message_file:
            break
        case .tts_message_end:
            break
        }
        
        message.modified = .now
        return message
    }

    func decode(role: Role?) -> Message.Role {
        switch role {
        case .user: .user
        case .assistant, .none: .assistant
        }
    }

    func decode(finishReason: StopReason?) -> Message.FinishReason? {
        switch finishReason {
        case .end_turn:
            return .stop
        case .max_tokens:
            return .length
        case .stop_sequence:
            return .cancelled
        case .tool_use:
            return .toolCalls
        default:
            return .none
        }
    }
}
