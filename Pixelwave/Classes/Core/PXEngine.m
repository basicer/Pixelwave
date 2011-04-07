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

#include "PXEngine.h"

#include "PXGLPrivate.h"
#include "PXMathUtils.h"
#include "PXPrivateUtils.h"

#import "PXLinkedList.h"
#import "PXObjectPool.h"
#import "PXSoundEngine.h"
#import <QuartzCore/QuartzCore.h>

#import "PXDebugUtils.h"
#import "PXExceptionUtils.h"

#define PX_ENGINE_MIN_BUFFER_SIZE 4
#define PX_ENGINE_MIN_FRAME_RATE 30

#define PX_ENGINE_CONVERT_POINT_TO_STAGE_ORIENTATION(_x_, _y_, _stage_) \
{ \
	PXStageOrientation _orientation_ = _stage_.orientation; \
	\
	if (_orientation_ == PXStageOrientation_PortraitUpsideDown) \
	{ \
		(_x_) = _stage_.stageWidth  - (_x_); \
		(_y_) = _stage_.stageHeight - (_y_); \
	} \
	else if (_orientation_ == PXStageOrientation_LandscapeLeft) \
	{ \
		float _oldX_ = _x_; \
		(_x_) = _stage_.stageWidth - (_y_); \
		(_y_) = _oldX_; \
	} \
	else if (_orientation_ == PXStageOrientation_LandscapeRight) \
	{ \
		float _oldX_ = _x_; \
		(_x_) = (_y_); \
		(_y_) = _stage_.stageHeight - _oldX_; \
	} \
}

#define PX_ENGINE_CONVERT_AABB_TO_STAGE_ORIENTATION(_aabb_, _stage_) \
{ \
	PXStageOrientation _orientation_ = _stage_.orientation; \
	int _stageWidth_  = _stage_.stageWidth; \
	int _stageHeight_ = _stage_.stageHeight; \
\
	if (_orientation_ == PXStageOrientation_PortraitUpsideDown) \
	{ \
		float _xMin_ = (_aabb_)->xMin; \
		float _xMax_ = (_aabb_)->xMax; \
		float _yMin_ = (_aabb_)->yMin; \
		float _yMax_ = (_aabb_)->yMax; \
\
		(_aabb_)->xMin = _stageWidth_  - _xMax_; \
		(_aabb_)->xMax = _stageWidth_  - _xMin_; \
		(_aabb_)->yMin = _stageHeight_ - _yMax_; \
		(_aabb_)->yMax = _stageHeight_ - _yMin_; \
	} \
	else if (_orientation_ == PXStageOrientation_LandscapeLeft) \
	{ \
		float _xMin_ = (_aabb_)->xMin; \
		float _xMax_ = (_aabb_)->xMax; \
		float _yMin_ = (_aabb_)->yMin; \
		float _yMax_ = (_aabb_)->yMax; \
\
		(_aabb_)->xMin = _stageWidth_ - _yMax_; \
		(_aabb_)->xMax = _stageWidth_ - _yMin_; \
		(_aabb_)->yMin = _xMin_; \
		(_aabb_)->yMax = _xMax_; \
	} \
	else if (_orientation_ == PXStageOrientation_LandscapeRight) \
	{ \
		float _xMin_ = (_aabb_)->xMin; \
		float _xMax_ = (_aabb_)->xMax; \
\
		(_aabb_)->xMin = (_aabb_)->yMin; \
		(_aabb_)->xMax = (_aabb_)->yMax; \
		(_aabb_)->yMin = _stageHeight_ - _xMax_; \
		(_aabb_)->yMax = _stageHeight_ - _xMin_; \
	} \
}

/**
 *	@internal
 */
@interface PXEngine : NSObject
{
@private
	id displayLink;
	short displayLinkInterval;
	BOOL displayLinkSupported;
	char pxEnginePadding;
	
	NSTimer *animationTimer;
}

- (void) updateMainLoopInterval;

@end

void PXEngineUpdateMainLoopInterval();

void PXEngineOnFrame( );
void PXEngineRenderStage( );

PXTouchEvent *pxEngineNewTouchEventWithTouch(UITouch *touch, CGPoint *pos, NSString *type, BOOL orientTouch);

PXObjectPool *pxEngineSharedObjectPool = nil;

PXLinkedList *pxEngineCachedListeners = nil;			//Strongly referenced
PXLinkedList *pxEngineFrameListeners = nil;				//Strongly referenced
PXLinkedList *pxEngineTouchEvents = nil;				//Strongly referenced
PXLinkedList *pxEngineSavedTouchEvents = nil;			//Strongly referenced
PXLinkedList *pxEngineRemoveFromSavedTouchEvents = nil;	//Strongly referenced

PXEvent *pxEngineEnterFrameEvent = nil;					//Strongly referenced
PXStage *pxEngineStage = nil;							//Strongly referenced
PXEngine *pxEngine = nil;								//Strongly referenced
PXDisplayObject *pxEngineRoot = nil;					//Weakly referenced
PXView *pxEngineView = nil;								//Weakly referenced

bool pxEngineInitialized = false;
bool pxEngineShouldClear = false;
bool pxEngineIsRunning = false;
char pxEnginePadding1;

// Render to texture frame buffer object
GLuint pxEngineRTTFBO = 0;

// This value may change later on. Currently 60HZ is the max screen refresh
// rate for any iDevice
float pxEngineMaxFrameRate = 60.0f;
const float pxEngineMaxDT = 1.0f / PX_ENGINE_MIN_FRAME_RATE;
float pxEngineMaxFrameRateSeconds = 1.0f; // Defined in PXEngineInit
float pxEngineMinFrameRateSeconds = 0.01;

float pxEngineMainDT = 0.0f;
float pxEngineRenderDT = 0.0f;
float pxEngineRenderTimeAccum = 0.0f;
float pxEngineLogicDT = 0.0f;
float pxEngineLogicTimeAccum = 0.0f;

// The size of the view in POINTS. Always in PORTRAIT
CGSize pxEngineViewSize;
PXColor3f pxEngineClearColor = {1.0f, 1.0f, 1.0f}; // Initialize to white

#ifdef PX_DEBUG_MODE
float pxEngineTimeBetweenFrames = 0.0f;
float pxEngineTimeBetweenLogic = 0.0f;
float pxEngineTimeBetweenRendering = 0.0f;
float pxEngineTimeWaiting = 0.0f;
#endif

#if (PX_ENGINE_IDLE_TIME_INCLUDES_BETWEEN_SYSTEM_CALLS)
NSTimeInterval pxEngineInterval = 0.0f;
#endif

typedef struct
{
	PXDisplayObject *displayObject;
} _PXEngineDisplayObject;

typedef struct
{
	unsigned size;
	unsigned maxSize;
	_PXEngineDisplayObject *array;
} _PXEngineDisplayObjectBuffer;

_PXEngineDisplayObjectBuffer pxEngineDOBuffer;
unsigned pxEngineDOBufferMaxSize = 0;
unsigned pxEngineDOBufferOldMaxSize = 0;

