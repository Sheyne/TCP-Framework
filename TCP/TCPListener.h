//
//  TCPListener.h
//  TCP
//
//  Created by Sheyne Anderson on 7/25/11.
//  Copyright 2011 Sheyne Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TCPListener<NSObject>

@optional
-(void)receivedMessage:(NSData *)message socket:(CFSocketRef)socket;
-(void)connectionReceived:(CFSocketRef)socket;
-(void)connected;
-(void)connectionFailedWithStatus:(NSString*)status;
-(void)disconnected;
-(void)stoppedLookingWithStatus:(NSString*)status;
-(void)stoppedPublishingWithStatus:(NSString*)status;
-(void)didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing;
-(void)didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing;

//needs improvement and refactoring
-(void)error;

@end
