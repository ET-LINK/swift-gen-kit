import Foundation
import OSLog
import Mistral

private let logger = Logger(subsystem: "MistralService", category: "GenKit")

public actor MistralService {
    
    let client: MistralClient
    
    public init(configuration: MistralClient.Configuration) {
        self.client = MistralClient(configuration: configuration)
    }
    
    private func makeRequest(model: String, messages: [Message], tools: [Tool] = [], toolChoice: Tool? = nil) -> ChatRequest {
        return .init(
            model: model,
            messages: encode(messages: messages),
            tools: encode(tools: tools),
            toolChoice: encode(toolChoice: toolChoice)
        )
    }
}

extension MistralService: ChatService {
    
    public func completion(_ request: ChatServiceRequest) async throws -> Message {
        var req = makeRequest(model: request.model.id, messages: request.messages, tools: request.tools, toolChoice: request.toolChoice)
        req.temperature = request.temperature
        
        let result = try await client.chat(req)
        return decode(result: result)
    }
    
    public func completionStream(_ request: ChatServiceRequest, update: (Message) async throws -> Void) async throws {
        var req = makeRequest(model: request.model.id, messages: request.messages, tools: request.tools, toolChoice: request.toolChoice)
        req.temperature = request.temperature
        req.stream = true
        
        var message = Message(role: .assistant)
        for try await result in client.chatStream(req) {
            message = decode(result: result, into: message)
            try await update(message)
        }
    }
}

extension MistralService: EmbeddingService {
    
    public func embeddings(model: Model, input: String) async throws -> [Double] {
        let req = EmbeddingRequest(model: model.id, input: [input])
        let result = try await client.embeddings(req)
        return result.data.first?.embedding ?? []
    }
}

extension MistralService: ModelService {
    
    public func models() async throws -> [Model] {
        let result = try await client.models()
        return result.data.map { decode(model: $0) }
    }
}

extension MistralService: ToolService {
    
    public func completion(_ request: ToolServiceRequest) async throws -> Message {
        var req = makeRequest(model: request.model.id, messages: request.messages, tools: [request.tool], toolChoice: request.tool)
        req.temperature = request.temperature
        
        let result = try await client.chat(req)
        return decode(result: result)
    }
    
    public func completionStream(_ request: ToolServiceRequest, update: (Message) async throws -> Void) async throws {
        var req = makeRequest(model: request.model.id, messages: request.messages, tools: [request.tool], toolChoice: request.tool)
        req.temperature = request.temperature
        req.stream = true
        
        var message = Message(role: .assistant)
        for try await result in client.chatStream(req) {
            message = decode(result: result, into: message)
            try await update(message)
        }
    }
}
