//
//  ChatView.swift
//  MyApp
//
//  Created by Prosenjit Kolay on 20/09/26.
//


import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isTextFieldFocused: Bool // Tracks keyboard focus visibility
    
    var body: some View {
        NavigationView {
            VStack {
                switch viewModel.engine.modelState {
                case .unloaded, .loading:
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Compiling local Metal GPU kernels. Please wait...")
                            .font(.headline)
                    }
                    .frame(maxHeight: .infinity)
                    
                case .ready:
                    // Main Chat Window Frame
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    ChatBubble(
                                        message: message,
                                        streamingText: viewModel.engine.currentResponse,
                                        isLast: message.id == viewModel.messages.last?.id
                                    )
                                }
                                
                                // Silent visual anchor point for scroll target execution routines
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottomAnchor")
                            }
                            .padding()
                        }
                        // FIX: Hide the keyboard when the user drags or scrolls down manually
                        .scrollDismissesKeyboard(.interactively)
                        // FIX: Hide the keyboard when tapping anywhere inside the conversation window background
                        .onTapGesture {
                            isTextFieldFocused = false
                        }
                        // Push view frame upward instantly when incoming list array counts change
                        .onChange(of: viewModel.messages.count) { _, _ in
                            scrollToBottom(with: proxy)
                        }
                        // Watch character accumulation to lock the frame while typing
                        .onChange(of: viewModel.engine.currentResponse) { _, _ in
                            scrollToBottom(with: proxy)
                        }
                        // Force immediate scroll target alignment when keyboard sweeps up
                        .onChange(of: isTextFieldFocused) { _, isFocused in
                            if isFocused {
                                // Short delay to let the iOS system window transition complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    scrollToBottom(with: proxy)
                                }
                            }
                        }
                    }
                    
                    // Instrumentation Data Dashboard Overlay Bar
                    if viewModel.isGenerating && viewModel.engine.tokensPerSecond > 0 {
                        HStack {
                            Image(systemName: "cpu.fill")
                            Text(String(format: "Inference Speed: %.1f tokens/sec (Metal Core)", viewModel.engine.tokensPerSecond))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .transition(.opacity)
                    }
                    
                    // Conversation Input Bar Components
                    HStack(spacing: 12) {
                        TextField("Type an offline prompt...", text: $viewModel.currentInput)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .disabled(viewModel.isGenerating)
                            .focused($isTextFieldFocused) // Binds structural state to event loops
                        
                        Button(action: {
                            Task { await viewModel.sendMessage() }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(viewModel.currentInput.isEmpty || viewModel.isGenerating ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.currentInput.isEmpty || viewModel.isGenerating)
                    }
                    .padding()
                    
                case .failed(let error):
                    ContentUnavailableView(
                        "Failed to Load Model",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            }
            .navigationTitle("Local AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.clearHistory() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.messages.isEmpty || viewModel.isGenerating)
                }
            }
            .task {
                await viewModel.setup()
            }
        }
    }
    
    /// Animates down seamlessly to secure text visibility parameters
    private func scrollToBottom(with proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let streamingText: String
    let isLast: Bool
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.text.isEmpty && isLast ? streamingText : message.text)
                .padding(12)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(12)
            
            if !message.isUser { Spacer() }
        }
    }
}
