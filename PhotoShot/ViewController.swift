//
//  ViewController.swift
//  PhotoShot
//
//  Created by Deivi Taka on 3/26/17.
//  Copyright © 2017 Deivi Taka. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {

    var captureSession = AVCaptureSession()
    var cameraOutput = AVCapturePhotoOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var currentImage: (image: Data, imageName: String)?
    
    var previewing = false
    var highResolutionEnabled = true
    var rawEnabled = false
    var live = 0
    var flashMode = AVCaptureFlashMode.off
    var cameraPosition = AVCaptureDevicePosition.back
    
    @IBOutlet weak var capturedButton: UIButton!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var menuView: UIView!
    @IBOutlet weak var toastLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadCamera()
        
        menuView.layer.cornerRadius = 8.0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if captureSession.isRunning {
            captureSession.stopRunning()
        } else {
            captureSession.startRunning()
        }
    }
    
    func loadCamera() {
        let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                                   mediaType: AVMediaTypeVideo,
                                                   position: cameraPosition)
        
        captureSession.removeInput(captureSession.inputs.first as! AVCaptureInput!)
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        if let input = try? AVCaptureDeviceInput(device: device) {
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                if (captureSession.canAddOutput(cameraOutput)) {
                    
                    cameraOutput.isHighResolutionCaptureEnabled = self.highResolutionEnabled
                    captureSession.addOutput(cameraOutput)
                    
                    if !cameraOutput.isLivePhotoCaptureSupported {
                        self.live = -1
                    }
                    
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer.frame = previewView.bounds
                    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                    previewView.clipsToBounds = true
                    previewView.layer.addSublayer(previewLayer)
                    captureSession.startRunning()
                }
            } else {
                print("Cannot add output")
            }
        }
    }
    
    func showToast(text: String) {
        toastLabel.text = text
        
        UIView.animate(withDuration: 1.0, animations: {
            self.toastLabel.alpha = 1.0
        })
        
        UIView.animate(withDuration: 1.0, delay: 2.0, options:
            .curveLinear, animations: {
                self.toastLabel.alpha = 0.0
        }, completion: nil)
    }
    
    func save(image: Data, withName: String) throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory().appending(withName))
        
        try image.write(to: url, options: .atomicWrite)
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: image, options: nil)
            
            let creationOptions = PHAssetResourceCreationOptions()
            creationOptions.shouldMoveFile = true
            request.addResource(with: .alternatePhoto, fileURL: url, options: nil)
            
        }, completionHandler: { (success, error) in
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            if FileManager.default.fileExists(atPath: url.absoluteString) {
                do {
                    try FileManager.default.removeItem(at: url)
                }
                catch let err {
                    print(err.localizedDescription)
                }
            }
            
            DispatchQueue.main.async {
                self.saveButton.isHidden = true
                self.showToast(text: "Image saved")
            }
        })
    }
}

extension ViewController : AVCapturePhotoCaptureDelegate {
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?)
    {
        
        if let error = error {
            print("Capture failed: \(error.localizedDescription)")
        }
        
        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput
                .jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            self.currentImage = (dataImage, "\(resolvedSettings.uniqueID).jpg")
            showImage()
        }
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingRawPhotoSampleBuffer rawSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        
        if let error = error {
            print("Capture failed: \(error.localizedDescription)")
        }
        
        if  let sampleBuffer = rawSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput
                .dngPhotoDataRepresentation(forRawSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            self.currentImage = (dataImage, "\(resolvedSettings.uniqueID).dng")
            showImage()
        }
    }
    
    func showImage() {
        let dataProvider = CGDataProvider(data: self.currentImage!.image as CFData)
        let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImageOrientation.right)
        
        self.capturedButton.imageView?.contentMode = .scaleAspectFill
        self.capturedButton.setImage(image, for: .normal)
        self.capturedButton.isHidden = false
    }
    
}

