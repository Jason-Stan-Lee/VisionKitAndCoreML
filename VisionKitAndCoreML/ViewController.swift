//
//  ViewController.swift
//  VisionKitAndCoreML
//
//  Created by JasonLee on 2018/6/15.
//  Copyright © 2018年 JasonLee. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController {

    lazy var captureView: VideoCaptureView = {
        let captureView = VideoCaptureView()
        captureView.delegate = self
        return captureView
    }()

    var visionRequests = [VNRequest]()
    let resultView: UILabel = {
        let label = UILabel()
        label.textColor = .darkGray
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(captureView)
        resultView.textAlignment = .center
        resultView.backgroundColor = UIColor(white: 1, alpha: 0.1)
        view.addSubview(resultView)

        guard let resnet50Model = try? VNCoreMLModel(for: Resnet50().model),
            let rn1015Model = try? VNCoreMLModel(for: RN1015k500().model),
            let hourglassModel = try? VNCoreMLModel(for: Hourglass().model),
            let cpmModel = try? VNCoreMLModel(for: CPM().model) else {
            return
        }
        
        /*
         // 内置图像请求

         // 图像基础请求
         VNImageBasedRequest

         // 单应图像配准
         VNHomographicImageRegistrationRequest
         // 图像配准
         VNImageRegistrationRequest

         // 水平倾斜度
         VNDetectHorizonRequest
         // 条形码识别
         VNDetectBarcodesRequest
         // 投影矩形检测
         VNDetectRectanglesRequest
         // 文本矩形检测
         VNDetectTextRectanglesRequest
         // 物体位置和范围检查
         VNDetectedObjectObservation
         // 面部特征检测
         VNDetectFaceLandmarksRequest
         // 面部区域检测
         VNDetectFaceRectanglesRequest

         // 追踪请求抽象基类
         VNTrackingRequest
         // 物体追踪
         VNTrackObjectRequest
         // 矩形物体追踪
         VNTrackRectangleRequest
         */

        let resnet50Request = VNCoreMLRequest(model: resnet50Model, completionHandler: handleClassifications)
        resnet50Request.imageCropAndScaleOption = .centerCrop
        visionRequests.append(resnet50Request)

        let rn1015Request = VNCoreMLRequest(model: rn1015Model, completionHandler: handleRn1015)
        visionRequests.append(rn1015Request)

        let rectanglesRequest = VNDetectRectanglesRequest(completionHandler: handleRectanglesRequest)
        visionRequests.append(rectanglesRequest)

        let hourglassRequest = VNCoreMLRequest(model: hourglassModel, completionHandler: handleHourglass)
        visionRequests.append(hourglassRequest)

        let cpmRequest = VNCoreMLRequest(model: cpmModel, completionHandler: handleCPM)
        visionRequests.append(cpmRequest)

    }

    func handleRectanglesRequest(request: VNRequest, error: Error?) {
        guard let detectedRectangle = request.results?.first as? VNRectangleObservation else {
            return
        }
        print("detectedRectangle: \((detectedRectangle.topLeft, detectedRectangle.topRight, detectedRectangle.bottomLeft, detectedRectangle.bottomRight))")
    }

    func handleRn1015(request: VNRequest, error: Error?) {

    }

    func handleHourglass(request: VNRequest, error: Error?) {
        if let theError = error {
            print("Error: \(theError.localizedDescription)")
            return
        }

        guard let observations = request.results else {
            print("No result")
            return
        }

        // 14 x 48 x 48 array
        guard let value = (observations.compactMap { $0 as? VNCoreMLFeatureValueObservation}.first?.featureValue.multiArrayValue) else {
            return
        }

        print("Hourglass \(String(describing: value.shape))")
    }

    func handleCPM(request: VNRequest, error: Error?) {
        if let theError = error {
            print("Error: \(theError.localizedDescription)")
            return
        }

        guard let observations = request.results else {
            print("No result")
            return
        }

        // 14 x 96 x 96 array
        guard let value = (observations.compactMap { $0 as? VNCoreMLFeatureValueObservation}.first?.featureValue.multiArrayValue) else {
            return
        }

        print("========================================================")
        print("CPM Shape: \(value.shape)")
        
        for cy in 0..<96 {
            for cx in 0..<96 {
                for b in 0..<14 {
                    let item = value[[b, cx, cy] as [NSNumber]].floatValue
                    print("cx: \(cx), cy: \(cy), channel: \(b); item: \(item)")
                }
            }
        }

    }

    func handleClassifications(request: VNRequest, error: Error?) {
        if let theError = error {
            print("Error: \(theError.localizedDescription)")
            return
        }

        guard let observations = request.results else {
            print("No result")
            return
        }

        let classifications = observations[0...4]
            .compactMap { $0 as? VNClassificationObservation}
            .map { "\($0.identifier) \(($0.confidence * 100.0).rounded())" }
            .joined(separator: "\n")

        DispatchQueue.main.async {
            self.resultView.text = classifications
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        captureView.frame = self.view.bounds
        resultView.frame = self.view.bounds
    }

}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {


    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let piexBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var requestOptions: [VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }

        let imagerequestHandler = VNImageRequestHandler(cvPixelBuffer: piexBuffer, orientation: .up, options: requestOptions)

        do {
            try imagerequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }

}
