//
//  LocalLLMEngine.swift
//  MyApp
//
//  Created by Prosenjit Kolay on 20/09/26.
//


import Foundation
import Combine
import MLX
import MLXLLM
import MLXLMCommon     // Core data structures like ModelContainer
import MLXHuggingFace // Provides HubClient for model lookups
import HuggingFace    // Exposes HubClient and Repo references
import Tokenizers     // Exposes native Tokenizer protocols

@MainActor
class LocalLLMEngine: ObservableObject {
    @Published var modelState: ModelState = .unloaded
    @Published var currentResponse: String = ""
    @Published var downloadProgress: Double = 0.0
    @Published var tokensPerSecond: Double = 0.0 // <-- ADDED: Dynamic speed logging
    
    private var modelContainer: ModelContainer?
    private let modelConfiguration = ModelConfiguration(id: "mlx-community/Llama-3.2-1B-Instruct-4bit")
    
    // ADDED: Inject a foundational system persona prompt context structure
    private let systemPrompt = "You are a helpful, brilliant AI coding assistant running locally on an iPhone. Keep answers concise."
    
    enum ModelState {
        case unloaded
        case loading
        case ready
        case failed(String)
    }
    
    func loadModel() async {
        guard case .unloaded = modelState else { return }
        modelState = .loading
        downloadProgress = 0.0
        
        do {
            let container = try await #huggingFaceLoadModelContainer(
                configuration: modelConfiguration
            ) { [weak self] progress in
                guard let self = self else { return }
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                }
            }
            
            Task { @MainActor in
                self.modelContainer = container
                self.modelState = .ready
            }
        } catch {
            Task { @MainActor in
                self.modelState = .failed(error.localizedDescription)
            }
        }
    }

    /// Generates local tokens with system styling and performance instrumentation
    func generateResponse(messages: [ChatMessage]) async -> String {
        guard let container = modelContainer else { return "Model not initialized." }
        currentResponse = ""
        
        // 1. Core Injection: Seed the structural context configuration template
        var chatInput: [Chat.Message] = [.system(systemPrompt)]
        
        // 2. Append conversation history elements safely
        chatInput.append(contentsOf: messages.map { msg in
            msg.isUser ? .user(msg.text) : .assistant(msg.text)
        })
        
        do {
            let userInput = UserInput(chat: chatInput)
            let lmInput = try await container.prepare(input: userInput)
            let generationStream = try await container.generate(
                input: lmInput,
                parameters: GenerateParameters(temperature: 0.7)
            )
            
            var fullOutput = ""
            
            for await event in generationStream {
                switch event {
                case .chunk(let text):
                    fullOutput += text
                    let updatedText = fullOutput
                    Task { @MainActor in
                        self.currentResponse = updatedText
                    }
                case .info(let metrics):
                    // 3. Telemetry capture: Route tokens per second updates directly to layout listeners
                    Task { @MainActor in
                        self.tokensPerSecond = metrics.tokensPerSecond
                    }
                case .toolCall(let call):
                    print("Tool request: \(call.function.name)")
                @unknown default:
                    break
                }
            }
            return fullOutput
        } catch {
            return "Local Inference Error: \(error.localizedDescription)"
        }
    }
}
