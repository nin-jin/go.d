import std.datetime;
import std.algorithm;
import std.range;
import std.stdio;
import std.typecons;
import jin.go;

enum int iterations = 1000;
enum int threads = 1000;

auto produce( Output!int numbers )
{
	foreach( i ; iterations.iota ) {
		numbers.next = i;
	}
	numbers.end;
}

auto consume( Output!int sums , Input!int numbers )
{
	int s;
	foreach( n ; numbers ) s += n;
	sums.next = s;
	sums.end;
}

auto testing( )
{
	writeln( "Worker count: " , workerCount );

	StopWatch timer;
	timer.start();

	Input!int sums;
	foreach( i ; threads.iota ) {
		Input!int channel;
		go!produce( channel.make );
		go!consume( sums.make(1) , channel );
	}

	foreach( sum ; sums ) write( sum , " " );

	timer.stop();

	writeln( "jin.go: " , timer.peek.msecs );

	import core.stdc.stdlib; exit(0);
}

void main( )
{
	go!testing;
	startWorking;
}


