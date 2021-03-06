//
//  SACChainRender.m
//  Selene
//
//  Created by Theresa on 2017/12/18.
//  Copyright © 2017年 Theresa. All rights reserved.
//

#import <GLKit/GLKit.h>

#import "SACChainRender.h"
#import "SACShaderOperation.h"
#import "SACContext.h"
#import "SACFilter.h"

@interface SACChainRender ()

@property (nonatomic, strong) NSMutableArray *filters;
@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation SACChainRender {
    CFDataRef data;
    GLubyte *_imageData;
    
    GLuint _texture0;
    GLuint _texture1;
    GLuint _frameBuffer;
    
    GLuint _glProgram;
    GLuint _positionSlot;
    GLuint _coordSlot;
    GLuint _vbo;
    
    GLubyte *_rawImagePixels;
}

- (void)dealloc {
    glDeleteTextures(1, &_texture0);
    glDeleteTextures(1, &_texture1);
    glDeleteFramebuffers(1, &_frameBuffer);
    glDeleteProgram(_glProgram);
    glDeleteBuffers(1, &_vbo);
//    free(_rawImagePixels); bug
    CFRelease(data);
}

- (instancetype)initWithImage:(UIImage *)image {
    if (self = [super init]) {
        _queue   = dispatch_queue_create("com.opengl.queue", 0);
        _filters = [NSMutableArray array];
        _width   = image.size.width;
        _height  = image.size.height;

        data       = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
        _imageData = (GLubyte *)CFDataGetBytePtr(data);
    
        [self setupContext];
    }
    return self;
}

- (void)setupContext {
    [[SACContext sharedContext] setCurrentContext];
}

- (void)setupGLProgram {
    _glProgram = [SACShaderOperation compileVertex:@"Origin" fragment:@"Origin"];
    glUseProgram(_glProgram);
    _positionSlot = glGetAttribLocation(_glProgram, "position");
    _coordSlot = glGetAttribLocation(_glProgram, "texcoord");
    glUniform1i(glGetUniformLocation(_glProgram, "image"), 0);
}

- (void)setupRenderTexture {
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &_texture0);
    glBindTexture(GL_TEXTURE_2D, _texture0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, _imageData);
}

- (void)setupVBO {
    GLfloat vertices[] = {
        1.0f,  1.0f, 0.0f, 1.0f, 1.0f,   // 右上
        1.0f, -1.0f, 0.0f, 1.0f, 0.0f,   // 右下
        -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,  // 左下
        -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,  // 左下
        -1.0f,  1.0f, 0.0f, 0.0f, 1.0f,  // 左上
        1.0f,  1.0f, 0.0f, 1.0f, 1.0f,   // 右上
    };
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
}

- (void)activeVBO {
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, 0);
    glEnableVertexAttribArray(_positionSlot);
    glVertexAttribPointer(_coordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, NULL + sizeof(GL_FLOAT) * 3);
    glEnableVertexAttribArray(_coordSlot);
}

- (void)setupOutputTarget {
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_texture1);
    glBindTexture(GL_TEXTURE_2D, _texture1);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture1, 0);
}

- (void)render {
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glViewport(0, 0, _width, _height);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

#pragma mark - public

- (void)addFilter:(SACFilter *)filter {
    [self.filters addObject:filter];
}

- (void)startRender {
    [self setupGLProgram];
    [self setupRenderTexture];
    [self setupVBO];
    [self activeVBO];
    [self setupOutputTarget];
    [self render];
    for (int i = 0; i < self.filters.count; i++) {
        SACFilter *filter = self.filters[i];
        glUseProgram(filter.glProgram);
        _positionSlot = glGetAttribLocation(filter.glProgram, "position");
        _coordSlot = glGetAttribLocation(filter.glProgram, "texcoord");
        
        GLuint texture, index;
        if (i % 2 != 0) {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, _texture0);
            texture = _texture0;
            index = 1;
        } else {
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, _texture1);
            texture  = _texture1;
            index = 0;
        }
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glUniform1i(glGetUniformLocation(_glProgram, "image"), index);

        glGenFramebuffers(1, &_frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        [self render];
    }
}

- (GLuint)fetchTexture {
    if (self.filters.count % 2 == 0) {
        return _texture0;
    } else {
        return _texture1;
    }
}

- (UIImage *)fetchImage {
    GLuint totalBytesForImage = _width * _height * 4;
    _rawImagePixels = (GLubyte *)malloc(totalBytesForImage * sizeof(GLubyte));
    
    glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, _rawImagePixels);
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, _rawImagePixels, totalBytesForImage, NULL);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImageFromBytes = CGImageCreate(_width,
                                                _height,
                                                8,
                                                32,
                                                4 * _width,
                                                colorSpace,
                                                kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                                dataProvider,
                                                NULL,
                                                YES,
                                                kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    CGColorSpaceRelease(colorSpace);
    return [UIImage imageWithCGImage:cgImageFromBytes];
}

@end
