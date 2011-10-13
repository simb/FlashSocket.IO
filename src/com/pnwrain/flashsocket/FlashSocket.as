package com.pnwrain.flashsocket
{
	import com.adobe.serialization.json.JSON;
	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.system.Security;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.utils.URLUtil;

	public class FlashSocket extends EventDispatcher implements IWebSocketWrapper
	{
		protected var debug:Boolean = false;
		protected var callerUrl:String;
		protected var socketURL:String;
		protected var webSocket:WebSocket;
		
		//vars returned from discovery
		public var sessionID:String;
		protected var heartBeatTimeout:int;
		protected var connectionClosingTimeout:int;
		protected var protocols:Array;
		
		//hold over variables from constructor for discover to use
		private var domain:String;
		private var protocol:String;
		private var proxyHost:String;
		private var proxyPort:int;
		private var headers:String;
		private var timer:Timer;
		
		public function FlashSocket( domain:String, protocol:String=null, proxyHost:String = null, proxyPort:int = 0, headers:String = null)
		{
			this.socketURL = "ws://" + domain + "/socket.io/1/flashsocket";
			this.callerUrl = "http://localhost/socket.swf";
			
			this.domain = domain;
			this.protocol = protocol;
			this.proxyHost = proxyHost;
			this.proxyPort = proxyPort;
			this.headers = headers;
			
			var r:URLRequest = new URLRequest();
			r.url = "http://" + domain + "/socket.io/1/";
			r.method = URLRequestMethod.POST;
			var ul:URLLoader = new URLLoader(r);
			ul.addEventListener(Event.COMPLETE, onDiscover);
			ul.addEventListener(HTTPStatusEvent.HTTP_STATUS, onDiscoverError);
			ul.addEventListener(IOErrorEvent.IO_ERROR , onDiscoverError);
		}
		
		protected function onDiscover(event:Event):void{
			var response:String = event.target.data;
			var respData:Array = response.split(":");
			sessionID = respData[0];
			heartBeatTimeout = respData[1];
			connectionClosingTimeout = respData[2];
			protocols = respData[3].toString().split(",");
			
			timer = new Timer( Math.ceil(heartBeatTimeout*.75)*1000);
			timer.addEventListener(TimerEvent.TIMER, onHeartBeatTimer);
			//timer.start();
			
			var flashSupported:Boolean = false;
			for ( var i:int=0; i<protocols.length; i++ ){
				if ( protocols[i] == "flashsocket" ){
					flashSupported = true;
					break;
				}
			}
			this.socketURL = this.socketURL + "/" + sessionID;
			
			
			onHandshake(event);
			
		}
		protected function onHandshake(event:Event):void{
			
			loadDefaultPolicyFile(socketURL);
			webSocket = new WebSocket(this, socketURL, protocol, proxyHost, proxyPort, headers);
			webSocket.addEventListener("event", onData);
			webSocket.addEventListener(Event.CLOSE, onClose);
			webSocket.addEventListener(Event.CONNECT, onConnect);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			webSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
		}
		protected function onHeartBeatTimer(event:TimerEvent):void{
			this._onHeartbeat();
		}
		
		protected function onDiscoverError(event:Event):void{
			if ( event is HTTPStatusEvent ){
				if ( (event as HTTPStatusEvent).status != 200){
					//we were unsuccessful in connecting to server for discovery
					var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT_ERROR);
					dispatchEvent(fe);
				}
			}
		}
		protected function onHandshakeError(event:Event):void{
			if ( event is HTTPStatusEvent ){
				if ( (event as HTTPStatusEvent).status != 200){
					//we were unsuccessful in connecting to server for discovery
					var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT_ERROR);
					dispatchEvent(fe);
				}
			}
		}
		
		protected function onClose(event:Event):void{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CLOSE);
			dispatchEvent(fe);
		}
		
		protected function onConnect(event:Event):void{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
			dispatchEvent(fe);
		}
		protected function onIoError(event:Event):void{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.IO_ERROR);
			dispatchEvent(fe);
		}
		protected function onSecurityError(event:Event):void{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.SECURITY_ERROR);
			dispatchEvent(fe);
		}
		
		protected function loadDefaultPolicyFile(wsUrl:String):void {
			var policyUrl:String = "xmlsocket://" + URLUtil.getServerName(wsUrl) + ":843";
			log("policy file: " + policyUrl);
			Security.loadPolicyFile(policyUrl);
		}
		
		public function getOrigin():String {
			return (URLUtil.getProtocol(this.callerUrl) + "://" +
				URLUtil.getServerNameWithPort(this.callerUrl)).toLowerCase();
		}
		
		public function getCallerHost():String {
			return null;
			//I dont think we need this
			//return URLUtil.getServerName(this.callerUrl);
		}
		public function log(message:String):void {
			if (debug) {
				trace("webSocketLog: " + message);
			}
		}
		
		public function error(message:String):void {
			trace("webSocketError: "  + message);
		}
		
		public function fatal(message:String):void {
			trace("webSocketError: " + message);
		}
		
		/////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////
		protected var frame:String = '~m~';
		
		protected function onData(e:*):void{
			var event:Object = (e.target as WebSocket).receiveEvents();
			var data:Object = event[0];
			
			if ( data.type == "message" ){
				this._setTimeout();
				var msg:String = unescape(data.data);
				if (msg){
					this._onMessage(msg);
				}
			}else if ( data.type == "open") {
				//this is good I think
			}else if ( data.type == "close" ){
				var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CLOSE);
				dispatchEvent(fe);
			}else{
				
				log("We got a data message that is not 'message': " + data.type);
			}
		}
		private function _setTimeout():void{
			
		}
		
		public var connected:Boolean;
		public var connecting:Boolean;
		
		private function _onMessage(message:String):void{
			//https://github.com/LearnBoost/socket.io-spec#Encoding
			/*	0		Disconnect
				1::	Connect
				2::	Heartbeat
				3:: Message
				4:: Json Message
				5:: Event
				6	Ack
				7	Error
				8	noop
			*/
			var dm:Object = deFrame(message);
			
			switch ( dm.type ){
				case '0':
					this._onDisconnect();
					break;
				case '1':
					this._onConnect();
					break;
				case '2':
					this._onHeartbeat();
					break;
				case '3':
					var fem:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.MESSAGE);
					fem.data = dm.msg;
					dispatchEvent(fem);
					break;
				case '4':
					var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.MESSAGE);
					fe.data = JSON.decode(dm.msg);
					dispatchEvent(fe);
					break;
				case '5':
					var m:Object = JSON.decode(dm.msg);
					var e:FlashSocketEvent = new FlashSocketEvent(m.name);
					e.data = m.args;
					dispatchEvent(e);
					break;
					
			}
			
		}
		protected function deFrame(message:String):Object{
			var si:int = 0;
			for ( var i5:int=0;i5<3;i5++){
				si = message.indexOf(":",si+1);
			}
			var ds:String = message.substring(si+1,message.length);
			return {type: message.substr(0, 1), msg: ds};
		}
		private function _decode(data:String):Array{
			var messages:Array = [], number:*, n:*;
			do {
				if (data.substr(0, 3) !== frame) return messages;
				data = data.substr(3);
				number = '', n = '';
				for (var i:int = 0, l:int = data.length; i < l; i++){
					n = Number(data.substr(i, 1));
					if (data.substr(i, 1) == n){
						number += n;
					} else {	
						data = unescape(data.substr(number.length + frame.length));
						number = Number(number);
						break;
					} 
				}
				messages.push(data.substr(0, number)); // here
				data = data.substr(number);
			} while(data !== '');
			return messages;
		}
		
		private function _onHeartbeat():void{
			webSocket.send( '2::' ); // echo
		};
		
		public function send(msg:Object, event:String = null):void{
			
			if ( event == null ){
				if ( msg is String){
					//webSocket.send(_encode(msg));
					webSocket.send('3:::' + msg as String);
				}else if ( msg is Object ){
					webSocket.send('4:::' + JSON.encode(msg));
				}else{
					throw("Unsupported Message Type");
				}
			}else{
				webSocket.send('5:::' + JSON.encode({"name":event,"args":msg}));
			}
			
		}
		
		private function _onConnect():void{
			this.connected = true;
			this.connecting = false;
			var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
			dispatchEvent(e);
		};
		private function _onDisconnect():void{
			this.connected = false;
			this.connecting = false;
			var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.DISCONNECT);
			dispatchEvent(e);
		};
		
		private function _encode(messages:*, json:Boolean=false):String{
			var ret:String = '',
				message:String,
				messages:* =  (messages is Array) ? messages : [messages];
			for (var i:int = 0, l:int = messages.length; i < l; i++){
				message = messages[i] === null || messages[i] === undefined ? '' : (messages[i].toString());
				if ( json ) {
					message = "~j~" + message;
				}
				ret += frame + message.length + frame + message;
			}
			return ret;
		};
	}
}