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
	fprintf(outFile, "Usage: vision-ocr [options] input-files [frames]\n");
	fprintf(outFile, "input-files is one or more paths to image files in common image formats such as PNG or JPEG.\n");
	fprintf(outFile, "frames are zero or more rectangles in the form “[name=]X,Y,WxH”. Units are in pixels unless specified (e.g., 2cm). Origin is upper-left for positive coordinates, lower-right for negative. If no frames specified, scan the entire image. If frames are named (e.g., pageNumber=-2cm,-2cm,2cmx2cm), output will be CSV.\n");
	fprintf(outFile, "\n");
	fprintf(outFile, "Options:\n");
	fprintf(outFile, "--transpose: Default is to emit one row per image. With --transpose, output will be one row per frame: name,value.\n");
	fprintf(outFile, "--header: Default is to emit a header row before any data rows. With --no-header, header row will be omitted (this enables concatenating output from multiple runs).\n");
	fprintf(outFile, "--languages=LANGS: LANGS is a comma-separated of ISO language codes to direct the recognizer to favor.\n");
	return outFile == stderr ? EX_USAGE : EXIT_SUCCESS;
}

bool transposeOutput = false;
bool includeHeaderRow = true;
bool debugMode = false;

static NSString *_Nonnull const PRHEscapeForCSV(NSString *_Nullable const value);

static CGImageRef _Nullable const PRHLoadImageFromFile(NSURL *_Nonnull const fileURL, NSDictionary <NSString *, NSNumber *> *_Nullable *_Nullable const outProps);
static CGImageRef _Nullable const PRHLoadImageFromRasterFile(NSURL *_Nonnull const fileURL, NSDictionary <NSString *, NSNumber *> *_Nullable *_Nullable const outProps);
static CGImageRef _Nullable const PRHLoadImageFromPDFFile(NSURL *_Nonnull const fileURL, NSDictionary <NSString *, NSNumber *> *_Nullable *_Nullable const outProps);

