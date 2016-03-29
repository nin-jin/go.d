module jin.go;

import core.atomic;
import core.time;
import std.stdio;
import std.range;
import std.exception;
import std.typecons;
import std.traits;
import std.algorithm;
import des.ts;

public import vibe.core.core;
public import vibe.core.concurrency;

/// vibe.core.core.yield works not correctly
alias yield = vibe.core.concurrency.yield;

/// Run function asynchronously
auto go( alias task , Args... ) ( auto ref Args args )
if( is( ReturnType!task : void ) && ( Parameters!task.length == Args.length ) )
{
	return runWorkerTaskH( &task , args );
}

/// Run function asynchronously and return channel connectetd with range returned by function
auto go( alias task , Args... ) ( auto ref Args args )
if( isInputRange!(ReturnType!task) )
{
	alias Result = ReturnType!task;
	alias Value = ElementType!Result;

	auto future = new Channel!Value;

	runWorkerTask( ( Channel!Value future , Result function( Args ) task , Args args ) {
		foreach( value ; task( args ) ) future.next = value;
		future.close();
	} , future , &task , args );

	return future;
}

/// Run function with autocreated result channel and return this channel
auto go( alias task , Args... )( auto ref Args args )
if( ( Parameters!task.length == Args.length + 1 )&&( is( Parameters!task[0] == Channel!Message , Message ) ) )
{
	alias Future = Parameters!task[0];
	auto future = new Future;
	go!task( future , args );
	return future;
}

/// Cut and return head from input range;
auto next( Range )( auto ref Range range )
if( isInputRange!Range )
{
    auto value = range.front;
	range.popFront;
    return value;
}

/// Put to output range
auto next( Range , Value )( auto ref Range range , Value value )
if( isOutputRange!(Range,Value) )
{
	return range.put( value );
}

/// Wait-free one input one output queue
class Channel( Message )
{
	/// Allow transferring between tasks
	static __isIsolatedType = true;

	/// Message needs for receiver
	bool needed;

	/// Offset of first not received message
	private size_t tail;

	/// Cyclic buffer of transferring messages
	private Message[] messages;
	
	/// Offset of next free slot for message
	private size_t head;

	/// One of two task will no longer operate with this channel
	bool closed;

	/// Limit channel to 512B by default
	this( int size = 512 / Message.sizeof - 1 )
	{
		enforce( size > 0 , "Channel size must be greater then 0" );

		this.messages = new Message[ size + 1 ];
	}

	/// Maximum transferring messages count at one time
	size_t size( )
	{
		return this.messages.length - 1;
	}

	/// No more messages in buffer
	bool clear( ) 
	{
		return this.tail == this.head;
	}

	/// End of input range
	auto empty( )
	{
		return this.clear && this.closed;
	}

	/// No more messages can be transferred now
	bool full( )
	{
		return this.tail == ( this.head + 1 ) % this.messages.length;
	}

	/// Count of messages in buffer now
	auto pending( )
	{
		return ( this.head - this.tail ) % this.messages.length;
	}

	/// Count of messages that can be sended before buffer will be full
	auto available( )
	{
		return this.size - this.pending;
	}

	/// Inform other task about disconnecting
	/// TODO: deprecate by unique refs
	void close( )
	{
		this.closed = true;
	}

	/// Put message to head
	Value put( Value )( Value value )
	{
		static assert( isWeaklyIsolated!Value , "Argument type " ~ Value.stringof ~ " is not safe to pass between threads." ); 
		//enforce( !this.closed , "Channel is closed" );

		while( this.full ) yield;

		this.needed = false;
		this.messages[ this.head ] = value;
		atomicFence;
		this.head = ( this.head + 1 ) % this.messages.length;

		return value;
	}

	/// Create and put message to head
	Value put( Value , Args... )( Args args )
	{
		return this.put( Value( args ) );
	}

	/// Get message at tail
	auto front( )
	{
		if( this.clear ) this.needed = true;

		while( this.clear ) {
			enforce( !empty , "Channel is closed" );
			yield;
		}

		return this.messages[ this.tail ];
	}

	/// Remove message from tail
	auto popFront( )
	{
		enforce( !this.clear , "Channel is clear" );

		this.tail = ( this.tail + 1 ) % this.messages.length;
	}
}

/// Common channel collections realization
mixin template Channels( Message )
{
	/// All registered channels
	Channel!Message[] channels;

	/// Offset of current channel
	private size_t current;

	/// Make new registered channel
	auto make( Args... ) ( Args args )
	{
		auto channel = new Channel!Message( args );
		this.channels ~= channel;
		return channel;
	}

	/// Close all channels;
	void close( )
	{
		foreach( channel ; this.channels ) channel.close();
	}
}

/// Round robin input channels
struct Inputs( Message )
{
	mixin Channels!Message;