void PXEngineInit( PXView *view )
{
#ifdef PIXELWAVE_DEBUG
	PXDebug.logErrors = YES;
#endif

	///////////////
	// Top Level //
	///////////////

	_PXTopLevelInitialize();

	////////
	// ?? //
	////////

	pxEngineDOBuffer.size = 0;
	pxEngineDOBuffer.maxSize = PX_ENGINE_MIN_BUFFER_SIZE;
	pxEngineDOBuffer.array = malloc( sizeof( _PXEngineDisplayObject ) * pxEngineDOBuffer.maxSize );

	///////////
	// Timer //
	///////////

	pxEngine = [PXEngine new];
	pxEngineView = view;
	
	// view.bounds are measured in PIXELS by Cocoa
	pxEngineViewSize = view.bounds.size;
	
	// pxEngineViewSize should be in POINTS, convert:
	float contentScaleFactor = pxEngineView.contentScaleFactor;
	float one_contentScaleFactor = 1.0f / contentScaleFactor;
	pxEngineViewSize.width  *= one_contentScaleFactor;
	pxEngineViewSize.height *= one_contentScaleFactor;

	//////////////////////
	// Rendering System //
	//////////////////////

	PXGLInit( pxEngineViewSize.width, pxEngineViewSize.height, contentScaleFactor );

	// Create a frame buffer to use for renderToTexture
	glGenFramebuffersOES( 1, &pxEngineRTTFBO );

	////////////
	// Events //
	////////////

	// Initialized with weak references so that DisplayObjects with an
	// ENTER_FRAME listener can get deallocated when they leave the Display
	// list. It's the object's responsibility to remove all of the event
	// listeners it added once it gets deallocated.
	pxEngineFrameListeners = [[PXLinkedList alloc] initWithWeakReferences:YES];

	pxEngineCachedListeners = [[PXLinkedList alloc] init];
	pxEngineTouchEvents = [[PXLinkedList alloc] init];
	pxEngineSavedTouchEvents = [[PXLinkedList alloc] init];
	pxEngineRemoveFromSavedTouchEvents = [[PXLinkedList alloc] init];

	// Create a reusable enter frame event instead of creating one every frame.
	pxEngineEnterFrameEvent = [[PXEvent alloc] initWithType:PX_EVENT_ENTER_FRAME
										   doesBubble:NO
										 isCancelable:NO];

	//////////
	// Misc //
	//////////

	// Seed the random number generator
#if (PX_SEED_RAND_WITH_TIME_ON_INIT)
	PXMathSeedRandomWithTime();
#endif

	//////////////////
	// Display List //
	//////////////////

	// Create the stage
	pxEngineStage = [[PXStage alloc] init];
	pxEngineIsRunning = true;
	PXEngineSetRenderFrameRate(30.0f);
	PXEngineSetLogicFrameRate(30.0f);
	PXEngineSetClearScreen(YES);

	////////////////
	// The Toggle //
	////////////////

	pxEngineInitialized = true;

	// Create the root
	PXSprite *defaultRoot = [PXSprite new];
	PXEngineSetRoot( defaultRoot );
	[defaultRoot release];

	//PXSoundEngineInit();
}

void PXEngineDealloc( )
{
	PXSoundEngineDealloc();

	// Backwards of init()
	if (pxEngineSharedObjectPool)
	{
		[pxEngineSharedObjectPool release];
		pxEngineSharedObjectPool = nil;
	}

	pxEngineRoot = nil;
	[pxEngineStage release];
	pxEngineStage = nil;

	[pxEngineEnterFrameEvent release];
	pxEngineEnterFrameEvent = nil;

	[pxEngineRemoveFromSavedTouchEvents release];
	pxEngineRemoveFromSavedTouchEvents = nil;

	// Loops through each of the saved touches, and releases their hold on the
	// target.  This is used in checking if the finger was released inside or
	// outside of the bounding area of the first target.

	PXTouchEvent *savedTouch;
	PXLinkedListForEach(pxEngineSavedTouchEvents, savedTouch)
	{
		[savedTouch->_target release];
	}

	[pxEngineSavedTouchEvents release]; pxEngineSavedTouchEvents = nil;

	[pxEngineTouchEvents release]; pxEngineTouchEvents = nil;
	[pxEngineCachedListeners release]; pxEngineCachedListeners = nil;
	[pxEngineFrameListeners release]; pxEngineFrameListeners = nil;

	// Get rid of the render-to-texture buffer
	if (pxEngineRTTFBO != 0)
		glDeleteFramebuffersOES( 1, &pxEngineRTTFBO );
	pxEngineRTTFBO = 0;

	PXGLDealloc( );

	[pxEngine dealloc];
	pxEngine = nil;

	pxEngineView = nil;

	if (pxEngineDOBuffer.array)
	{
		for (int index = 0; index < pxEngineDOBuffer.size; ++index)
			[pxEngineDOBuffer.array[index].displayObject release];

		free( pxEngineDOBuffer.array );
		pxEngineDOBuffer.array = 0;
	}

	_PXTopLevelDealloc();

	pxEngineInitialized = false;
}

_PXEngineDisplayObject *PXEngineNextBufferObject( )
{
	//Check to see if our size (you could also think of this as the current
	//index for our purposes) is at the end of the array.  If so, then we need
	//to increase the size of the array.
	if (pxEngineDOBuffer.size == pxEngineDOBuffer.maxSize)
	{
		//Lets double the size of the array
		pxEngineDOBuffer.maxSize <<= 1;
		pxEngineDOBuffer.array = realloc( pxEngineDOBuffer.array, sizeof( _PXEngineDisplayObject ) * pxEngineDOBuffer.maxSize );
	}

	//Lets return the next available vertex for use.
	return &pxEngineDOBuffer.array[pxEngineDOBuffer.size++];
}

PXView *PXEngineGetView( )
{
	return pxEngineView;
}
unsigned PXEngineGetViewWidth( )
{
	return pxEngineViewSize.width;
}

unsigned PXEngineGetViewHeight( )
{
	return pxEngineViewSize.height;
}

void PXEngineUpdateViewSize()
{
	return;

	// This does not work properly, it may not be needed.

	//pxEngineViewSize = pxEngineView.bounds.size;

	//float contentScaleFactor = pxEngineView.contentScaleFactor;
	//float one_contentScaleFactor = 1.0f / contentScaleFactor;

	//pxEngineViewSize.width  *= one_contentScaleFactor;
	//pxEngineViewSize.height *= one_contentScaleFactor;

	//PXGLSetViewSize(pxEngineViewSize.width, pxEngineViewSize.height, contentScaleFactor);
}

void PXEngineConvertPointToStageOrientation(float *x, float *y)
{
	if (x && y)
	{
		PX_ENGINE_CONVERT_POINT_TO_STAGE_ORIENTATION(*x, *y, pxEngineStage);
	}
}

PXStage *PXEngineGetStage( )
{
	return pxEngineStage;
}

void PXEngineSetContentScaleFactor(float scale)
{
	PXGLSetViewSize(pxEngineViewSize.width, pxEngineViewSize.height, scale, true);
}
float PXEngineGetContentScaleFactor()
{
	return PXGLGetContentScaleFactor();
}
float PXEngineGetOneOverContentScaleFactor()
{
	return PXGLGetOneOverContentScaleFactor();
}
float PXEngineGetMainScreenScale()
{
	float screenScaleFactor = 1.0f;
#ifdef __IPHONE_4_0
	NSString *reqSysVer = @"4.0";
	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
	if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
		screenScaleFactor = [UIScreen mainScreen].scale;
#endif
	return screenScaleFactor;
}

void PXEngineSetMultiTouchEnabled(BOOL enabled)
{
	pxEngineView.multipleTouchEnabled = enabled;
}

void PXEngineSetRoot( PXDisplayObject *root )
{
	if (!root)
		return;

	if (root == pxEngineRoot)
		return;

	if (pxEngineRoot)
		[pxEngineStage removeChild:pxEngineRoot];

	pxEngineRoot = root;
	[pxEngineStage addChild:pxEngineRoot];
	[pxEngineRoot setName:@"root1"];
}

PXDisplayObject *PXEngineGetRoot( )
{
	return pxEngineRoot;
}

BOOL PXEngineIsInitialized( )
{
	return pxEngineInitialized;
}

#pragma mark Clearing the screen

