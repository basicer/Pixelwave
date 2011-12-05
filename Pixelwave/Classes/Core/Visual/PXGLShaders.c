//
//  PXGLShaders.c
//  Pixelwave
//
//  Created by Robert Blanckaert on 12/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


#include "PXGLShaders.h"
#include "PXOpenGL.h"

#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

int m_shaderProgram;

const char *VertexShader = "                                                        \n\
attribute vec4 px_position;                                                         \n\
attribute vec4 px_color;                                                            \n\
attribute vec2 px_uv;                                                               \n\
                                                                                    \n\
varying vec4 v_color;                                                               \n\
varying vec2 v_uv;                                                                  \n\
                                                                                    \n\
uniform int mode;                                                                   \n\
                                                                                    \n\
void main(void) {                                                                   \n\
    //gl_Position = vec4(px_position.xy,0.0,1.0) * 0.001;                           \n\
    //vec2 scale = vec2(1.0/320.0,1.0/480.0);                                       \n\
    vec2 scale = vec2(2.0/320.0,2.0/480.0);                                         \n\
    gl_Position = vec4(                                                             \n\
        -1.0+px_position.x * scale.x,                                               \n\
        1.0+px_position.y * -scale.y,                                               \n\
        px_position.z,                                                              \n\
        px_position.w                                                               \n\
    );                                                                              \n\
    v_color = px_color;                                                             \n\
    v_uv = px_uv;                                                                   \n\
}                                                                                   \n\
";

const char *FragmentShader = "                                                      \n\
#ifdef GL_ES                                                                        \n\
// define default precision for float, vec, mat.                                    \n\
precision highp float;                                                              \n\
#endif                                                                              \n\
                                                                                    \n\
uniform sampler2D px_texture;                                                       \n\
                                                                                    \n\
varying vec4 v_color;                                                               \n\
varying vec2 v_uv;                                                                  \n\
                                                                                    \n\
uniform int px_mode;                                                                \n\
                                                                                    \n\
void main(void) {                                                                   \n\
                                                                                    \n\
    //gl_FragColor = vec4(gl_FragCoord.x/480.0,gl_FragCoord.y/320.0,0.0,0.5);       \n\
    if ( px_mode == 1 ) {                                                           \n\
        gl_FragColor = v_color;                                                     \n\
    } else {                                                                        \n\
        gl_FragColor = texture2D(px_texture, v_uv) * v_color;                       \n\
    }                                                                               \n\
}                                                                                   \n\
";



int PXLoadShader (GLenum type, const char* source)
{
    const unsigned int shader = glCreateShader(type);
	assert(shader != 0);
    
	glShaderSource(shader, 1, (const GLchar**)&source, NULL);
	glCompileShader(shader);
    
	int success;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    printf("SRC:\n---\n%s\n---\n", source);

	if (success == 0)
	{
		char errorMsg[2048];
		glGetShaderInfoLog(shader, sizeof(errorMsg), NULL, errorMsg);
		printf("Compile error: %s\n", errorMsg);
		glDeleteShader(shader);
		return 0;
	} else {
        printf("OK!\n");
        
    }
    
    printf("-> ERROR @ %s %d = %x\n",__FUNCTION__,__LINE__,glGetError());

    return shader;
}

void PXApplyShaders() {
    
    glEnable(GL_TEXTURE_2D);
    
	const int vertexShader = PXLoadShader (GL_VERTEX_SHADER, VertexShader);
    const int fragmentShader = PXLoadShader (GL_FRAGMENT_SHADER, FragmentShader);
	assert(fragmentShader != 0);

	m_shaderProgram = glCreateProgram();
	assert(m_shaderProgram != 0);
    
	glAttachShader(m_shaderProgram, vertexShader);
	glAttachShader(m_shaderProgram, fragmentShader);
    
    
	glLinkProgram(m_shaderProgram);
	int linked;
	glGetProgramiv(m_shaderProgram, GL_LINK_STATUS, &linked);
	assert(linked != 0);
    
    printf("-> ERROR @ %s %d = %x\n",__FUNCTION__,__LINE__,glGetError());
    
    
}


