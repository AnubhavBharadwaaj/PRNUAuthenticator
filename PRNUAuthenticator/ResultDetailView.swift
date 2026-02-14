//
//  ResultDetailView.swift
//  PRNUAuthenticator
//
//  Created by Anubhav Anubhav on 26/01/26.
//

//
//  ResultDetailView.swift
//  PRNUAuthenticator
//
//  Detailed authentication result display
//

import SwiftUI

struct ResultDetailView: View {
    let result: AuthenticationResult
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Result Icon
                    Image(systemName: result.resultIcon)
                        .font(.system(size: 80))
                        .foregroundColor(result.resultColor)
                        .padding(.top, 40)
                    
                    // Main Status
                    Text(result.isAuthentic ? "AUTHENTIC" : "NOT AUTHENTIC")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(result.resultColor)
                    
                    Text(result.isAuthentic ? "Image verified as authentic" : "Image may be tampered or from different camera")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Metrics Cards
                    VStack(spacing: 15) {
                        MetricCard(
                            title: "PCE Score",
                            value: String(format: "%.2f", result.pceScore),
                            subtitle: "Peak Correlation Energy",
                            color: result.resultColor
                        )
                        
                        MetricCard(
                            title: "Confidence",
                            value: String(format: "%.1f%%", result.confidence),
                            subtitle: "Match Confidence Level",
                            color: result.resultColor
                        )
                        
                        MetricCard(
                            title: "Quality",
                            value: result.qualityLevel.rawValue,
                            subtitle: "Authentication Quality",
                            color: result.resultColor
                        )
                    }
                    .padding(.horizontal)
                    
                    // Detailed Info
                    DetailedInfoSection(result: result)
                    
                    // Interpretation Guide
                    InterpretationGuide(result: result)
                    
                    Spacer()
                }
            }
            .navigationTitle("Authentication Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: getIconForMetric(title))
                        .foregroundColor(color)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private func getIconForMetric(_ title: String) -> String {
        switch title {
        case "PCE Score":
            return "waveform.path.ecg"
        case "Confidence":
            return "percent"
        case "Quality":
            return "star.fill"
        default:
            return "info.circle"
        }
    }
}

// MARK: - Detailed Info Section

struct DetailedInfoSection: View {
    let result: AuthenticationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                DetailRow(label: "Camera ID", value: result.cameraID)
                Divider()
                DetailRow(label: "Timestamp", value: formatDate(result.timestamp))
                Divider()
                DetailRow(label: "Status", value: result.isAuthentic ? "Verified" : "Suspicious")
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(radius: 2)
            )
            .padding(.horizontal)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
    }
}

// MARK: - Interpretation Guide

struct InterpretationGuide: View {
    let result: AuthenticationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("What Does This Mean?")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                if result.isAuthentic {
                    InterpretationRow(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        title: "Authentic Image",
                        description: "This image was captured by the enrolled camera and shows no signs of tampering."
                    )
                    
                    if result.pceScore > 70 {
                        InterpretationRow(
                            icon: "star.fill",
                            color: .blue,
                            title: "High Confidence",
                            description: "The PRNU pattern strongly matches the enrolled camera fingerprint."
                        )
                    }
                } else {
                    InterpretationRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "Verification Failed",
                        description: "This image may have been edited, captured by a different camera, or heavily compressed."
                    )
                    
                    InterpretationRow(
                        icon: "info.circle.fill",
                        color: .blue,
                        title: "Possible Reasons",
                        description: "• Image from different camera\n• Heavy JPEG compression\n• Digital manipulation\n• Screenshot or edited photo"
                    )
                }
                
                InterpretationRow(
                    icon: "questionmark.circle.fill",
                    color: .purple,
                    title: "PCE Score: \(String(format: "%.1f", result.pceScore))",
                    description: getPCEInterpretation(result.pceScore)
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(radius: 2)
            )
            .padding(.horizontal)
        }
        .padding(.bottom, 30)
    }
    
    private func getPCEInterpretation(_ score: Float) -> String {
        switch score {
        case 80...:
            return "Excellent match - Very high confidence in authenticity"
        case 60..<80:
            return "Good match - High confidence in authenticity"
        case 40..<60:
            return "Fair match - Medium confidence, manual review recommended"
        default:
            return "Poor match - Low confidence, likely not authentic"
        }
    }
}

struct InterpretationRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ResultDetailView(result: AuthenticationResult(
        isAuthentic: true,
        pceScore: 75.5,
        confidence: 92.3,
        cameraID: "MainDevice_Camera",
        timestamp: Date(),
        additionalInfo: [:]
    ))
}
