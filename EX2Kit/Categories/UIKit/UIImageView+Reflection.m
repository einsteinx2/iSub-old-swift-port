//
//  UIImageView+Reflection.m
//  iSub
//
//  Created by Ben Baron on 2/9/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UIImageView+Reflection.h"

@implementation UIImageView (Reflection)

CGImageRef CreateGradientImageRef(CGSize size);
CGContextRef CreateReflectionBitmapContext(CGSize size);

CGImageRef CreateGradientImageRef(CGSize size)
{
	CGImageRef theCGImage = NULL;
	
	// gradient is always black-white and the mask must be in the gray colorspace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	
	// create the bitmap context
	CGContextRef gradientBitmapContext = CGBitmapContextCreate(NULL, size.width, size.height,
															   8, 0, colorSpace, kCGImageAlphaNone);
	
	// define the start and end grayscale values (with the alpha, even though
	// our bitmap context doesn't support alpha the gradient requires it)
	CGFloat colors[] = {0.0, 1.0, 1.0, 1.0};
	
	// create the CGGradient and then release the gray color space
	CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
	CGColorSpaceRelease(colorSpace);
	
	// create the start and end points for the gradient vector (straight down)
	CGPoint gradientStartPoint = CGPointZero;
	CGPoint gradientEndPoint = CGPointMake(0, size.height);
	
	// draw the gradient into the gray bitmap context
	CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
								gradientEndPoint, kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(grayScaleGradient);
	
	// convert the context into a CGImageRef and release the context
	theCGImage = CGBitmapContextCreateImage(gradientBitmapContext);
	CGContextRelease(gradientBitmapContext);
	
	// return the imageref containing the gradient
    return theCGImage;
}

CGContextRef CreateReflectionBitmapContext(CGSize size)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	// create the bitmap context
	CGContextRef bitmapContext = CGBitmapContextCreate (NULL, size.width, size.height, 8,
														0, colorSpace,
														// this will give us an optimal BGRA format for the device:
														(kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
	CGColorSpaceRelease(colorSpace);
	
    return bitmapContext;
}

- (UIImage *)reflectedImageWithHeight:(NSUInteger)height
{
    if(height == 0)
		return nil;
	
	CGFloat theWidth = self.bounds.size.width * SCREEN_SCALE();
	CGFloat theHeight = height * SCREEN_SCALE();
    
	// create a bitmap graphics context the size of the image
	CGSize size = CGSizeMake(theWidth, theHeight);
	CGContextRef mainViewContentContext = CreateReflectionBitmapContext(size);
	
	// create a 2 bit CGImage containing a gradient that will be used for masking the 
	// main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
	// function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
	CGImageRef gradientMaskImage = CreateGradientImageRef(CGSizeMake(1, theHeight));
	
	// create an image by masking the bitmap of the mainView content with the gradient view
	// then release the  pre-masked content bitmap and the gradient bitmap
	CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, theWidth, theHeight), gradientMaskImage);
	CGImageRelease(gradientMaskImage);
	
	// In order to grab the part of the image that we want to render, we move the context origin to the
	// height of the image that we want to capture, then we flip the context so that the image draws upside down.
	CGContextTranslateCTM(mainViewContentContext, 0.0, theHeight);
	CGContextScaleCTM(mainViewContentContext, 1.0, -1.0);
	
	// draw the image into the bitmap context
	CGRect frame = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width * SCREEN_SCALE(), self.bounds.size.height * SCREEN_SCALE());
	CGContextDrawImage(mainViewContentContext, frame, self.image.CGImage);
	
	// create CGImageRef of the main view bitmap content, and then release that bitmap context
	CGImageRef reflectionImage = CGBitmapContextCreateImage(mainViewContentContext);
	CGContextRelease(mainViewContentContext);
	
	// convert the finished reflection image to a UIImage 
	UIImage *theImage = [UIImage imageWithCGImage:reflectionImage];
	
	// image is retained by the property setting above, so we can release the original
	CGImageRelease(reflectionImage);
	
	return theImage;
}


@end