void PXEngineSetClearScreen( BOOL clear )
{
	pxEngineShouldClear = clear;
}

BOOL PXEngineShouldClearScreen( )
{
	return pxEngineShouldClear;
}

void PXEngineSetClearColor(PXColor3f color)
{
	pxEngineClearColor = color;
}
PXColor3f PXEngineGetClearColor()
{
	return pxEngineClearColor;
}

/*
void PXEngineSetTimerInterval( float seconds )
{
	[pxEngine startAnimationWithInterval:1.0f / seconds];
}

void PXEngineSetTimerStep( float dt )
{
	pxEngineRenderDT = dt;
	pxEngineRenderDTAccum = 0.0f;
}
*/

#pragma mark Setting the Frame Rate

void PXEngineUpdateMainLoopInterval()
{
	pxEngineMainDT = PXMathMin(pxEngineLogicDT, pxEngineRenderDT);

	float minDT = 1.0f / pxEngineMaxFrameRate;
	float index = 2.0f;
	float startDT = minDT;
	float lastDT = startDT;

	while (startDT < pxEngineMainDT)
	{
		lastDT = startDT;
		startDT = 1.0f / (pxEngineMaxFrameRate/index);

		index += 1.0f;
	}
	startDT = lastDT;
	pxEngineMainDT = startDT;

	// Make sure the real timer interval never goes under the minimum frame rate
	// @see PX_ENGINE_MIN_FRAME_RATE
	if (pxEngineMainDT > pxEngineMaxDT)
		pxEngineMainDT = pxEngineMaxDT;
	else if (pxEngineMainDT < minDT)
		pxEngineMainDT = minDT;	

	[pxEngine updateMainLoopInterval];
}

void PXEngineSetLogicFrameRate(float fps)
{
	fps = roundf(fps);

	if (PXMathIsZero(fps))
	{
		pxEngineLogicDT = 0.0f;
	}
	else
	{
		if (fps < pxEngineMinFrameRateSeconds)
			fps = pxEngineMinFrameRateSeconds;
		else if (fps > pxEngineMaxFrameRate)
			fps = pxEngineMaxFrameRate;

		pxEngineLogicDT = 1.0f / fps;
	}

	PXEngineUpdateMainLoopInterval();
}
float PXEngineGetLogicFrameRate()
{
	if (PXMathIsZero(pxEngineLogicDT))
		return 0.0f;

	return 1.0f / pxEngineLogicDT;
}

void PXEngineSetRenderFrameRate(float fps)
{
	fps = roundf(fps);

	if (PXMathIsZero(fps))
	{
		pxEngineRenderDT = 0.0f;
	}
	else
	{
		if (fps < pxEngineMinFrameRateSeconds)
			fps = pxEngineMinFrameRateSeconds;
		else if (fps > pxEngineMaxFrameRate)
			fps = pxEngineMaxFrameRate;

		pxEngineRenderDT = 1.0f / fps;
	}

	PXEngineUpdateMainLoopInterval();
}
float PXEngineGetRenderFrameRate()
{
	if (PXMathIsZero(pxEngineRenderDT))
		return 0.0f;
	return 1.0f / pxEngineRenderDT;
}

/**
 * Plays and pauses the engine
 */
void PXEngineSetRunning(bool val)
{
	pxEngineIsRunning = val;
	PXEngineUpdateMainLoopInterval();
}
bool PXEngineGetRunning()
{
	return pxEngineIsRunning;
}

#pragma mark Registering Frame Event Listeners

void PXEngineAddFrameListener( PXDisplayObject *displayObject )
{
	if (!pxEngineFrameListeners)
		return;

	[pxEngineFrameListeners addObject:displayObject];
}

void PXEngineRemoveFrameListener( PXDisplayObject *displayObject )
{
	if (!pxEngineFrameListeners)
		return;

	[pxEngineFrameListeners removeObject:displayObject];
}

PXDisplayObject *PXEngineFindTouchTarget( float x, float y )
{
	PXDisplayObject *target;
	PXDisplayObjectContainer *parent;
	PXDisplayObject *possibleParentTarget = nil;
	PXGLAABB *aabb;

	BOOL touchEnabled = NO;
	BOOL origTouchEnabled = NO;
	BOOL parentTouchEnabled = NO;
	BOOL onceHadTarget = NO;

	_PXEngineDisplayObject *curDisplayObject;
	int index;
	int startIndex = pxEngineDOBuffer.size - 1;

	for (index = startIndex, curDisplayObject = &(pxEngineDOBuffer.array[startIndex]);
		 index >= 0;
		 --index, --curDisplayObject)
	{
		//target = pxEngineDOBuffer.array[index].displayObject;
		target = curDisplayObject->displayObject;

		aabb = &target->_aabb;

		if (!PXGLAABBContainsPointv(aabb, x, y))
		{
			continue;
		}

		if (!([target _hitTestPointWithoutRecursionWithGlobalX:x andGlobalY:y shapeFlag:YES]))
		{
			continue;
		}

		origTouchEnabled = PX_IS_BIT_ENABLED(target->_flags, _PXDisplayObjectFlags_isInteractive) ? ((PXInteractiveObject *)(target))->_touchEnabled : NO;
		touchEnabled = origTouchEnabled;

		parent = (PXDisplayObjectContainer *)(target->_parent);
		onceHadTarget = NO;

		if (parent)
		{
			parentTouchEnabled = PX_IS_BIT_ENABLED(parent->_flags, _PXDisplayObjectFlags_isInteractive) ? ((PXInteractiveObject *)(parent))->_touchEnabled : NO;

			if (!(parent->_touchChildren) && parent == pxEngineRoot && parentTouchEnabled)
			{
				onceHadTarget = YES;
				possibleParentTarget = parent;
			}
		}

		while (parent && parent != pxEngineRoot)
		{
			if (parent == possibleParentTarget)
			{
				onceHadTarget = YES;
			}

			parentTouchEnabled = PX_IS_BIT_ENABLED(parent->_flags, _PXDisplayObjectFlags_isInteractive) ? ((PXInteractiveObject *)(parent))->_touchEnabled : NO;

			if (parent->_touchChildren) //|| !parentTouchEnabled )
			{
				if (!touchEnabled && parentTouchEnabled)
				{
					possibleParentTarget = parent;
					onceHadTarget = YES;
					touchEnabled = parentTouchEnabled;
				}

				parent = (PXDisplayObjectContainer *)parent->_parent;

				continue;
			}

			target = parent;
			possibleParentTarget = nil;
			onceHadTarget = NO;
			touchEnabled = parentTouchEnabled;
			origTouchEnabled = parentTouchEnabled;
			parent = (PXDisplayObjectContainer *)parent->_parent;
		}

		//if (!onceHadTarget && possibleParentTarget)
		if (onceHadTarget && possibleParentTarget)
		{
			return possibleParentTarget;
		}

		if (origTouchEnabled)
		{
			return target;
		}
	}

	return possibleParentTarget;
}

