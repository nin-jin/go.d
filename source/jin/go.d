module jin.go;

import core.thread;
import std.stdio;
import std.parallelism;
import std.conv;
import std.variant;

alias Message = VariantN!( maxSize!( real , size_t , char[] , void delegate() ) );

class Queue {
	const size_t size = 64;

	private size_t tail;
	private Message[ this.size ] messages;
	private size_t head;

	bool full( )
	{
		return this.head == ( this.tail + 1 ) % this.size;
	}

	Value push( Value )( Value value )
	{
		while( this.full ) Thread.sleep( 10.dur!"nsecs" );
		this.messages[ this.tail ] = value;
		this.tail = ( this.tail + 1 ) % this.size;
		return value;
	}

	bool empty( ) 
	{
		return this.head == this.tail;
	}

	auto take( )
	{
		while( this.empty ) Thread.sleep( 10.dur!"nsecs" );
		
		auto value = this.messages[ this.head ];
		this.head = ( this.head + 1 ) % this.size;

		auto error = value.peek!Throwable;
		if( error !is null ) throw *error;

		return value;
	}

}

struct Channel
{
	private Queue inbox;
	private Queue outbox;

	auto mirror()
	{
		return Channel( this.outbox , this.inbox );
	}

	auto empty()
	{
		return this.inbox.empty;
	}

	Message take()
	{
		return this.inbox.take();
	}

	auto full()
	{
		return this.outbox.full;
	}

	void push( Value )( Value value )
	{
		this.outbox.push( value );
	}
}

struct RoundRobin
{
	Channel[] channels;
	alias channels this;

	int opApply( int delegate( Message ) handle )
	{
		while( true ) 
		{
			bool someHandled = false;
			foreach( channel ; this.channels ) 
			{
				if( channel.empty ) continue;
				auto br = handle( channel.take );
				if( br ) return br;
				someHandled = true;
			}
			if( someHandled ) continue;

			Thread.sleep( 100.dur!"nsecs" );
		}
	}
}

auto go( void delegate( Channel channel ) task )
{
	auto channel = Channel( new Queue , new Queue );

	new Thread({
		try {
			task( channel );
		} catch( Throwable error ) {
			channel.push( error );
		}
	}).start();
	
	return channel.mirror;
}
