module jin.go;

import core.thread;
import core.atomic;
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
		return this.tail == ( this.head + 1 ) % this.size;
	}

	auto pending( )
	{
		return ( this.head - this.tail ) % this.size;
	}

	auto available( )
	{
		return this.size - this.pending;
	}

	Value push( Value )( Value value )
	{
		static assert( !hasUnsharedAliasing!( Value ) , "Aliases to mutable thread-local data not allowed." ); 

		Waiter.sleepWhile( this.full );

		auto head = this.head;
		this.messages[ head ] = value;
		atomicFence;
		this.head = ( head + 1 ) % this.size;

		return value;
	}

	Value push( Value , Args... )( Args args )
	{
		return this.push( Value( args ) );
	}

	auto take( )
	{
		Waiter.sleepWhile( this.empty );

		auto tail = this.tail;
		auto value = this.messages[ this.tail ];
		atomicFence;
		this.tail = ( this.tail + 1 ) % this.size;

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

			if( !queue.empty )
			{
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
				next = curr;
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

	int delay = 1;
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


/// Bidirection : start , push*2 , take
unittest {
	auto output = new Queue!int;
	auto input = new Queue!int;
	
	void summator( Queue!int input , Queue!int output ) {
		output.push( input.take + input.take );
	}

	auto child = go!summator( output , input );
	scope( exit ) child.join();
	
	output.push( 3 );
	output.push( 4 );
	
	assert( input.take == 3 + 4 );
}

/// Bidirection : push*2 , start , take
unittest {
	auto output = new Queue!int;
	auto input = new Queue!int;

	void summator( Queue!int input , Queue!int output ) {
		output.push( input.take + input.take );
	}

	output.push( 3 );
	output.push( 4 );

	auto worker = go!summator( output , input );
	scope( exit ) worker.join();

	assert( input.take == 3 + 4 );
}

/// Round robin : start*2 , push*4 , take*2
unittest {
	Queues!int output;
	Queues!int input;

	void summator( Queue!int input , Queue!int output ) {
		output.push( input.take + input.take );
	}

	auto worker1 = go!summator( output.make() , input.make() );
	scope( exit ) worker1.join();

	auto worker2 = go!summator( output.make() , input.make() );
	scope( exit ) worker2.join();

	output.push( 3 ); // 1
	output.push( 4 ); // 2
	output.push( 5 ); // 1
	output.push( 6 ); // 2

	assert( input.take * input.take == ( 3 + 5 ) * ( 4 + 6 ) );
}

/// Event loop on multiple queues
unittest {
	auto input1 = new Queue!int;
	auto input2 = new Queue!int;

	void generating1( Queue!int output ) {
		output.push( 2 );
		output.push( 3 );
		output.push( 0 );
	}

	void generating2( Queue!int output ) {
		output.push( 4 );
		output.push( 5 );
		output.push( 0 );
	}

	auto worker1 = go!generating1( input1 );
	scope( exit ) worker1.join();

	auto worker2 = go!generating2( input2 );
	scope( exit ) worker2.join();

	int summ1;
	int summ2;

	for( int i = 0 ; i < 2 ; ++ i ) { 
		cycle(
			input1.handle( ( val ) {
				summ1 += val;
				if( val == 0 ) throw new EOC;
			} ) ,
			input2.handle( ( val ) {
				summ2 += val;
				if( val == 0 ) throw new EOC;
			} ) ,
		);
	}

	assert( summ1 == 2 + 3 );
	assert( summ2 == 4 + 5 );
}

/// Blocking on buffer overflow
unittest {
	auto input = new Queue!int;

	void summator( Queue!int output ) {
		for( int i = 0 ; i < output.size * 2 ; ++i ) {
			output.push( 1 );
		}
	}

	auto child = go!summator( input );
	scope( exit ) child.join();

	Waiter.sleepWhile( !input.full );

	int summ;
	for( int i = 0 ; i < input.size * 2 ; ++i ) {
		summ += input.take;
	}

	assert( summ == input.size * 2 );
}
