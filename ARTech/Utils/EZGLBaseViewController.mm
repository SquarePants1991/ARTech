//
//  EZGLCubeWithTextureViewController.m
//  EZGLKit
//
//  Created by wang yang on 2016/10/27.
//  Copyright © 2016年 ocean. All rights reserved.
//

#import "EZGLBaseViewController.h"
#import <OpenGLES/ES2/gl.h>

@interface EZGLBaseViewController () <EZGLMoveJoyStickerDelegate> {
    ELWorld* world;
}
@property (assign, nonatomic) CGPoint lastTouchPoint;
@property (assign, nonatomic) CGPoint currentTouchPoint;
@property (assign, nonatomic) CGFloat lastScale;

@property (strong, nonatomic) EAGLContext *context;

@end

@implementation EZGLBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self.preferredFramesPerSecond = 120;
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [EAGLContext setCurrentContext:self.context];
    
    const char * bundlePath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/"] UTF8String];
    ELAssets::shared()->addSearchPath(bundlePath);
    
    
    world = new ELWorld();
    world->enablePhysics();
    
    ELLight *defaultLight = new ELLight();
    defaultLight->position = ELVector3Make(0,1,1);
   // defaultLight->type = ELLightTypeDirection;
    defaultLight->color = ELVector4Make(1.0,1.0,1.0,1.0);
    defaultLight->intensity = 1.0;
    defaultLight->intensityFallOff = 0.0;
    defaultLight->identity = "main-light";
    //defaultLight->enableShadow();
    world->addNode(retain_ptr(ELLight, defaultLight));
    
    [self setupWorld:world];
    
    CGRect bounds = self.view.bounds;
    self.moveSticker = [[EZGLMoveJoySticker alloc]initWithFrame:CGRectMake(0, 0, bounds.size.width / 2, bounds.size.height)];
    self.moveSticker.delegate = self;
    [self.view addSubview:self.moveSticker];
    
    self.rotateSticker = [[EZGLMoveJoySticker alloc]initWithFrame:CGRectMake(bounds.size.width / 2, 0, bounds.size.width / 2,bounds.size.height)];
    self.rotateSticker.delegate = self;
    [self.view addSubview:self.rotateSticker];
    
    GLint MaxTextureUnits;
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &MaxTextureUnits);
    
}


- (void)dealloc {
    ELTexture::clearCache();
}

- (ELWorld *)getWorld {
    return world;
}

- (void)setupWorld:(ELWorld *)world {
    [(GLKView *)self.view bindDrawable];
    GLint defaultFBO;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &defaultFBO);
    world->defaultFBO = defaultFBO;
    world->fbWidth = self.view.frame.size.width * [UIScreen mainScreen].scale;
    world->fbHeight = self.view.frame.size.height * [UIScreen mainScreen].scale;
    world->enableDefaultCamera(world->fbWidth / (float)world->fbHeight);
    
    std::string vertexShader = ELFileUtil::stringContentOfShader(ELAssets::shared()->findFile("vtx_phong_es.glsl").c_str());
    std::string fragShader = ELFileUtil::stringContentOfShader(ELAssets::shared()->findFile("frg_phong_es.glsl").c_str());
    std::string dispVideoVertexShader = ELFileUtil::stringContentOfShader(ELAssets::shared()->findFile("vtx_video_disp.glsl").c_str());
    std::string dispVideoFragShader = ELFileUtil::stringContentOfShader(ELAssets::shared()->findFile("frg_video_disp.glsl").c_str());
    std::string shadowFragShader = ELFileUtil::stringContentOfShader(ELAssets::shared()->findFile("frg_shadowmap_es.glsl").c_str());
    std::string waterFragShader = ELFileUtil::stringContentOfShader(ELAssets::shared()->findFile("water_es.glsl").c_str());
    ELEffect * activeEffect = new ELEffect(vertexShader.c_str(), fragShader.c_str());
    ELEffect * dispVideoEffect = new ELEffect(dispVideoVertexShader.c_str(), dispVideoFragShader.c_str());
    ELEffect * shadowEffect = new ELEffect(vertexShader.c_str(), shadowFragShader.c_str());
    ELEffect * waterEffect = new ELEffect(vertexShader.c_str(), waterFragShader.c_str());
    
    activeEffect->identity = "render_scene";
    dispVideoEffect->identity = "disp_video";
    shadowEffect->identity = "gen_shadow";
    waterEffect->identity = "water";
    world->addNode(retain_ptr(ELEffect, activeEffect));
    world->addNode(retain_ptr(ELEffect, dispVideoEffect));
    world->addNode(retain_ptr(ELEffect, shadowEffect));
    world->addNode(retain_ptr(ELEffect, waterEffect));
    
    //    world->addRenderPass(new ELWaterPlaneRenderPass());
    //    world->addRenderPass(new ELShadowMapRenderPass());
    
    activeEffect->frogColor = ELVector4Make(0.2,0.2,0.2,1.0);
    activeEffect->frogStart = 1380;
    activeEffect->frogEnd = 1500;
    
    ELGLState::set(GL_CULL_FACE, GL_FALSE);
    ELGLState::set(GL_DEPTH_TEST, GL_TRUE);
}


- (void)setIsStickerEnabled:(BOOL)isStickerEnabled {
    _isStickerEnabled = isStickerEnabled;
    if (_isStickerEnabled == NO) {
        self.moveSticker.hidden = YES;
        self.rotateSticker.hidden = YES;
    }
}

- (NSString *)shaderName {
    return @"default";
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    world->render();
}

- (void)update {
    if (self.isStickerEnabled) {
        [self updateCamera:self.timeSinceLastUpdate];
    }
    
    world->update(self.timeSinceLastUpdate);
}

- (void)joyStickerStateUpdated:(EZGLMoveJoyStickerState)state joySticker:(EZGLMoveJoySticker *)joySticker {
    if (self.isStickerEnabled == NO) {
        return;
    }
    if (joySticker == self.rotateSticker) {
        ELCamera *perspectiveCamera = world->activedCamera;
        perspectiveCamera->rotateLookAtAroundUp(-state.deltaOffsetX / 5.0);
        perspectiveCamera->rotateLookAtAroundLeft(-state.deltaOffsetY / 5.0);
    }
}

- (void)updateCamera:(NSTimeInterval)interval {
    //    ELCamera *perspectiveCamera = world->activedCamera;
    //
    //    EZGLMoveJoyStickerState moveState = self.moveSticker.state;
    //
    //    perspectiveCamera->translateForward(-moveState.offsetY * interval);
    ////    perspectiveCamera->translateLeft(moveState.offsetY * interval);
    
}

@end
