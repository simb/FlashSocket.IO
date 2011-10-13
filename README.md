# FlashSocket.IO

Flash library to facilitate communication between Flex applications and Socket.IO servers.

The actual websocket communication is taken care of by my fork of gimite/web-socket-js project.

This project wraps that and facilitates the hearbeat and en/decoding of messages so they work with Socket.IO servers

# Checkout

Because this project makes use of git submodules you must make use of the recursive clone.

git clone --recursive git://github.com/simb/FlashSocket.IO.git

# Building

Because this library is dependent on the websocket library, you must add the support/websocket-js path to you source path in flash builder or your build files.

# Usage

For Socket.io 0.7 and 0.8 you will need to use the Beta swc that you can find in the downloads  section.  Currently in beta.

An example of a flex application connecting to a server on localhost is below

	<?xml version="1.0" encoding="utf-8"?>
	<s:Application xmlns:fx="http://ns.adobe.com/mxml/2009" 
				   xmlns:s="library://ns.adobe.com/flex/spark" 
				   xmlns:mx="library://ns.adobe.com/flex/mx" minWidth="955" minHeight="600"
				   creationComplete="application1_creationCompleteHandler(event)">
		<s:layout>
			<s:VerticalLayout />
		</s:layout>
		<fx:Declarations>
			<!-- Place non-visual elements (e.g., services, value objects) here -->
		</fx:Declarations>
		<fx:Script>
			<![CDATA[
				import com.pnwrain.flashsocket.FlashSocket;
				import com.pnwrain.flashsocket.events.FlashSocketEvent;

				import mx.controls.Alert;
				import mx.events.FlexEvent;

				[Bindable]
				protected var socket:FlashSocket;

				protected function application1_creationCompleteHandler(event:FlexEvent):void
				{

					socket = new FlashSocket("localhost:8080");
					socket.addEventListener(FlashSocketEvent.CONNECT, onConnect);
					socket.addEventListener(FlashSocketEvent.MESSAGE, onMessage);
					socket.addEventListener(FlashSocketEvent.IO_ERROR, onError);
					socket.addEventListener(FlashSocketEvent.SECURITY_ERROR, onError);

					socket.addEventListener("my other event", myCustomMessageHandler);
				}

				protected function myCustomMessageHandler(event:FlashSocketEvent):void{
					Alert.show('we got a custom event!')	
				}

				protected function onConnect(event:FlashSocketEvent):void {

					clearStatus();

				}

				protected function onError(event:FlashSocketEvent):void {

					setStatus("something went wrong");

				}

				protected function setStatus(msg:String):void{

					status.text = msg;

				}
				protected function clearStatus():void{

					status.text = "";
					this.currentState = "";

				}

				protected function onMessage(event:FlashSocketEvent):void{

					trace('we got message: ' + event.data);
					socket.send({msgdata: event.data},"my other event");

				}

			]]>
		</fx:Script>
		<s:Label id="status" />
		<s:Label id="glabel" />
	</s:Application>
	
