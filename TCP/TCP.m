//
//  TCP.m
//  TCP
//
//  Created by Sheyne Anderson on 7/25/11.
//  Copyright 2011 Sheyne Anderson. All rights reserved.
//

#import "TCP.h"

#import "TCP.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>



void sendDataToSocket(const void*sock,void*data);
void disconnectFromSocket(const void*sock,void*data);
void sendToAllExcept(const void*sock,void*data);
void cSocketFunction(CFSocketRef socket,
					 CFSocketCallBackType type,
					 CFDataRef address,
					 const void * data,
					 void *info);


#pragma mark Constants
NSInteger const TCPAnyPort=0;

#pragma mark C Functions
struct sock_data_pair {
	CFSocketRef sock;
	CFDataRef data;
};
void sendToAllExcept(const void*sock,void*data){
	struct sock_data_pair * dat=((struct sock_data_pair *)data);
	if (sock!=dat->sock)
		CFSocketSendData((CFSocketRef)sock, NULL,(CFDataRef) dat->data, 0); 
}
void cSocketFunction(CFSocketRef socket,
					 CFSocketCallBackType type,
					 CFDataRef address,
					 const void * data,
					 void *info){
	TCP* self=(TCP*)info;
#pragma mark C Socket Receiving Data
	if (type==kCFSocketDataCallBack) {
		NSData * dat=(NSData*)data;
		if (dat.length==0){
			//connection terminated
			if (self.activeSockets){
				CFSetRemoveValue(self.activeSockets, socket);
			}
			if ([self.delegate respondsToSelector:@selector(disconnected)]) {
				[self.delegate disconnected];
			}			
			return;
		}
		if (self.repeatMode && self.activeSockets){
			struct sock_data_pair pair={socket, data};
			CFSetApplyFunction(self.activeSockets,sendToAllExcept, &pair);
		}
		if ([self.delegate respondsToSelector:@selector(receivedMessage:socket:)]) {
			[self.delegate receivedMessage:(NSData*)data socket:socket];
		}
#pragma mark C Socket Accepting Connection
	}else if (type==kCFSocketAcceptCallBack) {
		CFSocketNativeHandle csock = *(CFSocketNativeHandle *)data;
		CFSocketRef s = CFSocketCreateWithNative(NULL, csock,
												 kCFSocketDataCallBack,
												 cSocketFunction, 
												 &(CFSocketContext){ 0, self, NULL, NULL, NULL });
		CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, s, 0);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source,
						   kCFRunLoopDefaultMode);
		CFRelease(source);
		if (!self.activeSockets) {
			self.activeSockets=CFSetCreateMutable (NULL,0,&kCFTypeSetCallBacks);
		}
		CFSetAddValue(self.activeSockets, s);
		if ([self.delegate respondsToSelector:@selector(connectionReceived:)]) {
			[self.delegate connectionReceived:s];
		}
		CFRelease(s);
	}
}
@interface TCP () <NSNetServiceDelegate,NSNetServiceBrowserDelegate,NSNetServiceDelegate>

-(void)stopPublishingWithStatus:(NSString*)status;
-(void)stopLookingWithStatus:(NSString *)status;
-(void)connectToSocket:(CFSocketRef)socket;

@property (readwrite,assign) NSInteger port;
@property (retain) NSNetService*netService;
@property (retain) NSNetServiceBrowser*netServiceBrowser;

@end

@implementation TCP
@synthesize mode;
@synthesize netServiceBrowser;
@synthesize port;
@synthesize delegate;
@synthesize activeSockets;
@synthesize connected;
@synthesize netService;
@synthesize address;
@synthesize repeatMode;

#pragma mark Initialization
-(TCP*)init{
	if (self=[super init]) {
		//[self addObserver:self forKeyPath:@"mode" options:NSKeyValueObservingOptionNew context:NULL];
		//[self addObserver:self forKeyPath:@"port" options:NSKeyValueObservingOptionNew context:NULL];
		//[self addObserver:self forKeyPath:@"address" options:NSKeyValueObservingOptionNew context:NULL];
		//[self addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew context:NULL];
	}
	return self;
}

