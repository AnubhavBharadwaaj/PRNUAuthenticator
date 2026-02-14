//
//  ContentView.swift
//  PRNUAuthenticator
//
//  UPDATED - With AI/PRNU selection and enrollment flow
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var showCamera = false
    @State private var showEnrollment = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Authentication Home
            NavigationStack {
                AuthenticationHomeView(
                    showCamera: $showCamera,
                    showEnrollment: $showEnrollment
                )
            }
            .tabItem {
                Label("Authenticate", systemImage: "checkmark.shield.fill")
            }
            .tag(0)
            
            // Tab 2: History
            NavigationStack {
                HistoryView(items: items,
                           deleteItems: deleteItems,
                           addItem: addItem)
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
            .tag(1)
            
            // Tab 3: Settings
            NavigationStack {
                SettingsView(showEnrollment: $showEnrollment)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView()
        }
        .fullScreenCover(isPresented: $showEnrollment) {
            EnrollmentView(authenticator: PRNUAuthenticationManager())
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// MARK: - Authentication Home View

struct AuthenticationHomeView: View {
    @Binding var showCamera: Bool
    @Binding var showEnrollment: Bool
    @StateObject private var authenticator = PRNUAuthenticationManager()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Method Selection
                    methodSelectionSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Status Info
                    statusSection
                    
                    // Info Card
                    infoCard
                    
                    Spacer(minLength: 50)
                }
                .padding(.top, 50)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { @MainActor in
                    authenticator.authenticateImage(image)
                }
            }
        }
        .alert("Enrollment Required", isPresented: $authenticator.showEnrollmentRequired) {
            Button("Enroll Now") {
                showEnrollment = true
            }
            Button("Cancel", role: .cancel) {
                authenticator.selectedMethod = .aiDetection
            }
        } message: {
            Text("PRNU authentication requires enrolling your camera with 50 photos. This creates a unique fingerprint for authentication.\n\nWould you like to enroll now?")
        }
    }
    
    // MARK: - UI Sections
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Image Authenticator")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(authenticator.statusMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var methodSelectionSection: some View {
        VStack(spacing: 15) {
            Text("Detection Method")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 15) {
                // AI Detection Button
                MethodButton(
                    icon: "sparkles",
                    title: "AI Detection",
                    subtitle: "Always Available",
                    isSelected: authenticator.selectedMethod == .aiDetection,
                    isEnabled: true
                ) {
                    authenticator.switchToAI()
                }
                
                // PRNU Button (locked if not enrolled)
                MethodButton(
                    icon: "camera.fill",
                    title: "PRNU Camera",
                    subtitle: authenticator.isEnrolled ? "Enrolled ✓" : "Needs Enrollment",
                    isSelected: authenticator.selectedMethod == .prnuCamera,
                    isEnabled: authenticator.isEnrolled
                ) {
                    authenticator.switchToPRNU()
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 15) {
            // Capture Button
            Button(action: { showCamera = true }) {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                    Text("Capture & Authenticate")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.blue)
                .cornerRadius(15)
                .shadow(radius: 5)
            }
            
            // Library Button
            Button(action: { showImagePicker = true }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("Select from Library")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.purple)
                .cornerRadius(15)
                .shadow(radius: 5)
            }
            
            // Enrollment Button (if not enrolled)
            if !authenticator.isEnrolled {
                Button(action: { showEnrollment = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Enroll Camera for PRNU")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.orange)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    private var statusSection: some View {
        VStack(spacing: 10) {
            HStack {
                StatusBadge(
                    icon: "sparkles",
                    title: "AI Detection",
                    status: "Ready",
                    color: .green
                )
                
                StatusBadge(
                    icon: "camera.fill",
                    title: "PRNU",
                    status: authenticator.isEnrolled ? "Enrolled" : "Locked",
                    color: authenticator.isEnrolled ? .green : .orange
                )
            }
            .padding(.horizontal, 30)
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("About Detection Methods")
                .font(.headline)
                .foregroundColor(.primary)
            
            DetectionMethodInfo(
                icon: "sparkles",
                color: .blue,
                title: "AI Detection",
                description: "Detects AI-generated images from Midjourney, DALL-E, Stable Diffusion, and deepfakes. Works immediately, no setup required.",
                features: ["No enrollment", "Fast analysis", "94.4% accuracy"]
            )
            
            Divider()
            
            DetectionMethodInfo(
                icon: "camera.fill",
                color: .purple,
                title: "PRNU Authentication",
                description: "Verifies images came from YOUR specific camera. Detects editing and tampering. Requires one-time enrollment.",
                features: ["50 photos needed", "Device-specific", "Tamper detection"]
            )
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal, 30)
    }
}

// MARK: - Method Button

struct MethodButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : (isEnabled ? .white.opacity(0.7) : .gray))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : (isEnabled ? .white : .gray))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : (isEnabled ? .white.opacity(0.7) : .gray.opacity(0.7)))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isEnabled ? Color.white : Color.gray, lineWidth: 2)
                    )
            )
        }
        .disabled(!isEnabled)
        .overlay(
            !isEnabled ?
                VStack {
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                }
                .padding(8)
            : nil
        )
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let icon: String
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(status)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Detection Method Info