int main(int argc, const char * argv[]) {
	int status = EXIT_SUCCESS;

	@autoreleasepool {
		NSArray <NSString *> *_Nonnull const args = [NSProcessInfo processInfo].arguments;
		NSEnumerator <NSString *> *_Nonnull const argsEnum = [args objectEnumerator];
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
		bool expectLanguages = false;
		NSArray <NSString *> *_Nullable languageCodes = nil;
		NSMutableArray <NSString *> *_Nonnull const imagePaths = [NSMutableArray arrayWithCapacity:args.count];
		NSArray <NSString *> *_Nullable frameStrings = nil;
		NSFileManager *_Nonnull const mgr = [NSFileManager defaultManager];

		for (NSString *_Nonnull const arg in argsEnum) {
			bool optionParsed = false;

			if (expectLanguages) {
				languageCodes = [arg componentsSeparatedByString:@","];
				expectLanguages = false;
				continue;
			}

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
				} else if ([arg isEqualToString:@"--languages"]) {
					expectLanguages = true;
					optionParsed = true;
				} else if ([arg hasPrefix:@"--languages="]) {
					NSString *_Nonnull const payload = [arg substringFromIndex:@"--languages=".length];
					languageCodes = [payload componentsSeparatedByString:@","];
					optionParsed = true;
				} else if ([arg isEqualToString:@"--help"]) {
					return usage(stdout);
				} else if ([arg isEqualToString:@"--"]) {
					optionsAllowed = false;
					optionParsed = true;
				}

				if (! optionParsed) {
					optionsAllowed = false;
				}
			}

			if (! optionsAllowed) {
				if ([arg containsString:@"/"]) {
					[imagePaths addObject:arg];
				} else if ([mgr fileExistsAtPath:arg]) {
					[imagePaths addObject:arg];
				} else if (! [arg containsString:@","]) {
					//Doesn't look like a frame rectangle, but it doesn't exist.
					fprintf(stderr, "error: Not an extant file or frame rectangle: %s\n", arg.UTF8String);
					return EX_NOINPUT;
				} else {
					//Not an extant file. Assume this is a frame.
					frameStrings = [@[ arg ] arrayByAddingObjectsFromArray:[argsEnum allObjects]];
					//Note: This exhausts argsEnum, which will end the loop
				}
			}
		}

		if (imagePaths.count == 0) {
			return usage(stderr);
		}

		bool anyFrameHasAName = false;
		//We can't parse the real frames once for all images because their interpretation may differ by image (e.g., one being 300 DPI and another being 600 DPI, real-world units will equate to different numbers of pixels). So we parse them here without DPI info just to get the names, and then again for each image.
		NSMutableArray <PRHScannableFrame *> *_Nonnull const dimensionlessFrames = [NSMutableArray arrayWithCapacity:frameStrings.count];
		for (NSString *_Nonnull const str in frameStrings) {
			PRHScannableFrame *_Nullable const frame = [PRHScannableFrame frameWithString:str imageProperties:nil];
			if (frame.name != nil && frame.name.length > 0) {
				anyFrameHasAName = true;
			}
			[dimensionlessFrames addObject:frame];
		}

		if (transposeOutput) {
			//Header row is always suppressed if all frames are unnamed. In that case, you get each value on one row.
			if (includeHeaderRow || anyFrameHasAName) {
				printf("Name,Value\n");
			}
		} else {
			if (includeHeaderRow) {
				NSMutableArray <NSString *> *_Nonnull const headerRow = [NSMutableArray arrayWithCapacity:1 + dimensionlessFrames.count];
				[headerRow addObject:@"Image file"];
				for (PRHScannableFrame *_Nonnull const frame in dimensionlessFrames) {
					[headerRow addObject:frame.name ?: @""];
				}

				printf("%s\n", [headerRow componentsJoinedByString:@","].UTF8String);
			}
		}

		for (NSString *_Nonnull const imagePath in imagePaths) {
			NSURL *_Nonnull const imageURL = [NSURL fileURLWithPath:imagePath isDirectory:false];

			NSDictionary <NSString *, NSNumber *> *_Nullable imageProps = nil;
			CGImageRef _Nullable const image = PRHLoadImageFromFile(imageURL, &imageProps);

			if (image == NULL) {
				fprintf(stderr, "error: Could not decode image from %s\n", imagePath.UTF8String);
				status = EX_DATAERR;
				continue;
			}

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

			PRHImageScanner *_Nonnull const imageScanner = [PRHImageScanner scannerWithImage:image properties:imageProps];
			imageScanner.languageCodes = languageCodes;

			if (transposeOutput) {
				[imageScanner scanFrames:frames resultHandler:^(NSString *_Nullable name, NSString *_Nullable value) {
					if (anyFrameHasAName) {
						printf("%s,%s\n", name.UTF8String ?: "", PRHEscapeForCSV(value).UTF8String);
					} else {
						printf("%s\n", (value ?: @"").UTF8String);
					}
				}];
			} else {
				NSMutableArray <NSString *> *_Nonnull const dataRow = [NSMutableArray arrayWithCapacity:1 + frames.count];
				[dataRow addObject:imagePath];
				[imageScanner scanFrames:frames resultHandler:^(NSString *_Nullable name, NSString *_Nullable value) {
					[dataRow addObject:PRHEscapeForCSV(value)];
				}];

				printf("%s\n", [dataRow componentsJoinedByString:@","].UTF8String);
			}

			CFRelease(image);
		}
	}
	return status;
}

static NSString *_Nonnull const PRHEscapeForCSV(NSString *_Nullable const value) {
	return [NSString stringWithFormat:@"\"%@\"", [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""] ?: @""];
}

static CGImageRef _Nullable const PRHLoadImageFromFile(NSURL *_Nonnull const fileURL, NSDictionary <NSString *, NSNumber *> *_Nullable *_Nullable const outProps) {
	if ([fileURL.pathExtension.lowercaseString isEqualToString:@"pdf"]) {
		return PRHLoadImageFromPDFFile(fileURL, outProps);
	} else {
		return PRHLoadImageFromRasterFile(fileURL, outProps);
	}
}
static CGImageRef _Nullable const PRHLoadImageFromRasterFile(NSURL *_Nonnull const fileURL, NSDictionary <NSString *, NSNumber *> *_Nullable *_Nullable const outProps) {
	CGImageSourceRef _Nonnull const src = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, /*options*/ NULL);
	if (src == NULL) {
		NSString *_Nonnull const errorString = [NSString stringWithUTF8String:strerror(errno)];
		fprintf(stderr, "error: Could not read file %s: %s\n", fileURL.path.UTF8String, errorString.UTF8String ?: "(unknown error)");

		return NULL;
	} else {
		NSDictionary <NSString *, NSNumber *> *_Nullable const imageProps = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, /*idx*/ 0, /*options*/ NULL);

		CGImageRef _Nullable const image = CGImageSourceCreateImageAtIndex(src, /*idx*/ 0, /*options*/ NULL);
		if (outProps != NULL) *outProps = imageProps;

		CFRelease(src);

		return image;
	}
}
static CGImageRef _Nullable const PRHLoadImageFromPDFFile(NSURL *_Nonnull const fileURL, NSDictionary <NSString *, NSNumber *> *_Nullable *_Nullable const outProps) {
	return NULL;
}
