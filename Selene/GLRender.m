//
//  GLRender.m
//  Selene
//
//  Created by Theresa on 2017/12/18.
//  Copyright © 2017年 Theresa. All rights reserved.
//

#import "GLRender.h"
#import "ShaderOperation.h"

@implementation GLRender {
    EAGLContext *_context;
    
    GLuint _colorRenderBuffer;
    GLuint _frameBuffer;
    
    GLuint _glProgram;
    GLuint _positionSlot;
    GLuint _colorSlot;
    
    GLint _image;
    GLubyte *_imageData;
    GLuint _width;
    GLuint _height;
}

- (instancetype)initWithImage:(UIImage *)image {
    if (self = [super init]) {
        [self setupImage:image];
        [self setupContext];
        [self setupBuffer];
        [self setupGLProgram];
        [self setupVBO];
        [self setupTexture];
    }
    return self;
}

- (void)setupImage:(UIImage *)image {
    _width = image.size.width;
    _height = image.size.height;
    CGImageRef cgImage = image.CGImage;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    _imageData = (GLubyte *)CFDataGetBytePtr(data);
}

- (void)setupContext {
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 3.0 context");
        exit(1);
    }
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupBuffer {
    glDeleteRenderbuffers(1, &_colorRenderBuffer);
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, _width, _height);
    
    glDeleteFramebuffers(1, &_frameBuffer);
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
}

- (void)setupGLProgram {
    _glProgram = [ShaderOperation compileVertex:@"vert" fragment:@"frag"];
    glUseProgram(_glProgram);
    _positionSlot = glGetAttribLocation(_glProgram, "position");
    _colorSlot = glGetAttribLocation(_glProgram, "texcoord");
}

- (void)setupVBO {
    GLfloat vertices[] = {
        1.0f,  1.0f, 0.0f, 1.0f, 0.0f,   // 右上
        1.0f, -1.0f, 0.0f, 1.0f, 1.0f,   // 右下
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,  // 左下
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,  // 左下
        -1.0f,  1.0f, 0.0f, 0.0f, 0.0f,  // 左上
        1.0f,  1.0f, 0.0f, 1.0f, 0.0f,   // 右上
    };
    GLuint vbo;
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, 0);
    glEnableVertexAttribArray(_positionSlot);
    
    glVertexAttribPointer(_colorSlot, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, NULL + sizeof(GL_FLOAT) * 3);
    glEnableVertexAttribArray(_colorSlot);
}

- (void)setupTexture {
    GLuint texID;
    glGenTextures(1, &texID);
    glBindTexture(GL_TEXTURE_2D, texID);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, _imageData);
    
}

- (UIImage *)render {
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glViewport(0, 0, _width, _height);
    
    glDrawArrays(GL_TRIANGLES, 0, 6);
    
    glFinish();
    NSUInteger totalBytesForImage = _width * _height * 4;
    GLubyte *rawImagePixels = (GLubyte*)malloc(totalBytesForImage * sizeof(GLubyte));
    
    glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, rawImagePixels);
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rawImagePixels, totalBytesForImage, NULL);
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
    CGColorSpaceRelease(colorSpace);
    return [UIImage imageWithCGImage:cgImageFromBytes];
}

@end