struct DetectionMethodInfo: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(features, id: \.self) { feature in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(feature)
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    let items: [Item]
    let deleteItems: (IndexSet) -> Void
    let addItem: () -> Void
    
    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Authentication")
                                .font(.headline)
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var showEnrollment: Bool
    @StateObject private var authenticator = PRNUAuthenticationManager()
    
    var body: some View {
        Form {
            Section(header: Text("Detection Methods")) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("AI Detection")
                    Spacer()
                    Text("Always Available")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.purple)
                    Text("PRNU Camera")
                    Spacer()
                    Text(authenticator.isEnrolled ? "Enrolled ✓" : "Not Enrolled")
                        .foregroundColor(authenticator.isEnrolled ? .green : .orange)
                        .font(.caption)
                }
            }
            
            Section(header: Text("PRNU Enrollment")) {
                if authenticator.isEnrolled {
                    Button("View Enrollment Info") {
                        // Show enrollment details
                    }
                    
                    Button("Reset Enrollment", role: .destructive) {
                        authenticator.resetEnrollment()
                    }
                } else {
                    Button("Enroll Camera") {
                        showEnrollment = true
                    }
                    .foregroundColor(.blue)
                    
                    Text("Enroll your camera with 50 photos to enable PRNU authentication")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("About")) {
                NavigationLink("About AI Detection") {
                    AboutAIView()
                }
                NavigationLink("About PRNU") {
                    AboutPRNUView()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - About Views

struct AboutAIView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("AI Detection")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Uses a deep learning model to detect AI-generated and deepfake images.")
                
                Text("Detects:")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 5) {
                    Text("• Midjourney images")
                    Text("• DALL-E images")
                    Text("• Stable Diffusion images")
                    Text("• Deepfake faces")
                    Text("• AI-manipulated content")
                }
                
                Text("Model: deepfake-detector-model-v1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Accuracy: 94.4%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("AI Detection")
    }
}

struct AboutPRNUView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("PRNU Authentication")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Photo Response Non-Uniformity (PRNU) is like a fingerprint for your camera sensor.")
                
                Text("How it works:")
                    .font(.headline)
                Text("Your camera sensor has unique imperfections that leave a pattern in every photo. PRNU extracts and analyzes this pattern.")
                
                Text("Use cases:")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 5) {
                    Text("• Verify image source")
                    Text("• Detect tampering")
                    Text("• Forensic analysis")
                    Text("• Device authentication")
                }
            }
            .padding()
        }
        .navigationTitle("PRNU")
    }
}

// MARK: - Image Picker (from CameraView)


#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
