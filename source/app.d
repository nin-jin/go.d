module app;

import std.datetime.stopwatch;
import std.range;
import std.stdio;
import std.algorithm;

import jin.go;

enum long iterations = 10_000;
enum long threads = 1000;

static auto produce()
{
	return iterations.iota;
}

static auto consume(Input!long numbers)
{
	return [numbers.fold!q{a+b}];
}

void main()
{
	auto timer = StopWatch(AutoStart.yes);

	Input!long sums;
	for (auto i = 0; i < threads; ++i)
		sums ~= go!produce.go!consume;

	long sumsums = sums.fold!q{a+b};

	timer.stop();

	writeln("Workers\tResult\t\tTime");
	writeln(0, "\t", sumsums, "\t", timer.peek.total!"msecs", " ms");

}
