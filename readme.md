<h1>IOSObjCWebSockets</h1>

Class to help with TLS web sockets, and their respective connections between iOS and a basic NodeJS TLS Server.

<h2>IMPORTANT RESOURCES</h2>

  - https://support.apple.com/en-us/HT210176 - new (as of iOS 13) Apple TLS restrictions.

  - https://jamielinux.com/docs/openssl-certificate-authority/introduction.html - tutorial for creating SSL certificates - a certificate authority, intermediate certificate authority, and server/client certificates. Follow exactly, except his default configuration files may not be up to standards - if you find that is the case, use mine.

  NOTE: I have included my configuration files for this process - `openssl_intermediate_ca.conf` and `openssl.conf`. `openssl_intermediate_ca.conf` is referenced in the tutorial as `openssl.conf`, it is just in a different directory (intermediate) than the `openssl.conf` for the main certificate authority. Follow the tutorial and you will see - also I used `.conf` as the extension instead of `.cnf`, which is used in the tutorial, so if you get error messages, check to make sure you are using the right extension for the `openssl.conf` file you are using. You can use either, my choice to use `.conf` was an arbitrary choice due to habits.

  - https://developer.apple.com/documentation/network/implementing_netcat_with_network_framework?language=objc - A helpful project to analyze and understand if you are trying to do this, it is written in C, but I adopted a lot of what I am doing from that project.

<h2>RELEVANT OFFICIAL DOCUMENTATION:</h2>

  - The Apple documentation for Network package (Network.h) is helpful, it is the basis for the iOS side of the TLS socket.
  
  - NodeJS docs for TLS server that I use in index.js - https://nodejs.org/api/tls.html#tls_tls_ssl

<h2>Important Info</h2>

To use in your project, copy `IOSObjCWebSockets.h` into your project and import. Also, copy `IOSObjCWebSockets.m` to the same directory as `IOSObjCWebSockets.h`. 

Instantiate `IOSObjCWebSockets` how you would any other object.

See my `ViewController` for how to implement the class.

**IMPORTANT:** you need to set the name of your server (DNS) using the following line:

    [self.web_socket setDNS:@"your.DNS.server.name.here"];

Once you determine what cipher you are using, you will need to set that with this line:

    [self.web_socket set_encryption:tls_ciphersuite_ECDHE_RSA_WITH_AES_128_GCM_SHA256];

It is set with `tls_ciphersuite_ECDHE_RSA_WITH_AES_128_GCM_SHA256` by default if now cipher is set.

<h2>Client (iOS) Setup</h2>

The code below initiates a listener and an outbound connection, which a test button (when clicked) will send data to the server.

<h3>Initialize</h3>

    const char *localhost = [@"127.0.0.1" UTF8String]; //localhost for your iPhone's listening.
    const char *local_port = [@"0" UTF8String]; //Using '0' for the port number allows it to choose what port it uses.

    //Create outbound and inbound connections
    dispatch_async(dispatch_get_main_queue(), ^{nw_listener_t g_listener = [self->web_socket create_and_start_listener:localhost port:local_port]; //***CALLING IMPORTANT STARTING FUNCTION HERE***
    if (g_listener == NULL) {
        NSLog(@"error creating listener");
    }
    else {
        //If listener is successfully created, create the outbound connection
        
        const char *ip = [@"10.0.0.225" UTF8String]; //Change to your server IP
        const char *port = [@"3000" UTF8String]; //Change to the port being used for your TLS server
        
        nw_connection_t connection = [self->web_socket create_outbound_connection:ip port:port]; //***CALLING IMPORTANT STARTING FUNCTION HERE***
        if (connection == NULL) {
            NSLog(@"error, no connection available after creation.");
        }
        else {
            [self->web_socket start_connection:connection]; //Make initial connection ***CALLING IMPORTANT STARTING FUNCTION HERE***
            [self->web_socket start_receive_loop:connection];//Allow receiving of "welcome!" message from server ***CALLING IMPORTANT STARTING FUNCTION HERE***
        }
    }

The functions I marked with `//***CALLING IMPORTANT STARTING FUNCTION HERE***` are the main functions you need to use to start everything, and you should use them in the order that they are used here. You may require a slightly different setup depending on what you are doing.

<h3>Send data:</h3>

    [self send_data:[@"10.0.0.225" UTF8String] port:[@"3000" UTF8String] data_param:data_param];

You provide the `ip` and `port` for the server, and the `dispatch_data_t` object that contains the data you are sending.

<h3>Receive data:</h3>

You can receive data by implementing this delegate function:

    - (void)receive_data:(NSString*)data_as_string;

I am returning the data as an `NSString` for ease of logging, you should also be able to convert it to whatever you need from an `NSString`.

<h2>Server (NodeJS) Setup</h2>

On the server side, I am using a NodeJS TLS server, there are a few important parts of the server side configuration:

    const options = {
      key: [fs.readFileSync('/Users/eamonwhite/ar_pong/corona_pong/certs/root/ca/intermediate/private/server.key.pem')], //This should be your server side certificate
      cert: [fs.readFileSync('/Users/eamonwhite/ar_pong/corona_pong/certs/root/ca/intermediate/certs/server.cert.pem')], //This should be your server side key

      //Note from NodeJS docs: This is necessary only if using client certificate authentication.
      //requestCert: true,

      // This is necessary only if the client uses a self-signed certificate.
      ca: [ fs.readFileSync('/Users/eamonwhite/ar_pong/corona_pong/certs/root/ca/intermediate/certs/ca-chain.cert.pem') ], //This should be your chain file, as created during the process described here https://jamielinux.com/docs/openssl-certificate-authority/introduction.html
      passphrase: 'blahjour7', //Password, if any, for your certificates - a reason to use the same password for all of your certificates.
      hostname: 'com.ewizard86.staff' //Must include to make iOS happy, this should be the same as the DNS information included in your certificates per these restrictions https://support.apple.com/en-us/HT210176
    };

<h3>Final Notes:</h3>

I would start out with the above configuration, and tweak it if neccessary - you shouldn't need to reconfigure much, and you can reference the NodeJS documentation mentioned above to help. The main trouble with figuring this out was getting the certificates right (with all the restrictions) so that the connection would even happen. I commented the code thoroughly, I hope this helps!