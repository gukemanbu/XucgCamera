//
//  RootViewController.m
//  XucgCamera
//
//  Created by xucg on 5/4/16.
//  Copyright © 2016 xucg. All rights reserved.
//

#import "RootViewController.h"
#import "XucgCamera.h"

@interface RootViewController ()

@property (nonatomic, strong) XucgCamera *xucgCamera;

@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (weak, nonatomic) IBOutlet UIImageView *picView;

- (IBAction)cameraButtonAction:(UIButton *)sender;
- (IBAction)takeButtonAction:(UIButton *)sender;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.xucgCamera = [[XucgCamera alloc] init];
    self.xucgCamera.delegate = (id<XucgCameraDelegate>)self;
    self.xucgCamera.previewView.frame = CGRectMake(0, 0, 200, 100);
    [_videoView addSubview:self.xucgCamera.previewView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cameraButtonAction:(UIButton *)sender {
    sender.selected = !sender.isSelected;
    
    sender.backgroundColor = sender.isSelected ? [UIColor redColor] : [UIColor greenColor];
    
    if (sender.isSelected) {
        [self.xucgCamera startCamera];
    } else {
        [self.xucgCamera stopCamera];
    }
}

- (IBAction)takeButtonAction:(UIButton *)sender {
    UIImage *snapShot = [self.xucgCamera takePicture];
    
    [_picView setImage:snapShot];
}

@end
