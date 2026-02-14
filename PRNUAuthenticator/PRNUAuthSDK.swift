// PRNU Authentication SDK for iOS
// Complete Implementation in a Single File
// Version 1.0.0
// MIT License

import UIKit
import Accelerate
import Foundation
import Security

// MARK: - Configuration

/// Configuration options for PRNU authentication
public struct PRNUConfig {
    
    public var enrollmentImageCount: Int
    public var pceThreshold: Float
    public var imageSize: CGSize
    public var useWienerFilter: Bool
    public var enableGammaCorrection: Bool
    public var gamma: Float
    public var enableSecureStorage: Bool
    public var maxConcurrentOperations: Int
    public var enableParallelProcessing: Bool
    
    /// Default configuration
    public static let `default` = PRNUConfig(
        enrollmentImageCount: 50,
        pceThreshold: 60.0,
        imageSize: CGSize(width: 512, height: 512),
        useWienerFilter: true,
        enableGammaCorrection: false,
        gamma: 2.2,
        enableSecureStorage: true,
        maxConcurrentOperations: 4,
        enableParallelProcessing: true
    )
    
    /// Fast configuration (lower quality, faster processing)
    public static let fast = PRNUConfig(
        enrollmentImageCount: 30,
        pceThreshold: 50.0,
        imageSize: CGSize(width: 256, height: 256),
        useWienerFilter: false,
        enableGammaCorrection: false,
        gamma: 2.2,
        enableSecureStorage: true,
        maxConcurrentOperations: 8,
        enableParallelProcessing: true
    )
    
    /// High accuracy configuration
    public static let highAccuracy = PRNUConfig(
        enrollmentImageCount: 100,
        pceThreshold: 70.0,
        imageSize: CGSize(width: 1024, height: 1024),
        useWienerFilter: true,
        enableGammaCorrection: true,
        gamma: 2.2,
        enableSecureStorage: true,
        maxConcurrentOperations: 2,
        enableParallelProcessing: true
    )
    
    public init(
        enrollmentImageCount: Int = 50,
        pceThreshold: Float = 60.0,
        imageSize: CGSize = CGSize(width: 512, height: 512),
        useWienerFilter: Bool = true,
        enableGammaCorrection: Bool = false,
        gamma: Float = 2.2,
        enableSecureStorage: Bool = true,
        maxConcurrentOperations: Int = 4,
        enableParallelProcessing: Bool = true
    ) {
        self.enrollmentImageCount = enrollmentImageCount
        self.pceThreshold = pceThreshold
        self.imageSize = imageSize
        self.useWienerFilter = useWienerFilter
        self.enableGammaCorrection = enableGammaCorrection
        self.gamma = gamma
        self.enableSecureStorage = enableSecureStorage
        self.maxConcurrentOperations = maxConcurrentOperations
        self.enableParallelProcessing = enableParallelProcessing
    }
    
    var processingWidth: Int { Int(imageSize.width) }
    var processingHeight: Int { Int(imageSize.height) }
}

// MARK: - Errors

public enum PRNUError: LocalizedError {
    case insufficientImages(required: Int, provided: Int)
    case imageProcessingFailed(String)
    case fingerprintNotFound(String)
    case dimensionMismatch
    case storageError(String)
    case processingError(String)
    case invalidConfiguration(String)
    case enrollmentFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .insufficientImages(let required, let provided):
            return "Insufficient images. Required: \(required), Provided: \(provided)"
        case .imageProcessingFailed(let msg):
            return "Image processing failed: \(msg)"
        case .fingerprintNotFound(let id):
            return "Fingerprint not found: \(id)"
        case .dimensionMismatch:
            return "Dimension mismatch"
        case .storageError(let msg):
            return "Storage error: \(msg)"
        case .processingError(let msg):
            return "Processing error: \(msg)"
        case .invalidConfiguration(let msg):
            return "Invalid config: \(msg)"
        case .enrollmentFailed(let msg):
            return "Enrollment failed: \(msg)"
        }
    }
}

// MARK: - Models

public struct CameraFingerprint: Codable {
    public let cameraID: String
    public let fingerprint: [Float]
    public let width: Int
    public let height: Int
    public let enrollmentDate: Date
    public let numberOfImages: Int
    public let averagePCE: Float
    public let sdkVersion: String
    