extension ViewController {
    @IBAction func didPressTakePhoto(_ sender: UIButton) {
        var settings = AVCapturePhotoSettings()
        
        if rawEnabled {
            if let rawFormat = cameraOutput.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(rawPixelFormatType: OSType(rawFormat))
            }
        }
        
        if self.live == 1 {
            let path = "\(NSTemporaryDirectory())/Photoshot_\(settings.uniqueID)"
            settings.livePhotoMovieFileURL = URL(fileURLWithPath: path)
        }
        
        settings.isHighResolutionPhotoEnabled = self.highResolutionEnabled
        if cameraOutput.supportedFlashModes.contains(NSNumber(value: self.flashMode.rawValue)) {
            settings.flashMode = self.flashMode
        }
        
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: self.capturedButton.frame.width,
            kCVPixelBufferHeightKey as String: self.capturedButton.frame.height
        ] as [String : Any]
        settings.previewPhotoFormat = previewFormat
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @IBAction func previewClicked() {
        UIView.animate(withDuration: 0.5, animations: {
            if !self.previewing {
                self.capturedButton.frame = self.view.frame
                self.saveButton.isHidden = false
            } else {
                let x: CGFloat = 20.0
                let y: CGFloat = self.view.frame.height - 100.0 - 20.0
                self.capturedButton.frame = CGRect(x: x, y: y, width: 75.0, height: 100.0)
                self.saveButton.isHidden = true
            }
        })
        previewing = !previewing
    }
    
    @IBAction func saveClicked() {
        if let image = currentImage {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    do {
                        try self.save(image: image.image, withName: image.imageName)
                    } catch let error {
                        print(error.localizedDescription)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showToast(text: "Not authorized!")
                    }
                }
            })
        }
    }
    
    @IBAction func moreClicked() {
        UIView.animate(withDuration: 1.0, animations: {
            self.menuView.alpha = 1.0 - self.menuView.alpha
        })
    }
    
    @IBAction func toggleLive(button: UIButton) {
        switch live {
        case -1:
            showToast(text: "Live photo not supported")
            break
            
        case 1:
            live = 0
            showToast(text: "Live: off")
            button.titleLabel?.font = UIFont (name: "System-Thin", size: 15)
            break
            
        case 0:
            live = 1
            showToast(text: "Live on")
            button.titleLabel?.font = UIFont (name: "System-Heavy", size: 15)
            break
            
        default:
            break
        }
    }
    
    @IBAction func toggleHDR(button: UIButton) {
        highResolutionEnabled = !highResolutionEnabled
        button.titleLabel?.font = highResolutionEnabled ?
            UIFont (name: "System-Heavy", size: 15) :
            UIFont (name: "System-Thin", size: 15)
        
        showToast(text: "High resolution: \(highResolutionEnabled)")
    }
    
    @IBAction func toggleRAW(button: UIButton) {
        if cameraOutput.availableRawPhotoPixelFormatTypes.count == 0 {
            showToast(text: "RAW not available")
            return
        }
        
        rawEnabled = !rawEnabled
        button.titleLabel?.font = rawEnabled ?
            UIFont (name: "System-Heavy", size: 15) :
            UIFont (name: "System-Thin", size: 15)
        
        showToast(text: "RAW: \(rawEnabled)")
    }
    
    @IBAction func toggleFlash(button: UIButton) {
        switch self.flashMode {
        case .off:
            self.flashMode = .on
            showToast(text: "Flash mode: on")
            button.setImage(UIImage(named: "FlashOn"), for: .normal)
            break
        case .on:
            self.flashMode = .auto
            showToast(text: "Flash mode: auto")
            button.setImage(UIImage(named: "FlashAuto"), for: .normal)
            break
        case .auto:
            self.flashMode = .off
            showToast(text: "Flash mode: off")
            button.setImage(UIImage(named: "FlashOff"), for: .normal)
            break
        }
    }
    
    @IBAction func toggleCamera() {
        if cameraPosition == .back {
            cameraPosition = .front
            showToast(text: "Camera: front")
        } else {
            cameraPosition = .back
            showToast(text: "Camera: back")
        }
        
        loadCamera()
    }
}
