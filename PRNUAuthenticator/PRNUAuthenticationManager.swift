//
//  PRNUAuthenticationManager.swift
//  PRNUAuthenticator
//
//  COMBO VERSION - AI Detection + PRNU with Enforced Enrollment
//

import SwiftUI
import Combine

// MARK: - Detection Method

enum DetectionMethod {
    case aiDetection    // No enrollment needed
    case prnuCamera     // Requires 50 photos enrollment
}

class PRNUAuthenticationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isEnrolled = false
    @Published var enrollmentProgress: Float = 0.0
    @Published var lastResult: AuthenticationResult?
    @Published var statusMessage = ""
    @Published var isProcessing = false
    @Published var currentResult: AuthenticationResult?
    
    @Published var selectedMethod: DetectionMethod = .aiDetection
    @Published var showEnrollmentRequired = false
    
    // MARK: - Private Properties
    
    private let aiDetector = AIImageDetector()
    private let prnu = PRNUAuthenticator()
    private let cameraID = "MainDevice_Camera"
    private var enrollmentImages: [UIImage] = []
    
    // MARK: - Initialization
    
    init() {
        checkEnrollmentStatus()
    }
    
    // MARK: - Enrollment
    
    func checkEnrollmentStatus() {
        isEnrolled = prnu.isCameraEnrolled(cameraID: cameraID)
        
        if isEnrolled {
            statusMessage = "✅ Ready: AI Detection & PRNU available"
        } else {
            statusMessage = "✅ AI Detection ready | ⚠️ PRNU requires enrollment"
        }
        
        print("📊 [INIT] Enrollment status: \(isEnrolled ? "Enrolled" : "Not enrolled")")
        print("📊 [INIT] AI Detection: Always available")
        print("📊 [INIT] PRNU Authentication: \(isEnrolled ? "Available" : "Locked (needs 50 photos)")")
    }
    
    func addEnrollmentImage(_ image: UIImage) {
        enrollmentImages.append(image)
        enrollmentProgress = Float(enrollmentImages.count) / 50.0
        statusMessage = "📸 Captured \(enrollmentImages.count)/50 enrollment photos"
        
        print("📸 [ENROLL] Progress: \(enrollmentImages.count)/50")
        
        if enrollmentImages.count >= 50 {
            enrollCamera()
        }
    }
    
    private func enrollCamera() {
        isProcessing = true
        statusMessage = "⏳ Enrolling camera (this may take a minute)..."
        
        print("⏳ [ENROLL] Starting enrollment with 50 images...")
        
        prnu.enrollCamera(withID: cameraID, images: enrollmentImages) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let fingerprint):
                    print("✅ [ENROLL] Success!")
                    print("   - Average PCE: \(fingerprint.averagePCE)")
                    print("   - PRNU now available!")
                    
                    self?.isEnrolled = true
                    self?.enrollmentImages = []
                    self?.enrollmentProgress = 0
                    self?.statusMessage = "✅ Camera enrolled! PRNU authentication now available"
                    
                case .failure(let error):
                    print("❌ [ENROLL] Failed: \(error.localizedDescription)")
                    self?.statusMessage = "❌ Enrollment failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func resetEnrollment() {
        do {
            try prnu.deleteFingerprint(cameraID: cameraID)
            isEnrolled = false
            enrollmentImages = []
            enrollmentProgress = 0
            statusMessage = "🔄 Enrollment reset - PRNU locked until re-enrollment"
            
            print("🔄 [ENROLL] Reset complete")
        } catch {
            statusMessage = "❌ Failed to reset: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Authentication
    
    func authenticateImage(_ image: UIImage) {
        print("🔍 [AUTH] Starting authentication...")
        print("🔍 [AUTH] Method: \(selectedMethod == .aiDetection ? "AI Detection" : "PRNU")")
        
        switch selectedMethod {
        case .aiDetection:
            runAIDetection(image)
            
        case .prnuCamera:
            // ENFORCE ENROLLMENT FOR PRNU
            guard isEnrolled else {
                print("❌ [AUTH] PRNU blocked - Not enrolled!")
                DispatchQueue.main.async {
                    self.showEnrollmentRequired = true
                    self.statusMessage = "⚠️ PRNU requires enrollment - Please enroll with 50 photos first"
                }
                return
            }
            runPRNUAuthentication(image)
        }
    }
    
    // MARK: - AI Detection
    
    private func runAIDetection(_ image: UIImage) {
        print("🤖 [AI] Starting AI detection...")
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.statusMessage = "🤖 Analyzing with AI model..."
            self.currentResult = nil
        }
        
        Task {
            let aiResult = await aiDetector.detectAIImage(image)
            
            print("🤖 [AI] ✅ Complete!")
            print("   - AI Generated: \(aiResult.isAIGenerated)")
            print("   - Confidence: \(aiResult.confidencePercentage)")
            
            let authResult = convertAIToAuthResult(aiResult)
            
            await MainActor.run {
                self.currentResult = authResult
                self.lastResult = authResult
                self.isProcessing = false
                self.updateStatusForAI(aiResult)
            }
        }
    }
    
    // MARK: - PRNU Authentication
    
    private func runPRNUAuthentication(_ image: UIImage) {
        print("📸 [PRNU] Starting PRNU authentication...")
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.statusMessage = "📸 Analyzing with PRNU..."
            self.currentResult = nil
        }
        
        prnu.authenticateImage(image, cameraID: cameraID) { [weak self] result in
            DispatchQueue.main.async {
                defer { self?.isProcessing = false }
                
                switch result {
                case .success(let authResult):
                    print("📸 [PRNU] ✅ Complete!")
                    print("   - Authentic: \(authResult.isAuthentic)")
                    print("   - PCE Score: \(authResult.pceScore)")
                    
                    self?.currentResult = authResult
                    self?.lastResult = authResult
                    self?.updateStatusForPRNU(authResult)
                    
                case .failure(let error):
                    print("📸 [PRNU] ❌ Error: \(error.localizedDescription)")
                    self?.statusMessage = "❌ PRNU failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Tamper Detection (PRNU only)
    
    func detectTampering(_ image: UIImage, completion: @escaping (TamperDetectionResult?) -> Void) {
        guard isEnrolled else {
            statusMessage = "⚠️ Tamper detection requires PRNU enrollment"
            showEnrollmentRequired = true
            completion(nil)
            return
        }
        
        isProcessing = true
        statusMessage = "🔍 Detecting tampering..."
        
        prnu.detectTampering(in: image, cameraID: cameraID) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let tamperResult):
                    if tamperResult.isTampered {
                        self?.statusMessage = "⚠️ TAMPERING DETECTED! \(tamperResult.tamperedRegions.count) regions affected"
                    } else {
                        self?.statusMessage = "✅ No tampering detected"
                    }
                    completion(tamperResult)
                    
                case .failure(let error):
                    self?.statusMessage = "❌ Detection failed: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertAIToAuthResult(_ aiResult: AIDetectionResult) -> AuthenticationResult {
        let isAuthentic = !aiResult.isAIGenerated
        let score = aiResult.confidence * 100
        
        return AuthenticationResult(
            isAuthentic: isAuthentic,
            pceScore: score,
            confidence: score,
            cameraID: "AI_Detection",
            timestamp: Date(),
            additionalInfo: [
                "method": "AI Detection",
                "model": "deepfake-detector-model-v1",
                "processingTime": aiResult.processingTime
            ]
        )
    }
    
    private func updateStatusForAI(_ result: AIDetectionResult) {
        if result.isAIGenerated {
            statusMessage = "⚠️ AI-GENERATED IMAGE (\(result.confidencePercentage))"
        } else {
            statusMessage = "✅ REAL PHOTO (\(result.confidencePercentage))"
        }
    }
    
    private func updateStatusForPRNU(_ result: AuthenticationResult) {
        let pceString = String(format: "%.2f", result.pceScore)
        
        if result.isAuthentic {
            statusMessage = "✅ AUTHENTIC - From this camera (PCE: \(pceString))"
        } else {
            statusMessage = "❌ NOT AUTHENTIC - Different camera or edited (PCE: \(pceString))"
        }
    }
    
    func getEnrollmentInfo() -> String {
        if isEnrolled {
            return "✅ Enrolled - Both AI and PRNU available"
        } else {
            let remaining = 50 - enrollmentImages.count
            return "AI available now | PRNU needs \(remaining) more photos"
        }
    }
    
    // MARK: - Method Selection
    
    func canUsePRNU() -> Bool {
        return isEnrolled
    }
    
    func switchToAI() {
        selectedMethod = .aiDetection
        statusMessage = "🤖 Using AI Detection"
    }
    
    func switchToPRNU() {
        if isEnrolled {
            selectedMethod = .prnuCamera
            statusMessage = "📸 Using PRNU Authentication"
        } else {
            showEnrollmentRequired = true
            statusMessage = "⚠️ PRNU requires enrollment first"
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════
 🎯 HOW THIS COMBO VERSION WORKS
 ═══════════════════════════════════════════════════════════════
 
 TWO DETECTION METHODS:
 
 1. AI DETECTION (Always Available) ✅
    - No enrollment needed
    - Detects AI-generated images
    - Fast: ~200-500ms
    - Use: authenticator.selectedMethod = .aiDetection
 
 2. PRNU AUTHENTICATION (Locked Until Enrolled) 🔒
    - REQUIRES 50 photos enrollment
    - Verifies image from YOUR camera
    - Slower: ~2-5 seconds
    - Use: authenticator.selectedMethod = .prnuCamera
 
 ═══════════════════════════════════════════════════════════════
 🔒 ENROLLMENT ENFORCEMENT
 ═══════════════════════════════════════════════════════════════
 
 When user tries to use PRNU without enrollment:
 
 🔍 [AUTH] Method: PRNU
 ❌ [AUTH] PRNU blocked - Not enrolled!
 ⚠️ Shows: "PRNU requires enrollment - Please enroll first"
 ⚠️ Sets: showEnrollmentRequired = true
 
 This triggers your UI to show enrollment screen!
 
 ═══════════════════════════════════════════════════════════════
 📱 UI INTEGRATION EXAMPLE
 ═══════════════════════════════════════════════════════════════
 
 In your ContentView:
 
 // Method picker
 Picker("Method", selection: $authenticator.selectedMethod) {
     Text("AI Detection").tag(DetectionMethod.aiDetection)
     Text("PRNU Camera").tag(DetectionMethod.prnuCamera)
         .disabled(!authenticator.isEnrolled)  // Disabled until enrolled
 }
 
 // Show enrollment alert
 .alert("Enrollment Required", isPresented: $authenticator.showEnrollmentRequired) {
     Button("Enroll Now") {
         // Navigate to enrollment screen
     }
     Button("Cancel", role: .cancel) { }
 } message: {
     Text("PRNU requires 50 photos. Would you like to enroll now?")
 }
 
 ═══════════════════════════════════════════════════════════════
 */

// MARK: - Authentication Result Extension

extension AuthenticationResult {
    var resultColor: Color {
        if isAuthentic {
            return confidence > 90 ? .green : .blue
        } else {
            return confidence > 90 ? .red : .orange
        }
    }
    
    var resultIcon: String {
        if isAuthentic {
            return "checkmark.shield.fill"
        } else {
            return cameraID == "AI_Detection" ? "sparkles" : "xmark.shield.fill"
        }
    }
    
    var methodBadge: String {
        cameraID == "AI_Detection" ? "🤖 AI" : "📸 PRNU"
    }
}