-(void)listenOnPort:(NSInteger)aPort{
	[self disconnect];
	CFSocketRef socket = CFSocketCreate(NULL,
										PF_INET,
										SOCK_STREAM,
										IPPROTO_TCP,
										kCFSocketAcceptCallBack, 
										cSocketFunction, 
										&(CFSocketContext){ 0, self, NULL, NULL, NULL });
	
	
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(aPort);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
	
    NSData *addressStruct= [ NSData dataWithBytes: &addr length: sizeof(addr) ];
    if (CFSocketSetAddress(socket, (CFDataRef) addressStruct) != kCFSocketSuccess) {
        CFRelease(socket);
		if ([delegate respondsToSelector:@selector(error)]) {
			[delegate error];
		}
		return;
	}
    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
	CFRelease(sourceRef);
	
	if (aPort==TCPAnyPort) {
		struct sockaddr_in addr;
		socklen_t addrlen=sizeof(addr);
		getsockname(CFSocketGetNative(socket), (struct sockaddr *)&addr, &addrlen);
		
		self.port=ntohs(addr.sin_port);
	}else{
		self.port=aPort;
	}
	CFRelease(socket);
	if ([self.delegate respondsToSelector:@selector(connected)]) {
		[self.delegate connected];
	}
	connected=YES;
	// CFRunLoopRun();
	//NSLog(@"past run loop run");	
	
}
-(void)connectToServer:(NSString *)server onPort:(NSInteger)_port{
	[self disconnect];
	address=[server retain];
	CFSocketRef socket = CFSocketCreate(NULL, PF_INET, 
										SOCK_STREAM, IPPROTO_TCP, 
										kCFSocketDataCallBack, 
										cSocketFunction, 
										&(CFSocketContext){ 0, self, NULL, NULL, NULL });
	struct sockaddr_in sin; 
	struct hostent   *host;
	
	host = gethostbyname([server UTF8String]);      
	memset(&sin, 0, sizeof(sin));
	memcpy(&(sin.sin_addr), host->h_addr,host->h_length); 
	sin.sin_family = AF_INET;
	sin.sin_port = htons(_port);
	
	CFDataRef addressStruct;
	
	addressStruct = CFDataCreate(NULL, (UInt8 *)&sin, sizeof(sin));
	
	CFSocketConnectToAddress(socket, addressStruct, 0);
	CFRelease(addressStruct);
	[self connectToSocket:socket];
	
}
-(void)connectToSocket:(CFSocketRef)socket{
	CFRunLoopSourceRef source;
	
	source = CFSocketCreateRunLoopSource(NULL, socket, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), 
					   source, 
					   kCFRunLoopDefaultMode);
	CFRelease(source);
	if (self.activeSockets) {
		CFSetRemoveAllValues(self.activeSockets);
	}else {
		self.activeSockets=CFSetCreateMutable (NULL,0,&kCFTypeSetCallBacks);
	}
	CFSetAddValue(self.activeSockets, socket);
	if([self.delegate respondsToSelector:@selector(connected)]){
		[self.delegate connected];
	}	
	
}

-(void)resolveServiceAndConnect:(NSNetService *)service timeout:(NSTimeInterval)timeout{
	netService.delegate=self;
	[netService resolveWithTimeout:timeout];
	[netService retain];
}

-(void)netServiceDidResolveAddress:(NSNetService*)sender{
	NSData*sock=(NSData*)[sender.addresses objectAtIndex:0];
	CFSocketRef socket=(CFSocketRef)[sock bytes];
	[self connectToSocket:socket];
	//NSLog(@"did resolve service with name: %@ on host %@:%d",sender.name,sender.port);
	[sender release];
}

