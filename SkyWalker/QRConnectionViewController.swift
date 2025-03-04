//
//  QRConnectionViewController.swift
//  SkyWalker
//
//  Created by Héctor Del Campo Pando on 7/4/17.
//  Copyright © 2017 Héctor Del Campo Pando. All rights reserved.
//

import UIKit
import AVFoundation

/**
    QR Connection view controller.
 */
class QRConnectionViewController: NewConnectionViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    /**
     Connection status
     */
    var connecting: Bool!
    
    /**
        Camera's session.
    */
    var captureSession: AVCaptureSession!

    //MARK: Outlets
    @IBOutlet weak var cameraView: UIView!
    
    override func viewDidLayoutSubviews() {
        startCameraPreviewWithQRDetection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
        connecting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .default).async {_ in
            
            self.captureSession.startRunning()
            
        }
        connecting = false
    }
    
    /**
        Starts the camera preview with QR detection enabled.
    */
    private func startCameraPreviewWithQRDetection() {
        
        
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let input: AnyObject! = try? AVCaptureDeviceInput.init(device: captureDevice)
        captureSession = AVCaptureSession()
        captureSession.addInput(input as! AVCaptureInput)
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)
        
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "QR Detection queue"))
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = cameraView.layer.bounds
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        cameraView.layer.addSublayer(previewLayer!)
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if (nil == metadataObjects || metadataObjects.count == 0) {
            return
        }
        
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObjectTypeQRCode {
            
            if connecting {
                return
            }
            
            connecting = true
            
            if (isXtremeLocQR(qr: metadataObj.stringValue)) {
                treat(qr: metadataObj.stringValue)
            } else {
                show(error: .INVALID_URL)
            }
        }
        
    }
    
    /**
        Detects whether a QR is valid as XtremeLoc scheme or not.
        - Parameter qr: QR content.
        - Returns: True if QR is a valid XtremeLoc one, false otherwise.
    */
    private func isXtremeLocQR(qr: String) -> Bool {
        
        let qrData = qr.data(using: .utf8)!
        
        if let json = try? JSONSerialization.jsonObject(with: qrData, options: []) as? Dictionary<String, Any> {
            return json!["scheme"] != nil
        } else {
            return false
        }

    }
    
    
    /**
        Handles a QR code.
        - Parameter qr: QR content.
    */
    private func treat(qr: String) {
        
        let data = qr.data(using: .utf8)!
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! Dictionary<String, String>
        
        let url = json["url"]!
        let username: String? = json["username"]
        let password: String? = json["password"]
        
        newConnection(url: url, username: username, password: password)

    }
    
    override func show(error: PersistenceErrors) {
        
        
        indicator?.removeFromSuperview()
        
        switch error {
        case .INVALID_URL:
            alert = UIAlertController(title: nil,
                                      message: NSLocalizedString("invalid_qr", comment: ""),
                                      preferredStyle: .alert)
            
        case .INVALID_CREDENTIALS:
            alert.message = NSLocalizedString("invalid_username_password", comment: "")
        case .INTERNET_ERROR:
            alert.message = NSLocalizedString("no_internet", comment: "")
        default:
            alert.message = NSLocalizedString("server_bad_connection", comment: "")
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""),
                                      style: .default,
                                      handler: {_ in
                                        self.connecting = false
        }))
        
        if (error == .INVALID_URL) {
            present(alert, animated: true, completion: nil)
        }
        
    }

}
