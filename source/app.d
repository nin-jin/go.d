import std.datetime;
import std.algorithm;
import std.range;
import std.stdio;
import jin.go;

enum int iterations = 1000;
enum int threads = 1000;

void main( )
{
	StopWatch timer;
	timer.start();

	struct Data {
		int value;
	}

	static auto writing( ) {
		return iterations.iota.map!Data;
	}

	auto inputs = threads.iota.map!( i => go!writing ).array.Inputs!Data;

	foreach( i ; inputs ) {}

	timer.stop();

	writeln( "jin.go: " , timer.peek.msecs );
}
