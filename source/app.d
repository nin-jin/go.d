import std.stdio;
import std.concurrency;
import std.conv;
import std.datetime;
import std.variant;
import std.range;
import jin.go;

const int iterations = 1000000;
const int writers = 2;

void one() {
	StopWatch timer;
	timer.start();

	for( int j = writers ; j > 0 ; --j ) {
		spawn({
			for( int i = iterations - 1 ; i >= 0 ; --i ) {
				ownerTid.send( i );
			}
		});
	}

	for( int j = writers ; j > 0 ; --j ) {
		while( receiveOnly!int ) {}
	}

	timer.stop();

	writeln( "std.concurency milliseconds=" , timer.peek.msecs );
}

void two() {
	StopWatch timer;
	timer.start();

	RoundRobin childs;

	for( int j = writers ; j > 0 ; --j ) {
		childs ~= go(( owner ){
			for( int i = iterations - 1 ; i >= 0 ; --i ) {
				owner.push( i );
			}
		});
	}

	for( int j = writers ; j > 0 ; --j ) {
		foreach( msg ; childs ) {
			auto val = msg.get!int;
			if( !val ) break;
		}
	}

	timer.stop();

	writeln( "jin.go milliseconds=" , timer.peek.msecs );
}

void main() {
	writeln( "iterations=" , iterations );
	writeln( "writers=" , writers );
	writeln( "messages=" , iterations * writers );
	one();
	two();
}
