//
//  PRHImageScanner.h
//  vision-ocr
//
//  Created by Peter Hosey on 2025-02-19.
//

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

@class PRHScannableFrame;

@interface PRHImageScanner : NSObject

+ (instancetype _Nonnull) scannerWithImage:(CGImageRef _Nonnull const)image properties:(NSDictionary *_Nullable const)imageProps;
- (instancetype _Nonnull) initWithImage:(CGImageRef _Nonnull const)image properties:(NSDictionary *_Nullable const)imageProps;

@property(copy) NSString *_Nullable imagePath;
@property(copy) NSArray <NSString *> *_Nullable languageCodes;

- (PRHScannableFrame *_Nonnull const) extent;

- (NSString *_Nullable) scanFrame:(PRHScannableFrame *_Nonnull const)frame;
- (NSDictionary <NSString *, NSString *> *_Nonnull) scanFrames:(NSArray <PRHScannableFrame *> *_Nonnull const)frames resultHandler:(void (^_Nonnull const)(NSString *_Nullable name, NSString *_Nullable value))resultHandler;

@end
