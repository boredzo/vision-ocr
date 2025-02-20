//
//  main.m
//  vision-ocr
//
//  Created by Peter Hosey on 2025-02-19.
//

#import <sysexits.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#import "PRHScannableFrame.h"
#import "PRHImageScanner.h"

static int usage(FILE *_Nonnull const outFile) {
	fprintf(outFile, "Usage: vision-ocr input-file [frames]\n");
	fprintf(outFile, "input-file can be any image file in a common image format like PNG or JPEG.\n");
	fprintf(outFile, "frames are zero or more rectangles in the form “[name=]X,Y,WxH”. Units are in pixels unless specified (e.g., 2cm). Origin is upper-left for positive coordinates, lower-right for negative. If no frames specified, scan the entire image. If frames are named (e.g., pageNumber=-2cm,-2cm,2cmx2cm), output will be CSV of name,value.\n");
	return outFile == stderr ? EX_USAGE : EXIT_SUCCESS;
}

bool debugMode = false;

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSEnumerator <NSString *> *_Nonnull const argsEnum = [[NSProcessInfo processInfo].arguments objectEnumerator];
		[argsEnum nextObject];

		NSString *_Nullable firstArg = [argsEnum nextObject];
		if ([firstArg isEqualToString:@"--debug"]) {
			debugMode = true;
			firstArg = [argsEnum nextObject];
		}

		NSString *_Nullable const imagePath = firstArg;
		if (imagePath == nil) {
			return usage(stderr);
		} else if ([imagePath isEqualToString:@"--help"]) {
			return usage(stdout);
		}
		NSURL *_Nonnull const imageURL = [NSURL fileURLWithPath:imagePath isDirectory:false];

		CGImageSourceRef _Nonnull const src = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, /*options*/ NULL);
		NSDictionary <NSString *, NSNumber *> *_Nullable const imageProps = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, /*idx*/ 0, /*options*/ NULL);

		bool anyFrameHasAName = false;
		NSArray <NSString *> *_Nonnull const frameStrings = [argsEnum allObjects];
		NSMutableArray <PRHScannableFrame *> *_Nonnull const frames = [NSMutableArray arrayWithCapacity:frameStrings.count];
		for (NSString *_Nonnull const str in frameStrings) {
			PRHScannableFrame *_Nullable const frame = [PRHScannableFrame frameWithString:str imageProperties:imageProps];
			if (frame.name != nil && frame.name.length > 0) {
				anyFrameHasAName = true;
			}
			[frames addObject:frame];
		}
		if (frames.count == 0) {
			[frames addObject:[PRHScannableFrame frameWithExtentFromImageProperties:imageProps]];
		}

		CGImageRef _Nonnull const image = CGImageSourceCreateImageAtIndex(src, /*idx*/ 0, /*options*/ NULL);
		PRHImageScanner *_Nonnull const imageScanner = [PRHImageScanner scannerWithImage:image properties:imageProps];

		if (anyFrameHasAName) {
			printf("Name,Value\n");
		}
		[imageScanner scanFrames:frames resultHandler:^(NSString *_Nullable name, NSString *_Nullable value) {
			if (anyFrameHasAName) {
				printf("%s,%s\n", name.UTF8String ?: "", value ? value.UTF8String : "");
			} else {
				printf("%s\n", value ? value.UTF8String : "");
			}
		}];

		CFRelease(image);
		CFRelease(src);
	}
	return EXIT_SUCCESS;
}
