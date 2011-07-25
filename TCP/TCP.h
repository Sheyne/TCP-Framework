//
//  TCP.h
//  TCP
//
//  Created by Sheyne Anderson on 7/25/11.
//  Copyright 2011 Sheyne Anderson. All rights reserved.
//

//
//  TCP.h
//  VideoTransmittor
//
//  Created by Sheyne Anderson on 4/25/11.
//  Copyright 2011 Sheyne Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCPListener.h"

extern NSInteger const TCPAnyPort;
enum TCPMode {
	TCPOffMode,
	TCPServerMode,
	TCPClientMode
};

@interface TCP : NSObject {
	BOOL repeatMode;
	enum TCPMode mode;
	//CFSocketRef socket;
	NSString*address;
	BOOL connected;
	id<TCPListener> delegate;
	NSInteger port;
	CFMutableSetRef activeSockets;
	NSNetService*netService;
	NSNetServiceBrowser*netServiceBrowser;
}
@property (assign) BOOL repeatMode;
@property (assign) enum TCPMode mode;
@property (retain) NSString* address;
@property (readonly) NSInteger port;
@property (readonly) BOOL connected;
@property (assign) CFMutableSetRef activeSockets;
@property (retain) id<TCPListener> delegate;

#pragma mark Initialization
-(void)listenOnPort:(NSInteger)port;
-(void)connectToServer:(NSString *)server onPort:(NSInteger)port;
-(void)resolveServiceAndConnect:(NSNetService *)service timeout:(NSTimeInterval)timeout;

#pragma mark Bonjour
-(void)publishServiceWithDomain:(NSString*)domain type:(NSString*)type name:(NSString*)name;
-(void)lookForServiceOfType:(NSString*)type inDomain:(NSString*)domain;
-(void)stopLooking;
-(void)stopPublishing;

#pragma mark Sending
-(void)send:(NSData*) data;
-(void)send:(NSData*) data socket:(CFSocketRef)socket;

#pragma mark Disconnect
-(void)disconnect;

@end
