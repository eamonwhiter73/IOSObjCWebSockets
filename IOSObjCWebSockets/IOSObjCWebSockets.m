//
//  ViewController.m
//  IOSObjCWebSockets
//
//  Created by Eamon White on 4/25/20.
//  Copyright © 2020 Eamon White. All rights reserved.
//

//This class handles all that is neccessary to configure a TLS socket on iOS to work with the stock NodeJS TLS server. If you are adopting this code, and it is not working for you, the problem probably lies in the create_params function.

#import "IOSObjCWebSockets.h"
#import <SceneKit/SceneKit.h> //Only imported to handle my test case, in the test() function - using potential game data in the form of a transformation matrix.

@interface IOSObjCWebSockets ()

@property (nonatomic) bool connected;        // used to decide when
@property (nonatomic) nw_connection_t listener_connection;
@property (nonatomic) const char* dns;
@property (nonatomic) uint16_t tls_encryption;
@property (nonatomic) const char* ip;
@property (nonatomic) const char* port;

@end

@implementation IOSObjCWebSockets

@synthesize ip, port, tls_encryption, dns, connected, listener_connection; //io is for dispatch_io, and listener_connection is to store the listener connection

- (instancetype)init
{
    self = [super init];
    if (self) {
        //init with default cipher
        self.tls_encryption = tls_ciphersuite_ECDHE_RSA_WITH_AES_128_GCM_SHA256; //Default encryption
    }
    return self;
}

//Setter for cipher type
- (void)set_encryption:(u_int16_t)encryption {
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        self.tls_encryption = encryption;
    });
}

//Setter for DNS
- (void)set_DNS:(NSString*)dns {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        self.dns = [dns UTF8String];
    });
}

//Setter for server IP
- (void)set_IP:(NSString*)ip {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        self.ip = [ip UTF8String];
    });
}

//Setter for server IP
- (void)set_port:(NSString*)port {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        self.port = [port UTF8String];
    });
}

/*
* Contains what is needed to make a successful TLS handshake between iOS and NodeJS server.
*/
- (nw_parameters_t)create_params {

    nw_parameters_configure_protocol_block_t configure_tls = NW_PARAMETERS_DEFAULT_CONFIGURATION;
    
    //Create TLS protocol, this part might end up needing to be reconfigured given the intent of your app.
    configure_tls = ^(nw_protocol_options_t tls_options) {
        sec_protocol_options_t sec_options = nw_tls_copy_sec_protocol_options(tls_options);
        
        //VERY IMPORTANT OPTIONS
        sec_protocol_options_append_tls_ciphersuite(sec_options, self.tls_encryption); //may need to change based on the encryption you are using
        
        sec_protocol_options_set_min_tls_protocol_version(sec_options, tls_protocol_version_TLSv10); //below TLSv1 is defnitely not advisable
        sec_protocol_options_set_max_tls_protocol_version(sec_options, tls_protocol_version_TLSv13); //set max TLS version to TLSv1.3 (you will probably be using TLSv1.2)
        if(self.dns != NULL) {
            sec_protocol_options_set_tls_server_name(sec_options, self.dns); //VERY IMPORTANT, needed for connection to work. Must be the same as the DNS name that you are using for your server. See this for a great guide for how to create certificates that work with TLS and iOS -> https://jamielinux.com/docs/openssl-certificate-authority/introduction.html
        }
        else {
            NSLog(@"***IMPORTANT*** YOU NEED TO SET THE DNS ***IMPORTANT***");
        }
        
        sec_protocol_options_set_verify_block(sec_options, ^(sec_protocol_metadata_t  _Nonnull metadata, sec_trust_t  _Nonnull trust_ref, sec_protocol_verify_complete_t  _Nonnull complete) {
            
            SecTrustRef trust = sec_trust_copy_ref(trust_ref);
            
            SecCertificateRef ref = SecTrustGetCertificateAtIndex(trust, 0); //get certificate from connection at index
            
            CFMutableArrayRef cert_arr = CFArrayCreateMutable(NULL, 1, &kCFTypeArrayCallBacks);
            CFArrayAppendValue(cert_arr, ref);
            
            //Maybe not neccessary - but won't hurt, setting the correct cerificate (verfiably) as an anchor certificate.
            OSStatus set = SecTrustSetAnchorCertificates(trust, cert_arr);
            
            //LEAVE FOR DEBUGGING YOUR CONNECTION! VERIFY TLS RELATED VERSIONS. TAKE OUT FOR PRODUCTION.
            //***************************************************************************************
            const char* server_name = sec_protocol_metadata_get_server_name(metadata);
            tls_protocol_version_t proto_v = sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata);
            tls_ciphersuite_t suite = sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata);
            
            NSLog(@"server name: %s", server_name);
            NSLog(@"protocol version: %hu", proto_v);
            NSLog(@"protocol ciphersuite: %hu", suite);
            NSLog(@"certifcate count: %ld",(long)SecTrustGetCertificateCount(trust));
            NSLog(@"error setting certificate as anchor: %@", SecCopyErrorMessageString(set, NULL));
            //***************************************************************************************
            
            OSStatus status = SecTrustEvaluateAsyncWithError(trust, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^(SecTrustRef  _Nonnull trustRef, bool result, CFErrorRef  _Nullable error) {
                if(error) {
                    //LEAVE FOR DEBUGGING YOUR CONNECTION! VERIFY TLS RELATED VERSIONS. TAKE OUT FOR PRODUCTION.
                    //***************************************************************************************
                    NSLog(@"error code with trust evaluation: %li", (long)CFErrorGetCode(error));
                    NSLog(@"error domain with trust evaluation: %@", CFErrorGetDomain(error));
                    NSLog(@"error with trust evaluation - not human readable: %@", error);
                    NSLog(@"error with trust evaluation - human readable: %@", CFErrorCopyDescription(error));
                    NSLog(@"result in error block for trust evaluation: %i", result);
                    //***************************************************************************************
                    
                    complete(false);
                }
                else {
                    NSLog(@"positive result for trust evaluation: %i", result);
                    complete(result);
                }
            });
            
            //LEAVE FOR DEBUGGING YOUR CONNECTION! VERIFY TLS RELATED VERSIONS. TAKE OUT FOR PRODUCTION.
            //***************************************************************************************
            NSLog(@"status of trust evaluation - human readable: %@", SecCopyErrorMessageString(status, NULL));
            //***************************************************************************************
            
        }, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)); //I handle it async on the background queue because this has to happen everytime a connection is created, which happens everytime you send data!
    };
    
    //Can use the below line to ignore having to configure tls (everything above is rendered mute by NW_PARAMETERS_DISABLE_PROTOCOL)
    //nw_parameters_configure_protocol_block_t configure_tls = NW_PARAMETERS_DISABLE_PROTOCOL;
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(
        configure_tls,
        NW_PARAMETERS_DEFAULT_CONFIGURATION
    );
    
    return parameters;
}

