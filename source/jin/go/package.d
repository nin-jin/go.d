module jin.go;

import core.thread;
import core.time;
import std.range;
import std.traits;
import std.algorithm;
import std.parallelism;

import des.ts;

public import jin.go.channel;
public import jin.go.await;

/// Binds args to delegate that calls function with moving args to it.
auto delegateWithMovedArgs(CALLABLE, ARGS...)(auto ref CALLABLE callable, ref ARGS args)
{
	struct TARGS
	{
		ARGS expand;
	}

	enum maxTaskParameterSize = 128;

	static assert(TARGS.sizeof <= maxTaskParameterSize,
			"The arguments must not exceed " ~ maxTaskParameterSize.to!string
			~ " bytes in total size.");

	struct TaskFuncInfo
	{
		void[maxTaskParameterSize] args = void;

		@property ref A typedArgs(A)()
		{
			static assert(A.sizeof <= args.sizeof);
			return *cast(A*) args.ptr;
		}

	}

	TaskFuncInfo tfi;
	foreach (i, A; ARGS)
	{
		args[i].move(tfi.typedArgs!TARGS.expand[i]);
	}

	string callWithMove(ARGS...)(string func, string args)
	{
		import std.string : format;

		string ret = "return " ~ func ~ "(";
		foreach (i, T; ARGS)
		{
			if (i > 0)
				ret ~= ", ";
			ret ~= format("%s[%s].move", args, i);
		}
		return ret ~ ");";
	}

	return {
		TARGS args2;
		tfi.typedArgs!TARGS.move(args2);

		mixin(callWithMove!ARGS("callable", "args2.expand"));
	};
}

/// Safe to transfer between threads: shared, immutable, non-copiable
template IsSafeToTransfer(Value)
{
	enum IsSafeToTransfer = !hasUnsharedAliasing!Value || !__traits(compiles, {
			Value x, y = x;
		});
}

/// Run function asynchronously
auto go(alias func, Args...)(auto ref Args args)
		if (is(ReturnType!func : void) && (Parameters!func.length == Args.length))
{
	foreach (i, Arg; Args)
	{
		static assert(IsSafeToTransfer!Arg,
				"Value of type (" ~ Arg.stringof
				~ ") is not safe to pass between threads. Make it immutable or shared!");
	}

	auto task = delegateWithMovedArgs(&func, args).task;

	taskPool.put(task);

	return task;
}

/// Run function asynchronously and return Queue connectetd with range returned by function
auto go(alias func, Args...)(auto ref Args args)
		if (isInputRange!(ReturnType!func))
{
	alias Result = ReturnType!func;
	alias Message = ElementType!Result;

	Input!Message future;

	static void wrapper(Output!Message future, Result function(Args) func, Args args)
	{
		func(args).copy(&future);
	}

	go!wrapper(future.pair, &func, args);

	return future.release;
}

/// Run function with autocreated result Queue and return this Queue
auto go(alias task, Args...)(auto ref Args args)
		if ((Parameters!task.length == Args.length + 1)
			&& (is(Parameters!task[0] == Output!Message, Message)))
{
	Parameters!task[0] results;
	auto future = results.pair;
	go!task(results, args);
	return future;
}

/// Cut and return head from input range;
auto next(Range)(auto ref Range range) if (isInputRange!Range)
{
	auto value = range.front;
	range.popFront;
	return value;
}

/// Put to output range
auto next(Range, Value)(auto ref Range range, Value value)
		if (isOutputRange!(Range, Value))
{
	return range.put(value);
}

/// Bidirection : start , put*2 , take
unittest
{
	static void summing(Output!int sums, Input!int feed)
	{
		sums.next = feed.next + feed.next;
	}

	Output!int feed;
	Input!int sums;
	go!summing(sums.pair, feed.pair);

	feed.next = 3;
	feed.next = 4;
	sums.next.assertEq(3 + 4);
}

/// Bidirection : put*2 , start , take
unittest
{
	static void summing(Output!int sums, Input!int feed)
	{
		sums.next = feed.next + feed.next;
	}

	Output!int feed;
	auto ifeed = feed.pair;
	feed.next = 3;
	feed.next = 4;
	feed.destroy();

	Input!int sums;
	go!summing(sums.pair, ifeed);

	sums.next.assertEq(3 + 4);
}

/// Round robin : start*2 , put*4 , take*2
unittest
{
	Output!int feed;
	Input!int sums;

	static void summing(Output!int sums, Input!int feed)
	{
		sums.next = feed.next + feed.next;
	}

	go!summing(sums.pair, feed.pair);
	go!summing(sums.pair, feed.pair);

	feed.next = 3; // 1
	feed.next = 4; // 2
	feed.next = 5; // 1
	feed.next = 6; // 2

	sums[].sort().assertEq([3 + 5, 4 + 6]);
}

/// Event loop on multiple queues
unittest
{
	static void generating1(Output!int numbs)
	{
		numbs.next = 2;
		numbs.next = 3;
	}

	static void generating2(Output!long numbs)
	{
		numbs.next = 4;
		numbs.next = 5;
	}

	auto numbs1 = go!generating1;
	auto numbs2 = go!generating2;

	int[] results1;
	long[] results2;

	for (;;)
	{
		if (!numbs1.empty)
		{
			results1 ~= numbs1.next;
			continue;
		}
		if (!numbs2.empty)
		{
			results2 ~= numbs2.next;
			continue;
		}
		break;
	}

	results1.assertEq([2, 3]);
	results2.assertEq([4, 5]);
}

/// Blocking on buffer overflow
unittest
{
	static auto generating()
	{
		return 1.repeat.take(200);
	}

	auto numbs = go!generating;
	Thread.sleep(10.msecs);

	numbs[].sum.assertEq(200);
}

