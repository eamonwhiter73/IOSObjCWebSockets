<h1>IOSObjCWebSockets</h1>

Class to help with TLS web sockets, and their respective connections between iOS and a basic NodeJS TLS Server.

<h2>IMPORTANT RESOURCES</h2>

  - https://support.apple.com/en-us/HT210176 - new (as of iOS 13) Apple TLS restrictions.

  - https://jamielinux.com/docs/openssl-certificate-authority/introduction.html - tutorial for creating SSL certificates - a certificate authority, intermediate certificate authority, and server/client certificates. Follow exactly, except his default configuration files may not be up to standards - if you find that is the case, use mine.

  - https://developer.apple.com/documentation/network/implementing_netcat_with_network_framework?language=objc - A helpful project to analyze and understand if you are trying to do this, it is written in C, but I adopted a lot of what I am doing from that project.

**NOTE:** I have included my configuration files for this process, one for the main certificate authority, and one for an intermediate certificate authority. Follow the tutorial @ the link above for how to create the certificates correctly. As far as I can tell, you need a certificate authority AND an intermediate certicate authority, to sign your server and client certificates. It does not seem like a self-signed certificate is enough if you want to configure TLS at all to make a secure handshake. It took a lot of tweaking for me to get this part right - any errors that you have, I would first assume that it is with your certificate creation.

**IMPORTANT:** If you use my configuration files, you need to change the DNS name all the way at the bottom of both files to be the DNS of your server.

<h2>RELEVANT OFFICIAL DOCUMENTATION:</h2>

  - The Apple documentation for Network package (Network.h) is helpful, it is the basis for the iOS side of the TLS socket.
  
  - NodeJS docs for TLS server that I use in index.js - https://nodejs.org/api/tls.html#tls_tls_ssl

<h2>Client (iOS) Setup</h2>

Upon use of this class, an inbound connection (listener) is created, as well as an outbound connection. One is also able to easily send and receive data via a `send_data` method, and a `receive_data` delegate method. If you run the project, the `ViewController` creates and presents a button that you can tap to test sending data. I expect the most difficult part of this process for anyone to be creating the certificates correctly. If you follow the link above exactly for creating certificates, and use my `.cnf` files, you shouldn't have too many problems to surmount, if any.

To use in your project, copy `IOSObjCWebSockets.h` into your project directory, and import it. Also, copy `IOSObjCWebSockets.m` to the same directory as `IOSObjCWebSockets.h`. 

<h3>Initialize</h3>

The main parts of instantiating are as follows:

1.) Import into the class/controller you want to use it in.

    #import "IOSObjCWebSockets.h"

2.) Set your class/controller to be a delegate of `IOSObjCWebSocketsDelegate`.

    @interface YourClass : YourType <IOSObjCWebSocketsDelegate>

3.) Instantiate object.

    self.web_socket = [[IOSObjCWebSockets alloc] init];

4.) Set the `delegate`.

    self.web_socket.delegate = self;

5.) Set server IP.

    [self.web_socket set_IP:@"your.server.IP"];

6.) Set server port.

    [self.web_socket set_port:@"your.server.port"];

7.) Set server name (DNS of server...mutable).

    [self.web_socket set_DNS:@"your.server.DNS"];

8.) Set your encryption cipher.

    [self.web_socket set_encryption:tls_ciphersuite_ECDHE_RSA_WITH_AES_128_GCM_SHA256]; //used as default cipher, many choices

9.) Start the sockets.

    [self.web_socket start];

See `ViewController` for an example of how to implement.

<h3>Wait for networking to setup</h3>

Depending on what you are doing, some things that you instantiate in your app may need to be instantiated after networking is setup. You can use this delegate function to know when that is, and execute any necessary setup code. Be aware, this fires for every connection, so if you only want it to fire once you must handle that with your own code.

    - (void)finished_setup;

<h3>Send data:</h3>

You must create a `dispatch_data_t` object for `data_param`.

    [self.web_socket send_data:your.server.IP port:your.server.port data_param:data_param];

<h3>Receive data:</h3>

Implement this delegate method in your class/controller, all of the received data gets sent to it.

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
      passphrase: 'xxx', //Password, if any, for your certificates - a reason to use the same password for all of your certificates.
      hostname: 'xxx.xxx.xxx' //Must include to make iOS happy, this should be the same as the DNS information included in your certificates per these restrictions https://support.apple.com/en-us/HT210176
    };

<h3>Final Notes:</h3>

I would start out with the above configuration, and tweak it if neccessary - you shouldn't need to reconfigure much, and you can reference the NodeJS documentation mentioned above to help. The main trouble with figuring this out was getting the certificates right (with all the restrictions) so that the connection would even happen. You will also need to create a client certificate for for your iPhone. To get it onto your iPhone, email it to yourself in the form that it is created in, then on your iPhone, open the email with your iPhone's apple mail client (might not work with any other mail client), then tap to download, tap to install. Then follow the instructions for installing the certificate.  I commented the code thoroughly. I hope this helps! 