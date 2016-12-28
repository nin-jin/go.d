import std.datetime;
import std.algorithm;
import std.range;
import std.stdio;
import std.typecons;
import jin.go;

enum long iterations = 1000;
enum long threads = 1000;

auto produce()
{
	return iterations.iota;
}

auto consume( Output!long sums , Input!long numbers )
{
	long s;
	foreach( n ; numbers ) s += n;
	sums.next = s;
}

auto testing( )
{
	auto timer = StopWatch( AutoStart.yes );

	Input!long sums;
	foreach( i ; threads.iota ) {
		go!consume( sums.make(1) , go!produce );
	}

	long sumsums;
	foreach( sum ; sums ) sumsums += sum;

	timer.stop();

	writeln( "Workers\tResult\t\tTime" );
	writeln( workerCount , "\t" , sumsums , "\t" , timer.peek.msecs , "ms" );

	core.stdc.stdlib.exit(0);
}

void main( )
{
	go!testing;
	startWorking;
}


