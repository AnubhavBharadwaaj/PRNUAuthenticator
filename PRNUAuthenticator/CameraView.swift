//
//  CameraView.swift
//  PRNUAuthenticator
//
//  Created by Anubhav Anubhav on 26/01/26.
//

//
//  CameraView.swift
//  PRNUAuthenticator
//
//  Camera interface for capturing and authenticating images
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var authenticator = PRNUAuthenticationManager()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()
            
            VStack {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    Text("PRNU Camera")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    
                    Spacer()
                    
                    Button(action: { camera.switchCamera() }) {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
                
                // Processing Indicator
                if authenticator.isProcessing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text(authenticator.statusMessage.isEmpty ? "Analyzing Image..." : authenticator.statusMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        // Emergency cancel button
                        Button("Cancel") {
                            authenticator.isProcessing = false
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .padding(30)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
                }
                // Show result if available
                if !authenticator.isProcessing, let result = authenticator.currentResult {
                    VStack(spacing: 15) {
                        Image(systemName: result.isAuthentic ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .font(.system(size: 50))
                            .foregroundColor(result.isAuthentic ? .green : .red)
                        
                        Text(result.isAuthentic ? "AUTHENTIC" : "NOT AUTHENTIC")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("PCE Score: \(String(format: "%.2f", result.pceScore))")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding(30)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
                }

                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 40) {
                    // Photo Library Button
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .disabled(authenticator.isProcessing)
                    
                    // Capture Button
                    Button(action: capturePhoto) {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    .disabled(isProcessing)
                    
                    // Settings Button
                    Button(action: {}) {
                        Image(systemName: "gear")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { @MainActor in
                    authenticateImage(image)
                }
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
    }
    
    private func capturePhoto() {
        isProcessing = true
        
        camera.capturePhoto { image in
            if let capturedImage = image {
                // Use Task to avoid publishing warnings
                Task { @MainActor in
                    authenticateImage(capturedImage)
                }

            } else {
                isProcessing = false
                print("❌ Failed to capture photo")
            }
        }
    }
    
//    private func authenticateImage(_ image: UIImage) {
//        isProcessing = true
//        
//        authenticator.authenticateImage(image) { result in
//            switch result {
//            case .success(let authResult):
//                DispatchQueue.main.async {
//                    self.isProcessing = false
//                    print("✅ Authentication complete")
//                    print("PCE Score: \(authResult.pceScore)")
//                    print("Is Authentic: \(authResult.isAuthentic)")
//                    // Result will be shown in ResultView
//                }
//            case .failure(let error):
//                DispatchQueue.main.async {
//                    self.isProcessing = false
//                    print("❌ Authentication failed: \(error)")
//                }
//            }
//        }
//    }
//
    @MainActor
    private func authenticateImage(_ image: UIImage) {
        print("📸 Starting authentication...")
        
        // Clear previous result
        authenticator.currentResult = nil
        
        // Start authentication
        authenticator.authenticateImage(image)
        
        // Safety timeout - force reset after 30 seconds if still processing
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if authenticator.isProcessing {
                print("⚠️ Authentication timeout - forcing reset")
                authenticator.isProcessing = false
                authenticator.statusMessage = "❌ Authentication timed out"
            }
        }
    }
}


// MARK: - Camera Manager


// MARK: - Image Picker


#Preview {
    CameraView()
}
