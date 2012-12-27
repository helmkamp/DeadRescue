/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "cocos2d.h"
#import "Box2D.h"
#import "GLES-Render.h"
#import "LevelHelperLoader.h"
#import "ContactListener.h"

enum
{
	kTagBatchNode,
};

@interface PhysicsLayer : CCLayer
{
	b2World* world;
	ContactListener* contactListener;
	GLESDebugDraw* debugDraw;
    LevelHelperLoader *loader;
    
    CGSize gameScrSize;
    CGRect gameWorldRect;
    LHSprite *player;
    b2Body *_playerBody;
    double playerVelX;
}

@end
