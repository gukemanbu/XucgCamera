//
//  XucgCamera.m
//  Camera
//
//  Created by xucg on 5/4/16.
//  Copyright © 2016 xucg. All rights reserved.
//  Welcome visiting https://github.com/gukemanbu/XucgCamera

#import "XucgCamera.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

@interface XucgCamera () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession           *captureSession;
@property (nonatomic, strong) UIImage                    *capturedImage;

@end

@implementation XucgCamera

-(instancetype) init {
    self = [super init];
    if (self) {
        // 初始化设备（默认为后摄像头）
        AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:nil];
        
        // 设置输出属性
        AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
        captureOutput.alwaysDiscardsLateVideoFrames = YES;
        captureOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        
        // 设备输出放在GCD里
        dispatch_queue_t cameraQueue;
        cameraQueue = dispatch_queue_create("com.xucg.camera", NULL);
        [captureOutput setSampleBufferDelegate:self queue:cameraQueue];
        
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

-(AVCaptureDevice*) getCameraWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureDevicePosition devicePosition = (AVCaptureDevicePosition)position;
    
    NSArray *cameraArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *curCamera in cameraArray) {
        if ([curCamera position] == devicePosition) {
            return curCamera;
        }
    }
    
    return cameraArray[0];
}

-(void) captureOutput:(AVCaptureOutput *)captureOutput
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

-(void) switchCamera {
    _cameraPosition = !_cameraPosition;
    
    [self.captureSession beginConfiguration];
    
    // 先删除现在的camera
    AVCaptureInput *currentCameraInput = [self.captureSession.inputs objectAtIndex:0];
    [self.captureSession removeInput:currentCameraInput];
    
    // 找到对应的摄像头
    AVCaptureDevice *newCamera = nil;
    if (_cameraPosition == XucgCameraPositionBack) {
        newCamera = [self getCameraWithPosition:AVCaptureDevicePositionBack];
        _previewView.transform = CGAffineTransformMakeScale(1, 1);
    } else {
        newCamera = [self getCameraWithPosition:AVCaptureDevicePositionFront];
        _previewView.transform = CGAffineTransformMakeScale(-1, 1);
    }
    
    // 添加新摄像头到session里
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
    [self.captureSession addInput:newVideoInput];
    
    [self.captureSession commitConfiguration];
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
    UIImage *snapImage = [self.capturedImage copy];
    return [self fixImageOrientation:snapImage];
}

- (UIImage*)fixImageOrientation:(UIImage*)srcImage {
    
    // No-op if the orientation is already correct
    if (srcImage.imageOrientation == UIImageOrientationUp) return srcImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (srcImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImage.size.width, srcImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, srcImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, srcImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (srcImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, srcImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, srcImage.size.width, srcImage.size.height,
                                             CGImageGetBitsPerComponent(srcImage.CGImage), 0,
                                             CGImageGetColorSpace(srcImage.CGImage),
                                             CGImageGetBitmapInfo(srcImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (srcImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImage.size.height,srcImage.size.width), srcImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImage.size.width,srcImage.size.height), srcImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

@end
