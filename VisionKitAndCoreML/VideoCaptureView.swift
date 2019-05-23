//
//  VideoCaptureView.swift
//  VisionKitAndCoreML
//
//  Created by JasonLee on 2018/6/15.
//  Copyright © 2018年 JasonLee. All rights reserved.
//

import AVFoundation
import UIKit
import NaturalLanguage

class VideoCaptureView: UIView {

    weak var delegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        didSet {
            self.videoDataOutput.setSampleBufferDelegate(delegate, queue: captureQueue)
        }
    }

    private let captureQueue = DispatchQueue(label: "capture_queue")

    private let captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        return session
    }()

    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.layer.addSublayer(layer)
        return layer
    }()

    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        let conn = output.connection(with: .video)
        conn?.videoOrientation = .portrait
        return output
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        captureSession.addInput(input)
        captureSession.addOutput(videoDataOutput)
        captureSession.startRunning()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutMarginsDidChange() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
    }
}
