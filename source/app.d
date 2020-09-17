import std.datetime.stopwatch;
import std.range;
import std.stdio;
import vibe.core.core;

import jin.go;

// enum long iterations = 10000;
// enum long threads = 100;

// static auto produce()
// {
// 	return iterations.iota;
// }

// static auto consume(Output!long sums, Input!long numbers)
// {
// 	long s;
// 	foreach (n; numbers)
// 		s += n;
// 	sums.put(s);
// }

// void main()
// {
// 	runTask({
// 		auto timer = StopWatch(AutoStart.yes);

// 		Input!long sums;
// 		foreach (i; threads.iota)
// 		{
// 			go!consume(sums.pair(1), go!produce());
// 		}

// 		long sumsums;
// 		foreach (s; sums)
// 		{
// 			sumsums += s;
// 		}

// 		timer.stop();

// 		writeln("Workers\tResult\t\tTime");
// 		writeln(workerThreadCount, "\t", sumsums, "\t", timer.peek.total!"msecs", " ms");

// 	});

// 	runEventLoopOnce();

// }


const long n = 10_000_000;

void threadProducer(Output!(long,1023) queue)
{
  foreach (long i; 0..n) {
	queue ~= i;
  }
}

void main()
{
	Input!(long,1023) queue;
	go!threadProducer(queue.pair);

	StopWatch sw;
	sw.start();
	long sum = 0;

	foreach (p; queue)
	{
		sum += p;
	}

	sw.stop();

	writefln("received %d messages in %d msec sum=%d speed=%d msg/msec", n,
			sw.peek.total!"msecs", sum, n / sw.peek.total!"msecs");
	
	assert(sum == (n * (n - 1) / 2));
}
