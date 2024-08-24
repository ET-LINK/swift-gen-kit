import Foundation

public class ChatSession {
    public static let shared = ChatSession()
    
    public func stream(_ request: ChatSessionRequest, runLoopLimit: Int = 10) -> AsyncThrowingStream<Message, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let runID = String.id
                
                var messages = request.messages
                
                var runLoopCount = 0
                var runShouldContinue = true
                
                while runShouldContinue && runLoopCount < runLoopLimit {
                    // Prepare service request, DO NOT include a tool choice on subsequent runs, this will
                    // cause an expensive infinite loop of tool calls.
                    let req = ChatServiceRequest(
                        model: request.model,
                        messages: messages,
                        tools: request.tools,
                        toolChoice: (runLoopCount > 0) ? nil : request.tool // FIRST REQUEST ONLY
                    )
                    try await request.service.completionStream(request: req) { update in
                        var message = update
                        message.runID = runID
                        
                        messages = apply(message: message, messages: messages)
                        continuation.yield(update)
                    }
                    
                    // Determine if there were any tool calls on the last message, process them by calling their
                    // repsective functions to return tool responses, then decide whether the loop should continue.
                    guard request.toolCallback != nil else {
                        break
                    }
                    let lastMessage = messages.last!
                    let (toolMessages, shouldContinue) = try await processToolCalls(in: lastMessage, callback: request.toolCallback)
                    for message in toolMessages {
                        messages = apply(message: message, messages: messages)
                        continuation.yield(message)
                    }
                    runShouldContinue = shouldContinue
                    runLoopCount += 1
                }
                
                continuation.finish()
            }
        }
    }
    
    public func completion(_ request: ChatSessionRequest, runLoopLimit: Int = 10) async throws -> ChatSessionResponse {
        let runID = String.id
        
        var messages = request.messages
        var response = ChatSessionResponse(messages: [])
        
        var runLoopCount = 0
        var runShouldContinue = true
        
        while runShouldContinue && runLoopCount < runLoopLimit {
            // Prepare service request, DO NOT include a tool choice on subsequent runs, this will
            // cause an expensive infinite loop of tool calls.
            let req = ChatServiceRequest(
                model: request.model,
                messages: messages,
                tools: request.tools,
                toolChoice: (runLoopCount > 0) ? nil : request.tool // FIRST REQUEST ONLY
            )
            var message = try await request.service.completion(request: req)
            message.runID = runID
            
            response.messages = apply(message: message, messages: response.messages)
            messages = apply(message: message, messages: messages)
            
            // Determine if there were any tool calls on the last message, process them by calling their
            // repsective functions to return tool responses, then decide whether the loop should continue.
            guard request.toolCallback != nil else {
                break
            }
            let (toolMessages, shouldContinue) = try await processToolCalls(in: message, callback: request.toolCallback)
            for message in toolMessages {
                response.messages = apply(message: message, messages: response.messages)
                messages = apply(message: message, messages: messages)
            }
            runShouldContinue = shouldContinue
            runLoopCount += 1
        }
        
        return response
    }
    
    func processToolCalls(in message: Message, callback: ChatSessionRequest.ToolCallback?) async throws -> ([Message], Bool) {
        guard let callback else { return ([], false) }
        guard let toolCalls = message.toolCalls else { return ([], false) }
        let runID = message.runID
        
        // Parallelize tool calls.
        var responses: [ToolCallResponse] = []
        await withTaskGroup(of: ToolCallResponse.self) { group in
            for toolCall in toolCalls {
                group.addTask {
                    do {
                        return try await callback(toolCall)
                    } catch {
                        let message = Message(
                            role: .tool,
                            content: "Unknown tool.",
                            toolCallID: toolCall.id,
                            name: toolCall.function.name,
                            metadata: ["label": "Unknown tool"]
                        )
                        return .init(messages: [message], shouldContinue: false)
                    }
                }
            }
            for await response in group {
                responses.append(response)
            }
        }
        
        // Flatten messages from task responses and annotate each message with a Run identifier.
        let messages = responses
            .flatMap { $0.messages }
            .map {
                var message = $0
                message.runID = runID
                return message
            }
        
        // If any task response suggests the Run should stop, stop it.
        let shouldContinue = !responses.contains(where: { $0.shouldContinue == false })
        
        return (messages, shouldContinue)
    }
    
    func apply(message: Message, messages: [Message]) -> [Message] {
        var messages = messages
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
            return messages
        } else {
            messages.append(message)
            return messages
        }
    }
}

// MARK: - Types

public struct ChatSessionRequest {
    public typealias ToolCallback = @Sendable (ToolCall) async throws -> ToolCallResponse
    
    public let service: ChatService
    public let model: String
    public let toolCallback: ToolCallback?
    
    public private(set) var messages: [Message] = []
    public private(set) var tools: [Tool] = []
    public private(set) var tool: Tool? = nil
    public private(set) var memories: [String] = []
    
    public init(service: ChatService, model: String, toolCallback: ToolCallback? = nil) {
        self.service = service
        self.model = model
        self.toolCallback = toolCallback
    }
    
    public mutating func with(messages: [Message]) {
        self.messages = messages
    }
    
    public mutating func with(tools: [Tool]) {
        self.tools = tools
    }
    
    public mutating func with(tool: Tool?) {
        if let tool {
            self.tool = tool
            self.tools.append(tool)
        } else {
            self.tool = nil
        }
    }
    
    public mutating func with(memories: [String]) {
        self.memories = memories
    }
}

public struct ChatSessionResponse {
    public var messages: [Message]
    
    public func extractTool<T: Codable>(name: String, type: T.Type) throws -> T {
        guard let message = messages.last else {
            throw ChatSessionError.missingMessage
        }
        guard let toolCalls = message.toolCalls else {
            throw ChatSessionError.missingToolCalls
        }
        guard let toolCall = toolCalls.first(where: { $0.function.name == name }) else {
            throw ChatSessionError.missingToolCall
        }
        guard let data = toolCall.function.arguments.data(using: .utf8) else {
            throw ChatSessionError.unknown
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

enum ChatSessionError: Error {
    case missingMessage
    case missingToolCalls
    case missingToolCall
    case missingTool
    case unknown
}
