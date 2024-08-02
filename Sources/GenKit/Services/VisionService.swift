import Foundation

public protocol VisionService {
    func completion(request: VisionServiceRequest) async throws -> Message
    func completionStream(request: VisionServiceRequest, update: (Message) async -> Void) async throws
}

public struct VisionServiceRequest {
    public var model: String
    public var messages: [Message]
    public var maxTokens: Int?
    public var conversationId: String?
    public init(model: String, messages: [Message], conversationId: String? = nil, maxTokens: Int? = nil) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.conversationId = conversationId
    }
}
