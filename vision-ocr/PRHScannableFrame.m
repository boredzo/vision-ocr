//
//  PRHScannableFrame.m
//  vision-ocr
//
//  Created by Peter Hosey on 2025-02-19.
//

#import "PRHScannableFrame.h"

#import <ImageIO/ImageIO.h>

extern bool debugMode;

static CGFloat convertFromUnitToPixels(CGFloat const value, NSString *_Nullable const unit);

@implementation PRHScannableFrame
{
	NSUInteger dpiX, dpiY;
}

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

	dpiX = imageProps[(__bridge NSString *)kCGImagePropertyDPIWidth].integerValue;
	dpiY = imageProps[(__bridge NSString *)kCGImagePropertyDPIHeight].integerValue;

	NSString *_Nullable name = nil;
	[scanner scanUpToString:@"=" intoString:&name];
	if (name != nil && name.length == 0) {
		name = nil;
	}

	CGFloat xCoord = 0, yCoord = 0;
	NSString *_Nullable xUnit = nil;
	NSString *_Nullable yUnit = nil;
	CGFloat width = 0, height = 0;
	NSString *_Nullable widthUnit = nil;
	NSString *_Nullable HeightUnit = nil;

	[scanner scanDouble:&xCoord];
	[scanner scanUpToString:@"," intoString:&xUnit];
	[scanner scanString:@"," intoString:NULL];
	[scanner scanDouble:&yCoord];
	[scanner scanUpToString:@"," intoString:&yUnit];
	[scanner scanString:@"," intoString:NULL];

	[scanner scanDouble:&width];
	[scanner scanString:@"cm" intoString:&xUnit];
	[scanner scanString:@"mm" intoString:&xUnit];
	[scanner scanString:@"in" intoString:&xUnit];
	[scanner scanString:@"," intoString:NULL];
	[scanner scanString:@"x" intoString:NULL];
	[scanner scanDouble:&height];
	[scanner scanString:@"cm" intoString:&yUnit];
	[scanner scanString:@"mm" intoString:&yUnit];
	[scanner scanString:@"in" intoString:&yUnit];

	self = [self initWithName:name
		x:convertFromUnitToPixels(xCoord, xUnit)
		y:convertFromUnitToPixels(yCoord, yUnit)
		width:convertFromUnitToPixels(width, widthUnit)
		height:convertFromUnitToPixels(height, HeightUnit)];

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

static CGFloat convertFromUnitToPixels(CGFloat const value, NSString *_Nullable const unit) {
#warning TODO: Implement in, cm, mm units
	return value;
}
