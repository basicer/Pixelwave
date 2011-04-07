/*
 *  _____                       ___                                            
 * /\  _ `\  __                /\_ \                                           
 * \ \ \L\ \/\_\   __  _    ___\//\ \    __  __  __    ___     __  __    ___   
 *  \ \  __/\/\ \ /\ \/ \  / __`\\ \ \  /\ \/\ \/\ \  / __`\  /\ \/\ \  / __`\ 
 *   \ \ \/  \ \ \\/>  </ /\  __/ \_\ \_\ \ \_/ \_/ \/\ \L\ \_\ \ \_/ |/\  __/ 
 *    \ \_\   \ \_\/\_/\_\\ \____\/\____\\ \___^___ /\ \__/|\_\\ \___/ \ \____\
 *     \/_/    \/_/\//\/_/ \/____/\/____/ \/__//__ /  \/__/\/_/ \/__/   \/____/
 *       
 *           www.pixelwave.org + www.spiralstormgames.com
 *                            ~;   
 *                           ,/|\.           
 *                         ,/  |\ \.                 Core Team: Oz Michaeli
 *                       ,/    | |  \                           John Lattin
 *                     ,/      | |   |
 *                   ,/        |/    |
 *                 ./__________|----'  .
 *            ,(   ___.....-,~-''-----/   ,(            ,~            ,(        
 * _.-~-.,.-'`  `_.\,.',.-'`  )_.-~-./.-'`  `_._,.',.-'`  )_.-~-.,.-'`  `_._._,.
 * 
 * Copyright (c) 2011 Spiralstorm Games http://www.spiralstormgames.com
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

#import "PXTextureFontOptions.h"

/**
 *	@ingroup Text
 *
 *	A PXTextureFontOptions creates options for when making a new font.  These
 *	options will decide how the texture atlas will be created and what will be
 *	stored.
 *
 *	@b Example:
 *	@code
 *	PXTextureFontOptions *fontOptions = [[PXTextureFontOptions alloc] initWithSize:24.0f
 *	                                                                 characterSets:PXFontCharacterSet_AllLetters | PXFontCharacterSet_Numerals
 *	                                                             specialCharacters:@",.!?"]];
 *	[PXFont registerFontWithContentsOfFile:@"font.ttf"
 *	                                  name:@"myFont"
 *	                               options:fontOptions];
 *	[fontOptions release];
 *	@endcode
 */
@implementation PXTextureFontOptions

@synthesize size;
@synthesize textureModifier;

- (id) init
{
	return [self initWithSize:[PXTextureFontOptions defaultSize]
				characterSets:[PXFontOptions defaultCharacterSets]
			specialCharacters:[PXFontOptions defaultSpecialCharacters]];
}

- (id) initWithSize:(float)_size
	  characterSets:(unsigned)characterSets
  specialCharacters:(NSString *)specialCharacters
{
	if (self = [super initWithCharacterSets:characterSets
						  specialCharacters:specialCharacters])
	{
		size = _size;

		textureModifier = nil;
	}
	
	return self;
}

- (void) dealloc
{
	self.textureModifier = nil;

	[super dealloc];
}

- (void) reset
{
	size = [PXTextureFontOptions defaultSize];

	[super reset];
}

#pragma mark -
#pragma mark NSObject Overrides

- (id) copyWithZone:(NSZone *)zone
{
	PXTextureFontOptions *options = [[self class] allocWithZone:zone];

	options->size = size;
	options.characters = characters;
	options.textureModifier = textureModifier;

	return options;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"(size=%f, character==%@)",
			size,
			characters];
}

+ (float) defaultSize
{
	return 12.0f;
}

+ (PXTextureFontOptions *)textureFontOptionsWithSize:(float)size
									   characterSets:(unsigned)characterSets
								   specialCharacters:(NSString *)specialCharacters
{
	return [[[PXTextureFontOptions alloc] initWithSize:size
										 characterSets:characterSets
									 specialCharacters:specialCharacters] autorelease];
}

@end
