const tls = require('tls');
const fs = require('fs');

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

const server = tls.createServer(options, (socket) => {
  console.log('server connected',
              socket.authorized ? 'authorized' : 'unauthorized');

  //In this example, the messages from the iOS app are received and 'piped' back to be received by the phone.
  socket.write('welcome!\n');
  socket.setEncoding('utf8');
  socket.pipe(socket);
});

server.listen(3000, () => {
  console.log('server bound');
});