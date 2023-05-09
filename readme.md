# websocket-jai

Rough implementation of websocket specification in JAI. Supports TLS. Currently only Linux is supported as epoll is 
used for I/O. The module currently handles message loop internally and doesn't leave much control about it to the user.

There are missing parts and in some cases the server could be wrong and/or crash. Use at own risk.

## SSL

For SSL to work you have to provide cert and key file that is trusted. Examples are currently setup to work for non-SSL
connections so the .html files are loading 'ws://' url, which you will have to also change if you want to try it.

Untrusted connections will be dropped.

## Problem with epoll bindings

There is a small bug in epoll bindings in 0.1.062 which you will need to patch fix before this module can work. To fix simply replace following definition in the modules/POSIX/bindings/linux/epoll.jai file. This will eventually be fixed so it won't be an issue down the road.

```
epoll_event :: struct {
    events: u32;
    data: epoll_data #align 4; // the alignment is missing...
}
```

## Todo
 - Support control frames (ping/pong,...)
 - Handle edgecases like when client hardcloses TCP connection

## Examples

In examples folder there is currently a simple chat example app with no backend storage, only message forwarding
to multiple clients. Just start the server and open the html in browser.

## OpenSSL bindings

The module also comes with hand-written OpenSSL bindings. This also will probably change in the future.

