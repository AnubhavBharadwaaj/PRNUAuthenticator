//
//  CameraPreviewView.swift
//  PRNUAuthenticator
//
//  Created by Anubhav Anubhav on 04/02/26.
//


//
//  CameraPreviewView.swift
//  PRNUAuthenticator
//
//  Reusable Camera Preview Component
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview?.videoGravity = .resizeAspectFill
        camera.preview?.frame = view.bounds
        
        if let preview = camera.preview {
            view.layer.addSublayer(preview)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            camera.preview?.frame = uiView.bounds
        }
    }
}