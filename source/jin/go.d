module jin.go;

import core.thread;
import core.sync.condition;
import std.stdio;
import std.parallelism;
import std.algorithm;
import std.concurrency;
import std.conv;
import std.variant;
import std.traits;

class Queue( Message ) {
	const size_t size = 64;

	private size_t tail;
	private Message[ this.size ] messages;
	private size_t head;

	bool empty( ) 
	{
		return this.tail == this.head;
	}

	bool full( )
	{
		return this.head == ( this.tail + 1 ) % this.size;
	}

	auto pending( )
	{
		return ( this.tail - this.head ) % this.size;
	}

	auto available( )
	{
		return this.size - this.pending;
	}

	Value push( Value )( Value value )
	{
		static assert( !hasUnsharedAliasing!( Value ) , "Aliases to mutable thread-local data not allowed." ); 

		Waiter.sleepWhile( this.full );

		this.messages[ this.tail ] = value;
		this.tail = ( this.tail + 1 ) % this.size;

		return value;
	}

	Value push( Value , Args... )( Args args )
	{
		return this.push( Value( args ) );
	}

	auto take( )
	{
		Waiter.sleepWhile( this.empty );

		auto value = this.messages[ this.head ];
		this.head = ( this.head + 1 ) % this.size;

		return value;
	}

	bool delegate() handle( void delegate( Message ) handler )
	{
		return {
			if( this.empty ) return false;
			handler( this.take );
			return true;
		};
	}

}

struct Queues( Message )
{
	Queue!Message[] queues;
	alias queues this;

	size_t next;

	auto empty( )
	{
		return this.queues.all!q{ a.empty };
	}

	auto full( )
	{
		return this.queues.all!q{ a.full };
	}

	auto take( )
	{
		auto curr = next;
		Waiter waiter;

		while( true ) 
		{
			auto queue = queues[ curr ];
			curr = ( curr + 1 ) % queues.length;

			if( !queue.empty ) {
				next = curr;
				return queue.take();
			}

			if( curr == next )
			{
				waiter.wait();
			}
		}
	}

	Value push( Value )( Value value )
	{
		auto curr = next;
		Waiter waiter;

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
				waiter.wait();
			}
		}
	}

	Value push( Value , Args... )( Args args )
	{
		return this.push( Value( args ) );
	}

	auto make( )
	{
		auto queue = new Queue!Message;
		this.queues ~= queue;
		return queue;
	}

	bool delegate() handle( void delegate( Message ) handler )
	{
		return {
			if( this.empty ) return false;
			handler( this.take );
			return true;
		};
	}

}

struct Waiter
{

	int delay = 4;
	int maxDelay = 64;

	void wait()
	{
		Thread.sleep( delay.dur!"nsecs" );
		if( delay <= maxDelay ) delay *= 2;
	}

	static void sleepWhile( lazy bool cond )
	{
		auto waiter = Waiter();
		while( cond() ) {
			waiter.wait();
		}
	}

}

Thread go( alias task , Args... )( Args args ){
	auto thread = new Thread({
		auto scheduler = new FiberScheduler;
		scheduler.start({
			try {
				task( args );
			} catch( Throwable error ) {
				stderr.write( error );
			}
		});
	});

	thread.isDaemon = true;
	thread.start();
	
	return thread;
}

void cycle( bool delegate()[] handlers... ) {
	try {
		Waiter waiter;
		while( true ) {
			bool needWait = true;
			foreach( handle ; handlers ) {
				if( handle() ) needWait = false;
			}
			if( needWait ) {
				waiter.wait();
			} else {
				waiter = Waiter.init;
			}
		}
	} catch( EOC end ) {}
}

class EOC : Exception {
	@nogc @safe pure nothrow this(string msg="", string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
}
