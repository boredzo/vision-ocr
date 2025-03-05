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
	fprintf(outFile, "Usage: vision-ocr [options] input-file [frames]\n");
	fprintf(outFile, "input-file can be any image file in a common image format like PNG or JPEG.\n");
	fprintf(outFile, "frames are zero or more rectangles in the form “[name=]X,Y,WxH”. Units are in pixels unless specified (e.g., 2cm). Origin is upper-left for positive coordinates, lower-right for negative. If no frames specified, scan the entire image. If frames are named (e.g., pageNumber=-2cm,-2cm,2cmx2cm), output will be CSV.\n");
	fprintf(outFile, "\n");
	fprintf(outFile, "Options:\n");
	fprintf(outFile, "--transpose: Default is to emit one row per image. With --transpose, output will be one row per frame: name,value.\n");
	fprintf(outFile, "--header: Default is to emit a header row before any data rows. With --no-header, header row will be omitted (this enables concatenating output from multiple runs).\n");
	return outFile == stderr ? EX_USAGE : EXIT_SUCCESS;
}

bool transposeOutput = false;
bool includeHeaderRow = true;
bool debugMode = false;

static NSString *_Nonnull const PRHEscapeForCSV(NSString *_Nullable const value);

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSEnumerator <NSString *> *_Nonnull const argsEnum = [[NSProcessInfo processInfo].arguments objectEnumerator];
		[argsEnum nextObject];

		/*TODO: Options to add:
		 * --output-format=csv/tsv/json/plist: Write output as comma-separated values, tab-separated values, or a JSON or property-list dictionary. Note that all dictionary values will be strings.
		 * --transpose: Each row should be name,value
		 * --no-transpose (should be new default): Each row should be filename,frame_value,frame_value,frame_value,…
		 * --no-filename: Don't include filename in multi-column output
		 * --no-header: Don't print the header row
		 * --prefilters=red,green,blue,cyan,magenta,yellow,invert,levels(BP,G,WP),rotate(angle): Pre-filter the image before scanning.
		 *	red: Take only the red channel and splat it across all channels.
		 *	green, blue: Same thing from each of those channels.
		 *	cyan, magenta, yellow: Take two channels, average them, and splat across all channels. E.g., cyan = (red + green) / 2.
		 *	invert: Exactly what it sounds like. Likely works best on B&W images.
		 *	levels: Levels filter. Set black point at BP (default=0%), white point at WP (100%), gamma at G (1.0).
		 *	rotate: Rotate the image counter-clockwise around the center by some angle. angle should be a number followed by a degree sign (e.g., -0.1°).
		 *	Prefilters can be specified in any order and multiple times.
		 */
		//TODO: Implement CSV-compliant value escaping.

		bool optionsAllowed = true;
		NSString *_Nullable imagePath = nil;
		NSArray <NSString *> *_Nullable frameStrings = nil;

		for (NSString *_Nonnull const arg in argsEnum) {
			bool optionParsed = false;

			if (optionsAllowed) {
				if ([arg isEqualToString:@"--debug"]) {
					debugMode = true;
					optionParsed = true;
				} else if ([arg isEqualToString:@"--transpose"]) {
					transposeOutput = true;
					optionParsed = true;
				} else if ([arg isEqualToString:@"--no-transpose"]) {
					transposeOutput = false;
					optionParsed = true;
				} else if ([arg isEqualToString:@"--header"]) {
					includeHeaderRow = true;
					optionParsed = true;
				} else if ([arg isEqualToString:@"--no-header"]) {
					includeHeaderRow = false;
					optionParsed = true;
				} else if ([arg isEqualToString:@"--help"]) {
					return usage(stdout);
				} else if ([arg isEqualToString:@"--"]) {
					optionsAllowed = false;
					optionParsed = true;
				}
			}

			if (! optionParsed) {
				optionsAllowed = false;

				imagePath = arg;
				frameStrings = [argsEnum allObjects];
				//Note: This exhausts argsEnum, which will end the loop
			}
		}

		if (imagePath == nil) {
			return usage(stderr);
		}
		NSURL *_Nonnull const imageURL = [NSURL fileURLWithPath:imagePath isDirectory:false];

		CGImageSourceRef _Nonnull const src = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, /*options*/ NULL);
		NSDictionary <NSString *, NSNumber *> *_Nullable const imageProps = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, /*idx*/ 0, /*options*/ NULL);

		bool anyFrameHasAName = false;
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

		if (transposeOutput) {
			//Header row is always suppressed if all frames are unnamed. In that case, you get each value on one row.
			if (includeHeaderRow || anyFrameHasAName) {
				printf("Name,Value\n");
			}
			[imageScanner scanFrames:frames resultHandler:^(NSString *_Nullable name, NSString *_Nullable value) {
				if (anyFrameHasAName) {
					printf("%s,%s\n", name.UTF8String ?: "", PRHEscapeForCSV(value).UTF8String);
				} else {
					printf("%s\n", (value ?: @"").UTF8String);
				}
			}];
		} else {
			if (includeHeaderRow) {
				NSMutableArray <NSString *> *_Nonnull const headerRow = [NSMutableArray arrayWithCapacity:1 + frames.count];
				[headerRow addObject:@"Image file"];
				for (PRHScannableFrame *_Nonnull const frame in frames) {
					[headerRow addObject:frame.name ?: @""];
				}

				printf("%s\n", [headerRow componentsJoinedByString:@","].UTF8String);
			}

			NSMutableArray <NSString *> *_Nonnull const dataRow = [NSMutableArray arrayWithCapacity:1 + frames.count];
			[dataRow addObject:imagePath];
			[imageScanner scanFrames:frames resultHandler:^(NSString *_Nullable name, NSString *_Nullable value) {
				[dataRow addObject:PRHEscapeForCSV(value)];
			}];

			printf("%s\n", [dataRow componentsJoinedByString:@","].UTF8String);
		}

		CFRelease(image);
		CFRelease(src);
	}
	return EXIT_SUCCESS;
}

static NSString *_Nonnull const PRHEscapeForCSV(NSString *_Nullable const value) {
	return [NSString stringWithFormat:@"\"%@\"", [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""] ?: @""];
}
