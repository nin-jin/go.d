import std.datetime;
import std.algorithm;
import std.range;
import std.stdio;
import std.typecons;
import jin.go;
import vibe.core.log;

enum int iterations = 1000;
enum int threads = 1000;

void main( )
{
	static auto produce( Output!int numbers )
	{
		foreach( i ; iterations.iota ) numbers.next = i;
	}

	static auto consume( Output!int sums , Input!int numbers )
	{
		int s;
		foreach( n ; numbers ) s += n;
		sums.next = s;
	}

	StopWatch timer;
	timer.start();

	Input!int sums;
	foreach( i ; threads.iota ) {
		Input!int channel;
		go!produce( channel.make(100) );
		go!consume( sums.make(1) , channel );
	}

	writefln( "%(%d %)" , sums[] );
	//foreach( s ; sums ) {}

	timer.stop();

	writeln( "jin.go: " , timer.peek.msecs );

	//setLogLevel(LogLevel.debugV);
}


