module jin.go;

import core.thread;
import std.stdio;
import std.parallelism;
import std.conv;
import std.variant;
import std.parallelism;

class Queue( Message ) {
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
		while( this.empty )Thread.sleep( 10.dur!"nsecs" );
		
		auto value = this.messages[ this.head ];
		this.head = ( this.head + 1 ) % this.size;

		return value;
	}

}

class Channel( InQueue , OutQueue )
{
	InQueue inbox;
	OutQueue outbox;

	this( InQueue inbox , OutQueue outbox ) {
		this.inbox = inbox;
		this.outbox = outbox;
	}

	auto empty()
	{
		return this.inbox.empty;
	}

	auto take()
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

class Input( Message )
{
	Queue!Message[] queues;
	alias queues this;
	
	size_t next;

	auto take( )
	{
		auto curr = next;

		while( true ) 
		{
			auto queue = queues[ curr ];
			curr = ( curr + 1 ) % queues.length;

			if( !queue.empty )
			{
				next = curr;
				return queue.take();
			}

			if( curr == next )
			{
				Thread.sleep( 10.dur!"nsecs" );
			}
		}
	}
}


struct Output( Message )
{
	Queue!Message[] queues;
	alias queues this;

	size_t next;

	void push( Value )( Value value )
	{
		auto curr = next;

		while( true ) 
		{
			auto queue = queues[ curr ];
			curr = ( curr + 1 ) % queues.length;

			if( !queue.full )
			{
				return queue.push( value );
			}

			if( curr == next )
			{
				Thread.sleep( 10.dur!"nsecs" );
			}
		}
	}
}

Channel!( Queue!OutMessage , Queue!InMessage ) go( InMessage , OutMessage )(
	void delegate( Channel!( Queue!InMessage , Queue!OutMessage ) channel ) task
){
	auto inQueue = new Queue!InMessage;
	auto outQueue = new Queue!OutMessage;

	auto enChannel = new Channel!( Queue!InMessage , Queue!OutMessage )( inQueue , outQueue );
	auto exChannel = new Channel!( Queue!OutMessage , Queue!InMessage )( outQueue , inQueue );

	auto thread = new Thread({
		task( enChannel );
	});
	thread.isDaemon = true;
	thread.start();
	
	return exChannel;
}
