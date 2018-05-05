//
//  OpenCV.h
//  OpenCVSample_iOS
//
//

#import <UIKit/UIKit.h>

@interface OpenCV : NSObject

/// Converts a full color image to grayscale image with using OpenCV.
+ (nonnull UIImage *)cvtColorBGR2GRAY:(nonnull UIImage *)image;
+ (nonnull UIImage *)cvtSubtractBackground:(nonnull UIImage *)image;
+ (nonnull UIImage *)cvtBinarizeImage:(nonnull UIImage *)image backgroundImg:(nonnull UIImage *)backgroundImg backgroundScale:(float)backgroundScale;

@end
