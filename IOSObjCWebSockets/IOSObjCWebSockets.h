//
//  ViewController.h
//  IOSObjCWebSockets
//
//  Created by Eamon White on 4/25/20.
//  Copyright © 2020 Eamon White. All rights reserved.
//

//This class handles all that is neccessary to configure a TLS socket on iOS to work with the stock NodeJS TLS server. If you are adopting this code, and it is not working for you, the problem probably lies in the create_params function.

#import <UIKit/UIKit.h>
#import <Network/Network.h>

@protocol IOSObjCWebSocketsDelegate;

@interface IOSObjCWebSockets : NSObject

@property (nonatomic, weak) id<IOSObjCWebSocketsDelegate> delegate;

- (nw_listener_t)create_and_start_listener:(const char*)host port:(const char*)port;
- (nw_connection_t)create_outbound_connection:(const char*)host port:(const char*)port;
- (void)start_connection:(nw_connection_t)connection;
- (void)start_receive_loop:(nw_connection_t)connection;
- (void)test:(UIButton*)sender;

@end

@protocol IOSObjCWebSocketsDelegate <NSObject>

- (void)receive_data:(NSString*)data_as_string;

@end

