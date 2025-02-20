//
//  PRHScannableFrame.m
//  vision-ocr
//
//  Created by Peter Hosey on 2025-02-19.
//

#import "PRHScannableFrame.h"

#import <ImageIO/ImageIO.h>

extern bool debugMode;

enum PRHDimension {
	PRHDimensionX,
	PRHDimensionY,
};

static CGFloat convertFromUnitToPixels(CGFloat const value, NSString *_Nullable const unit, NSDictionary <NSString *, NSNumber *> *_Nullable const imageProps, enum PRHDimension const dim);

@implementation PRHScannableFrame

+ (instancetype _Nullable) frameWithString:(NSString *_Nonnull const)str imageProperties:(NSDictionary <NSString *, NSNumber *> *_Nullable const)imageProps {
	return [[self alloc] initWithString:str imageProperties:imageProps];
}
+ (instancetype _Nonnull) frameWithName:(NSString *_Nullable const)name x:(CGFloat const)xCoord y:(CGFloat const)yCoord width:(CGFloat const)width height:(CGFloat const)height {
	return [[self alloc] initWithName:name x:xCoord y:yCoord width:width height:height];
}
+ (instancetype _Nonnull) frameWithExtentFromImageProperties:(NSDictionary <NSString *, NSNumber *> *_Nonnull const)imageProps {
	CGFloat const width = (imageProps[(__bridge NSString *)kCGImagePropertyPixelWidth] ?: imageProps[(__bridge NSString *)kCGImagePropertyWidth]).doubleValue;
	CGFloat const height = (imageProps[(__bridge NSString *)kCGImagePropertyPixelHeight] ?: imageProps[(__bridge NSString *)kCGImagePropertyHeight]).doubleValue;
	return [self frameWithName:@"extent"
		x:0.0
		y:0.0
		width:width
		height:height];
}

- (instancetype _Nullable) initWithString:(NSString *_Nonnull const)str imageProperties:(NSDictionary <NSString *, NSNumber *> *_Nullable const)imageProps {
	NSScanner *_Nonnull const scanner = [NSScanner scannerWithString:str];

	CGFloat const imageWidth = (imageProps[(__bridge NSString *)kCGImagePropertyPixelWidth] ?: imageProps[(__bridge NSString *)kCGImagePropertyWidth]).doubleValue;
	CGFloat const imageHeight = (imageProps[(__bridge NSString *)kCGImagePropertyPixelHeight] ?: imageProps[(__bridge NSString *)kCGImagePropertyHeight]).doubleValue;

	NSString *_Nullable name = nil;
	[scanner scanUpToString:@"=" intoString:&name];
	if (name != nil && name.length == 0) {
		name = nil;
	}
	[scanner scanString:@"=" intoString:NULL];

	CGFloat xCoord = 0, yCoord = 0;
	NSString *_Nullable xUnit = nil;
	NSString *_Nullable yUnit = nil;
	CGFloat width = 0, height = 0;
	NSString *_Nullable widthUnit = nil;
	NSString *_Nullable heightUnit = nil;

	NSArray <NSString *> *_Nonnull const unitNames = @[
		@"%",
		@"cm", @"mm",
		//Note that order matters when some units are potential prefixes of others. We need to try the longest string first.
		@"inches", @"inch", @"in",
	];

	[scanner scanDouble:&xCoord];
	for (NSString *_Nonnull const unitCandidate in unitNames) {
		if ([scanner scanString:unitCandidate intoString:&xUnit]) {
			break;
		}
	}
	[scanner scanString:@"," intoString:NULL];
	[scanner scanDouble:&yCoord];
	for (NSString *_Nonnull const unitCandidate in unitNames) {
		if ([scanner scanString:unitCandidate intoString:&yUnit]) {
			break;
		}
	}
	[scanner scanString:@"," intoString:NULL];

	[scanner scanDouble:&width];
	for (NSString *_Nonnull const unitCandidate in unitNames) {
		if ([scanner scanString:unitCandidate intoString:&widthUnit]) {
			break;
		}
	}
	[scanner scanString:@"," intoString:NULL];
	[scanner scanString:@"x" intoString:NULL];
	[scanner scanDouble:&height];
	for (NSString *_Nonnull const unitCandidate in unitNames) {
		if ([scanner scanString:unitCandidate intoString:&heightUnit]) {
			break;
		}
	}

	CGFloat xAbsPixels = signbit(xCoord)
		? imageWidth + convertFromUnitToPixels(xCoord, xUnit, imageProps, PRHDimensionX)
		: convertFromUnitToPixels(xCoord, xUnit, imageProps, PRHDimensionX);
	CGFloat yAbsPixels = signbit(yCoord)
		? imageHeight + convertFromUnitToPixels(yCoord, yUnit, imageProps, PRHDimensionY)
		: convertFromUnitToPixels(yCoord, yUnit, imageProps, PRHDimensionY);
	if (debugMode) {
		NSLog(@"Input origin: %.1f, %.1f", xCoord, yCoord);
		NSLog(@"Image WAH: %.1f, %.1f", imageWidth, imageHeight);
		NSLog(@"Converted origin: %.1f, %.1f", xAbsPixels, yAbsPixels);
	}
	CGFloat widthPixels = convertFromUnitToPixels(width, widthUnit, imageProps, PRHDimensionX);
	if (signbit(widthPixels)) {
		widthPixels = -widthPixels;
		xAbsPixels -= widthPixels;
	}
	CGFloat heightPixels = convertFromUnitToPixels(height, heightUnit, imageProps, PRHDimensionY);
	if (signbit(heightPixels)) {
		heightPixels = -heightPixels;
		yAbsPixels -= heightPixels;
	}
	if (debugMode) {
		NSLog(@"Final origin: %.1f, %.1f", xAbsPixels, yAbsPixels);
	}

	self = [self initWithName:name
		x:xAbsPixels
		y:yAbsPixels
		width:widthPixels
		height:heightPixels];

	if (debugMode) {
		NSLog(@"%@ → %@=%f,%f,%fx%f", str, self.name ?: @"''", self.xCoordinate, self.yCoordinate, self.width, self.height);
	}

	return self;
}

