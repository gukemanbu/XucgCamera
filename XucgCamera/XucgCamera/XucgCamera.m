//
//  XucgCamera.m
//  Camera
//
//  Created by xucg on 5/4/16.
//  Copyright © 2016 xucg. All rights reserved.
//

#import "XucgCamera.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

@interface XucgCamera () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession           *captureSession;
@property (nonatomic, strong) AVCaptureDevice            *captureDevice;
@property (nonatomic, strong) UIImage                    *capturedImage;

@end

@implementation XucgCamera

-(instancetype) init {
    self = [super init];
    if (self) {
        // 初始化设备（摄像头）
        self.captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:nil];
        
        // 设置输出属性
        AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
        captureOutput.alwaysDiscardsLateVideoFrames = YES;
        captureOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        
        // 设备输出放在GCD里
        dispatch_queue_t cameraQueue;
        cameraQueue = dispatch_queue_create("com.xucg.camera", NULL);
        [captureOutput setSampleBufferDelegate:self queue:cameraQueue];
        
        // 设置真彩色
        NSString *key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
        NSNumber *value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
        NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
        [captureOutput setVideoSettings:videoSettings];
        
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        [self.captureSession addInput:captureInput];
        [self.captureSession addOutput:captureOutput];
        
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        self.previewLayer.frame = [UIScreen mainScreen].bounds;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        _previewView = [[UIImageView alloc] init];
    }
    
    return self;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,
                                                    width, height, 8, bytesPerRow, colorSpace,
                                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    self.capturedImage = [UIImage imageWithCGImage:newImage scale:1.0
                                  orientation:UIImageOrientationRight];
    
    CGImageRelease(newImage);
    
    [self.previewView performSelectorOnMainThread:@selector(setImage:)
                                     withObject:self.capturedImage waitUntilDone:YES];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    if ([self.delegate respondsToSelector:@selector(didOutputSampleBuffer:)]) {
        [self.delegate didOutputSampleBuffer:sampleBuffer];
    }
}

-(void) startCamera {
    [self.captureSession startRunning];
    _isRunning = YES;
}

-(void) stopCamera {
    [self.captureSession stopRunning];
    _isRunning = NO;
}

-(UIImage*) takePicture {
    return [self.capturedImage copy];
}

@end
