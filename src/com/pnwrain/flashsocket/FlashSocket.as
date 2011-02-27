package com.pnwrain.flashsocket
{
	import com.adobe.serialization.json.JSON;
	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.system.Security;
	
	import mx.utils.URLUtil;

	public class FlashSocket extends EventDispatcher implements IWebSocketWrapper
	{
		protected var debug:Boolean = false;
		protected var callerUrl:String;
		protected var socketURL:String;
		protected var webSocket:WebSocket;
		
		public function FlashSocket( url:String, protocol:String=null, proxyHost:String = null, proxyPort:int = 0, headers:String = null)
		{
			this.socketURL = url;
			this.callerUrl = "http://localhost/socket.swf";
			
			loadDefaultPolicyFile(url);
			webSocket = new WebSocket(this, url, protocol, proxyHost, proxyPort, headers);
			webSocket.addEventListener("event", onData);
			webSocket.addEventListener(Event.CLOSE, onClose);
			webSocket.addEventListener(Event.CONNECT, onConnect);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			webSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
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
				var msgs:Array = this._decode(data.data);
				if (msgs && msgs.length){
					for (var i:int = 0, l:int = msgs.length; i < l; i++){
						this._onMessage(msgs[i]);
					}
				}
			}
		}
		private function _setTimeout():void{
			
		}
		public var sessionid:String;
		public var connected:Boolean;
		public var connecting:Boolean;
		
		private function _onMessage(message:String):void{
			if (!this.sessionid){
				this.sessionid = message;
				this._onConnect();
			} else if (message.substr(0, 3) == '~h~'){
				this._onHeartbeat(message.substr(3));
			} else if (message.substr(0, 3) == '~j~'){
				var json:String = message.substring(3,message.length);
				var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.MESSAGE);
				fe.data = JSON.decode(json);
				dispatchEvent(fe);
			} else {
				var fe2:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.MESSAGE);
				fe2.data = message;
				dispatchEvent(fe2);
			}
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
		
		private function _onHeartbeat(heartbeat:*):void{
			var enc:String = '~h~' + heartbeat;
			send( enc ); // echo
		};
		
		public function send(msg:String):void{
			webSocket.send(_encode(msg));
		}
		
		private function _onConnect():void{
			this.connected = true;
			this.connecting = false;
			var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
			dispatchEvent(e);
		};
		
		private function _encode(messages:*):String{
			var ret = '', message,
				messages =  (messages is Array) ? messages : [messages];
			for (var i = 0, l = messages.length; i < l; i++){
				message = messages[i] === null || messages[i] === undefined ? '' : (messages[i].toString());
				ret += frame + message.length + frame + message;
			}
			return ret;
		};
	}
}