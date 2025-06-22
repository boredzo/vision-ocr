 //
//  PRHImageScanner.m
//  vision-ocr
//
//  Created by Peter Hosey on 2025-02-19.
//

#import "PRHImageScanner.h"

#import <Vision/Vision.h>

#import "PRHScannableFrame.h"

extern bool debugMode;

@implementation PRHImageScanner
{
	CGImageRef _Nonnull _image;
	NSDictionary *_Nullable _imageProps;
}

+ (instancetype _Nonnull) scannerWithImage:(CGImageRef _Nonnull const)image properties:(NSDictionary *_Nullable const)imageProps {
	return [[self alloc] initWithImage:image properties:imageProps];
}
- (instancetype _Nonnull) initWithImage:(CGImageRef _Nonnull const)image properties:(NSDictionary *_Nullable const)imageProps {
	if ((self = [super init])) {
		_image = (CGImageRef)CFRetain(image);
		_imageProps = [imageProps copy];
	}
	return self;
}

- (PRHScannableFrame *_Nonnull const) extent {
	return [PRHScannableFrame frameWithName:@"extent"
		x:0.0
		y:0.0
		width:CGImageGetWidth(_image)
		height:CGImageGetHeight(_image)];
}

- (NSString *_Nullable) scanFrame:(PRHScannableFrame *_Nonnull const)frame {
	__block NSString *_Nullable result = nil;
	VNRecognizeTextRequest *_Nonnull const request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *_Nonnull completedRequest, NSError *_Nullable error) {
		VNRecognizeTextRequest *_Nonnull const completedTextRequest = (VNRecognizeTextRequest *_Nonnull)completedRequest;
		NSMutableArray *_Nonnull const lines = [NSMutableArray arrayWithCapacity:1];
		for (VNRecognizedTextObservation *_Nonnull const obs in completedTextRequest.results) {
			NSString *_Nullable const topCandidate = [obs topCandidates:1].firstObject.string;
			if (topCandidate != nil) {
				[lines addObject:topCandidate];
			}
		}
		if (lines.count > 0) {
			result = [lines componentsJoinedByString:@"\n"];
		} else {
			result = nil;
		}
	}];

	CGFloat const imageWidth = CGImageGetWidth(_image);
	CGFloat const imageHeight = CGImageGetHeight(_image);
	request.regionOfInterest = (struct CGRect){
		{ frame.xCoordinate * imageWidth, frame.yCoordinate * imageHeight },
		{ frame.width / imageWidth, frame.height / imageHeight}
	};

	if (self.languageCodes) {
		request.recognitionLanguages = self.languageCodes;
	}

	VNImageRequestHandler *_Nonnull const handler = [[VNImageRequestHandler alloc] initWithCGImage:_image options:@{ VNImageOptionProperties: _imageProps }];

	NSError *_Nullable error = nil;
	if (! [handler performRequests:@[ request ] error:&error] ) {
		NSLog(@"Scan of frame %@ failed: %@", frame.name, error.localizedDescription);
	}

	return result;
}

- (NSDictionary <NSString *, NSString *> *_Nonnull) scanFrames:(NSArray <PRHScannableFrame *> *_Nonnull const)frames
	resultHandler:(void (^_Nonnull const)(NSString *_Nullable name, NSString *_Nullable value))resultHandler
{
	CGFloat const imageWidth = CGImageGetWidth(_image);
	CGFloat const imageHeight = CGImageGetHeight(_image);

	NSUInteger const numFrames = frames.count;
	NSMutableArray <VNRecognizeTextRequest *> *_Nonnull const requests = [NSMutableArray arrayWithCapacity:numFrames];
	NSMutableDictionary <NSString *, PRHScannableFrame *> *_Nonnull const requestToFrameMap = [NSMutableDictionary dictionaryWithCapacity:numFrames];
	NSMutableDictionary <VNRecognizeTextRequest *, NSString *> *_Nonnull const requestToResultMap = [NSMutableDictionary dictionaryWithCapacity:numFrames];
	NSMutableDictionary <NSString *, NSString *> *_Nonnull const frameNameToResultMap = [NSMutableDictionary dictionaryWithCapacity:numFrames];

	void (^_Nonnull const completionHandler)(VNRequest *_Nonnull completedRequest, NSError *_Nullable error) = ^(VNRequest *_Nonnull completedRequest, NSError *_Nullable error) {
		VNRecognizeTextRequest *_Nonnull const completedTextRequest = (VNRecognizeTextRequest *_Nonnull)completedRequest;
		NSMutableArray *_Nonnull const lines = [NSMutableArray arrayWithCapacity:1];
		for (VNRecognizedTextObservation *_Nonnull const obs in completedTextRequest.results) {
			NSString *_Nullable const topCandidate = [obs topCandidates:1].firstObject.string;
			if (topCandidate != nil) {
				[lines addObject:topCandidate];
			}
		}
		if (lines.count > 0) {
			NSString *_Nonnull const result = [lines componentsJoinedByString:@"\n"];
			requestToResultMap[completedTextRequest] = result;
			PRHScannableFrame *_Nonnull const frame = requestToFrameMap[completedTextRequest.description];
			frameNameToResultMap[frame.name ?: @""] = result;
		}
	};

	for (PRHScannableFrame *_Nonnull const frame in frames) {
		VNRecognizeTextRequest *_Nonnull const request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:completionHandler];

		request.regionOfInterest = (struct CGRect){
			{ frame.xCoordinate / imageWidth, 1.0 - frame.yCoordinate / imageHeight },
			{ frame.width / imageWidth, frame.height / -imageHeight}
		};
		if ((frame.xCoordinate / imageWidth + frame.width / imageWidth) >= 1.0) {
			NSLog(@"%@: Frame has invalid bounds: %@\nBounds: %f,%f,%fx%f", self.imagePath, frame, frame.xCoordinate, frame.yCoordinate, frame.width, frame.height);
		}

		if (self.languageCodes) {
			request.recognitionLanguages = self.languageCodes;
		}

		requestToFrameMap[request.description] = frame;
		[requests addObject:request];
	}

	VNImageRequestHandler *_Nonnull const requestHandler = [[VNImageRequestHandler alloc] initWithCGImage:_image options:@{ VNImageOptionProperties: _imageProps }];

	NSError *_Nullable error = nil;
	if (! [requestHandler performRequests:requests error:&error] ) {
		NSLog(@"Scan of %lu frames failed: %@", frames.count, error.localizedDescription);
	}

	for (PRHScannableFrame *_Nonnull const frame in frames) {
		NSString *_Nonnull const frameName = frame.name ?: @"";
		resultHandler(frameName, frameNameToResultMap[frameName]);
	}
	return frameNameToResultMap;
}

@end
