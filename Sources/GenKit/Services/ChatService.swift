import Foundation

public protocol ChatService {
    func completion(request: ChatServiceRequest) async throws -> Message
    func completionStream(request: ChatServiceRequest, update: (Message) async -> Void) async throws
}

public struct ChatServiceRequest {
    public var model: String
    public var messages: [Message]
    public var tools: Set<Tool>
    public var toolChoice: Tool?
    public var conversationId: String?
    
    public init(model: String, messages: [Message], conversationId: String?, tools: Set<Tool> = [], toolChoice: Tool? = nil) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.conversationId = conversationId
    }
}