void PXEngineDispatchTouchEvents( )
{
	if (pxEngineTouchEvents.count == 0)
	{
		return;
	}

	PXTouchEvent *originalEvent = nil;
	PXTouchEvent *savedEvent = nil;
	PXDisplayObject *target = pxEngineStage;
	PXDisplayObject *savedTarget = pxEngineStage;
	PXTouchEvent *outOrCancelEvent;
	PXTouchEvent *doubleTapEvent;
	PXInteractiveObject *interactiveTarget;
	CGPoint pos;
	NSString *eventType = nil;

	bool didTouchUp     = false;
	bool didTouchCancel = false;
	bool didTouchDown   = false;
	bool didTouchUpOrCancel = false;

	if (pxEngineStage->_touchChildren)
	{
		PXLinkedListForEach(pxEngineTouchEvents, originalEvent)
		{
			target = PXEngineFindTouchTarget(originalEvent.stageX, originalEvent.stageY);

			if (!target)
				target = pxEngineStage;

			eventType = originalEvent.type;

			// Ok, this is pretty complicated.  If either the user touched up,
			// or down, we need to make this check.  If they touched down, then
			// we need to retain the target they were going for, if they are
			// touching up, we need to release it.  This is because we need to
			// ensure the object doesn't disappear prior to sending out the
			// event.
			didTouchCancel = [eventType isEqualToString:PX_TOUCH_EVENT_TOUCH_CANCEL];
			didTouchUp     = [eventType isEqualToString:PX_TOUCH_EVENT_TOUCH_UP];
			didTouchDown   = [eventType isEqualToString:PX_TOUCH_EVENT_TOUCH_DOWN];
			didTouchUpOrCancel = didTouchUp || didTouchCancel;

			if (didTouchUpOrCancel || didTouchDown)
			{
				// Go through each of the saved touch events, and check to see
				// if our native touch... meaning the touch given to us by the
				// UI device, is the same as the touch we are checking against.
				PXLinkedListForEach(pxEngineSavedTouchEvents, savedEvent)
				{
					if (savedEvent.nativeTouch == originalEvent.nativeTouch)
					{
						savedTarget = savedEvent->_target;

						// If our saved target isn't the same as our current
						// target, then we need to update the previous target.
						// Otherwise we need to release the event we are holding
						// so that we do not hold it into memory forever.
						if (savedTarget != target)
						{
							if (didTouchUpOrCancel && savedTarget)
							{
								// Make a cgpoint out of the position.
								pos = CGPointMake(savedEvent->_stageX, savedEvent->_stageY);
								// Make an event to dispatch upon releasing the
								// button outside of it's place.
								outOrCancelEvent = pxEngineNewTouchEventWithTouch(savedEvent->_nativeTouch,
																				  &pos,
																				  (didTouchUp ? PX_TOUCH_EVENT_TOUCH_OUT : PX_TOUCH_EVENT_TOUCH_CANCEL),
																				  NO);

								[savedTarget dispatchEvent:outOrCancelEvent];
								[outOrCancelEvent release];

								// Make sure we release the target we kept a
								// retain on.
								[savedTarget release];
								savedEvent->_target = nil;
							}
							else
							{
								// If we had a previous saved target, we should
								// release it before swapping the pointer.
								if (savedTarget)
									[savedTarget release];

								// Lets retain it, so it can't die while we are
								// using it; then we should set the pointer.
								[target retain];
								savedEvent->_target = target;
							}
						}
						else if (didTouchUpOrCancel)
						{
							// We touched up in the same area we touched down
							// on, so we just need to release the target as no
							// out event will be sent.. the up event was already
							// sent also.
							[savedEvent->_target release];
							savedEvent->_target = nil;
							savedTarget = nil;
						}

						break;
					} // if (savedEvent.nativeTouch == event.nativeTouch)
				} // PXLinkedListForEach
			} // if (didTouchUpOrCancel || didTouchDown)

			if ([target isKindOfClass:PXInteractiveObject.class])
				interactiveTarget = (PXInteractiveObject *)target;
			else
				interactiveTarget = nil;

			if ([eventType isEqualToString:PX_TOUCH_EVENT_TAP] &&
				(interactiveTarget.doubleTapEnabled && savedEvent.tapCount == 2))
			{
				CGPointMake(savedEvent->_stageX, savedEvent->_stageY);
				// Make an event to dispatch upon releasing the
				// button outside of it's place.
				doubleTapEvent = pxEngineNewTouchEventWithTouch(savedEvent->_nativeTouch,
																&pos,
																PX_TOUCH_EVENT_DOUBLE_TAP,
																NO);

				[target dispatchEvent:doubleTapEvent];
				[doubleTapEvent release];
			}
			else
			{
				originalEvent->_target = target;
				[target dispatchEvent:originalEvent];
			}
		}
	}
	else
	{
		PXLinkedListForEach(pxEngineTouchEvents, originalEvent)
		{
			originalEvent->_target = target;
			[target dispatchEvent:originalEvent];
		}
	}

	[pxEngineTouchEvents removeAllObjects];

	PXLinkedListForEach(pxEngineRemoveFromSavedTouchEvents, originalEvent)
	{
		[pxEngineSavedTouchEvents removeObject:originalEvent];
	}

	[pxEngineRemoveFromSavedTouchEvents removeAllObjects];
}

void PXEngineDispatchFrameEvents( )
{
	if (pxEngineFrameListeners.count == 0)
		return;

	PXDisplayObject *child = nil;

	// Dispatch it on all listeners (listeners must be PXDisplayObject's, but aren't necessarily on the display list, don't have to have a non-nil 'parent')
	PXLinkedListForEach(pxEngineFrameListeners, child)
	{
		[pxEngineCachedListeners addObject:child];
	}

	// From Flash API:
	// Note: This event has neither a "capture phase" nor a "bubble phase", which means that event listeners must be added directly to any potential targets, whether the target is on the display list or not.
	PXLinkedListForEach(pxEngineCachedListeners, child)
	{
		//The enterFrame event doesn't follow the event flow, even though it's dispatched into the display list in some cases
		[child _dispatchEventNoFlow:pxEngineEnterFrameEvent];
	}

	[pxEngineCachedListeners removeAllObjects];
}

