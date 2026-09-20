# 📱 iOS Local AI Chatbot (SwiftUI + Apple MLX)

A completely **offline, privacy-first AI chatbot application** built natively for iOS using SwiftUI and Apple's official **MLX Swift** framework. This project runs lightweight, quantized open-source Large Language Models (LLMs) like **Llama 3.2 (1B)** completely on-device, leveraging the Apple Silicon Neural Engine and GPU without needing an internet connection.

---

## ✨ Features

- **100% Offline Inference:** Runs entirely on-device. Zero network requests, zero data tracking, and completely functional in Airplane Mode.
- **Apple MLX Optimization:** Powered by Apple's core machine learning frameworks, specifically tuned for maximum performance on Apple Silicon.
- **Real-Time Token Streaming:** Renders response text chunks dynamically as they are calculated by the Neural Engine.
- **Live Hardware Telemetry:** Displays an inference metric panel tracking real-time **Tokens-Per-Second (Tok/s)** computation speeds.
- **Smart Adaptive UI:** Uses standard SwiftUI focus states to automatically scroll long conversation contexts up when the iOS system keyboard is revealed.
- **Interactive Gesture Dismissal:** Supports dragging down or tapping anywhere on the conversation background to drop the keyboard smoothly.
- **Context Recycler:** Includes a context-clearing button to flush active conversation threads out of the device's RAM buffer.

---

## 🛠 Hardware & System Requirements

On-device AI execution is highly resource-intensive. This project targets compact models optimized to fit inside restrictive mobile memory boundaries:

| Device Target | Recommended Model Profile | Approximate RAM Impact |
| :--- | :--- | :--- |
| **iPhone 15 Pro, iPhone 16+** | `mlx-community/Meta-Llama-3-8B-Instruct-4bit` | ~4.5 GB - 5.0 GB |
| **iPhone 13, 14, 15 (Base)** | `mlx-community/Llama-3.2-1B-Instruct-4bit` | ~1.2 GB - 1.5 GB |

- **Minimum iOS Version:** iOS 18.0+
- **Development Environment:** Xcode 16.0+

---

## 🚀 Step-by-Step Setup Guide

### 1. Add Swift Package Dependencies
Open your project in Xcode and add the official Apple Silicon MLX ecosystem packages via **File -> Add Package Dependencies...**:

1. **MLX Swift Framework:**
   ```text
   https://github.com/ml-explore/mlx-swift
   ```
2. **MLX Language Model Extensions (includes Hugging Face macro tools):**
   ```text
   https://github.com/ml-explore/mlx-swift-lm
   ```
   *Make sure your main Application Target explicitly links `MLX`, `MLXLLM`, `MLXLMCommon`, and `MLXHuggingFace` in your **Frameworks, Libraries, and Embedded Content** configuration grid.*

### 2. Configure Xcode Entitlements & Capabilities
Because local models aggressively claim system memory resources, iOS will terminate the app unless you request high-memory boundaries.

1. Go to your target's **Signing & Capabilities** tab.
2. Click **+ Capability** and add **Increased Memory Limit**.
3. Open your target's **Info** tab (`Info.plist`) and add the following keys to allow background model chunk caching:
   - **`App Transport Security Settings`** -> Set `Allow Arbitrary Loads` to `YES`
   - **`Privacy - Local Network Usage Description`** -> *"Required to stream and cache offline weights."*

---

## 💻 Architecture Implementation Overview

The codebase is cleanly separated into three modular core layers:

### The Hardware Inference Layer (`LocalLLMEngine.swift`)
Manages model weight lifecycle initialization using Apple's official `#huggingFaceLoadModelContainer` macro and yields streaming text chunks utilizing asynchronous event streams:

```swift
let generationStream = try await container.generate(
    input: lmInput,
    parameters: GenerateParameters(temperature: 0.7)
)

for await event in generationStream {
    if case .chunk(let text) = event {
        // Appends token text strings in real time
    }
}
```

### The Context Buffer Manager (`ChatViewModel.swift`)
Maintains the visible message array state and protects mobile memory overhead limits by enforcing truncation logic limits (dropping historical contexts if the exchange thread extends past 16 steps).

### The Responsive UI Layer (`ChatView.swift`)
Draws a premium messaging interface using native `ScrollViewReader` anchors, `.scrollDismissesKeyboard(.interactively)`, and `@FocusState` flags to ensure conversational text components are never obscured by the active keyboard envelope.

---

## 🔍 First Launch Behavioral Expectation
When launching the application on a physical device for the first time, the UI will display a **"Connecting to Hugging Face..."** state. 

- **What's happening:** The app is fetching the 4-bit weights (~1.2 GB) over the network directly from the Hugging Face repository endpoints. 
- **Subsequent Launches:** Once fully completed, these weight vectors remain cached inside local application container folders indefinitely. Successive boot cycles skip network operations entirely, launching the conversation space **installs instantly and works 100% offline**.

---

## 📄 License
This project is open-source under the terms of the MIT License. Feel free to copy, modify, and distribute it inside your own localized iOS applications.
