//
//  AIImageDetector.swift
//  PRNUAuthenticator
//
//  AI-generated image detection using Hugging Face model converted to CoreML
//  Model: prithivMLmods/deepfake-detector-model-v1
//  Accuracy: 94.4%
//

import UIKit
import CoreML
import Vision

/// Detects AI-generated and deepfake images using machine learning
class AIImageDetector {
    
    // MARK: - Properties
    
    private var model: VNCoreMLModel?
    private var isModelLoaded: Bool {
        model != nil
    }
    
    // MARK: - Initialization
    
    init() {
        setupModel()
    }
    
    private func setupModel() {
        do {
            // Configure for optimal performance
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use Neural Engine, GPU, and CPU
            
            // Load the CoreML model (make sure AIDetector.mlpackage is in your project)
            let mlModel = try AIDetector(configuration: config)
            self.model = try VNCoreMLModel(for: mlModel.model)
            
            print("✅ AI Detection model loaded successfully")
        } catch {
            print("❌ Failed to load AI detection model: \(error)")
            print("💡 Make sure AIDetector.mlpackage is added to your Xcode project")
        }
    }
    
    // MARK: - Detection (Callback-based)
    
    /// Detect if image is AI-generated or deepfake (callback version)
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - completion: Result callback
    func detectAIImage(_ image: UIImage, completion: @escaping (AIDetectionResult) -> Void) {
        // Check if model is loaded
        guard let model = model else {
            completion(AIDetectionResult(
                isAIGenerated: false,
                confidence: 0,
                processingTime: 0,
                error: "Model not loaded"
            ))
            return
        }
        
        // Convert to CIImage
        guard let ciImage = CIImage(image: image) else {
            completion(AIDetectionResult(
                isAIGenerated: false,
                confidence: 0,
                processingTime: 0,
                error: "Failed to convert image"
            ))
            return
        }
        
        let startTime = Date()
        
        // Create Vision request
        let request = VNCoreMLRequest(model: model) { request, error in
            let processingTime = Date().timeIntervalSince(startTime)
            
            if let error = error {
                completion(AIDetectionResult(
                    isAIGenerated: false,
                    confidence: 0,
                    processingTime: processingTime,
                    error: error.localizedDescription
                ))
                return
            }
            
            // Process results
            guard let results = request.results as? [VNClassificationObservation] else {
                completion(AIDetectionResult(
                    isAIGenerated: false,
                    confidence: 0,
                    processingTime: processingTime,
                    error: "No classification results"
                ))
                return
            }
            
            // Parse results
            // Model outputs: [fake, real] or [0, 1]
            let fakeScore = results.first(where: { 
                $0.identifier == "fake" || $0.identifier == "0" 
            })?.confidence ?? 0
            
            let realScore = results.first(where: { 
                $0.identifier == "real" || $0.identifier == "1" 
            })?.confidence ?? 0
            
            // Determine if AI-generated
            let isAI = fakeScore > realScore
            let confidence = max(fakeScore, realScore)
            
            // Create result
            let result = AIDetectionResult(
                isAIGenerated: isAI,
                confidence: confidence,
                processingTime: processingTime,
                details: [
                    "fakeScore": fakeScore,
                    "realScore": realScore,
                    "allResults": results.map { "\($0.identifier): \(String(format: "%.3f", $0.confidence))" }
                ]
            )
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        // Configure request
        request.imageCropAndScaleOption = .centerCrop
        
        // Perform request on background thread
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(AIDetectionResult(
                        isAIGenerated: false,
                        confidence: 0,
                        processingTime: Date().timeIntervalSince(startTime),
                        error: error.localizedDescription
                    ))
                }
            }
        }
    }
    
    // MARK: - Detection (Async/Await)
    
    /// Detect if image is AI-generated or deepfake (async version)
    /// - Parameter image: The image to analyze
    /// - Returns: Detection result
    func detectAIImage(_ image: UIImage) async -> AIDetectionResult {
        await withCheckedContinuation { continuation in
            detectAIImage(image) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Batch Detection
    
    /// Detect AI in multiple images
    /// - Parameters:
    ///   - images: Array of images to analyze
    ///   - completion: Results callback
    func detectBatch(_ images: [UIImage], completion: @escaping ([AIDetectionResult]) -> Void) {
        var results: [AIDetectionResult] = []
        let group = DispatchGroup()
        
        for image in images {
            group.enter()
            detectAIImage(image) { result in
                results.append(result)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    /// Async batch detection
    func detectBatch(_ images: [UIImage]) async -> [AIDetectionResult] {
        await withCheckedContinuation { continuation in
            detectBatch(images) { results in
                continuation.resume(returning: results)
            }
        }
    }
}

// MARK: - Result Model

/// Result of AI image detection
struct AIDetectionResult {
    /// Whether the image is AI-generated or deepfake
    let isAIGenerated: Bool
    
    /// Confidence score (0.0 to 1.0)
    let confidence: Float
    
    /// Processing time in seconds
    let processingTime: TimeInterval
    
    /// Error message if detection failed
    let error: String?
    
    /// Additional details about the detection
    let details: [String: Any]
    
    // MARK: - Initializer
    
    init(
        isAIGenerated: Bool,
        confidence: Float,
        processingTime: TimeInterval = 0,
        error: String? = nil,
        details: [String: Any] = [:]
    ) {
        self.isAIGenerated = isAIGenerated
        self.confidence = confidence
        self.processingTime = processingTime
        self.error = error
        self.details = details
    }
    
    // MARK: - Computed Properties
    
    /// Confidence as percentage string
    var confidencePercentage: String {
        String(format: "%.1f%%", confidence * 100)
    }
    
    /// Processing time in milliseconds
    var processingTimeMs: String {
        String(format: "%.0fms", processingTime * 1000)
    }
    
    /// User-friendly status message
    var statusMessage: String {
        if let error = error {
            return "❌ Error: \(error)"
        }
        
        if isAIGenerated {
            return confidence > 0.9 
                ? "⚠️ DEFINITELY AI-GENERATED" 
                : "⚠️ LIKELY AI-GENERATED"
        } else {
            return confidence > 0.9 
                ? "✅ DEFINITELY REAL" 
                : "✅ LIKELY REAL"
        }
    }
    
    /// Detailed status with confidence
    var detailedStatus: String {
        if let error = error {
            return "Error: \(error)"
        }
        
        return """
        \(statusMessage)
        Confidence: \(confidencePercentage)
        Processing: \(processingTimeMs)
        """
    }
    
    /// Confidence level category
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.9...:
            return .veryHigh
        case 0.75..<0.9:
            return .high
        case 0.6..<0.75:
            return .medium
        default:
            return .low
        }
    }
    
    enum ConfidenceLevel: String {
        case veryHigh = "Very High"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

// MARK: - SwiftUI Color Extension

import SwiftUI

extension AIDetectionResult {
    /// Color for UI display
    var statusColor: Color {
        if error != nil {
            return .red
        }
        
        if isAIGenerated {
            return confidence > 0.9 ? .red : .orange
        } else {
            return confidence > 0.9 ? .green : .blue
        }
    }
    
    /// Icon for UI display
    var statusIcon: String {
        if error != nil {
            return "exclamationmark.triangle.fill"
        }
        
        if isAIGenerated {
            return "sparkles"
        } else {
            return "checkmark.shield.fill"
        }
    }
}

// MARK: - Usage Examples

/*
 // Example 1: Simple detection
 let detector = AIImageDetector()
 let image = UIImage(named: "test_photo")!
 
 detector.detectAIImage(image) { result in
     print(result.statusMessage)
     print(result.confidencePercentage)
 }
 
 // Example 2: Async/await
 Task {
     let result = await detector.detectAIImage(image)
     if result.isAIGenerated {
         print("⚠️ AI-generated image detected!")
     }
 }
 
 // Example 3: Batch detection
 let images = [image1, image2, image3]
 detector.detectBatch(images) { results in
     let aiCount = results.filter { $0.isAIGenerated }.count
     print("AI images: \(aiCount)/\(results.count)")
 }
 
 // Example 4: SwiftUI integration
 struct ImageCheckView: View {
     @State private var result: AIDetectionResult?
     let detector = AIImageDetector()
     
     var body: some View {
         VStack {
             if let result = result {
                 Label(result.statusMessage, systemImage: result.statusIcon)
                     .foregroundColor(result.statusColor)
                 Text(result.confidencePercentage)
             }
         }
         .task {
             result = await detector.detectAIImage(image)
         }
     }
 }
 */
