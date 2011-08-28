# FlashSocket.IO

Flash library to facilitate communication between Flex applications and Socket.IO servers.

The actual websocket communication is taken care of by my fork of gimite/web-socket-js project.

This project wraps that and facilitates the hearbeat and en/decoding of messages so they work with Socket.IO servers

# Checkout

Because this project makes use of git submodules you must make use of the recursive clone.

git clone --recursive git://github.com/simb/FlashSocket.IO.git

# Building

Because this library is dependent on the websocket library, you must add the support/websocket-js path to you source path in flash builder or your build files.