-(void)netService:(NSNetService*)sender didNotResolve:(NSDictionary *)errorDict{
	if([self.delegate respondsToSelector:@selector(connectionFailedWithStatus:)]){
		[self.delegate connectionFailedWithStatus:@"net service did not resolve"];
	}
	[sender release];
}


#pragma mark Bonjour Publishing
-(void)publishServiceWithDomain:(NSString*)domain type:(NSString*)type name:(NSString*)name{
	self.netService = [[[NSNetService alloc] initWithDomain:domain type:type name:name port:(int)self.port] autorelease];
	if (self.netService != nil) {
		self.netService.delegate=self;
		[self.netService publishWithOptions:0];
		NSLog(@"Publishing");
	}
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict{
	[self stopPublishingWithStatus:@"netServiceDidNotPublish"];
}

- (void)netServiceDidStop:(NSNetService *)sender{
	[self stopPublishingWithStatus:@"netServiceDidStop"];
}
-(void)stopPublishing{
	[self stopPublishingWithStatus:@"stopPublishing method called"];
}
-(void)stopPublishingWithStatus:(NSString*)status{
	self.netService.delegate=nil;
	[self.netService stop];
	self.netService = nil;	
	if ([self.delegate respondsToSelector:@selector(stoppedPublishingWithStatus:)]) {
		[self.delegate stoppedPublishingWithStatus:status];
	}	
}

#pragma mark Bonjour Looking

-(void)lookForServiceOfType:(NSString*)type inDomain:(NSString*)domain {
    self.netServiceBrowser = [[[NSNetServiceBrowser alloc] init] autorelease];
	self.netServiceBrowser.delegate=self;
    [self.netServiceBrowser searchForServicesOfType:type inDomain:domain];	
}
- (void)stopLooking{
	[self stopLookingWithStatus:@"Received stop looking message"];
}
- (void)stopLookingWithStatus:(NSString *)status{
    self.netServiceBrowser.delegate=nil;
    [self.netServiceBrowser stop];
    self.netServiceBrowser = nil;
	if ([self.delegate respondsToSelector:@selector(stoppedLookingWithStatus:)]) {
		[self.delegate stoppedLookingWithStatus:status];
	}
}

#pragma mark Bonjour Looking: NetServiceBrowserDelegate methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing{
	if ([self.delegate respondsToSelector:@selector(didFindService: moreComing:)]) {
		[self.delegate didFindService:aNetService moreComing:moreComing];
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing{
	if ([self.delegate respondsToSelector:@selector(didRemoveService: moreComing:)]) {
		[self.delegate didRemoveService:aNetService moreComing:moreComing];
	}
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser{
    [self stopLookingWithStatus:@"Service browsing did not search"];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict{
    [self stopLookingWithStatus:@"Service browsing failed."];
}


#pragma mark Sending
void sendDataToSocket(const void*sock,void*data){
	CFSocketSendData((CFSocketRef)sock, NULL,(CFDataRef) data, 0); 
}
-(void)send:(NSData*) data{
	if (self.activeSockets)
		CFSetApplyFunction(self.activeSockets,&sendDataToSocket, data);
}
-(void)send:(NSData*) data socket:(CFSocketRef)sock{
	if(sock)
		CFSocketSendData(sock, NULL,(CFDataRef) data, 0); 
}

#pragma mark Disconnect
void disconnectFromSocket(const void*sock,void*data){
	CFSocketInvalidate((CFSocketRef)sock);
}

-(void)disconnect{
	if(activeSockets){
		CFSetApplyFunction(self.activeSockets,&disconnectFromSocket,NULL);
		CFRelease(activeSockets);
		activeSockets=nil;
	}
	connected=NO;
}
-(void)dealloc{
	if (self.netService != nil) {
		[self stopPublishingWithStatus:@"Disconnect Message Received"];
	}	
	if (self.netServiceBrowser != nil) {
		[self stopLookingWithStatus:@"Disconnect Message Received"];
    }	
	if (connected) {
		[self disconnect];
	}
	[super dealloc];
}
@end
