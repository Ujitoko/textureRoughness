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
    //cv::Mat fgMask = cv::Mat::zeros(bgrMat.rows, bgrMat.cols, CV_8U);
    cv::Mat fgMask;
    fgMask.copySize(bgrMat);
    bs->apply(bgrMat, fgMask);
    UIImage *grayImage = MatToUIImage(bgrMat);
    
    //UIImage *grayImage = MatToUIImage(grayMat);
    return RestoreUIImageOrientation(grayImage, image);
}


//+ (nonnull UIImage *)cvtBinarizeImage:(nonnull UIImage *)image {
+ (nonnull UIImage *)cvtBinarizeImage:(nonnull UIImage *)image backgroundImg:(nonnull UIImage *)backgroundImg{
    cv::Mat bgrMat;
    UIImageToMat(backgroundImg, bgrMat);
    
    cv::Mat currentMat;
    UIImageToMat(image, currentMat);
    
    cv::Mat grayBgr;
    cv::Mat grayCurrent;
    
    cv::cvtColor(bgrMat, grayBgr, CV_BGR2GRAY);
    cv::cvtColor(currentMat, grayCurrent, CV_BGR2GRAY);
    
    // 背景差分算出
    cv::Mat diffMat;
    cv::absdiff(grayBgr, grayCurrent, diffMat);

    // 差分を二値化
    cv::Mat diffThMat;
    cv::threshold(diffMat, diffThMat, 85, 255, CV_THRESH_BINARY);
    
    // HSVへ変換
    cv::Mat hsvCurrent;
    cv::cvtColor(currentMat, hsvCurrent, CV_BGR2HSV);
    cv::Mat hsvMedianCurrent;
    cv::medianBlur(hsvCurrent, hsvMedianCurrent, 3);

    //cv::Size _size = (3,3);
    //cv::blur(hsvCurrent, hsvMedianCurrent, _size);
    cv::GaussianBlur(hsvMedianCurrent, hsvMedianCurrent, cv::Size(5,5), 0);
    // マスク
    cv::Mat hsvMask;
    cv::Scalar HSV_MIN = cv::Scalar(0, 58, 88);
    cv::Scalar HSV_MAX = cv::Scalar(25, 173, 229);
    //cv::Scalar RGB_MIN = cv::Scalar(110, 90, 70);
    //cv::Scalar RGB_MAX = cv::Scalar(230, 200, 200);
    
    
    cv::inRange(hsvMedianCurrent, HSV_MIN, HSV_MAX, hsvMask);
    //cv::inRange(hsvMedianCurrent, RGB_MIN, RGB_MAX, hsvMask);
    
    // カタマリ
    std::vector< std::vector < cv::Point > > vctContours;
    std::vector < cv::Vec4i > hierarchy;
    cv::findContours(hsvMask, vctContours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);
    cv::Mat matDrawnContour = cv::Mat::zeros(hsvMask.size(), CV_8UC3 );
    cv::Mat mask = cv::Mat::zeros(hsvMask.size(), CV_8UC1 );
    cv::Mat _out;//cv::Mat::zeros(hsvMask.size(), CV_8UC1 );
    bgrMat.copyTo(_out);
    //_out.setTo(cv::Scalar(0, 255, 0));
    
    int max_level = 0;
    double max_area = 0.0f;
    int max_idx = 0;
    for (int i = 0; i< vctContours.size(); i++){
        // 面積
        double area = cv::contourArea(vctContours[i], false);
        
        if (max_area < area){
            max_area = area;
            max_idx = i;
            // 輪郭を直線近似
            //std::vector< cv::Point > approx;
            //cv::approxPolyDP(cv::Mat(vctContours[i]), approx, 0.01 * cv::arcLength(vctContours[i], true), true);
        }
    }
    if (max_idx != 0){
        //cv::drawContours(matDrawnContour, vctContours, max_idx, cv::Scalar(255,0,0,255), 3, CV_AA, hierarchy, max_level);

        cv::drawContours(mask, vctContours, max_idx, cv::Scalar(255), CV_FILLED);
        currentMat.copyTo(_out, mask);
        //_out[mask == 255] = grayCurrent[mask == 255];
        /* cv::fillConvexPoly(matDrawnContour, vctContours[max_idx], (255, 60, 60)); */
        
    }

    
    // 輪郭
    //int i = 0;
    //for ( int i = intContourCount; intContourCount <= i; i--)
    
    /*
    for (auto contour = vctContours.begin(); contour != vctContours.end(); contour++)
    {
        std::vector< cv::Point > approx;
        // 輪郭を直線近似
        cv::approxPolyDP(cv::Mat(*contour), approx, 0.01 * cv::arcLength(*contour, true), true);
        
        double area = cv::contourArea(approx);

        if ( area > 1000 )
        {
            printf("area%lf\n", area);
            // 色の値を生成
            sclColor = cv::Scalar(255, 0, 0 );
            // 番号指定して色を付ける
            //cv::drawContours(hsvMask, vctContours, i, sclColor);
            cv::drawContours(matDrawnContour, vctContours, intContourCount, sclColor);
            
            // 矩形描画
            Rect rectOfArea = cv::boundingRect(contour);

        }
        
        i++;
    }
    */
    

    
    //UIImage *grayImage = MatToUIImage(diffThMat);
    //UIImage *grayImage = MatToUIImage(hsvMask);
    //UIImage *grayImage = MatToUIImage(matDrawnContour);
    //UIImage *grayImage = MatToUIImage(mask);
    UIImage *grayImage = MatToUIImage(_out);
    
    
    //UIImage *grayImage = MatToUIImage(grayMat);
    return RestoreUIImageOrientation(grayImage, image);
    //return grayImage;
}

@end
