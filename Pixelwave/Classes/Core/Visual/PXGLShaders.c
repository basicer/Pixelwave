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

int PXGLGetShaderAttrib(const char* name)
{
    return glGetAttribLocation(m_shaderProgram, "px_position");
    
}

int PXLoadShader (GLenum type, const char* source)
{
    char *buffer;
    FILE* file = fopen(source, "r");
    size_t len = fseek(file, 0, SEEK_END);
    int count;
    len = 1000;
    fseek(file, 0, SEEK_SET);
    buffer = malloc(len);
    count = fread(buffer, 1, len, file);
    fclose(file);
    buffer[count] = '\0';
    
	const unsigned int shader = glCreateShader(type);
	assert(shader != 0);
    
	glShaderSource(shader, 1, (const GLchar**)&buffer, NULL);
	glCompileShader(shader);
    
	int success;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    printf("SRC:\n---\n%s\n---\n", buffer);
    free(buffer);
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
    
	const int vertexShader = PXLoadShader (GL_VERTEX_SHADER, "/Users/basicer/Code/Vertex.txt");
    const int fragmentShader = PXLoadShader (GL_FRAGMENT_SHADER, "/Users/basicer/Code/Fragment.txt");
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