/// https://tour.golang.org/concurrency/1
/// "go" template starts function in new asynchronous coroutine
/// Coroutines starts in thread pool and may be executed in parallel threads.
/// Only thread safe values can be passed to function.
unittest
{
	import core.time;
	import std.range;
	import jin.go;

	__gshared static string[] log;

	static void saying(string message)
	{
		foreach (_; 3.iota)
		{
			Thread.sleep(200.msecs);
			log ~= message;
		}
	}

	go!saying("hello");
	Thread.sleep(100.msecs);
	saying("world");

	log.assertEq(["hello", "world", "hello", "world", "hello", "world"]);
}

/// https://tour.golang.org/concurrency/3
/// Queue is one-consumer-one-provider wait-free typed queue with InputRange and OutputRange interfaces support.
/// Use "next" property to send and receive messages;
unittest
{
	import jin.go;

	Output!int output;
	auto input = output.pair;
	output.next = 1;
	output.next = 2;
	input.next.assertEq(1);
	input.next.assertEq(2);
}

/// https://tour.golang.org/concurrency/2
/// Inputs is round robin input Queue list with InputRange and Queue interfaces support.
/// Method "pair" creates new Queue for every coroutine
unittest
{
	import std.algorithm;
	import std.range;
	import jin.go;

	static auto summing(Output!int sums, const int[] numbers)
	{
		sums.next = numbers.sum;
	}

	immutable int[] numbers = [7, 2, 8, -9, 4, 0];

	Input!int sums;
	go!summing(sums.pair(1), numbers[0 .. $ / 2]);
	go!summing(sums.pair(1), numbers[$ / 2 .. $]);
	auto res = (&sums).take(2).array;

	(res ~ res.sum).sort.assertEq([-5, 12, 17]);
}

/// https://tour.golang.org/concurrency/4
/// You can iterate over Queue by "foreach" like InputRange, and all standart algorithms support this.
/// Use "close" method to notify about no more data.
unittest
{
	import std.range;
	import jin.go;

	static auto fibonacci(Output!int numbers, size_t count)
	{
		auto range = recurrence!q{ a[n-1] + a[n-2] }(0, 1).take(count);
		foreach (x; range)
			numbers.next = x;
	}

	Input!int numbers;
	go!fibonacci(numbers.pair(10), 10);

	numbers[].assertEq([0, 1, 1, 2, 3, 5, 8, 13, 21, 34]);
}

/// https://tour.golang.org/concurrency/4
/// Function can return InputRange and it will be automatically converted to input Queue.
unittest
{
	import std.range;
	import jin.go;

	static auto fibonacci(int limit)
	{
		return recurrence!q{ a[n-1] + a[n-2] }(0, 1).take(limit);
	}

	fibonacci(10).array.assertEq([0, 1, 1, 2, 3, 5, 8, 13, 21, 34]);
	go!fibonacci(10).array.assertEq([0, 1, 1, 2, 3, 5, 8, 13, 21, 34]);
}

/// https://tour.golang.org/concurrency/5
/// Use custom loop to watch multiple Queues as you want.
/// Provider can be slave by using "needed" property.
/// Use "yield" to allow other coroutines executed between cycles.
unittest
{
	import std.range;
	import jin.go;

	__gshared int[] log;

	static auto fibonacci(Output!int numbers)
	{
		auto range = recurrence!q{ a[n-1] + a[n-2] }(0, 1);

		while (numbers.available >= 0)
		{
			numbers.next = range.next;
		}

	}

	static void printing(Output!bool controls, Input!int numbers)
	{
		foreach (i; 10.iota)
			log ~= numbers.next;
	}

	Output!int numbers;
	Input!bool controls;

	go!printing(controls.pair(1), numbers.pair(1));
	go!fibonacci(numbers);

	controls.pending.await;

	log.assertEq([0, 1, 1, 2, 3, 5, 8, 13, 21, 34]);
}
/+
/// https://tour.golang.org/concurrency/6
/// You can ommit first argument of Queue type, and it will be autogenerated and returned.
unittest
{
	import core.time;
	import jin.go;

	static auto after( ref Output!bool signals , Duration dur )
	{
		Thread.sleep( dur );
		signals.next = true;
		return signals.available >= 0;
	}

	static auto tick( Output!bool signals , Duration dur )
	{
		while( after( signals , dur ) ) {}
	}

	auto ticks = go!tick( 101.msecs );
	auto booms = go!after( 501.msecs );

	string log;

	for(;;) {
		if( ticks.pending > 0 ) {
			log ~= "tick";
			ticks.popFront;
			continue;
		}
		if( booms.pending > 0 ) {
			log ~= "BOOM!";
			break;
		}
		log ~= ".";
		Thread.sleep( 51.msecs );
	}

	while( booms.clear )
	{
		while( !ticks.empty ) {
			log ~= "tick";
			ticks.popFront;
		}
	}

	log.assertEq( "..tick..tick..tick..tick..BOOM!" );
}

/// https://tour.golang.org/concurrency/9
unittest
{
	import core.atomic;
	import core.time;
	import std.range;
	import std.typecons;
	import jin.go;

	synchronized class SafeCounter
	{
		private int[string] store;

		void inc( string key )
		{
			++ store[key];
		}

		auto opIndex( string key )
		{
			return store[ key ];
		}
		void opIndexUnary( string op = "++" )( string key )
		{
			this.inc( key );
		}
	}

		scope static counter = new shared SafeCounter;

	static void working( int i )
	{
		++ counter["somekey"];
	}

	foreach( i ; 1000.iota ) {
		go!working( i );
	}

	Thread.sleep( 1.seconds );

	counter["somekey"].assertEq( 1000 );
}
+/
