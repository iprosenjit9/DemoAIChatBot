//
//  ChatViewModel.swift
//  MyApp
//
//  Created by Prosenjit Kolay on 20/09/26.
//

import Foundation
import Combine

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isGenerating: Bool = false
    
    let engine = LocalLLMEngine()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    func setup() async {
        await engine.loadModel()
    }
    
    // ADDED: Clear conversation memory limits to refresh active device RAM
    func clearHistory() {
        messages.removeAll()
        engine.currentResponse = ""
        engine.tokensPerSecond = 0.0
    }
    
    func sendMessage() async {
        let textToSend = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        
        // Safe contextual truncation boundary rules for 4GB hardware footprints
        if messages.count > 16 {
            messages.removeFirst(2) // Drop oldest pair to recycle active slots
        }
        
        let userMessage = ChatMessage(text: textToSend, isUser: true)
        messages.append(userMessage)
        currentInput = ""
        isGenerating = false // Reset state quickly to trigger immediate scroll action
        
        let assistantPlaceholder = ChatMessage(text: "", isUser: false)
        messages.append(assistantPlaceholder)
        let placeholderIndex = messages.count - 1
        
        isGenerating = true
        
        // Extract array references minus placeholder
        let finalOutput = await engine.generateResponse(messages: Array(messages.dropLast()))
        
        messages[placeholderIndex] = ChatMessage(text: finalOutput, isUser: false)
        isGenerating = false
    }
}
