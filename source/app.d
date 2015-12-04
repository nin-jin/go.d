module jin.msg;

import core.thread;
import std.stdio;
import std.concurrency;
import std.conv;
import std.algorithm;
import std.datetime;
import std.meta;
import std.traits;
import std.variant;

class Queue {
	const size = 10;
	
	private int posFeed;
	private Variant[ this.size ] messages;
	private int posEat;

	Value eat( Value )( ) {
		while( this.posEat == this.posFeed ) Thread.sleep( 10.dur!"nsecs" );
		auto value = this.messages[ this.posEat ];
		this.posEat = ( this.posEat + 1 ) % this.size;
		return value.get!Value;
	}
	
	void feed( Value )( Value value ) {
		while( this.posEat == ( this.posFeed + 1 ) % this.size ) Thread.sleep( 10.dur!"nsecs" );
		this.messages[ this.posFeed ] = value;
		this.posFeed = ( this.posFeed + 1 ) % this.size;
	}
}

alias Queue[ ThreadID ] Channel;

synchronized {
	__gshared Channel[ ThreadID ] channels;
}

Channel ingoing;
Channel outgoing;

void feed( Value )( Thread target , Value value )
{
	if( target.id in outgoing )
	{
		auto queue = cast( Queue ) outgoing[ target.id ];
		queue.feed( value );
	} else {
		while( target.id !in channels ) Thread.sleep( 10.dur!"nsecs" );

		auto chan = channels[ target.id ];
		auto queue = chan[ Thread.getThis.id ];
		//outgoing[ target.id ] = cast( Queue ) queue;

		queue.feed( value );
	}
}

auto eat( Value )( Thread source )
{
	auto thisId = Thread.getThis.id; 
	if( thisId in channels )
	{
		auto chan = channels[ Thread.getThis.id ];
		if( source.id in chan )
		{
			auto queue = chan[ source.id ];
			return queue.eat!Value;
		} else {
			Queue queue;
			chan[ source.id ] = queue;
			return queue.eat!Value;
		}
	} else {
		Queue[ ThreadID ] chan;
		auto queue = chan[ source.id ] = new Queue;
		channels[ Thread.getThis.id ] = chan; 
		return queue.eat!Value;
	}
}

const int iterations = 1000000;

void one() {
	StopWatch timer;

	auto owner = Thread.getThis;
	auto child = spawn({
		for( int i = iterations ; i >= 0 ; --i ) ownerTid.send( i );
	});

	timer.start();
	while( receiveOnly!int ) {}
	timer.stop();

	writeln( "std.concurrency.send messages=" , iterations , " milliseconds=" , timer.peek.msecs , " frequency=" , 1000 * iterations / ( timer.peek.msecs + 1 ) );
}

void two() {
	StopWatch timer;

	auto owner = Thread.getThis;
	auto child = new Thread({
		for( int i = iterations ; i >= 0 ; --i ) {
			owner.feed( i );
		}
	}).start();

	timer.start();
	while( child.eat!int ) {}
	timer.stop();

	writeln( "jin.msg.feed messages=" , iterations , " milliseconds=" , timer.peek.msecs , " frequency=" , 1000 * iterations / ( timer.peek.msecs + 1 ) );
}

void main() {
	one();
	two();
}