void PXEngineRender( )
{
	assert( pxEngineDOBuffer.array );
	for (int index = 0; index < pxEngineDOBuffer.size; ++index)
		[pxEngineDOBuffer.array[index].displayObject release];

	pxEngineDOBuffer.size = 0;

	if (pxEngineDOBufferMaxSize < (pxEngineDOBufferOldMaxSize >> 2))
	{
		int newMaxSize = pxEngineDOBuffer.maxSize >> 1;
		if (newMaxSize > PX_ENGINE_MIN_BUFFER_SIZE)
		{
			pxEngineDOBuffer.maxSize = newMaxSize;
			pxEngineDOBuffer.array = realloc( pxEngineDOBuffer.array, sizeof( _PXEngineDisplayObject ) * pxEngineDOBuffer.maxSize );
		}
	}

	pxEngineDOBufferOldMaxSize = pxEngineDOBufferMaxSize;
	pxEngineDOBufferMaxSize = 0;

	if (pxEngineShouldClear)
	{
		//glClearColor( pxEngineStage->_bgColorR, pxEngineStage->_bgColorG, pxEngineStage->_bgColorB, 1.0f );
		glClearColor(pxEngineClearColor.r, pxEngineClearColor.g, pxEngineClearColor.b, 1.0f);
		glClear( GL_COLOR_BUFFER_BIT );
	}

	PXGLPreRender( );
	//glPushMatrix( );

#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_HalveStage))
	{
		/*
		glPushMatrix();
		glScalef(0.5f, 0.5f, 1.0f);
		glTranslatef(pxEngineViewSize.width * 0.5f, pxEngineViewSize.height * 0.5f, 0.0f);
		 */
		PXGLPushMatrix();
		PXGLTranslate(pxEngineViewSize.width * 0.5f, pxEngineViewSize.height * 0.5f);
		PXGLScale(0.5f, 0.5f);
	}
#endif

	PXEngineRenderDisplayObject(pxEngineStage, true, true);

#ifdef PX_DEBUG_MODE
	
	// Draw a magenta border around the smaller stage
	if (PXDebugIsEnabled(PXDebugSetting_HalveStage))
	{
		float locs[8];
		
		float viewWidth = pxEngineViewSize.width;
		float viewHeight = pxEngineViewSize.height;
		
		locs[0] = 0.0f;			locs[1] = 0.0f;
		locs[2] = 0.0f;			locs[3] = viewHeight;
		locs[4] = viewWidth;	locs[5] = viewHeight;
		locs[6] = viewWidth;	locs[7] = 0.0f;
		
		PXGLLineWidth(1.0f);
		PXGLShadeModel(GL_SMOOTH);
		PXGLDisable(GL_TEXTURE_2D);
		PXGLDisable(GL_POINT_SPRITE_OES);
		PXGLColor4ub(0xFF, 0x00, 0xFF, 0xFF);
		PXGLVertexPointer(2, GL_FLOAT, 0, locs);
		PXGLDrawArrays(GL_LINE_LOOP, 0, 4);
		//PXGLFlush();
		
		PXGLPopMatrix();
	}
	
	if (PXDebugIsEnabled(PXDebugSetting_DrawBoundingBoxes))
	{
		float locs[8];
		
		PXGLAABB aabb;
		PXGLAABB *aabbPtr;
		PXDisplayObject *doAABB;
		
		for (int index = 0; index < pxEngineDOBuffer.size; ++index)
		{
			doAABB = pxEngineDOBuffer.array[index].displayObject;

			if (!PX_IS_BIT_ENABLED(doAABB->_flags, _PXDisplayObjectFlags_shouldRenderAABB))
				continue;
			
			aabbPtr = &doAABB->_aabb;
			
			aabb.xMin = aabbPtr->xMin;
			aabb.xMax = aabbPtr->xMax;
			aabb.yMin = aabbPtr->yMin;
			aabb.yMax = aabbPtr->yMax;
			
			PX_ENGINE_CONVERT_AABB_TO_STAGE_ORIENTATION(&aabb, pxEngineStage);
			PX_ENGINE_CONVERT_AABB_TO_STAGE_ORIENTATION(&aabb, pxEngineStage);
			PX_ENGINE_CONVERT_AABB_TO_STAGE_ORIENTATION(&aabb, pxEngineStage);
			
			locs[0] = aabb.xMin; locs[1] = aabb.yMin;
			locs[2] = aabb.xMin; locs[3] = aabb.yMax;
			locs[4] = aabb.xMax; locs[5] = aabb.yMax;
			locs[6] = aabb.xMax; locs[7] = aabb.yMin;
			
			PXGLShadeModel(GL_SMOOTH);
			PXGLDisable( GL_TEXTURE_2D );
			PXGLColor4ub( 0xFF, 0, 0, 0xFF );
			PXGLVertexPointer( 2, GL_FLOAT, 0, locs );
			PXGLDrawArrays( GL_LINE_LOOP, 0, 4 );
		}
	}
#endif

	PXGLPostRender( );
	PXGLConsolidateBuffers( );

	/*
#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_HalveStage))
	{
		glPopMatrix();
	}
#endif
	 */

	[pxEngineView _swapBuffers];
}

/*
 if (pxEngineRenderDT <= 0)
 return;
 
 pxEngineRenderDTAccum += pxEngineMainDT;
 if (pxEngineRenderDTAccum < pxEngineRenderDT)
 return;
 
 pxEngineRenderDTAccum = 0.0f;
 */

void PXEngineLogicPhase( )
{
	PXEngineDispatchTouchEvents( ); //Touch

	pxEngineLogicTimeAccum += pxEngineMainDT;

	if (pxEngineLogicTimeAccum >= pxEngineLogicDT)
	{
#ifdef PX_DEBUG_MODE
		if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
		{
			NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
			NSTimeInterval end = 0;
			PXEngineDispatchFrameEvents( ); //Frame
			pxEngineLogicTimeAccum -= pxEngineLogicDT;
			end = [NSDate timeIntervalSinceReferenceDate];
			pxEngineTimeBetweenLogic = end - start;

			return;
		}
#endif

		PXEngineDispatchFrameEvents( ); //Frame
		pxEngineLogicTimeAccum -= pxEngineLogicDT;
	}
}

void PXEngineRenderPhase( )
{
	// If we don't have a render change in time, and 
	if (!PXMathIsZero(pxEngineRenderDT))
	{
		pxEngineRenderTimeAccum += pxEngineMainDT;
		if (pxEngineRenderTimeAccum >= pxEngineRenderDT)
		{
#ifdef PX_DEBUG_MODE
			if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
			{
				NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
				NSTimeInterval end = 0;
	
				PXEngineRender( ); //Render
				pxEngineRenderTimeAccum -= pxEngineRenderDT;

				end = [NSDate timeIntervalSinceReferenceDate];
				pxEngineTimeBetweenRendering = end - start;

				return;
			}
#endif

			PXEngineRender( ); //Render
			pxEngineRenderTimeAccum -= pxEngineRenderDT;
		}
	}
}

void PXEngineOnFrame( )
{
	PXSoundEngineUpdate( );

	PXEngineLogicPhase( );
	PXEngineRenderPhase( );

#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
	{
		pxEngineTimeBetweenFrames = pxEngineTimeBetweenLogic + pxEngineTimeBetweenRendering;
	}
#endif
}

