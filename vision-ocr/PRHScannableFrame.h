//
//  PRHScannableFrame.h
//  vision-ocr
//
//  Created by Peter Hosey on 2025-02-19.
//

#import <Foundation/Foundation.h>

@interface PRHScannableFrame : NSObject

+ (instancetype _Nullable) frameWithString:(NSString *_Nonnull const)str imageProperties:(NSDictionary <NSString *, NSNumber *> *_Nullable const)imageProps;
+ (instancetype _Nonnull) frameWithName:(NSString *_Nullable const)name x:(CGFloat const)xCoord y:(CGFloat const)yCoord width:(CGFloat const)width height:(CGFloat const)height;
+ (instancetype _Nonnull) frameWithExtentFromImageProperties:(NSDictionary <NSString *, NSNumber *> *_Nonnull const)imageProps;

- (instancetype _Nullable) initWithString:(NSString *_Nonnull const)str imageProperties:(NSDictionary <NSString *, NSNumber *> *_Nullable const)imageProps;

- (instancetype _Nonnull) initWithName:(NSString *_Nullable const)name x:(CGFloat const)xCoord y:(CGFloat const)yCoord width:(CGFloat const)width height:(CGFloat const)height;

@property(copy) NSString *_Nullable name;

@property CGFloat xCoordinate, yCoordinate;
@property CGFloat width, height;

@end
