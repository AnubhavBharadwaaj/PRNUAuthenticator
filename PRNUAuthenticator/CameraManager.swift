//
//  CameraManager.swift
//  PRNUAuthenticator
//
//  Created by Anubhav Anubhav on 04/02/26.
//

//
//  CameraManager.swift
//  PRNUAuthenticator
//
//  Reusable Camera Manager Component
//

import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isCameraAuthorized = false
    
    private var output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var photoCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        // Input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            currentDevice = device
        }
        
        // Output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        // Remove current input
        session.inputs.forEach { session.removeInput($0) }
        
        // Switch position
        let newPosition: AVCaptureDevice.Position = currentDevice?.position == .back ? .front : .back
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            currentDevice = device
        }
        
        session.commitConfiguration()
    }
    
    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCompletion?(nil)
            return
        }
        
        photoCompletion?(image)
    }
}