#pragma mark -
#pragma mark RENDER
#pragma mark -
void PXEngineRenderDisplayObject(PXDisplayObject *displayObject, bool transformationsEnabled , bool canBeUsedForTouches)
{
	//////////////////////
	// Quick exit tests //
	//////////////////////
	
	float doScaleX = 1.0f;
	float doScaleY = 1.0f;
	float doAlpha = 1.0f;
	
	if (transformationsEnabled)
	{
		doScaleX = displayObject->_scaleX;
		doScaleY = displayObject->_scaleY;
		doAlpha = displayObject->_colorTransform.alphaMultiplier;

		if (!PX_IS_BIT_ENABLED(displayObject->_flags, _PXDisplayObjectFlags_visible))
			return;

		if (PXMathIsZero( doScaleX ))
			return;

		if (PXMathIsZero( doScaleY ))
			return;

		// This has been commented out so that display objects with
		// an alpha of 0.0 can get clicked

		//if ( doAlpha < 0.0001f )
		//	return;
	}	

	//Byte count = 12

	bool matrixPushed = false;
	bool transformPushed = false;
	bool crippleAABB = false;
	bool useCustomHitArea = PX_IS_BIT_ENABLED(displayObject->_flags, _PXDisplayObjectFlags_useCustomHitArea);
	//Byte count = 16

	bool isCustom = displayObject->_renderMode == PXRenderMode_Custom;
	bool isCustomOrManaged = (displayObject->_renderMode == PXRenderMode_ManageStates) || isCustom;
	bool isRenderOn = !(displayObject->_renderMode == PXRenderMode_Off);
	bool padding = false; // ;-/
	padding = padding ? !padding : padding;
	//Byte count = 20

	if (isCustomOrManaged)
	{
		PXGLFlush( );
	}

	if (transformationsEnabled)
	{
		float doX = displayObject->_matrix.tx;
		float doY = displayObject->_matrix.ty;
		float doRotation = displayObject->_rotation;
		// ByteCount = 32

		// Color Transform
		PXGLColorTransform *doColorTransform = &displayObject->_colorTransform;
		// Byte count = 36

		// Matrix Transform
		//Should translate, scale or rotate
		if (!PXMathIsZero( doX ) ||
			!PXMathIsZero( doY ) ||
		    !PXMathIsOne( doScaleX ) ||
			!PXMathIsOne( doScaleY ) ||
		    !PXMathIsZero( doRotation ))
		{
			PXGLPushMatrix( );
			PXGLMultMatrix( &displayObject->_matrix );

			matrixPushed = true;
		}

		if (!PXMathIsOne(doColorTransform->redMultiplier  ) ||
			!PXMathIsOne(doColorTransform->greenMultiplier) ||
			!PXMathIsOne(doColorTransform->blueMultiplier ) ||
			!PXMathIsOne(doAlpha))
		{
			PXGLColorTransform colorTransform;
			// Byte count = 52

			colorTransform.redMultiplier   = doColorTransform->redMultiplier;
			colorTransform.greenMultiplier = doColorTransform->greenMultiplier;
			colorTransform.blueMultiplier  = doColorTransform->blueMultiplier;
			colorTransform.alphaMultiplier = doAlpha;

			PXGLPushColorTransform( );
			PXGLSetColorTransform( &colorTransform );

			transformPushed = true;
		}
		// Byte count = 36
	}

	// Byte count = 20

	PXGLAABB *doAABB = &displayObject->_aabb;
	//Byte count = 24

	// Used for debugging - will only have an aabb if it can be used for
	// touching.
	if (canBeUsedForTouches)
	{
		PX_ENABLE_BIT(displayObject->_flags, _PXDisplayObjectFlags_shouldRenderAABB);
	}
	else
	{
		PX_DISABLE_BIT(displayObject->_flags, _PXDisplayObjectFlags_shouldRenderAABB);
	}
	//displayObject->_shouldRenderAABB = canBeUsedForTouches;

	if (isRenderOn)
	{
		// Reset the bounding box in gl so that when we draw it, it updates the
		// bounding box to the drawn area. If custom or managed, then it resets
		// the aabb to the clip rect defined in gl; this is done because it will
		// always fire for the touch events, as long as the clip rect is within
		// a touchable area.
		PXGLResetAABB(isCustomOrManaged);

		// If it is custom or managed, then we need the real matrix to be inside
		// gl, so when they use the gl draw commands, they draw in the correct
		// spot. Note, this will push the ENTIRE matrix thus far, so we need to
		// pop it immediately after incase a child of this custom or managed is
		// also custom or managed.
		if (isCustomOrManaged)
		{
			PXGLSyncTransforms();
		}

		PXGLResetStates(displayObject->_glState);
		displayObject->_impRenderGL( displayObject, nil );

		// Popping the matrix, please see the above comment.
		if (isCustomOrManaged)
		{
			PXGLUnSyncTransforms();
		}

		// This is like popping the color transform of the display object. It
		// resets the color to the previous color on the stack (that was set
		// before they called 'color4f, or color4ub').
		PXGLColor4ub( 0xFF, 0xFF, 0xFF, 0xFF );

		// Grab the current AABB of the drawn display object (only itself, not
		// it's children).
		PXGLAABB *aabb = PXGLGetCurrentAABB( );
		// Byte count = 28

		if (useCustomHitArea)
		{
			CGRect aabbRect;
			[displayObject _measureGlobalBounds:&aabbRect];

			aabb->xMin = floorf(aabbRect.origin.x);
			aabb->yMin = floorf(aabbRect.origin.y);
			aabb->xMax = ceilf(aabb->xMin + aabbRect.size.width);
			aabb->yMax = ceilf(aabb->yMin + aabbRect.size.height);

			PXGLAABBMult(aabb);
		}

		// Is usable refers to if the display object even drew anything, which
		// will change the AABB from max/min ints (the reset state) to what was
		// drawn. IsAABBVisable is true when the aabb is within the current
		// clipping rectangle.
		if ((!PXGLAABBIsReset(aabb)) && PXGLIsAABBVisible(aabb) && canBeUsedForTouches)
		{
			// List is to contain a display object pointer, and an aabb. We
			// retain it here, as it is released when the list is emptied
			// (which is done after drawing).
			[displayObject retain];

			// We get the next object on the 'drawn list' and set this display
			// object and aabb to that object. This is done to retain a list of
			// drawn display objects for looping on when asking for touch
			// events.
			_PXEngineDisplayObject *obj = PXEngineNextBufferObject( );
			//Byte count = 32

		//	if (orientationEnabled)
		//	{
				PX_ENGINE_CONVERT_AABB_TO_STAGE_ORIENTATION(aabb, pxEngineStage);
		//	}

			// Set the AABB of the display object to the one found by rendering.
			doAABB->xMin = aabb->xMin;
			doAABB->yMin = aabb->yMin;
			doAABB->xMax = aabb->xMax;
			doAABB->yMax = aabb->yMax;

			obj->displayObject = displayObject;
			++pxEngineDOBufferMaxSize;
		}
		else
		{
			// The aabb was not acceptable, cripple the renderer's version
			crippleAABB = true;
		}
	}
	else
	{
		// The display object was not drawn, cripple the renderer's aabb so that
		// it can not be checked for touchs.
		crippleAABB = true;
	}

	//Byte count = 24

	if (crippleAABB)
	{
		// Setting the aabb to a bounds that makes no sense, and can not be both
		// below and above.
		doAABB->xMin =  1;
		doAABB->xMax = -1;
		doAABB->yMin =  1;
		doAABB->yMax = -1;
	}

	// If it is a custom drawing, then we need to set GL back to what Pixelwave
	// is, thus we need to upload every value of pixelwave back into gl.
	if (isCustom)
	{
		PXGLSyncGLToPX( );
	}

	// If you have children, draw them too!
	if (PX_IS_BIT_ENABLED(displayObject->_flags, _PXDisplayObjectFlags_isContainer))
	{
		PXDisplayObjectContainer *container = (PXDisplayObjectContainer *)displayObject;
		PXDisplayObject *child = container->_childrenHead;
		//Byte count = 32

		container->_impPreChildRenderGL( container, nil );

		unsigned index;
		//Byte count = 36
		for (index = 0; index < container->_numChildren; ++index)
		{
			PXEngineRenderDisplayObject( child, true, canBeUsedForTouches );

			child = child->_next;
		}

		container->_impPostChildRenderGL( container, nil );
	}
	// Byte count = 24

	// If we pushed a color transform, we need to pop it.
	if (transformPushed)
	{
		PXGLPopColorTransform( );
	}

	// If we pushed a matrix transform, we need to pop it.
	if (matrixPushed)
	{
		PXGLPopMatrix( );
	}
}