    public init(
        cameraID: String,
        fingerprint: [Float],
        width: Int,
        height: Int,
        enrollmentDate: Date,
        numberOfImages: Int,
        averagePCE: Float,
        sdkVersion: String = "1.0.0"
    ) {
        self.cameraID = cameraID
        self.fingerprint = fingerprint
        self.width = width
        self.height = height
        self.enrollmentDate = enrollmentDate
        self.numberOfImages = numberOfImages
        self.averagePCE = averagePCE
        self.sdkVersion = sdkVersion
    }
    
    public var sizeInBytes: Int {
        fingerprint.count * MemoryLayout<Float>.size
    }
}

public struct AuthenticationResult {
    public let isAuthentic: Bool
    public let pceScore: Float
    public let confidence: Float
    public let cameraID: String
    public let timestamp: Date
    public let additionalInfo: [String: Any]
    
    public init(
        isAuthentic: Bool,
        pceScore: Float,
        confidence: Float,
        cameraID: String,
        timestamp: Date,
        additionalInfo: [String: Any] = [:]
    ) {
        self.isAuthentic = isAuthentic
        self.pceScore = pceScore
        self.confidence = confidence
        self.cameraID = cameraID
        self.timestamp = timestamp
        self.additionalInfo = additionalInfo
    }
    
    public var qualityLevel: QualityLevel {
        switch pceScore {
        case 80...: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .poor
        }
    }
    
    public enum QualityLevel: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
    }
}

public struct TamperDetectionResult {
    public let isTampered: Bool
    public let tamperedRegions: [CGRect]
    public let overallPCE: Float
    public let confidence: Float
    private let totalBlocks: Int
    
    public var severityLevel: SeverityLevel {
        if !isTampered { return .none }
        let percentage = Float(tamperedRegions.count) / Float(max(1, totalBlocks))
        switch percentage {
        case 0.5...: return .severe
        case 0.2..<0.5: return .moderate
        case 0.05..<0.2: return .minor
        default: return .minimal
        }
    }
    
    public init(
        isTampered: Bool,
        tamperedRegions: [CGRect],
        overallPCE: Float,
        confidence: Float,
        totalBlocks: Int = 100
    ) {
        self.isTampered = isTampered
        self.tamperedRegions = tamperedRegions
        self.overallPCE = overallPCE
        self.confidence = confidence
        self.totalBlocks = totalBlocks
    }
    
    public enum SeverityLevel: String {
        case none, minimal, minor, moderate, severe
    }
}

// MARK: - PRNU Extractor

public class PRNUExtractor {
    
    private let config: PRNUConfig
    private let wienerFilter: WienerFilter
    
    init(config: PRNUConfig) {
        self.config = config
        self.wienerFilter = WienerFilter()
    }
    
    /// Extract noise residual: W = I - F(I)
    public func extractNoiseResidual(from image: UIImage) throws -> [Float] {
        let preprocessed = try preprocessImage(image)
        
        let denoised = config.useWienerFilter
            ? wienerFilter.denoise(preprocessed, width: config.processingWidth, height: config.processingHeight)
            : applyFastDenoisingFilter(preprocessed)
        
        var residual = [Float](repeating: 0, count: preprocessed.count)
        vDSP_vsub(denoised, 1, preprocessed, 1, &residual, 1, vDSP_Length(preprocessed.count))
        
        return residual
    }
    
    /// Preprocess image for PRNU extraction
    public func preprocessImage(_ image: UIImage) throws -> [Float] {
        guard let resizedImage = resizeImage(image, to: config.imageSize) else {
            throw PRNUError.imageProcessingFailed("Failed to resize")
        }
        
        guard let grayPixels = convertToGrayscale(resizedImage) else {
            throw PRNUError.imageProcessingFailed("Failed to convert to grayscale")
        }
        
        var normalized = grayPixels.map { Float($0) / 255.0 }
        
        if config.enableGammaCorrection {
            normalized = applyGammaCorrection(normalized, gamma: config.gamma)
        }
        
        return normalized
    }
    
