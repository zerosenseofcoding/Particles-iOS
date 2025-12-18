//
//  ContentView.swift
//  Particles iOS
//
//  Created by @ZeroSenseOfCoding on 15/12/25.
//
// MARK: - Warranty void if you actually read the code. 😂

import SwiftUI
import AVFoundation
import SceneKit
import Vision
import Combine
import UIKit

struct ContentView: View {
    let scene = ParticleScene()
    @StateObject var tracker = HandTracker()
    
    var body: some View {
        ZStack {
            // [TWEAK] .allowsCameraControl: Set to false if you want to lock the view solely to hand gestures
            SceneView(scene: scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            tracker.particleScene = scene
        }
    }
}

class ParticleScene: SCNScene {
    var particleNode: SCNNode!
    var ringNode: SCNNode!
    var mainWrapper: SCNNode!
    
    override init() {
        super.init()
        setupScene()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupScene() {
        // [TWEAK] Background Color: Change .black to .white or any other color if needed
        self.background.contents = UIColor.black
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // [TWEAK] Camera Position: Change 'z' (10) to zoom in/out initially. Lower (e.g., 5) is closer.
        cameraNode.position = SCNVector3(0, 0, 10)
        self.rootNode.addChildNode(cameraNode)
        
        mainWrapper = SCNNode()
        self.rootNode.addChildNode(mainWrapper)
        
        let circleImg = createCircleImage()
        
        // --- CORE SPHERE SETUP ---
        // [TWEAK] Sphere Radius: Size of the invisible ball emitting particles
        let sphere = SCNSphere(radius: 1.0)
        particleNode = SCNNode()
        
        let coreSystem = SCNParticleSystem()
        
        // [TWEAK] Birth Rate (Core): How many particles spawn per second.
        // Higher (e.g., 10000) = Solid/Dense look. Lower (e.g., 1000) = Airy/Sparse look.
        coreSystem.birthRate = 5000
        
        coreSystem.emissionDuration = 1.0
        coreSystem.emitterShape = sphere
        coreSystem.birthLocation = .surface
        
        // [TWEAK] Life Span: How long a particle lives.
        // Higher = Long trails/tails. Lower = Short, snappy dots.
        coreSystem.particleLifeSpan = 1.5
        
        // [TWEAK] Particle Size: Size of individual dots.
        coreSystem.particleSize = 0.04
        
        coreSystem.particleImage = circleImg
        
        // [TWEAK] Core Color: Change the RGB values for the center planet color.
        coreSystem.particleColor = UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0) // Gold
        
        coreSystem.blendMode = .additive
        coreSystem.spreadingAngle = 180
        
        particleNode.addParticleSystem(coreSystem)
        mainWrapper.addChildNode(particleNode)
        
        // --- RING (SATURN) SETUP ---
        // [TWEAK] Ring Dimensions: ringRadius = how wide the ring is. pipeRadius = how thick the band is.
        let torus = SCNTorus(ringRadius: 2.5, pipeRadius: 0.2)
        ringNode = SCNNode()
        
        // [TWEAK] Ring Tilt: Adjust x/y/z to change the angle of the ring.
        ringNode.eulerAngles = SCNVector3(x: 0.5, y: 0, z: 0.2)
        
        let ringSystem = SCNParticleSystem()
        
        // [TWEAK] Birth Rate (Ring): Density of the ring particles.
        ringSystem.birthRate = 8000
        
        ringSystem.emissionDuration = 1.0
        ringSystem.emitterShape = torus
        ringSystem.birthLocation = .surface
        
        // [TWEAK] Ring Life Span: Longer life makes the ring look continuous.
        ringSystem.particleLifeSpan = 2.0
        
        // [TWEAK] Ring Particle Size: Usually smaller than core to look like dust.
        ringSystem.particleSize = 0.01
        
        ringSystem.particleImage = circleImg
        
        // [TWEAK] Ring Color: Currently White. Uncomment the line below for Blue.
        ringSystem.particleColor = UIColor.white
        // ringSystem.particleColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        
        ringSystem.blendMode = .additive
        
        ringNode.addParticleSystem(ringSystem)
        mainWrapper.addChildNode(ringNode)

        // [TWEAK] Idle Rotation Speed: 'duration: 20' means one full spin takes 20 seconds.
        // Decrease to spin faster (e.g., 5), Increase to spin slower (e.g., 50).
        let rotateAction = SCNAction.rotateBy(x: 0, y: 1, z: 0, duration: 20)
        let loopAction = SCNAction.repeatForever(rotateAction)
        mainWrapper.runAction(loopAction, forKey: "idleRotation")
    }
    
