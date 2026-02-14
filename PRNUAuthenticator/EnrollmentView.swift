//
//  EnrollmentView.swift
//  PRNUAuthenticator
//
//  Enrollment flow for PRNU - Capture 50 photos
//

import SwiftUI
import AVFoundation

struct EnrollmentView: View {
    @StateObject private var camera = CameraManager()
    @ObservedObject var authenticator: PRNUAuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var capturedCount = 0
    @State private var showInstructions = true
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()
            
            // Dark overlay when showing instructions
            if showInstructions {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
            }
            
            VStack {
                // Top Info Bar
                VStack(spacing: 10) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 50)
                    
                    // Progress
                    VStack(spacing: 5) {
                        Text("\(capturedCount)/50")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Photos Captured")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        ProgressView(value: Double(capturedCount), total: 50)
                            .tint(.green)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .padding(.horizontal, 40)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Instructions Overlay
                if showInstructions {
                    instructionsOverlay
                } else if authenticator.isProcessing {
                    processingOverlay
                }
                
                Spacer()
                
                // Capture Button
                if !showInstructions && !authenticator.isProcessing {
                    captureButton
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            camera.checkPermissions()
            capturedCount = authenticator.enrollmentProgress > 0
                ? Int(authenticator.enrollmentProgress * 50)
                : 0
        }
    }
    
    // MARK: - UI Components
    
    private var instructionsOverlay: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("PRNU Enrollment")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                InstructionRow(icon: "camera.viewfinder", text: "Capture 50 different photos")
                InstructionRow(icon: "photo.on.rectangle", text: "Use various lighting conditions")
                InstructionRow(icon: "square.grid.2x2", text: "Include different subjects")
                InstructionRow(icon: "timer", text: "Takes about 2-3 minutes")
            }
            .padding()
            
            Text("This creates a unique fingerprint of your camera's sensor for authentication")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showInstructions = false }) {
                Text("Start Enrollment")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemBackground))
        )
        .padding(30)
    }
    
    private var processingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Enrolling Camera...")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Analyzing 50 photos to create fingerprint")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            Text("This may take 1-2 minutes")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
        )
    }
    
    private var captureButton: some View {
        Button(action: capturePhoto) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 5)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(capturedCount < 50 ? Color.white : Color.green)
                    .frame(width: 68, height: 68)
                
                if capturedCount >= 50 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(authenticator.isProcessing)
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        camera.capturePhoto { [weak authenticator] image in
            guard let image = image, let authenticator = authenticator else { return }
            
            // Add to enrollment
            authenticator.addEnrollmentImage(image)
            
            // Update UI
            DispatchQueue.main.async {
                capturedCount += 1
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // Check if done
                if capturedCount >= 50 {
                    // Enrollment will start automatically in manager
                    print("✅ All 50 photos captured! Starting enrollment...")
                }
            }
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Success View (shown after enrollment)

struct EnrollmentSuccessView: View {
    @Environment(\.dismiss) var dismiss
    let fingerprint: CameraFingerprint
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Enrollment Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                InfoRow(label: "Camera ID", value: fingerprint.cameraID)
                InfoRow(label: "Photos Used", value: "\(fingerprint.numberOfImages)")
                InfoRow(label: "Average PCE", value: String(format: "%.2f", fingerprint.averagePCE))
                InfoRow(label: "Fingerprint Size", value: "\(fingerprint.sizeInBytes / 1024) KB")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemGray6))
            )
            
            Text("PRNU authentication is now available!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
        }
        .padding(40)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Camera Manager (same as CameraView)


// MARK: - Preview Camera View (reuse from CameraView)


#Preview {
    EnrollmentView(authenticator: PRNUAuthenticationManager())
}