	/// No more messages in all channels
	auto clear( )
	{
		if( !this.channels.length ) return true;

		auto start = this.current;
		do {
			auto channel = this.channels[ this.current ];
			if( !channel.clear ) return false;

			this.current = ( this.current + 1 ) % this.channels.length;
		} while( this.current != start );

		return true;
	}

	/// End of input range
	auto empty( )
	{
		if( !this.channels.length ) return true;

		auto start = this.current;
		do {
			auto channel = this.channels[ this.current ];
			if( !channel.empty ) return false;

			this.current = ( this.current + 1 ) % this.channels.length;
		} while( this.current != start );

		return true;
	}

	/// Get message at tail of current non clear channel or wait
	auto front( )
	{
		while( this.clear ) yield;
		return this.channels[ this.current ].front;
	}

	/// Remove message from tail of current channel and switch to another channel
	void popFront( )
	{
		this.channels[ this.current ].popFront;
		this.current = ( this.current + 1 ) % this.channels.length;
	}
}

/// Round robin output channels
struct Outputs( Message )
{
	mixin Channels!Message;

	/// No more messages can be transferred now
	auto full( )
	{
		if( !this.channels.length ) return true;

		auto start = this.current;
		do {
			auto channel = this.channels[ this.current ];
			if( !channel.full ) return false;

			this.current = ( this.current + 1 ) % this.channels.length;
		} while( this.current != start );

		return true;
	}

	/// Put message to current non full channel and switch channel
	Value put( Value )( Value value )
	{
		while( this.full ) yield;
		auto message = this.channels[ this.current ].put( value );
		this.current = ( this.current + 1 ) % this.channels.length;
		return message;
	}
}


/// Bidirection : start , put*2 , take
unittest
{
	static void summing( Channel!int output , Channel!int input ) {
		output.next = input.next + input.next;
		output.close();
	}

	auto output = new Channel!int;
	auto input = go!summing( output );

	output.next = 3;
	output.next = 4;

	input.next.assertEq( 3 + 4 );
}

/// Bidirection : put*2 , start , take
unittest
{
	static void summing( Channel!int output , Channel!int input ) {
		output.next = input.next + input.next;
		output.close();
	}

	auto output = new Channel!int;
	output.next = 3;
	output.next = 4;

	auto input = go!summing( output );

	input.next.assertEq( 3 + 4 );
}

/// Round robin : start*2 , put*4 , take*2
unittest
{
	Outputs!int output;
	Inputs!int input;

	static void summing( Channel!int output , Channel!int input ) {
		output.next = input.next + input.next;
		output.close();
	}

	go!summing( input.make , output.make );
	go!summing( input.make , output.make );
	
	output.next = 3; // 1
	output.next = 4; // 2
	output.next = 5; // 1
	output.next = 6; // 2

	input.array.sort().assertEq([ 3 + 5 , 4 + 6 ]);
}

/// Event loop on multiple queues
unittest
{
	static void generating1( Channel!int output ) {
		output.next = 2;
		output.next = 3;
		output.close();
	}

	static void generating2( Channel!long output ) {
		output.next = 4;
		output.next = 5;
		output.close();
	}

	auto input1 = go!generating1;
	auto input2 = go!generating2;

	int[] results1;
	long[] results2;

	while( !input1.empty || !input2.empty ) {
		if( !input1.clear ) results1 ~= input1.next;
		if( !input2.clear ) results2 ~= input2.next;
	}

	results1.assertEq([ 2 , 3 ]);
	results2.assertEq([ 4 , 5 ]);
}

/// Blocking on buffer overflow
unittest
{
	static void summing( Channel!int output ) {
		foreach( i ; ( output.size * 2 ).iota ) {
			output.next = 1;
		}
		output.close();
	}

	auto input = go!summing;
	while( !input.full ) yield;

	input.sum.assertEq( input.size * 2 );
}



/// https://tour.golang.org/concurrency/1
/// "go" template starts function in new asynchronous coroutine
/// Coroutines starts in thread pool and may be executed in parallel threads.
/// Only thread safe values can be passed to function.
unittest
{
	import core.time;
	import std.range;
	import jin.go;

	__gshared static string[] log;

	static void saying( string message )
	{
		foreach( _ ; 3.iota ) {
			sleep( 100.msecs );
			log ~= message;
		}
	}

	go!saying( "hello" );
	sleep( 50.msecs );
	saying( "world" );

	log.assertEq([ "hello" , "world" , "hello" , "world" , "hello" , "world" ]);
}

/// https://tour.golang.org/concurrency/3
/// Channel is one-consumer-one-provider wait-free typed queue with InputRange and OutputRange interfaces support.
/// Use "next" property to send and receive messages;
unittest
{
	import jin.go;

	auto numbers = new Channel!int(2);
	numbers.next = 1;
	numbers.next = 2;
	numbers.next.assertEq( 1 );
	numbers.next.assertEq( 2 );
}

