//
//  MainView.swift
//  PRNUAuthenticator
//
//  Created by Anubhav Anubhav on 26/01/26.
//

//
//  MainView.swift
//  PRNUAuthenticator
//
//  Main dashboard for PRNU camera app
//

import SwiftUI

struct MainView: View {
    @StateObject private var authenticator = PRNUAuthenticationManager()
    @State private var showCamera = false
    @State private var showEnrollment = false
    @State private var showResults = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "camera.metering.matrix")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("PRNU Authenticator")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Camera Fingerprint Authentication")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Status Card
                        StatusCard(authenticator: authenticator)
                        
                        // Action Buttons
                        VStack(spacing: 15) {
                            if authenticator.isEnrolled {
                                // Camera Button
                                ActionButton(
                                    title: "Capture & Authenticate",
                                    icon: "camera.fill",
                                    color: .blue
                                ) {
                                    showCamera = true
                                }
                                
                                // Results Button
                                if authenticator.lastResult != nil {
                                    ActionButton(
                                        title: "View Last Result",
                                        icon: "doc.text.magnifyingglass",
                                        color: .green
                                    ) {
                                        showResults = true
                                    }
                                }
                                
                                // Reset Button
                                ActionButton(
                                    title: "Reset Enrollment",
                                    icon: "arrow.clockwise",
                                    color: .orange
                                ) {
                                    authenticator.resetEnrollment()
                                }
                                
                            } else {
                                // Enrollment Button
                                ActionButton(
                                    title: "Enroll Camera",
                                    icon: "person.badge.plus",
                                    color: .green
                                ) {
                                    showEnrollment = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Info Section
                        InfoSection()
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
                    .environmentObject(authenticator)
            }
            .sheet(isPresented: $showEnrollment) {
                EnrollmentView(authenticator: authenticator)
                    .environmentObject(authenticator)
            }
            .sheet(isPresented: $showResults) {
                if let result = authenticator.lastResult {
                    ResultDetailView(result: result)
                }
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    @ObservedObject var authenticator: PRNUAuthenticationManager
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: authenticator.isEnrolled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(authenticator.isEnrolled ? .green : .orange)
                
                Text(authenticator.isEnrolled ? "Enrolled" : "Not Enrolled")
                    .font(.headline)
                
                Spacer()
            }
            
            if authenticator.isEnrolled {
                ProgressView(value: 1.0)
                    .tint(.green)
            } else {
                ProgressView(value: authenticator.enrollmentProgress)
                    .tint(.blue)
                
                Text(authenticator.getEnrollmentInfo())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Text(authenticator.statusMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
            )
        }
    }
}

// MARK: - Info Section

struct InfoIconRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}


struct InfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("How It Works")
                .font(.headline)
            
            InfoIconRow(icon: "1.circle.fill", text: "Enroll your camera by taking 50 photos")
            InfoIconRow(icon: "2.circle.fill", text: "Capture photos to authenticate")
            InfoIconRow(icon: "3.circle.fill", text: "System detects tampering automatically")
            
            Divider()
                .padding(.vertical, 5)
            
            Text("What is PRNU?")
                .font(.headline)
            
            Text("Photo Response Non-Uniformity (PRNU) is a unique noise pattern in every camera sensor. Like a fingerprint, it helps identify if a photo was taken by a specific camera and detect tampering.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 5)
        )
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}


#Preview {
    MainView()
}