    private func applyFastDenoisingFilter(_ pixels: [Float]) -> [Float] {
        let width = config.processingWidth
        let height = config.processingHeight
        var denoised = [Float](repeating: 0, count: pixels.count)
        
        let kernel: [Float] = [1/16, 2/16, 1/16, 2/16, 4/16, 2/16, 1/16, 2/16, 1/16]
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum: Float = 0
                var kernelIndex = 0
                
                for ky in -1...1 {
                    for kx in -1...1 {
                        sum += pixels[(y + ky) * width + (x + kx)] * kernel[kernelIndex]
                        kernelIndex += 1
                    }
                }
                denoised[y * width + x] = sum
            }
        }
        
        // Handle borders
        for y in 0..<height {
            denoised[y * width] = pixels[y * width]
            denoised[y * width + width - 1] = pixels[y * width + width - 1]
        }
        for x in 0..<width {
            denoised[x] = pixels[x]
            denoised[(height - 1) * width + x] = pixels[(height - 1) * width + x]
        }
        
        return denoised
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func convertToGrayscale(_ image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
    
    private func applyGammaCorrection(_ pixels: [Float], gamma: Float) -> [Float] {
        pixels.map { pow($0, gamma) }
    }
}

// MARK: - Wiener Filter

class WienerFilter {
    
    func denoise(_ pixels: [Float], width: Int, height: Int) -> [Float] {
        let windowSize = 5
        var denoised = [Float](repeating: 0, count: pixels.count)
        
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                var count: Float = 0
                
                for wy in max(0, y - windowSize)...min(height - 1, y + windowSize) {
                    for wx in max(0, x - windowSize)...min(width - 1, x + windowSize) {
                        sum += pixels[wy * width + wx]
                        count += 1
                    }
                }
                
                let localMean = sum / count
                var variance: Float = 0
                
                for wy in max(0, y - windowSize)...min(height - 1, y + windowSize) {
                    for wx in max(0, x - windowSize)...min(width - 1, x + windowSize) {
                        let diff = pixels[wy * width + wx] - localMean
                        variance += diff * diff
                    }
                }
                variance /= count
                
                let noiseVariance: Float = 0.01
                let wienerCoeff = max(0, variance - noiseVariance) / max(variance, 0.0001)
                
                denoised[y * width + x] = localMean + wienerCoeff * (pixels[y * width + x] - localMean)
            }
        }
        
        return denoised
    }
}

// MARK: - PCE Calculator

public class PCECalculator {
    
    private let config: PRNUConfig
    
    init(config: PRNUConfig) {
        self.config = config
    }
    
    /// Calculate Peak Correlation Energy: PCE = |peak|² / (1/N × Σ|correlation|²)
    public func calculatePCE(
        residual: [Float],
        fingerprint: [Float],
        width: Int,
        height: Int
    ) throws -> Float {
        guard residual.count == fingerprint.count else {
            throw PRNUError.dimensionMismatch
        }
        
        let correlation = calculateSpatialCorrelation(
            signal1: residual,
            signal2: fingerprint,
            width: width,
            height: height
        )
        
        var peak: Float = 0
        vDSP_maxv(correlation, 1, &peak, vDSP_Length(correlation.count))
        
        var energy: Float = 0
        vDSP_svesq(correlation, 1, &energy, vDSP_Length(correlation.count))
        
        let n = Float(correlation.count)
        let pce = (peak * peak) / (energy / n)
        
        return pce
    }
    
    /// Calculate local PCE scores for tamper detection
    public func calculateLocalPCE(
        residual: [Float],
        fingerprint: [Float],
        width: Int,
        height: Int,
        blockSize: Int
    ) throws -> [Float] {
        var localScores: [Float] = []
        
        let blocksX = width / blockSize
        let blocksY = height / blockSize
        
        for blockY in 0..<blocksY {
            for blockX in 0..<blocksX {
                var blockResidual: [Float] = []
                var blockFingerprint: [Float] = []
                
                for y in 0..<blockSize {
                    let rowIndex = (blockY * blockSize + y) * width + (blockX * blockSize)
                    blockResidual.append(contentsOf: residual[rowIndex..<(rowIndex + blockSize)])
                    blockFingerprint.append(contentsOf: fingerprint[rowIndex..<(rowIndex + blockSize)])
                }
                
                let blockPCE = try calculatePCE(
                    residual: blockResidual,
                    fingerprint: blockFingerprint,
                    width: blockSize,
                    height: blockSize
                )
                
                localScores.append(blockPCE)
            }
        }
        
        return localScores
    }
    