- (void)start {
    
    //localhost should probably be port for your iPhone's listening.
    //Using '0' for the port number allows it to choose what port it uses.
    
    //Create outbound and inbound connections
    dispatch_async(dispatch_get_main_queue(), ^{
        nw_listener_t g_listener = [self create_and_start_listener:[@"127.0.0.1" UTF8String] port:[@"0" UTF8String]];
        if (g_listener == NULL) {
            NSLog(@"error creating listener");
        }
        else {
            //If listener is successfully created, create the outbound connection
            if(self.ip != NULL && self.port != NULL) {
                nw_connection_t connection = [self create_outbound_connection:self.ip port:self.port];
                if (connection == NULL) {
                    NSLog(@"error, no connection available after creation.");
                }
                else {
                    [self start_connection:connection]; //Make initial connection
                    [self start_receive_loop:connection];//Allow receiving of "welcome!" message from server.
                }
            }
            else {
                NSLog(@"***IMPORTANT*** YOU NEED TO SET THE SERVER IP AND/OR THE SERVER PORT ***IMPORTANT***");
            }
        }
    });
}

/*
 * create_and_start_listener()
 * Returns a retained listener on a local port and optional address.
 * Sets up TLS as necessary.
 * Schedules listener on main queue and starts it.
 */
- (nw_listener_t)create_and_start_listener:(const char *)host port:(const char *)port {
    
    //Create and set paramaters for listener
    nw_endpoint_t local_endpoint = nw_endpoint_create_host(host, port);
    nw_parameters_t parameters = [self create_params];
    nw_parameters_set_local_endpoint(parameters, local_endpoint);
    
    nw_listener_t listener = nw_listener_create(parameters);
    nw_listener_set_queue(listener, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)); //Tis' a utility...
        
    nw_listener_set_state_changed_handler(listener, ^(nw_listener_state_t state, nw_error_t error) {
        //Listener state changes here
        error ? nw_error_get_error_code(error) : 0;
        if(error > 0) {
            NSLog(@"error in listener state: %@", error);
        }
        if (state == nw_listener_state_waiting) {
            NSLog(@"Listener on port %u tcp waiting\n",
                    nw_listener_get_port(listener));
        }
        else if (state == nw_listener_state_failed) {
            NSLog(@"listener tcp failed");
        } else if (state == nw_listener_state_ready) {
                NSLog(@"Listener on port %u tcp ready\n",
                nw_listener_get_port(listener));
            
                //Nothing needs to be done here, the listener is now created and available to receive data from the server.
            
        } else if (state == nw_listener_state_cancelled) {
            NSLog(@"listener cancelled");
        }
    });
    
    nw_listener_set_new_connection_handler(listener, ^(nw_connection_t connection) {
        
        if (self.listener_connection != NULL) {
            nw_connection_cancel(connection);
        } else {
            //Give to be able to reference anywhere.
            self.listener_connection = connection;
            
            //Start the connection
            [self start_connection:connection];
            [self start_receive_loop:connection];
        }
    });

    nw_listener_start(listener);
    
    return listener; //Return for error check in ViewController.
}