    func createCircleImage() -> UIImage {
        // [TWEAK] Image Quality: Higher size (e.g., 50x50) makes particles sharper but costs performance.
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).fill()
        }
        return image
    }
    
    // --- GESTURE LOGIC: PINCH (ZOOM) ---
    func updatePinch(distance: CGFloat) {
        // [TWEAK] Zoom Sensitivity: Multiplier (15.0).
        // Higher = Small hand movements create big zoom. Lower = Need to move hands wide to zoom.
        let targetScale: Float = Float(distance) * 15.0
        
        let currentScale: Float = mainWrapper.scale.x
        
        // [TWEAK] Smoothing (Lerp): The '0.1' factor.
        // Lower (0.05) = Very slow/smooth lag. Higher (0.5) = Snappy/Instant response.
        let newScale: Float = currentScale + (targetScale - currentScale) * 0.1
        
        // [TWEAK] Zoom Limits: max(0.5, ...) is minimum size. min(..., 4.0) is maximum size.
        let clampedScale: Float = max(0.5, min(newScale, 4.0))
        
        let cg = CGFloat(clampedScale)
        mainWrapper.scale = SCNVector3(cg, cg, cg)
        
        // [TWEAK] Dynamic Birth Rate:
        // When object is small (< 1.0), we increase density (8000) so it doesn't look empty.
        // When large, we decrease density (4000) to save battery/GPU.
        if clampedScale < 1.0 {
            particleNode.particleSystems?.first?.birthRate = 8000
        } else {
            particleNode.particleSystems?.first?.birthRate = 4000
        }
    }
    
    // --- GESTURE LOGIC: ROTATION ---
    func handleRotation(dx: CGFloat, dy: CGFloat) {
            // Stop auto-rotation when user interacts
            mainWrapper.removeAction(forKey: "idleRotation")
            
            // [TWEAK] Rotation Sensitivity:
            // Higher (10.0) = Fast spin. Lower (1.0) = Heavy/Slow object feel.
            let sensitivity: CGFloat = 5.0
            
            mainWrapper.eulerAngles.y += Float(dx * sensitivity)
            mainWrapper.eulerAngles.x += Float(dy * sensitivity)
        }
}

class HandTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    
    let session = AVCaptureSession()
    var particleScene: ParticleScene?
    var lastPinchPoint: CGPoint?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupCamera() } }
            }
        default:
            print("Camera permission denied")
        }
    }
    
    func setupCamera() {
            session.beginConfiguration()
            
            // [TWEAK] Camera Quality: .high is standard. Use .medium if phone gets too hot.
            session.sessionPreset = .high
            
            // Note: Using Front Camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                print("Error: Could not find Front Camera")
                session.commitConfiguration()
                return
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            // Drops frames if processing is too slow to keep UI smooth
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                
                if let connection = output.connection(with: .video) {
                    // [TWEAK] Orientation: Ensure this matches your App Settings.
                    // Currently set to LandscapeRight (Home button on right / Island on left)
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .landscapeRight
                    }
                    
                    // Mirroring front camera so movement feels natural
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                }
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let request = VNDetectHumanHandPoseRequest()
        // [TWEAK] Max Hands: Keep at 1 for single-hand control. Set to 2 if you want multi-hand features later.
        request.maximumHandCount = 1
        
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
        
        do {
            try handler.perform([request])
            
            guard let observation = request.results?.first else {
                DispatchQueue.main.async { self.lastPinchPoint = nil }
                return
            }
            
            let indexPoints = try observation.recognizedPoints(.indexFinger)
            let thumbPoints = try observation.recognizedPoints(.thumb)
            
            guard let indexTip = indexPoints[.indexTip], let thumbTip = thumbPoints[.thumbTip] else { return }
            
            // Math to calculate distance between fingers
            let distanceX = indexTip.location.x - thumbTip.location.x
            let distanceY = indexTip.location.y - thumbTip.location.y
            let pinchDistance = sqrt(distanceX * distanceX + distanceY * distanceY)
            
            // Calculate center point between fingers for rotation logic
            let centerX = (indexTip.location.x + thumbTip.location.x) / 2
            let centerY = (indexTip.location.y + thumbTip.location.y) / 2
            let currentPoint = CGPoint(x: centerX, y: centerY)
            
            DispatchQueue.main.async {
                // [TWEAK] Grab Threshold (0.06):
                // If distance is LESS than 0.06, app thinks you are grabbing/pinching (Rotation Mode).
                // If distance is MORE than 0.06, app thinks hand is open (Zoom Mode).
                // Increase this value (e.g., 0.1) if you find it hard to trigger the "Grab".
                if pinchDistance < 0.06 {
                    if let last = self.lastPinchPoint {
                        let dx = currentPoint.x - last.x
                        let dy = currentPoint.y - last.y
                        
                        // [TWEAK] Sensitivity Multiplier (* 2):
                        // Increases rotation speed relative to finger movement.
                        self.particleScene?.handleRotation(dx: dx * 2, dy: dy * 2)
                    }
                    self.lastPinchPoint = currentPoint
                } else {
                    self.lastPinchPoint = nil
                    self.particleScene?.updatePinch(distance: pinchDistance)
                }
            }
        } catch {
            print("Vision Error: \(error)")
        }
    }
}
