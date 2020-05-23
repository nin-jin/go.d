import std.datetime.stopwatch;
import std.algorithm;
import std.algorithm.iteration;
import std.parallelism;
import std.range;
import std.stdio;
import std.typecons;

import jin.go;
import core.stdc.stdlib;

enum long iterations = 1000;
enum long threads = 1000;

auto produce()
{
	return iterations.iota;
}

auto consume( Output!long sums , Input!long numbers )
{
	// write('[');
	long s;
	foreach( n ; numbers ) {
		s += n;
	}
	sums.next = s;
	// write(']');
}

void main()
{
	auto timer = StopWatch( AutoStart.yes );

	Input!long sums;
	foreach( i ; threads.iota ) {
		go!consume( sums.make(1) , go!produce );
	}

	long sumsums = 0;
	foreach( s; sums) sumsums += s;

	timer.stop();

	writeln( "Workers\tResult\t\tTime" );
	writeln( taskPool.size , "\t" , sumsums , "\t" , timer.peek.total!"msecs", " ms" );

}
