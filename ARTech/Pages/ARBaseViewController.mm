//
//  ARBaseViewController.m
//  ARTech
//
//  Created by wangyang on 2017/3/21.
//  Copyright © 2017年 wangyang. All rights reserved.
//

#import "ARBaseViewController.h"
#import "ARCameraCapture.h"
#import "ARMarkerPose.h"
#import "argl.h"

@interface ARBaseViewController () <ARCameraCaptureDelegate> {
    ELTexture *diffuseTexture;
    ELTexture *normalTexture;
}

@end

@implementation ARBaseViewController
@synthesize world;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.world = retain_ptr(ELWorld, [self getWorld]);
    arUtilChangeToResourcesDirectory(AR_UTIL_RESOURCES_DIRECTORY_BEHAVIOR_BEST, NULL);
    self.cameraCapture = [[ARCameraCapture alloc]init];
    self.cameraCapture.delegate = self;
    
    [self.cameraCapture openDevice:^(BOOL success) {
        [self cameraReady];
    }];
}

- (void)cameraReady {
    CGFloat width = self.cameraCapture.arParamLT->param.ysize;
    CGFloat height = self.cameraCapture.arParamLT->param.xsize;
    
    float scaleX = self.view.frame.size.width / width;
    float scaleY = self.view.frame.size.height / height;
    float scale = scaleX > scaleY ? scaleX : scaleY;
    float viewportLeft = (self.view.frame.size.width - scale * width) /2;
    float viewportBottom = (self.view.frame.size.height - scale * height) /2;
    float screenScale = [UIScreen mainScreen].scale;
    self.world->setViewport( viewportLeft * screenScale, viewportBottom * screenScale, scale * width * screenScale, scale * height * screenScale);
    
    ELCamera *orthoCamera = new ELCamera(ELVector3Make(0, 0, 1), ELVector3Make(0, 0, 0), ELVector3Make(0, 1, 0), 60,0.75,0.1,1000);
    orthoCamera->ortho(-width / 2, width / 2, -height / 2,  height / 2, -600, 600);
    orthoCamera->identity = "ortho";
    self.world->addNode(retain_ptr(ELCamera, orthoCamera));
    
    if ([self respondsToSelector:@selector(preferMarkerDetector)]) {
        [[self preferMarkerDetector] setupWith:self.cameraCapture.arParamLT pixelFormat:self.cameraCapture.pixelFormat];
    }
    
    diffuseTexture = ELTexture::texture(ELAssets::shared()->findFile("dirt.png"));
    normalTexture = ELTexture::texture(ELAssets::shared()->findFile("dirt.jpg"));
    ELVector2 videoPlaneSize = ELVector2Make(self.cameraCapture.arParamLT->param.ysize, self.cameraCapture.arParamLT->param.xsize);
    self.videoPlane = [self createVideoPlane:videoPlaneSize :diffuseTexture->value :normalTexture->value];
    
    [self.cameraCapture beginCapture];
    if ([self respondsToSelector:@selector(arDidBeganDetect)]) {
        [self arDidBeganDetect];
    }
}

- (void)dealloc {
    [self.cameraCapture endCapture];
    ELTexture::clearCache();
}


- (void)arCameraCaptureDidCaptureData:(AR2VideoBufferT *)buffer {
    if (self.cameraCapture.pixelFormat == AR_PIXEL_FORMAT_BGRA) {
        diffuseTexture->reset(buffer->buff, self.cameraCapture.arParamLT->param.xsize, self.cameraCapture.arParamLT->param.ysize, GL_RGBA);
    } else {
        diffuseTexture->reset(buffer->bufPlanes[0], self.cameraCapture.arParamLT->param.xsize, self.cameraCapture.arParamLT->param.ysize, GL_LUMINANCE);
        normalTexture->reset(buffer->bufPlanes[1], self.cameraCapture.arParamLT->param.xsize / 2, self.cameraCapture.arParamLT->param.ysize / 2, GL_LUMINANCE_ALPHA);
    }
    
    if ([self respondsToSelector:@selector(arWillProcessFrame:)]) {
        [self arWillProcessFrame:buffer];
    }
    
    if ([self respondsToSelector:@selector(preferMarkerDetector)] == NO) {
        return;
    }
    
    float matrix[16];
    if ([[self preferMarkerDetector] detect:buffer modelMatrix:matrix]) {
        float projection[16];
        arglCameraFrustumRHf(&(self.cameraCapture.arParamLT->param), 5.0, 2000, projection);
        ELMatrix4 projectionMatrix = ELMatrix4MakeWithArray(projection);
        
        float ir90[16] = {0.0f, -1.0f, 0.0f, 0.0f,  1.0f, 0.0f, 0.0f, 0.0f,  0.0f, 0.0f, 1.0f, 0.0f,  0.0f, 0.0f, 0.0f, 1.0f};
        
        ELMatrix4 ir90Matrix = ELMatrix4MakeWithArray(ir90);
        ELMatrix4 finalProjection;
        finalProjection = ir90Matrix;
        BOOL contentFlipH = NO;
        BOOL contentFlipV = NO;
        if (contentFlipH || contentFlipV) {
            finalProjection = ELMatrix4Scale(finalProjection, (contentFlipH ? -1.0f : 1.0f), (contentFlipV ? -1.0f : 1.0f), 1.0f);
        }
        
        finalProjection = ELMatrix4Multiply(finalProjection, projectionMatrix);
        finalProjection = ELMatrix4Multiply(finalProjection, ELMatrix4MakeWithArray(matrix));
        
        [self arDetecting:@[[[ARMarkerPose alloc] initWithMatrix:finalProjection.m]]];
    } else {
        [self arDetecting:@[]];
    }
}

- (EL2DPlane * )createVideoPlane:(ELVector2)size :(GLuint)diffuseMap :(GLuint) normalMap {
    auto gameObject = retain_ptr_init_v(ELGameObject, self.world);
    self.world->addNode(gameObject);
    gameObject->transform->position = ELVector3Make(0, 0, 0);
    EL2DPlane *plane = new EL2DPlane(size);
    gameObject->addComponent(plane);
    plane->materials[0].diffuseMap = diffuseMap;
    plane->materials[0].normalMap = normalMap;
    return plane;
}
@end