// clipRect is defined in POINTS
void PXEngineRenderToTexture( PXTextureData *textureData, PXDisplayObject *source, PXGLMatrix *matrix, PXGLColorTransform *colorTransform, CGRect *clipRect, BOOL smoothing, BOOL clearTexture )
{
	if (!textureData)
	{
		return;
	}
	if (!source)
	{
		return;
	}
	
	// Finish any rendering queued up to the main buffer
	PXGLFlush( );

	////////////////////////////////////////
	// Set up the texture rendering state //
	////////////////////////////////////////

	// Bind the renderToTexture buffer
	PXGLBindFramebuffer(GL_FRAMEBUFFER_OES, pxEngineRTTFBO);

	// Bind the texture to the buffer
	glFramebufferTexture2DOES( GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, textureData->_glName, 0 );

#ifdef PX_DEBUG_MODE
	// Make sure the buffer is bound properly
	GLenum status = glCheckFramebufferStatusOES( GL_FRAMEBUFFER_OES );

	if (status != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		PXDebugLog(@"Framebuffer object is not complete, error: %x", status);

		if (status == GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_OES)
		{
			PXDebugLog(@"GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT");
		}
		else if (status == GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_OES)
		{
			PXDebugLog(@"GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_OES");
		}
		else if (status == GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT_OES)
		{
			PXDebugLog(@"GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT");
		}
		else if (status == GL_FRAMEBUFFER_INCOMPLETE_FORMATS_OES)
		{
			PXDebugLog(@"GL_FRAMEBUFFER_INCOMPLETE_FORMATS_OES");
		}

		PXThrow(PXGLException, @"Framebuffer object is not complete. renderToTexture could not be completed");

		return;
	}
#endif

	// Decide if the render should be clipped
	BOOL bShouldClip = NO;
	BOOL bAlterViewport = NO;

	// Clip rect is in POINTS
	if(clipRect)
	{
		bShouldClip = YES;
	}

	// pxEngineViewSize is ALWAYS PORTRAIT. That's fine though because
	// renderToTexture doesn't take screen orientation into account, it's always
	// done in portrait as well. That's fine because we're not dealing with a 
	// screen we're rendering directly to texture

	// Now, since pxEngineViewSize is in POINTS, and TextureData in based on
	// PIXELS, we need to convert

	float textureDataScaleFactor = textureData.contentScaleFactor;
	CGSize textureDataSizeInPoints;
	textureDataSizeInPoints.width  = textureData.width  / textureDataScaleFactor;
	textureDataSizeInPoints.height = textureData.height / textureDataScaleFactor;

	if (textureDataSizeInPoints.width > pxEngineViewSize.width ||
		textureDataSizeInPoints.height > pxEngineViewSize.height)
	{
		bAlterViewport = YES;
	}

	// Set up the surfaces
	if (bAlterViewport)
	{
		// in POINTS
		PXGLSetViewSize(textureDataSizeInPoints.width, textureDataSizeInPoints.height, textureDataScaleFactor, false);//PXGLGetContentScaleFactor());

		// in POINTS
		PXGLClipRect( 0, 0, textureDataSizeInPoints.width, textureDataSizeInPoints.height );
	}
	
	if (bShouldClip)
	{
		glEnable( GL_SCISSOR_TEST );
		// Takes in coordinates in PIXELS
		glScissor(clipRect->origin.x	* textureDataScaleFactor,	// in PIXELS
				  clipRect->origin.y	* textureDataScaleFactor,	// in PIXELS
				  clipRect->size.width	* textureDataScaleFactor,	// in PIXELS
				  clipRect->size.height	* textureDataScaleFactor);	// in PIXELS
	}

	// Set up the rendering (reset the matrix/stacks/ect)
	
	PXGLPreRender( );

	if (matrix)
	{
		PXGLMultMatrix( matrix );
	}

	if (colorTransform)
	{
		PXGLSetColorTransform( colorTransform );
	}

	assert( pxEngineDOBuffer.array );

	// Clear the TextureData if the user asked
	if (clearTexture)
	{
		uint fillColor = textureData->_fillColor;
		float div = 1/255.0f;

		float a = (float)((fillColor >> 24) & 0xFF) * div;
		float r = (float)((fillColor >> 16) & 0xFF) * div;
		float g = (float)((fillColor >> 8) & 0xFF) * div;
		float b = (float)((fillColor) & 0xFF) * div;

		glClearColor(r, g, b, a);
		glClear( GL_COLOR_BUFFER_BIT );
	}

	// Offset in POINTS
	PXGLScale( 1.0f, -1.0f );

	if (bAlterViewport)
	{
		PXGLTranslate( 0, textureDataSizeInPoints.height );
	}
	else
	{
		PXGLTranslate( 0, pxEngineViewSize.height );
	}

	////////////
	// RENDER //
	////////////

	PXEngineRenderDisplayObject( source, false, false );

	// Flush anything, render any queued up commands
	PXGLPostRender( );

	////////////////////////////////////
	// Restore screen rendering state //
	////////////////////////////////////

	// Put the viewport / clip rect back to screen rendering settings
	if (bAlterViewport)
	{
		// in POINTS
		PXGLSetViewSize(pxEngineViewSize.width, pxEngineViewSize.height, pxEngineView.contentScaleFactor, true);
	}

	// in POINTS
	PXGLClipRect( 0, 0, pxEngineViewSize.width, pxEngineViewSize.height );

	if (bShouldClip)
	{
		glDisable( GL_SCISSOR_TEST );
	}

	// Switch back to main buffer
	PXGLBindFramebuffer( GL_FRAMEBUFFER_OES, pxEngineView->_framebuffer );
}

#pragma mark Extracting Pixel Data

// Delared in: PXTextureData.h

// x, y, width, height in PIXELS
void PXTextureDataReadPixels(PXTextureData *textureData, int x, int y, int width, int height, void *pixels)
{
	if(!textureData) return;
	
	// Change the state

	// Bind the Texture FBO
	PXGLBindFramebuffer(GL_FRAMEBUFFER_OES, pxEngineRTTFBO);
	// Connect the texture data to it
	glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES,
							  GL_COLOR_ATTACHMENT0_OES,
							  GL_TEXTURE_2D, textureData->_glName,
							  0);

	float textureDataScaleFactor = textureData.contentScaleFactor;
	float one_textureDataScaleFactor = 1.0f / textureDataScaleFactor;
	float widthInPoints = width * one_textureDataScaleFactor;
	float heightInPoints = height * one_textureDataScaleFactor;
	
	// Update the view size to match the texture's
	//PXGLSetViewSize(width, height, textureData.contentScaleFactor, false);
	PXGLSetViewSize(widthInPoints, heightInPoints, textureDataScaleFactor, false);

	// Read
	glReadPixels(x, y,
				 width, height,
				 GL_RGBA, GL_UNSIGNED_BYTE,
				 pixels);

	// Revert the state
	// Set the viewport back to match the screen's
	PXGLSetViewSize(pxEngineViewSize.width, pxEngineViewSize.height, pxEngineView.contentScaleFactor, true);

	// Bind the screen buffer back
	PXGLBindFramebuffer(GL_FRAMEBUFFER_OES, pxEngineView->_framebuffer);
}

/*
// Caller must free()
void *PXEngineGetScreenPixels(int *retWidth, int *retHeight)
{
	int width = pxEngineViewSize.width;
	int height = pxEngineViewSize.height;
	
	GLubyte *pixelData = malloc(width * height * 4);
	
	PXGLReadPixelsInverted(0, 0,
						   width, height,
						   pixelData);
	
	// Bind the screen buffer back
	PXGLBindFramebuffer(GL_FRAMEBUFFER_OES, pxEngineView->_framebuffer);
	
	// Give the pixels to the caller
	(*retWidth) = width;
	(*retHeight) = height;
	
	return pixelData;
}
*/

#pragma mark Misc

PXObjectPool *PXEngineGetSharedObjectPool()
{
	if (!pxEngineSharedObjectPool)
	{
		pxEngineSharedObjectPool = [[PXObjectPool alloc] init];
	}
	
	return pxEngineSharedObjectPool;
}

#pragma mark Touches

UITouch * PXEngineGetFirstTouch()
{
	if (!pxEngineSavedTouchEvents)
		return nil;

	if ([pxEngineSavedTouchEvents count] <= 0)
		return nil;

	PXTouchEvent *event = (PXTouchEvent *)[pxEngineSavedTouchEvents objectAtIndex:0];

	return event.nativeTouch;
}
PXLinkedList * PXEngineGetAllTouches()
{
	if (!pxEngineSavedTouchEvents)
		return nil;

	PXLinkedList *list = [[PXLinkedList alloc] init];
	PXTouchEvent *event;
	for (event in pxEngineSavedTouchEvents)
	{
		if (event.nativeTouch)
			[list addObject:event.nativeTouch];
	}

	return [list autorelease];
}

CGPoint PXEngineTouchToScreenCoordinates(UITouch *touch)
{
	if (!touch || !pxEngineView)
		return CGPointMake(0.0f, 0.0f);

	CGPoint point = [touch locationInView:pxEngineView];

	CAEAGLLayer *eaglLayer = (CAEAGLLayer *)[pxEngineView layer];
	CGPoint pos = eaglLayer.position;

	point.x += pos.x;
	point.y += pos.y;

	PX_ENGINE_CONVERT_POINT_TO_STAGE_ORIENTATION(point.x, point.y, pxEngineStage);

	return point;
}