/*
 * create_outbound_connection()
 * Returns a retained connection to a remote hostname and port.
 * Sets up TLS and local address/port as necessary.
 */
- (nw_connection_t)create_outbound_connection:(const char*)host port:(const char*)port {
    
    //Create parameters and endpoint
    nw_endpoint_t endpoint = nw_endpoint_create_host(host, port);
    nw_parameters_t parameters = [self create_params];
    
    //Create connection
    nw_connection_t connection = nw_connection_create(endpoint, parameters);
    
    return connection;
}


/*
 * start_connection()
 * Schedule a connection, process events, and
 * start the connection.
 */
- (void)start_connection:(nw_connection_t)connection {
    NSLog(@"connection logged: %@", [connection debugDescription]);
    nw_connection_set_queue(connection, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        if(error) {
            NSLog(@"error in starting connection: %@", error);
        }
        else{
            if (state == nw_connection_state_waiting) {
                //… tell the user that a connection couldn’t be opened but will retry when conditions are favourable …
                NSLog(@"connection waiting");
            } else if (state == nw_connection_state_failed) {
                //… tell the user that the connection has failed irrecoverably …
                NSLog(@"connection failed");
            } else if (state == nw_connection_state_ready) {
                //… tell the user that you are connected …
                NSLog(@"connected");
                
                id<IOSObjCWebSocketsDelegate> strong_delegate = self.delegate;

                // Our delegate method is optional, so we should
                // check that the delegate implements it
                if ([strong_delegate respondsToSelector:@selector(finished_setup)]) {
                    [strong_delegate finished_setup];
                }
                //Start listening
                [self start_receive_loop:connection];
            } else if (state == nw_connection_state_cancelled) {
                NSLog(@"canceled connection");
            }
        }
    });
    
    NSLog(@"connection before starting: %@", connection);
    //Actually start the connection
    nw_connection_start(connection);
}

/*
* send_data()
* Send data using connection.
*/

- (void)send_data:(const char*)ip port:(const char*)port data_param:(dispatch_data_t)data_param {
    nw_connection_t connection = [self create_outbound_connection:ip port:port];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self start_connection:connection]; //Start connection
        [self start_receive_loop:connection]; //Start listener for "new" connection
        nw_connection_send(connection, data_param, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t  _Nullable error) {
            if (error != NULL) {
                NSLog(@"error with sending data: %@", error);
            } else {
                NSLog(@"####### data sent #######");
            }
        });
    });
}

/*
 * receive_loop()
 * Perform a single read on the supplied connection.
 * If no error is encountered, schedule another read on the same connection.
 */
- (void)receive_loop:(nw_connection_t)connection {
    nw_connection_receive(connection, 1, UINT32_MAX, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t receive_error) {
        
        //prepare for next receive
        dispatch_block_t schedule_next_receive = ^{
            if (is_complete &&
                context != NULL && nw_content_context_get_is_final(context)) {
                NSLog(@"final notification received - no more data");
                exit(0);
            }
            if (receive_error == NULL) {
                [self receive_loop:connection]; //Perpetuate receive loop for next time
            } else {
                NSLog(@"error in scheduling next receive: %@", receive_error);
            }
        };
    
        if (content != NULL) {
            schedule_next_receive = [schedule_next_receive copy]; //For next receive
            
            //Turn received data into string for NSLog
            NSData* nscontent = (NSData*)content;
            const char* received_str = [nscontent bytes];
            NSString* rec_cast = [[NSString alloc] initWithBytes:received_str length:[nscontent length] encoding:NSUTF8StringEncoding];
            
            id<IOSObjCWebSocketsDelegate> strong_delegate = self.delegate;

            // Our delegate method is optional, so we should
            // check that the delegate implements it
            if ([strong_delegate respondsToSelector:@selector(receive_data:)]) {
                [strong_delegate receive_data:rec_cast];
            }
            //NSLog(@"%@", rec_cast);
        }
        else {
            // No content, so directly schedule the next receive
            schedule_next_receive();
        }
    });
}

/*
 * start_receive_loop()
 * Start reading data from listener connection
 */
- (void)start_receive_loop:(nw_connection_t)connection  {

    // Start reading from connection
    [self receive_loop:connection];
}


@end
