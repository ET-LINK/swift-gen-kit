import Foundation
import OSLog
import Ollama

private let logger = Logger(subsystem: "OllamaService", category: "GenKit")

public actor OllamaService {
    
    private var client: OllamaClient
    
    public init(configuration: OllamaClient.Configuration) {
        self.client = OllamaClient(configuration: configuration)
    }
    
    private func prepareToolMessage(_ tool: Tool?) -> Ollama.Message? {
        guard let tool else { return nil }
        guard let paramData = try? JSONEncoder().encode(tool.function.parameters) else { return nil }
        
        let parameters = String(data: paramData, encoding: .utf8) ?? ""
        return Ollama.Message(
            role: .user,
            content: """
                \(tool.function.description)
                Respond using JSON
                
                JSON schema:
                \(parameters)
                """
        )
    }
}

extension OllamaService: ChatService {
    
    public func completion(_ request: ChatServiceRequest) async throws -> Message {
        var messages = encode(messages: request.messages)
        if let toolMessage = prepareToolMessage(request.toolChoice) {
            messages.append(toolMessage)
        }
        let req = ChatRequest(
            model: request.model.id,
            messages: messages,
            format: (request.toolChoice != nil) ? "json" : nil // Encourage JSON output if tool choice is present
        )
        let result = try await client.chat(req)
        return decode(result: result)
    }
    
    public func completionStream(_ request: ChatServiceRequest, update: (Message) async throws -> Void) async throws {
        let req = ChatRequest(
            model: request.model.id,
            messages: encode(messages: request.messages),
            stream: true
        )
        var message = Message(role: .assistant)
        for try await result in client.chatStream(req) {
            message = decode(result: result, into: message)
            try await update(message)
            
            // The connection hangs if we don't explicitly return when the stream has stopped.
            if message.finishReason == .stop {
                return
            }
        }
    }
}

extension OllamaService: EmbeddingService {
    
    public func embeddings(model: Model, input: String) async throws -> [Double] {
        let payload = EmbeddingRequest(model: model.id, prompt: input, options: [:])
        let result = try await client.embeddings(payload)
        return result.embedding
    }
}

extension OllamaService: ModelService {
    
    public func models() async throws -> [Model] {
        let result = try await client.models()
        return result.models.map { decode(model: $0) }
    }
}

extension OllamaService: VisionService {

    public func completion(_ request: VisionServiceRequest) async throws -> Message {
        let messages = encode(messages: request.messages)
        let payload = ChatRequest(model: request.model.id, messages: messages)
        let result = try await client.chat(payload)
        return decode(result: result)
    }
    
    public func completionStream(_ request: VisionServiceRequest, update: (Message) async throws -> Void) async throws {
        let payload = ChatRequest(model: request.model.id, messages: encode(messages: request.messages), stream: true)
        var message = Message(role: .assistant)
        for try await result in client.chatStream(payload) {
            message = decode(result: result, into: message)
            try await update(message)
            
            // The connection hangs if we don't explicitly return when the stream has stopped.
            if message.finishReason == .stop {
                return
            }
        }
    }
}

extension OllamaService: ToolService {
    
    public func completion(_ request: ToolServiceRequest) async throws -> Message {
        let messages = encode(messages: request.messages)
        let tools = encode(tools: [request.tool])
        let payload = ChatRequest(model: request.model.id, messages: messages + tools, format: "json")
        let result = try await client.chat(payload)
        return decode(tool: request.tool, result: result)
    }
    
    public func completionStream(_ request: ToolServiceRequest, update: (Message) async throws -> Void) async throws {
        let messages = encode(messages: request.messages)
        let tools = encode(tools: [request.tool])
        let payload = ChatRequest(model: request.model.id, messages: messages + tools, stream: true, format: "json")
        var message = Message(role: .assistant)
        for try await result in client.chatStream(payload) {
            message = decode(tool: request.tool, result: result, into: message)
            try await update(message)
            
            // The connection hangs if we don't explicitly return when the stream has stopped.
            if message.finishReason == .stop {
                return
            }
        }
    }
}