/// https://tour.golang.org/concurrency/2
/// Inputs is round robin input channel list with InputRange and Channel interfaces support.
/// Method "make" creates new channel for every coroutine
unittest
{
	import std.algorithm;
	import std.range;
	import jin.go;

	static auto summing( Channel!int sums , const int[] numbers ) {
		sums.next = numbers.sum;
	}

	immutable int[] numbers = [ 7 , 2 , 8 , -9 , 4 , 0 ];

	Inputs!int sums;
	go!summing( sums.make(1) , numbers[ 0 .. $/2 ] );
	go!summing( sums.make(1) , numbers[ $/2 .. $ ] );
	auto res = sums.take(2).array;

	( res ~ res.sum ).assertEq([ 17 , -5 , 12 ]);
}

/// https://tour.golang.org/concurrency/4
/// You can iterate over channel by "foreach" like InputRange, and all standart algorithms support this.
/// Use "close" method to notify about no more data.
unittest
{
	import std.range;
	import jin.go;

	static auto fibonacci( Channel!int numbers , int count )
	{
		auto range = recurrence!q{ a[n-1] + a[n-2] }( 0 , 1 ).take( count );
		foreach( x ; range ) numbers.next = x;
		numbers.close();
	}

	auto numbers = new Channel!int(10);
	go!fibonacci( numbers , numbers.size );

	numbers.array.assertEq([ 0 , 1 , 1 , 2 , 3 , 5 , 8 , 13 , 21 , 34 ]);
}

/// https://tour.golang.org/concurrency/4
/// Function can return InputRange and it will be automatically converted to input channel.
unittest
{
	import std.range;
	import jin.go;

	static auto fibonacci( int limit )
	{
		return recurrence!q{ a[n-1] + a[n-2] }( 0 , 1 ).take( limit );
	}

	fibonacci( 10 ).array.assertEq([ 0 , 1 , 1 , 2 , 3 , 5 , 8 , 13 , 21 , 34 ]);
	go!fibonacci( 10 ).array.assertEq([ 0 , 1 , 1 , 2 , 3 , 5 , 8 , 13 , 21 , 34 ]);
}

/// https://tour.golang.org/concurrency/5
/// Use custom loop to watch multiple channels as you want.
/// Provider can be slave by using "needed" property.
/// Use "yield" to allow other coroutines executed between cycles.
unittest
{
	import std.range;
	import jin.go;

	__gshared int[] log;

	static auto fibonacci( Channel!int numbers , Channel!bool control )
	{
		auto range = recurrence!q{ a[n-1] + a[n-2] }( 0 , 1 );

		while( !control.closed )
		{
			if( numbers.needed ) numbers.next = range.next;
			yield;
		}

		log ~= -1;
		numbers.close();
	}

	static void print( Channel!bool control , Channel!int numbers )
	{
		foreach( i ; 10.iota ) log ~= numbers.next;
		control.close();
	}

	auto numbers = new Channel!int(1);
	auto control = new Channel!bool(1);

	go!print( control , numbers );
	go!fibonacci( numbers , control );

	while( !control.empty || !numbers.empty ) yield;

	log.assertEq([ 0 , 1 , 1 , 2 , 3 , 5 , 8 , 13 , 21 , 34 , -1 ]);
}

/// https://tour.golang.org/concurrency/6
/// You can ommit first argument of Channel type, and it will be autogenerated and returned.
unittest
{
	import core.time;
	import jin.go;

	static auto after( Channel!bool channel , Duration dur )
	{
		sleep( dur );
		if( !channel.closed ) channel.next = true;
	}

	static auto tick( Channel!bool channel , Duration dur )
	{
		while( !channel.closed ) after( channel , dur );
	}

	auto ticks = go!tick( 101.msecs );
	auto booms = go!after( 501.msecs );

	string log;

	while( booms.clear )
	{
		while( !ticks.clear ) {
			log ~= "tick";
			ticks.popFront;
		}
		log ~= ".";
		sleep( 51.msecs );
	}
	log ~= "BOOM!";

	log.assertEq( "..tick..tick..tick..tick..BOOM!" );
}

/// https://tour.golang.org/concurrency/9
unittest
{
	import core.atomic;
	import core.time;
	import std.range;
	import std.typecons;
	import jin.go;

	synchronized class SafeCounter
	{
		private int[string] store;

		void inc( string key )
		{
			++ store[key];
		}

		auto opIndex( string key )
		{
			return store[ key ];
		}
		void opIndexUnary( string op = "++" )( string key )
		{
			this.inc( key );
		}
	}

		scope static counter = new shared SafeCounter;

	static void working( int i )
	{
		++ counter["somekey"];
	}

	foreach( i ; 1000.iota ) {
		go!working( i );
	}

	sleep( 1.seconds );

	counter["somekey"].assertEq( 1000 );
}
