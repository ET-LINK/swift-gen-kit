import Foundation
import OSLog
import Ollama

private let logger = Logger(subsystem: "OllamaService", category: "GenKit")

public actor OllamaService {
    
    private var client: OllamaClient
    
    public init(configuration: OllamaClient.Configuration) {
        self.client = OllamaClient(configuration: configuration)
    }
}

extension OllamaService: ChatService {
    
    public func completion(_ request: ChatServiceRequest) async throws -> Message {
        let req = ChatRequest(
            model: request.model.id.rawValue,
            messages: encode(messages: request.messages),
            tools: encode(tools: request.tools),
            stream: false
        )
        let result = try await client.chat(req)
        return decode(result: result)
    }
    
    public func completionStream(_ request: ChatServiceRequest, update: (Message) async throws -> Void) async throws {
        
        // Ollama doesn't yet support streaming when tools are present.
        guard request.tools.isEmpty else {
            let message = try await completion(request)
            try await update(message)
            return
        }
        
        let req = ChatRequest(
            model: request.model.id.rawValue,
            messages: encode(messages: request.messages),
            tools: encode(tools: request.tools),
            stream: request.tools.isEmpty
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
    
    public func embeddings(_ request: EmbeddingServiceRequest) async throws -> [Double] {
        let req = EmbeddingRequest(model: request.model.id.rawValue, input: request.input)
        let result = try await client.embeddings(req)
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
        let payload = ChatRequest(model: request.model.id.rawValue, messages: messages)
        let result = try await client.chat(payload)
        return decode(result: result)
    }
    
    public func completionStream(_ request: VisionServiceRequest, update: (Message) async throws -> Void) async throws {
        let payload = ChatRequest(model: request.model.id.rawValue, messages: encode(messages: request.messages), stream: true)
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

