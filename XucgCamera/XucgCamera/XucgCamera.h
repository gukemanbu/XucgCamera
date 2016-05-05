//
//  XucgCamera.h
//  Camera
//
//  Created by xucg on 5/4/16.
//  Copyright © 2016 xucg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSUInteger, XucgCameraPosition) {
    XucgCameraPositionBack,
    XucgCameraPositionFront
};

@protocol XucgCameraDelegate <NSObject>

@optional
-(void) didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface XucgCamera : NSObject

@property (nonatomic, assign, readonly) BOOL isRunning;                       // 相机是否在运行
@property (nonatomic, strong, readonly) UIView *previewView;                  // 预览视图，输出数据
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;       // 预览层，源数据
@property (nonatomic, assign, readonly) XucgCameraPosition cameraPosition;    // 相机位置，默认为后
@property (nonatomic, weak) id<XucgCameraDelegate> delegate;

-(void) switchCamera;
-(void) startCamera;
-(void) stopCamera;
-(UIImage*) takePicture;

@end
