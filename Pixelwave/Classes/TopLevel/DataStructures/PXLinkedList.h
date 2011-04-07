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

#import "PXPooledObject.h"

#include "PXSettings.h"
#include "PXPrivateUtils.h"

/**
 *	@ingroup TopLevel
 *
 *	Used to efficiently traverse the items in a linked list.
 */
#define PXLinkedListForEach(_list_,_obj_) \
        _PXLLNode *PX_UNIQUE_VAR(_node_) = (_list_)->_head; \
        if (PX_UNIQUE_VAR(_node_)) (_obj_) = PX_UNIQUE_VAR(_node_)->data; \
		\
        for (	int PX_UNIQUE_VAR(_i_) = 0, PX_UNIQUE_VAR(_len_) = (_list_)->_numNodes; \
				PX_UNIQUE_VAR(_i_) < PX_UNIQUE_VAR(_len_); \
				++PX_UNIQUE_VAR(_i_), PX_UNIQUE_VAR(_node_) = PX_UNIQUE_VAR(_node_)->next, _obj_ = (PX_UNIQUE_VAR(_node_) ? PX_UNIQUE_VAR(_node_)->data : 0))

/**
 *	@ingroup TopLevel
 *
 *	Used to efficiently traverse the items in a linked list from the end to the
 *	start.
 */
#define PXLinkedListForEachReverse(_list_,_obj_) \
        _PXLLNode *PX_UNIQUE_VAR(_node_) = (_list_)->_tail; \
        if (PX_UNIQUE_VAR(_node_)) (_obj_) = PX_UNIQUE_VAR(_node_)->data; \
		\
        for (	int PX_UNIQUE_VAR(_i_) = (_list_)->_numNodes - 1; \
				PX_UNIQUE_VAR(_i_) >= 0; \
				--PX_UNIQUE_VAR(_i_), PX_UNIQUE_VAR(_node_) = PX_UNIQUE_VAR(_node_)->prev, _obj_ = (PX_UNIQUE_VAR(_node_) ? PX_UNIQUE_VAR(_node_)->data : 0))

/// @cond DX_IGNORE
// structure PXLinkedList Node, made public (but private) so the
// PXLinkedListForEach and reverse methods work for other people.
typedef struct _sPXLLNode
{
	struct _sPXLLNode *next;
	struct _sPXLLNode *prev;

	PXGenericObject data;
} _PXLLNode;
/// @endcond

@interface PXLinkedList : NSObject<NSFastEnumeration, NSCopying, NSCoding, PXPooledObject>
{
/// @cond DX_IGNORE
@public
	_PXLLNode *_head;
	_PXLLNode *_tail;

	unsigned _numNodes;

	BOOL _pooledNodes;
	BOOL _keepStrongReference;
@private
	short pxLLPadding;
/// @endcond
}

/**
 *	The number of items in the list.
 */
@property (nonatomic, readonly) unsigned count;
/**
 *	The first object in the list.
 *
 *	<i><b>Complexity:</b> O(1)</i>
 */
@property (nonatomic, readonly) PXGenericObject firstObject;
/**
 *	The last object in the list.
 *
 *	<i><b>Complexity:</b> O(1)</i>
 */
@property (nonatomic, readonly) PXGenericObject lastObject;
/**
 *	<code>YES</code> if the list does not retain its elements; otherwise
 *	<code>NO</code>.  Default value is <code>NO</code>, as it is advised to keep
 *	a retain on the added elements.
 *	
 *	@see PXLinkedList::initWithWeakReferences:
 */
@property (nonatomic, readonly) BOOL weakReferences;

//-- ScriptIgnore
- (id) initWithPooledNodes:(BOOL)pooledNodes;
//-- ScriptIgnore
- (id) initWithWeakReferences:(BOOL)weakReferences;
//-- ScriptName: LinkedList
//-- ScriptArg[0]: PX_LINKED_LISTS_USE_POOLED_NODES
//-- ScriptArg[1]: NO
- (id) initWithWeakReferences:(BOOL)weakReferences usePooledNodes:(BOOL)pooledNodes;

// Adding, +1 retain
//-- ScriptName: push
- (void) addObject:(PXGenericObject)object;
//- (void) insertObjectAtFront:(PXGenericObject)object;
//- (void) insertObject:(PXGenericObject)object beforeObject:(PXGenericObject)objectToAddBefore;
//-- ScriptName: pushAt
- (void) insertObject:(PXGenericObject)object atIndex:(int)index;
//-- ScriptName: pushAllFrom
- (void) addObjectsFromList:(PXLinkedList *)otherList;

// Removing, -1 retain
//-- ScriptName: pop
- (void) removeObject:(PXGenericObject)object;
//-- ScriptName: popAt
- (void) removeObjectAtIndex:(int)index;
//-- ScriptName: popLast
- (void) removeLastObject;
//-- ScriptName: popFirst
- (void) removeFirstObject;
//-- ScriptName: popAll
- (void) removeAllObjects;
//-- ScriptName: popAllFrom
- (void) removeObjectsInList:(PXLinkedList *)otherList;

// Swapping
//-- ScriptName: swap
- (void) swapObject:(PXGenericObject)object1 withObject:(id)object2;
//-- ScriptName: swapAt
- (void) swapObjectAtIndex:(int)index1 withObjectAtIndex:(int)index2;

// Querying
//-- ScriptName: objectAt
- (PXGenericObject)objectAtIndex:(int)index;
//-- ScriptName: contains
- (BOOL) containsObject:(PXGenericObject)object;
//-- ScriptName: indexOf
- (int) indexOfObject:(PXGenericObject)object;

///////////////
// Exporting //
///////////////

//-- ScriptIgnore
- (id *)cArray;
//-- ScriptName: clone
- (id) copy;

/////////////
// Statics //
/////////////

//-- ScriptName: cleanPool
+ (void) cleanNodesPool;

//-- ScriptIgnore
+ (PXLinkedList *)linkedListWithPooledNodes:(BOOL)pooledNodes;
//-- ScriptIgnore
+ (PXLinkedList *)linkedWithWeakReferences:(BOOL)weakReferences;
//-- ScriptName: make
//-- ScriptArg[0]: PX_LINKED_LISTS_USE_POOLED_NODES
//-- ScriptArg[1]: NO
+ (PXLinkedList *)linkedListWithWeakReferences:(BOOL)weakReferences usePooledNodes:(BOOL)pooledNodes;

@end
