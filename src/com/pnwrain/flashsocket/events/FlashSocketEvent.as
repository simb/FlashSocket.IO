package com.pnwrain.flashsocket.events
{
	import flash.events.Event;
	
	public class FlashSocketEvent extends Event
	{
		public static const CONNECT:String = "connect";
		public static const DISCONNECT:String = "disconnect";
		public static const MESSAGE:String = "message";
		
		public var data:*;
		
		public function FlashSocketEvent(type:String, bubbles:Boolean=true, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
	}
}