PXTouchEvent *pxEngineNewTouchEventWithTouch(UITouch *touch, CGPoint *pos, NSString *type, BOOL orientTouch)
{
	PXTouchEvent *event;

	CGPoint location = CGPointMake(0.0f, 0.0f);

	if (pos)
	{
		location = *pos;
	}

	if (orientTouch)
	{
		PX_ENGINE_CONVERT_POINT_TO_STAGE_ORIENTATION(location.x, location.y, pxEngineStage);
#ifdef PX_DEBUG_MODE
		if (PXDebugIsEnabled(PXDebugSetting_HalveStage) && pos)
		{
			location.x = 2.0f * ((pxEngineStage.stageWidth  * 0.75f) + ((location.x) - (pxEngineStage.stageWidth)));
			location.y = 2.0f * ((pxEngineStage.stageHeight * 0.75f) + ((location.y) - (pxEngineStage.stageHeight)));
		}
#endif
	}

	event = [[PXTouchEvent alloc] initWithType:type nativeTouch:touch stageX:location.x stageY:location.y tapCount:touch.tapCount];

	return event;
}

void PXEngineInvokeTouchBegan(UITouch *touch, CGPoint *pos)
{
	PXTouchEvent *event = pxEngineNewTouchEventWithTouch(touch, pos, PX_TOUCH_EVENT_TOUCH_DOWN, YES);
	[pxEngineTouchEvents addObject:event];
	[event release];

	event = pxEngineNewTouchEventWithTouch(touch, pos, PX_TOUCH_EVENT_TAP, YES);
	[pxEngineSavedTouchEvents addObject:event];
	[event release];
}
void PXEngineInvokeTouchMoved( UITouch *touch, CGPoint *pos )
{
	PXTouchEvent *event = pxEngineNewTouchEventWithTouch(touch, pos, PX_TOUCH_EVENT_TOUCH_MOVE, YES);
	[pxEngineTouchEvents addObject:event];
	[event release];
}

void PXEngineInvokeTouchEnded( UITouch *touch, CGPoint *pos )
{
	PXTouchEvent *event = pxEngineNewTouchEventWithTouch(touch, pos, PX_TOUCH_EVENT_TOUCH_UP, YES);
	[pxEngineTouchEvents addObject:event];
	[event release];

	PXTouchEvent *savedTouch;
	//PXGenericObject object;

	int x = pos->x;
	int y = pos->y;

	PX_ENGINE_CONVERT_POINT_TO_STAGE_ORIENTATION(x, y, pxEngineStage);

	float distX;
	float distY;
	float touchDistanceSq;
	// 30 point radius

	PXLinkedListForEach(pxEngineSavedTouchEvents, savedTouch)
	{
		if (savedTouch.nativeTouch == touch)
		{
			distX = savedTouch->_stageX - x;
			distX *= distX;
			distY = savedTouch->_stageY - y;
			distY *= distY;
			touchDistanceSq = distX + distY;
			//PX_ENGINE_IS_TOUCH_SAME_PLACE((int)savedTouch->_stageX, (int)savedTouch->_stageY, x, y)
			//if ((int)savedTouch->_stageX == x
			//&& (int)savedTouch->_stageY == y)
			if (touchDistanceSq < PX_ENGINE_TOUCH_RADIUS_SQ)
			{
				[pxEngineTouchEvents addObject:savedTouch];
			}

			[pxEngineRemoveFromSavedTouchEvents addObject:savedTouch];
			break;
		}
	}
}
void PXEngineInvokeTouchCanceled( UITouch *touch )
{
	PXTouchEvent *event = pxEngineNewTouchEventWithTouch(touch, nil, PX_TOUCH_EVENT_TOUCH_CANCEL, YES);
	[pxEngineTouchEvents addObject:event];
	[event release];

	PXTouchEvent *savedTouch;

	PXLinkedListForEach(pxEngineSavedTouchEvents, savedTouch)
	{
		if (savedTouch.nativeTouch == touch)
		{
			[pxEngineRemoveFromSavedTouchEvents addObject:savedTouch];
			break;
		}
	}
}

float _PXEngineDBGGetTimeBetweenFrames()
{
#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
	{
		return pxEngineTimeBetweenFrames;
	}

#endif
	return 0.0f;
}
float _PXEngineDBGGetTimeBetweenLogic()
{
#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
	{
		return pxEngineTimeBetweenLogic;
	}
#endif

	return 0.0f;
}
float _PXEngineDBGGetTimeBetweenRendering()
{
#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
	{
		return pxEngineTimeBetweenRendering;
	}
#endif

	return 0.0f;
}
float _PXEngineDBGGetTimeWaiting()
{
#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
	{
		return pxEngineTimeWaiting;
	}
#endif

	return 0.0f;
}

////////////////////////////
// PXEngine Private Class //
////////////////////////////

@implementation PXEngine

- (id) init
{
	if (!(self = [super init]))
		return nil;

	displayLinkSupported = NO;
#ifdef __IPHONE_3_1
	NSString *reqSysVer = @"3.1";
	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
	if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
		displayLinkSupported = YES;
#endif

	animationTimer = nil;

	displayLink = nil;

	return self;
}

- (void) dealloc
{
	if (pxEngineSharedObjectPool)
	{
		[pxEngineSharedObjectPool release];
		pxEngineSharedObjectPool = nil;
	}
		
	if (displayLinkSupported && displayLink)
	{
		[displayLink invalidate];
		displayLink = nil;
	}
	
	if (animationTimer)
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}

	[super dealloc];
}

- (void) onTimerTick
{
#ifdef PX_DEBUG_MODE
	if (PXDebugIsEnabled(PXDebugSetting_CalculateFrameRate))
	{
	#if (PX_ENGINE_IDLE_TIME_INCLUDES_BETWEEN_SYSTEM_CALLS)
		NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
		float delta = end - pxEngineInterval;

		if (PXMathIsZero(pxEngineInterval) || PXMathIsZero(delta) || delta < 0.0f || delta > 2700.0f)
		{
			pxEngineTimeWaiting = 0.0f;
		}
		else
		{
			pxEngineTimeWaiting = delta - pxEngineTimeBetweenFrames;
		}
		pxEngineInterval = end;
	#else
		pxEngineTimeWaiting = pxEngineLogicDT - pxEngineTimeBetweenFrames;
		if (pxEngineTimeWaiting < 0.0f)
		{
			pxEngineTimeWaiting = 0.0f;
		}
	#endif
	}
#endif

//	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		PXEngineOnFrame( );
//	[pool release];
}

//- (void) startAnimationWithInterval:(float)interval
- (void) updateMainLoopInterval
{
	/*
	if (PXMathIsZero( interval ))
		return;

	pxEngineMainDT = interval;
*/

	if (displayLink)
	{
		[displayLink invalidate];
		displayLink = nil;
	}

	if (animationTimer)
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}

	if(!pxEngineIsRunning)
	{
		return;
	}

#ifdef __IPHONE_3_1
	if (displayLinkSupported)
	{
		displayLinkInterval = (int)(pxEngineMaxFrameRate * pxEngineMainDT);
		if (displayLinkInterval < 1)
			displayLinkInterval = 1;

		displayLink = [NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(onTimerTick)];

		[displayLink setFrameInterval:displayLinkInterval];
		[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	}
	else
#endif
	{
		animationTimer = [NSTimer scheduledTimerWithTimeInterval:pxEngineMainDT target:self selector:@selector(onTimerTick) userInfo:nil repeats:YES];
	}
}

@end