- (instancetype _Nonnull) initWithName:(NSString *_Nullable const)name x:(CGFloat const)xCoord y:(CGFloat const)yCoord width:(CGFloat const)width height:(CGFloat const)height {
	if ((self = [super init])) {
		self.name = name;
		self.xCoordinate = xCoord;
		self.yCoordinate = yCoord;
		self.width = width;
		self.height = height;
	}

	return self;
}

- (NSString *_Nonnull) description {
	return [NSString stringWithFormat:@"<%@ %p “%@”>", self.class, self, self.name];
}

@end

static CGFloat convertFromUnitToPixels(CGFloat const value, NSString *_Nullable const unit, NSDictionary <NSString *, NSNumber *> *_Nullable const imageProps, enum PRHDimension const dim) {

	CGFloat const dpiX = imageProps[(__bridge NSString *)kCGImagePropertyDPIWidth].doubleValue;
	CGFloat const dpiY = imageProps[(__bridge NSString *)kCGImagePropertyDPIHeight].doubleValue;

	CGFloat const imageWidth = (imageProps[(__bridge NSString *)kCGImagePropertyPixelWidth] ?: imageProps[(__bridge NSString *)kCGImagePropertyWidth]).doubleValue;
	CGFloat const imageHeight = (imageProps[(__bridge NSString *)kCGImagePropertyPixelHeight] ?: imageProps[(__bridge NSString *)kCGImagePropertyHeight]).doubleValue;

	if ([unit isEqualToString:@"%"]) {
		CGFloat const fraction = value / 100.0;
		return fraction * ((dim == PRHDimensionX)
			? imageWidth
			: imageHeight);
	} else if ([unit hasPrefix:@"in"]) {
		CGFloat const inches = value;
		CGFloat const pixels = inches * (dim == PRHDimensionX ? dpiX : dpiY);
		return pixels;
	} else if ([unit hasPrefix:@"mm"]) {
		CGFloat const millimeters = value;
		CGFloat const inches = millimeters / 25.4;
		CGFloat const pixels = inches * (dim == PRHDimensionX ? dpiX : dpiY);
		return pixels;
	} else if ([unit hasPrefix:@"cm"]) {
		CGFloat const centimeters = value;
		CGFloat const inches = centimeters / 2.54;
		CGFloat const pixels = inches * (dim == PRHDimensionX ? dpiX : dpiY);
		return pixels;
	}

	return value;
}
