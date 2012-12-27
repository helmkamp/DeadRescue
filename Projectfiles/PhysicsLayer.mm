/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "PhysicsLayer.h"
#import "Box2DDebugLayer.h"

//Pixel to metres ratio. Box2D uses metres as the unit for measurement.
//This ratio defines how many pixels correspond to 1 Box2D "metre"
//Box2D is optimized for objects of 1x1 metre therefore it makes sense
//to define the ratio so that your most common object type is 1x1 metre.
const float PTM_RATIO = [LevelHelperLoader pointsToMeterRatio];

const int TILESIZE = 32;
const int TILESET_COLUMNS = 9;
const int TILESET_ROWS = 19;


@interface PhysicsLayer (PrivateMethods)
-(void) enableBox2dDebugDrawing;
-(b2Vec2) toMeters:(CGPoint)point;
-(CGPoint) toPixels:(b2Vec2)vec;
@end

@implementation PhysicsLayer

-(id) init
{
	if ((self = [super init]))
	{
		CCLOG(@"%@ init", NSStringFromClass([self class]));

		glClearColor(0.1f, 0.0f, 0.2f, 1.0f);
		
		// Construct a world object, which will hold and simulate the rigid bodies.
		b2Vec2 gravity = b2Vec2(0.0f, 0.0f);
		world = new b2World(gravity);
		world->SetAllowSleeping(NO);
		//world->SetContinuousPhysics(YES);
		
		// uncomment this line to draw debug info
		[self enableBox2dDebugDrawing];
        
		contactListener = new ContactListener();
		world->SetContactListener(contactListener);
		
        loader = [[LevelHelperLoader alloc] initWithContentOfFile:@"level3"];
        [loader addObjectsToWorld:world cocos2dLayer:self];
        
		if ([loader hasPhysicBoundaries]) {
            [loader createPhysicBoundaries:world];
        }
        
        [loader useLevelHelperCollisionHandling];
        
        player = [loader spriteWithUniqueName:@"player"];
        gameScrSize = [loader gameScreenSize]; //the device size set in loaded level
        gameWorldRect = [loader gameWorldSize]; //the size of the game world
        
        _playerBody = [player body];
        NSAssert(_playerBody!=nil, @"Couldn't find hero body");
        
		[self scheduleUpdate];
		
		[KKInput sharedInput].accelerometerActive = YES;
	}

	return self;
}

-(void) dealloc
{
    loader = nil;
	delete contactListener;
	delete world;

#ifndef KK_ARC_ENABLED
	[super dealloc];
#endif
}

-(void) enableBox2dDebugDrawing
{
	// Using John Wordsworth's Box2DDebugLayer class now
	// The advantage is that it draws the debug information over the normal cocos2d graphics,
	// so you'll still see the textures of each object.
	const BOOL useBox2DDebugLayer = YES;

	
	float debugDrawScaleFactor = 1.0f;
#if KK_PLATFORM_IOS
	debugDrawScaleFactor = [[CCDirector sharedDirector] contentScaleFactor];
#endif
	debugDrawScaleFactor *= PTM_RATIO;

	UInt32 debugDrawFlags = 0;
	debugDrawFlags += b2Draw::e_shapeBit;
	debugDrawFlags += b2Draw::e_jointBit;
	//debugDrawFlags += b2Draw::e_aabbBit;
	//debugDrawFlags += b2Draw::e_pairBit;
	//debugDrawFlags += b2Draw::e_centerOfMassBit;

	if (useBox2DDebugLayer)
	{
		Box2DDebugLayer* debugLayer = [Box2DDebugLayer debugLayerWithWorld:world
																  ptmRatio:PTM_RATIO
																	 flags:debugDrawFlags];
		[self addChild:debugLayer z:100];
	}
	else
	{
		debugDraw = new GLESDebugDraw(debugDrawScaleFactor);
		if (debugDraw)
		{
			debugDraw->SetFlags(debugDrawFlags);
			world->SetDebugDraw(debugDraw);
		}
	}
}

