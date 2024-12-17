import std.datetime.stopwatch;
import std.range;
import std.stdio;
import vibe.core.core;

import jin.go;

enum long iterations = 10_000;
enum long threads = 100;
enum KB = 1024;
enum MB = 1024 * KB;

static auto produce()
{
	return iterations.iota;
}

static auto consume(Output!long sums, Input!long numbers)
{
	long s;
	foreach (n; numbers)
		s += n;
	sums.put(s);
}

void main()
{
	runTask({
		auto timer = StopWatch(AutoStart.yes);

		Input!long sums;
		foreach (i; threads.iota)
		{
			sums.pair(1).go!consume( go!produce );
		}

		long sumsums;
		foreach (s; sums)
		{
			sumsums += s;
		}

		timer.stop();

		writeln("Workers\tResult\t\tTime");
		writeln(workerThreadCount, "\t", sumsums, "\t", timer.peek.total!"msecs", " ms");

	});

	runEventLoopOnce();

}
