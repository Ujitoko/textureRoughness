//
//  ViewController.swift
//  OpenCVSample_iOS
//
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

	//@IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var ImageView: UIImageView!
    
	var session: AVCaptureSession!
	var device: AVCaptureDevice!
	var output: AVCaptureVideoDataOutput!
    var count: Int16!
    var backgroundImg: UIImage!
    var tmpBackgroundImg: UIImage!
    var backgroundScale: Float!
    
    @IBOutlet weak var slider: UISlider!

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        backgroundScale = sender.value
    }
    
    override func viewDidLoad() {
		super.viewDidLoad()
        backgroundScale = 1.0
        
        count = 0
        let screenWidth = self.view.bounds.width
        let screenHeight = self.view.bounds.height
        print("\(screenWidth), \(screenHeight)")

        // Prepare a video capturing session.
		self.session = AVCaptureSession()
        // self.session.sessionPreset = AVCaptureSession.Preset.vga640x480
        self.session.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        //self.session.sessionPreset = AVCaptureSession.Preset.hd1280x720

        
        self.device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
        
        self.device.isFocusModeSupported(.locked)
        /*
        if self.device.isFocusPointOfInterestSupported{
            self.device.isFocusModeSupported(.locked)
            //self.device.focusMode = AVCaptureDevice.FocusMode.autoFocus
        }
        */

        //self.device = AVCaptureDevice.default(for: AVMediaType.video)
		if (self.device == nil) {
			print("no device")
			return
		}
		do {
			let input = try AVCaptureDeviceInput(device: self.device)
			self.session.addInput(input)
		} catch {
			print("no device input")
			return
		}
		self.output = AVCaptureVideoDataOutput()
		self.output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA) ]
		let queue: DispatchQueue = DispatchQueue(label: "videocapturequeue", attributes: [])
		self.output.setSampleBufferDelegate(self, queue: queue)
		self.output.alwaysDiscardsLateVideoFrames = true
		if self.session.canAddOutput(self.output) {
			self.session.addOutput(self.output)
		} else {
			print("could not add a session output")
			return
		}
		do {
			try self.device.lockForConfiguration()
			self.device.activeVideoMinFrameDuration = CMTimeMake(1, 30) // 20 fps
			self.device.unlockForConfiguration()
		} catch {
			print("could not configure a device")
			return
		}

		self.session.startRunning()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	override var shouldAutorotate : Bool {
		return false
	}

	func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
		// Convert a captured image buffer to UIImage.
		guard let buffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			print("could not get a pixel buffer")
			return
		}
		let capturedImage: UIImage
		do {
			CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
			defer {
				CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
			}
			let address = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
			let bytes = CVPixelBufferGetBytesPerRow(buffer)
			let width = CVPixelBufferGetWidth(buffer)
			let height = CVPixelBufferGetHeight(buffer)
			let color = CGColorSpaceCreateDeviceRGB()
			let bits = 8
			let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
			guard let context = CGContext(data: address, width: width, height: height, bitsPerComponent: bits, bytesPerRow: bytes, space: color, bitmapInfo: info) else {
				print("could not create an CGContext")
				return
			}
			guard let image = context.makeImage() else {
				print("could not create an CGImage")
				return
			}
			capturedImage = UIImage(cgImage: image, scale: 1.0, orientation: UIImageOrientation.right)
		}
		
        if (count <= 30){
            backgroundImg = capturedImage
            count = count + 1
            print(count)
        }

        //tmpBackgroundImg = backgroundImg.copy() as! UIImage
        //let _size:CGSize = (1.0f, 1.0f)
        //tmpBackgroundImg = backgroundImg.resize(size:CGSize(width:50, height:50))
        let resultImage = OpenCV.cvtBinarizeImage(capturedImage, backgroundImg:backgroundImg, backgroundScale:backgroundScale)
        
        // Show the result.
        DispatchQueue.main.async(execute: {

            self.ImageView.image = resultImage
            //self.rightImageView.image = grayImage

            //print("imageView.frame.size: \(self.imageView.frame.size)")
            
        })
    
	}
}

extension UIImage {
    func resize(size:CGSize) -> UIImage?{
        // リサイズ処理
        let origWidth = self.size.width
        let origHeight = self.size.height
        
        var resizeWidth:CGFloat = 0
        var resizeHeight:CGFloat = 0
        if (origWidth < origHeight) {
            resizeWidth = size.width
            resizeHeight = origHeight * resizeWidth / origWidth
        } else {
            resizeHeight = size.height
            resizeWidth = origWidth * resizeHeight / origHeight
        }
        
        let resizeSize = CGSize(width:resizeWidth, height:resizeHeight)
        UIGraphicsBeginImageContext(resizeSize)
        
        self.draw(in: CGRect(x:0,y: 0,width: resizeWidth, height: resizeHeight))
        
        let resizeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 切り抜き処理
        let cropRect = CGRect(x:( resizeWidth - size.width ) / 2,
                              y:( resizeHeight - size.height) / 2,
                              width:size.width,
                              height:size.height)
        
        if let cropRef = resizeImage?.cgImage {
            cropRef.cropping(to: cropRect)
            let cropImage = UIImage(cgImage: cropRef)
            return cropImage
        }else {
            print("error!")
            return nil
        }
    }
    
    //向きがおかしくなる時用
    func resizeMaintainDirection(size:CGSize) -> UIImage?{
        
        //縦横がおかしくなる時は一度書き直すと良いらしい
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        self.draw(in:CGRect(x:0,y:0,width:self.size.width,height:self.size.height))
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        
        // リサイズ処理
        let origWidth = image.size.width
        let origHeight = image.size.height
        
        var resizeWidth:CGFloat = 0
        var resizeHeight:CGFloat = 0
        if (origWidth < origHeight) {
            resizeWidth = size.width
            resizeHeight = origHeight * resizeWidth / origWidth
        } else {
            resizeHeight = size.height
            resizeWidth = origWidth * resizeHeight / origHeight
        }
        
        let resizeSize = CGSize(width:resizeWidth, height:resizeHeight)
        UIGraphicsBeginImageContext(resizeSize)
        
        image.draw(in: CGRect(x:0,y: 0,width: resizeWidth, height: resizeHeight))
        
        let resizeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 切り抜き処理
        let cropRect = CGRect(x:( resizeWidth - size.width ) / 2,
                              y:( resizeHeight - size.height) / 2,
                              width:size.width,
                              height:size.height)
        
        if let cropRef = resizeImage?.cgImage {
            cropRef.cropping(to: cropRect)
            let cropImage = UIImage(cgImage: cropRef)
            return cropImage
        }else {
            print("error!")
            return nil
        }
    }
}