    private func calculateSpatialCorrelation(
        signal1: [Float],
        signal2: [Float],
        width: Int,
        height: Int
    ) -> [Float] {
        var correlation = [Float](repeating: 0, count: signal1.count)
        
        let mean1 = signal1.reduce(0, +) / Float(signal1.count)
        let mean2 = signal2.reduce(0, +) / Float(signal2.count)
        
        var norm1 = signal1.map { $0 - mean1 }
        var norm2 = signal2.map { $0 - mean2 }
        
        var std1: Float = 0, std2: Float = 0
        vDSP_svesq(norm1, 1, &std1, vDSP_Length(norm1.count))
        vDSP_svesq(norm2, 1, &std2, vDSP_Length(norm2.count))
        std1 = sqrt(std1)
        std2 = sqrt(std2)
        
        if std1 > 0 && std2 > 0 {
            var scale1 = 1.0 / std1, scale2 = 1.0 / std2
            vDSP_vsmul(norm1, 1, &scale1, &norm1, 1, vDSP_Length(norm1.count))
            vDSP_vsmul(norm2, 1, &scale2, &norm2, 1, vDSP_Length(norm2.count))
            vDSP_vmul(norm1, 1, norm2, 1, &correlation, 1, vDSP_Length(correlation.count))
        }
        
        return correlation
    }
    
    public func calculateNCC(signal1: [Float], signal2: [Float]) -> Float {
        guard signal1.count == signal2.count else { return 0 }
        
        let n = Float(signal1.count)
        let mean1 = signal1.reduce(0, +) / n
        let mean2 = signal2.reduce(0, +) / n
        
        var numerator: Float = 0, sum1Sq: Float = 0, sum2Sq: Float = 0
        
        for i in 0..<signal1.count {
            let diff1 = signal1[i] - mean1
            let diff2 = signal2[i] - mean2
            numerator += diff1 * diff2
            sum1Sq += diff1 * diff1
            sum2Sq += diff2 * diff2
        }
        
        let denominator = sqrt(sum1Sq * sum2Sq)
        return denominator > 0 ? numerator / denominator : 0
    }
}

// MARK: - Fingerprint Storage

public class FingerprintStorage {
    