-(void) bodyCreateFixture:(b2Body*)body
{
	// Define another box shape for our dynamic bodies.
	b2PolygonShape dynamicBox;
	float tileInMeters = TILESIZE / PTM_RATIO;
	dynamicBox.SetAsBox(tileInMeters * 0.5f, tileInMeters * 0.5f);
	
	// Define the dynamic body fixture.
	b2FixtureDef fixtureDef;
	fixtureDef.shape = &dynamicBox;	
	fixtureDef.density = 0.3f;
	fixtureDef.friction = 0.5f;
	fixtureDef.restitution = 0.6f;
	body->CreateFixture(&fixtureDef);
	
}



-(void) update:(ccTime)delta
{
    
	CCDirector* director = [CCDirector sharedDirector];
	if (director.currentPlatformIsIOS)
	{
		KKInput* input = [KKInput sharedInput];
		if (director.currentDeviceIsSimulator == NO)
		{
			KKAcceleration* acceleration = input.acceleration;
			//CCLOG(@"acceleration: %f, %f", acceleration.rawX, acceleration.rawY);
			b2Vec2 gravity = 10.0f * b2Vec2(acceleration.rawX, acceleration.rawY);
			world->SetGravity(gravity);
		}
        
        if (input.anyTouchEndedThisFrame) {
            //CCLOG(@"touch detected");
            
            CGPoint location = [input locationOfAnyTouchInPhase:KKTouchPhaseAny];
            CGPoint playerPos = player.position;
            CGPoint diff = ccpSub(location, playerPos);
            
            if (abs(diff.x) > abs(diff.y)) {
                if (diff.x > 0) {
                    playerPos.x += 32;
                } else {
                    playerPos.x -= 32;
                }
            } else {
                if (diff.y > 0) {
                    playerPos.y += 34;
                } else {
                    playerPos.y -= 34;
                }
            }
            
            if (playerPos.x <= (gameWorldRect.size.width * 32) &&
                playerPos.y <= (gameWorldRect.size.height * 32) &&
                playerPos.y >= 0 &&
                playerPos.x >= 0 )
            {
                [player setUsesOverloadedTransformations:YES];
                player.position = location;
            }

            //[self setViewpointCenter: player.position];
            
        }

	}
	
	// The number of iterations influence the accuracy of the physics simulation. With higher values the
	// body's velocity and position are more accurately tracked but at the cost of speed.
	// Usually for games only 1 position iteration is necessary to achieve good results.
	float timeStep = 0.03f;
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	world->Step(timeStep, velocityIterations, positionIterations);
	
	// for each body, get its assigned sprite and update the sprite's position
	for (b2Body* body = world->GetBodyList(); body != nil; body = body->GetNext())
	{
		CCSprite* sprite = (__bridge CCSprite*)body->GetUserData();
		if (sprite != NULL)
		{
			// update the sprite's position to where their physics bodies are
			sprite.position = [self toPixels:body->GetPosition()];
			float angle = body->GetAngle();
			sprite.rotation = CC_RADIANS_TO_DEGREES(angle) * -1;
		}
	}
}

-(void)setViewpointCenter:(CGPoint)position {
    int x = MAX(position.x, gameScrSize.width/2);
    int y = MAX(position.y, gameScrSize.height/2);
    x = MIN(x, (gameWorldRect.origin.x + gameWorldRect.size.width)-gameScrSize.width/2);
    y = MIN(y, (gameWorldRect.origin.y + gameWorldRect.size.height)-gameScrSize.height/2);
    
    CGPoint actualPosition = ccp(x,y);
    
    CGPoint centerOfView = ccp(gameScrSize.width/2, gameScrSize.height/2);
    CGPoint viewPoint = ccpSub(centerOfView, actualPosition);
    
    self.position = viewPoint;
    
}

// convenience method to convert a CGPoint to a b2Vec2
-(b2Vec2) toMeters:(CGPoint)point
{
	return b2Vec2(point.x / PTM_RATIO, point.y / PTM_RATIO);
}

// convenience method to convert a b2Vec2 to a CGPoint
-(CGPoint) toPixels:(b2Vec2)vec
{
	return ccpMult(CGPointMake(vec.x, vec.y), PTM_RATIO);
}


#if DEBUG
-(void) draw
{
	[super draw];

	if (debugDraw)
	{
		ccGLEnableVertexAttribs(kCCVertexAttribFlag_Position);
		kmGLPushMatrix();
		world->DrawDebugData();	
		kmGLPopMatrix();
	}
}
#endif

@end
