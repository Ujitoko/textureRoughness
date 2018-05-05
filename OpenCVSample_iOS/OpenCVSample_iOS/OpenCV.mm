//
//  OpenCV.m
//  OpenCVSample_iOS
//
//

// Put OpenCV include files at the top. Otherwise an error happens.
#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>

#import <Foundation/Foundation.h>
#import "OpenCV.h"

/// Converts an UIImage to Mat.
/// Orientation of UIImage will be lost.
static void UIImageToMat(UIImage *image, cv::Mat &mat) {
	
	// Create a pixel buffer.
	NSInteger width = CGImageGetWidth(image.CGImage);
	NSInteger height = CGImageGetHeight(image.CGImage);
    // NSLog("\(width), \(height)")
	CGImageRef imageRef = image.CGImage;
	cv::Mat mat8uc4 = cv::Mat((int)height, (int)width, CV_8UC4);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef contextRef = CGBitmapContextCreate(mat8uc4.data, mat8uc4.cols, mat8uc4.rows, 8, mat8uc4.step, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	// Draw all pixels to the buffer.
	cv::Mat mat8uc3 = cv::Mat((int)width, (int)height, CV_8UC3);
	cv::cvtColor(mat8uc4, mat8uc3, CV_RGBA2BGR);
	
	mat = mat8uc3;
}

/// Converts a Mat to UIImage.
static UIImage *MatToUIImage(cv::Mat &mat) {
	
	// Create a pixel buffer.
	assert(mat.elemSize() == 1 || mat.elemSize() == 3);
	cv::Mat matrgb;
	if (mat.elemSize() == 1) {
		cv::cvtColor(mat, matrgb, CV_GRAY2RGB);
	} else if (mat.elemSize() == 3) {
		cv::cvtColor(mat, matrgb, CV_BGR2RGB);
	}
	
	// Change a image format.
	NSData *data = [NSData dataWithBytes:matrgb.data length:(matrgb.elemSize() * matrgb.total())];
	CGColorSpaceRef colorSpace;
	if (matrgb.elemSize() == 1) {
		colorSpace = CGColorSpaceCreateDeviceGray();
	} else {
		colorSpace = CGColorSpaceCreateDeviceRGB();
	}
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(matrgb.cols, matrgb.rows, 8, 8 * matrgb.elemSize(), matrgb.step.p[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *image = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	
	return image;
}

/// Restore the orientation to image.
static UIImage *RestoreUIImageOrientation(UIImage *processed, UIImage *original) {
	if (processed.imageOrientation == original.imageOrientation) {
		return processed;
	}
	return [UIImage imageWithCGImage:processed.CGImage scale:1.0 orientation:original.imageOrientation];
}

#pragma mark -

@implementation OpenCV

+ (nonnull UIImage *)cvtColorBGR2GRAY:(nonnull UIImage *)image {
	cv::Mat bgrMat;
	UIImageToMat(image, bgrMat);
	cv::Mat grayMat;
	cv::cvtColor(bgrMat, grayMat, CV_BGR2GRAY);
	UIImage *grayImage = MatToUIImage(grayMat);
	return RestoreUIImageOrientation(grayImage, image);
}

+ (nonnull UIImage *)cvtSubtractBackground:(nonnull UIImage *)image {
    cv::Mat bgrMat;
    UIImageToMat(image, bgrMat);
    //cv::Mat grayMat;
    //cv::cvtColor(bgrMat, grayMat, CV_BGR2GRAY);
    
    cv::BackgroundSubtractorMOG2* bs = cv::createBackgroundSubtractorMOG2();
    cv::Mat fgMask;
    fgMask.copySize(bgrMat);
    bs->apply(bgrMat, fgMask);
    UIImage *grayImage = MatToUIImage(bgrMat);
    
    //UIImage *grayImage = MatToUIImage(grayMat);
    return RestoreUIImageOrientation(grayImage, image);
}


//+ (nonnull UIImage *)cvtBinarizeImage:(nonnull UIImage *)image {
+ (nonnull UIImage *)cvtBinarizeImage:(nonnull UIImage *)image backgroundImg:(nonnull UIImage *)backgroundImg backgroundScale:(float)backgroundScale{
    cv::Mat bgrMat;
    UIImageToMat(backgroundImg, bgrMat);
    
    cv::Mat currentMat;
    UIImageToMat(image, currentMat);
    
    cv::Mat grayBgr;
    cv::Mat grayCurrent;
    
    cv::cvtColor(bgrMat, grayBgr, CV_BGR2GRAY);
    cv::cvtColor(currentMat, grayCurrent, CV_BGR2GRAY);
    
    // HSVへ変換
    cv::Mat hsvCurrent;
    cv::cvtColor(currentMat, hsvCurrent, CV_BGR2HSV);
    cv::Mat hsvMedianCurrent;
    cv::medianBlur(hsvCurrent, hsvMedianCurrent, 3);

    cv::GaussianBlur(hsvMedianCurrent, hsvMedianCurrent, cv::Size(5,5), 0);
    // マスク
    cv::Mat hsvMask;
    cv::Scalar HSV_MIN = cv::Scalar(0, 58, 88);
    cv::Scalar HSV_MAX = cv::Scalar(25, 173, 229);

    cv::inRange(hsvMedianCurrent, HSV_MIN, HSV_MAX, hsvMask);
    
    // カタマリ
    std::vector< std::vector < cv::Point > > vctContours;
    std::vector < cv::Vec4i > hierarchy;
    cv::findContours(hsvMask, vctContours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);
    cv::Mat mask = cv::Mat::zeros(hsvMask.size(), CV_8UC1 );
    
    cv::Mat _outNotScaled, _out;//cv::Mat::zeros(hsvMask.size(), CV_8UC1 );

    //_outNotScaled = bgrMat;
    bgrMat.copyTo(_outNotScaled);
    bgrMat.copyTo(_out);

    cv::resize(_outNotScaled, _out, cv::Size(0,0), backgroundScale, backgroundScale, cv::INTER_NEAREST);
    cv::Rect myROI(0,0,_outNotScaled.cols, _outNotScaled.rows);
    _out = _out(myROI);
    
    int max_level = 0;
    double max_area = 0.0f;
    int max_idx = 0;
    for (int i = 0; i< vctContours.size(); i++){
        // 面積
        double area = cv::contourArea(vctContours[i], false);
        
        if (max_area < area){
            max_area = area;
            max_idx = i;
        }
    }
    if (max_idx != 0){
        printf("area:%lf\n",max_area);
        cv::drawContours(mask, vctContours, max_idx, cv::Scalar(255), CV_FILLED);
        currentMat.copyTo(_out, mask);
    }

    UIImage *grayImage = MatToUIImage(_out);
    return RestoreUIImageOrientation(grayImage, image);
}

@end