    private let serviceName = "com.prnu.sdk.fingerprints"
    private let accessGroup: String?
    
    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }
    
    public func save(fingerprint: CameraFingerprint) throws {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(fingerprint) else {
            throw PRNUError.storageError("Failed to encode")
        }
        
        var query = baseKeychainQuery(for: fingerprint.cameraID)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PRNUError.storageError("Save failed: \(status)")
        }
    }
    
    public func load(cameraID: String) throws -> CameraFingerprint? {
        var query = baseKeychainQuery(for: cameraID)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return status == errSecItemNotFound ? nil : nil
        }
        
        guard let data = result as? Data else {
            throw PRNUError.storageError("Invalid data")
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(CameraFingerprint.self, from: data)
    }
    
    public func delete(cameraID: String) throws {
        let query = baseKeychainQuery(for: cameraID)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PRNUError.storageError("Delete failed")
        }
    }
    
    public func listCameraIDs() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    
    private func baseKeychainQuery(for cameraID: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: cameraID
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

// MARK: - Main Authenticator

public class PRNUAuthenticator {
    
    private let config: PRNUConfig
    private let storage: FingerprintStorage
    private let extractor: PRNUExtractor
    private let pceCalculator: PCECalculator
    private let processingQueue: OperationQueue
    
    public init() {
        self.config = PRNUConfig.default
        self.storage = FingerprintStorage()
        self.extractor = PRNUExtractor(config: config)
        self.pceCalculator = PCECalculator(config: config)
        
        self.processingQueue = OperationQueue()
        self.processingQueue.maxConcurrentOperationCount = config.maxConcurrentOperations
        self.processingQueue.qualityOfService = .userInitiated
    }
    
    public init(config: PRNUConfig) {
        self.config = config
        self.storage = FingerprintStorage()
        self.extractor = PRNUExtractor(config: config)
        self.pceCalculator = PCECalculator(config: config)
        
        self.processingQueue = OperationQueue()
        self.processingQueue.maxConcurrentOperationCount = config.maxConcurrentOperations
        self.processingQueue.qualityOfService = .userInitiated
    }
    
    // MARK: - Public API
    
    /// Enroll a camera with 50+ images
    public func enrollCamera(
        withID cameraID: String,
        images: [UIImage],
        completion: @escaping (Result<CameraFingerprint, PRNUError>) -> Void
    ) {
        guard images.count >= config.enrollmentImageCount else {
            completion(.failure(.insufficientImages(
                required: config.enrollmentImageCount,
                provided: images.count
            )))
            return
        }
        
        processingQueue.addOperation { [weak self] in
            guard let self = self else { return }
            
            do {
                let fingerprint = try self.extractCameraFingerprint(from: images, cameraID: cameraID)
                try self.storage.save(fingerprint: fingerprint)
                
                DispatchQueue.main.async {
                    completion(.success(fingerprint))
                }
            } catch let error as PRNUError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.processingError(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Authenticate an image
    public func authenticateImage(
        _ image: UIImage,
        cameraID: String,
        completion: @escaping (Result<AuthenticationResult, PRNUError>) -> Void
    ) {
        processingQueue.addOperation { [weak self] in
            guard let self = self else { return }
            
            do {
                guard let storedFingerprint = try self.storage.load(cameraID: cameraID) else {
                    throw PRNUError.fingerprintNotFound(cameraID)
                }
                
                let residual = try self.extractor.extractNoiseResidual(from: image)
                
                let pceScore = try self.pceCalculator.calculatePCE(
                    residual: residual,
                    fingerprint: storedFingerprint.fingerprint,
                    width: storedFingerprint.width,
                    height: storedFingerprint.height
                )
                
                let result = self.createAuthenticationResult(
                    pceScore: pceScore,
                    cameraID: cameraID,
                    image: image
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch let error as PRNUError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.processingError(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Authenticate multiple images
    public func authenticateImages(
        _ images: [UIImage],
        cameraID: String,
        completion: @escaping (Result<[AuthenticationResult], PRNUError>) -> Void
    ) {
        let group = DispatchGroup()
        var results: [AuthenticationResult] = []
        var encounteredError: PRNUError?
        let resultsLock = NSLock()
        
        for image in images {
            group.enter()
            
            authenticateImage(image, cameraID: cameraID) { result in
                resultsLock.lock()
                defer { resultsLock.unlock(); group.leave() }
                
                switch result {
                case .success(let authResult):
                    results.append(authResult)
                case .failure(let error):
                    if encounteredError == nil {
                        encounteredError = error
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if let error = encounteredError {
                completion(.failure(error))
            } else {
                completion(.success(results))
            }
        }
    }
    
    /// Detect image tampering
    public func detectTampering(
        in image: UIImage,
        cameraID: String,
        completion: @escaping (Result<TamperDetectionResult, PRNUError>) -> Void
    ) {
        processingQueue.addOperation { [weak self] in
            guard let self = self else { return }
            
            do {
                guard let storedFingerprint = try self.storage.load(cameraID: cameraID) else {
                    throw PRNUError.fingerprintNotFound(cameraID)
                }
                
                let residual = try self.extractor.extractNoiseResidual(from: image)
                let blockSize = 128
                
                let localScores = try self.pceCalculator.calculateLocalPCE(
                    residual: residual,
                    fingerprint: storedFingerprint.fingerprint,
                    width: storedFingerprint.width,
                    height: storedFingerprint.height,
                    blockSize: blockSize
                )
                
                let tamperedRegions = self.identifyTamperedRegions(
                    localScores: localScores,
                    blockSize: blockSize
                )
                
                let result = TamperDetectionResult(
                    isTampered: !tamperedRegions.isEmpty,
                    tamperedRegions: tamperedRegions,
                    overallPCE: localScores.reduce(0, +) / Float(localScores.count),
                    confidence: self.calculateTamperConfidence(localScores: localScores)
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch let error as PRNUError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.processingError(error.localizedDescription)))
                }
            }
        }
    }
    
    public func deleteFingerprint(cameraID: String) throws {
        try storage.delete(cameraID: cameraID)
    }
    
    public func listEnrolledCameras() -> [String] {
        storage.listCameraIDs()
    }
    
    public func isCameraEnrolled(cameraID: String) -> Bool {
        (try? storage.load(cameraID: cameraID)) != nil
    }
    
    // MARK: - Private Methods
    
    private func extractCameraFingerprint(
        from images: [UIImage],
        cameraID: String
    ) throws -> CameraFingerprint {
        var residuals: [[Float]] = []
        var processedImages: [[Float]] = []
        
        for image in images {
            let residual = try extractor.extractNoiseResidual(from: image)
            let processed = try extractor.preprocessImage(image)
            
            residuals.append(residual)
            processedImages.append(processed)
        }
        
        let width = config.processingWidth
        let height = config.processingHeight
        let size = width * height
        
        var fingerprint = [Float](repeating: 0, count: size)
        
        // Calculate: K = Σ(Wi × Ii) / Σ(Ii²)
        for i in 0..<size {
            var numerator: Float = 0, denominator: Float = 0
            
            for j in 0..<residuals.count {
                numerator += residuals[j][i] * processedImages[j][i]
                denominator += processedImages[j][i] * processedImages[j][i]
            }
            
            fingerprint[i] = denominator > 0 ? numerator / denominator : 0
        }
        
        // Normalize
        let mean = fingerprint.reduce(0, +) / Float(size)
        for i in 0..<size {
            fingerprint[i] -= mean
        }
        
        // Calculate average PCE
        var totalPCE: Float = 0
        for residual in residuals {
            let pce = try pceCalculator.calculatePCE(
                residual: residual,
                fingerprint: fingerprint,
                width: width,
                height: height
            )
            totalPCE += pce
        }
        let averagePCE = totalPCE / Float(residuals.count)
        
        return CameraFingerprint(
            cameraID: cameraID,
            fingerprint: fingerprint,
            width: width,
            height: height,
            enrollmentDate: Date(),
            numberOfImages: images.count,
            averagePCE: averagePCE
        )
    }
    
    private func createAuthenticationResult(
        pceScore: Float,
        cameraID: String,
        image: UIImage
    ) -> AuthenticationResult {
        let isAuthentic = pceScore >= config.pceThreshold
        let confidence = min(100, (pceScore / config.pceThreshold) * 100)
        
        let additionalInfo: [String: Any] = [
            "imageSize": image.size,
            "scale": image.scale,
            "threshold": config.pceThreshold
        ]
        
        return AuthenticationResult(
            isAuthentic: isAuthentic,
            pceScore: pceScore,
            confidence: confidence,
            cameraID: cameraID,
            timestamp: Date(),
            additionalInfo: additionalInfo
        )
    }
    
    private func identifyTamperedRegions(
        localScores: [Float],
        blockSize: Int
    ) -> [CGRect] {
        var tamperedRegions: [CGRect] = []
        
        let mean = localScores.reduce(0, +) / Float(localScores.count)
        let variance = localScores.map { pow($0 - mean, 2) }.reduce(0, +) / Float(localScores.count)
        let stdDev = sqrt(variance)
        let threshold = mean - 2 * stdDev
        
        let blocksPerRow = config.processingWidth / blockSize
        
        for (index, score) in localScores.enumerated() where score < threshold {
            let row = index / blocksPerRow
            let col = index % blocksPerRow
            
            tamperedRegions.append(CGRect(
                x: col * blockSize,
                y: row * blockSize,
                width: blockSize,
                height: blockSize
            ))
        }
        
        return tamperedRegions
    }
    
    private func calculateTamperConfidence(localScores: [Float]) -> Float {
        let mean = localScores.reduce(0, +) / Float(localScores.count)
        let variance = localScores.map { pow($0 - mean, 2) }.reduce(0, +) / Float(localScores.count)
        let coefficientOfVariation = sqrt(variance) / mean
        return min(100, coefficientOfVariation * 100)
    }
}

// MARK: - USAGE EXAMPLE

/*
 
 // QUICK START EXAMPLE
 
 import PRNUAuthSDK
 
 let auth = PRNUAuthenticator()
 
 // 1. Enroll camera (do once)
 let my50Images: [UIImage] = [...]
 auth.enrollCamera(withID: "MyiPhone", images: my50Images) { result in
     switch result {
     case .success(let fingerprint):
         print("✅ Enrolled! PCE: \(fingerprint.averagePCE)")
     case .failure(let error):
         print("❌ Error: \(error)")
     }
 }
 
 // 2. Authenticate image (do many times)
 let testPhoto = UIImage(named: "photo")!
 auth.authenticateImage(testPhoto, cameraID: "MyiPhone") { result in
     switch result {
     case .success(let authResult):
         if authResult.isAuthentic {
             print("✅ Verified! PCE: \(authResult.pceScore)")
         } else {
             print("⚠️ Suspicious")
         }
     case .failure(let error):
         print("❌ Error: \(error)")
     }
 }
 
 // 3. Detect tampering
 auth.detectTampering(in: image, cameraID: "MyiPhone") { result in
     if case .success(let r) = result, r.isTampered {
         print("⚠️ Tampered regions: \(r.tamperedRegions.count)")
     }
 }
 
 */
