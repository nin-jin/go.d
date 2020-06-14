module jin.go.go;

import std.range;
import std.traits;
import std.algorithm;

import vibe.core.core;
import des.ts;

public import jin.go.channel;
public import jin.go.await;

/// Run function asynchronously
auto go(alias task, Args...)(auto ref Args args)
        if (is(ReturnType!task : void) && (Parameters!task.length == Args.length))
{
    foreach (i, Arg; Args)
    {
        static assert(IsSafeToTransfer!Arg, "Value of type (" ~ Arg.stringof
                ~ ") is not safe to pass between threads. "
                ~ "Make it immutable, non-copyable or shared!");
    }
    return runWorkerTask(&task, args);
}

/// Run function asynchronously and return Queue connectetd with range returned by function
auto go(alias task, Args...)(auto ref Args args)
        if (isInputRange!(ReturnType!task))
{
    alias Result = ReturnType!task;
    alias Message = ElementType!Result;

    Input!Message future;

    static void wrapper(Output!Message future, Result function(Args) task, Args args)
    {
        task(args).copy(&future);
    }

    go!wrapper(future.pair, &task, args);

    return future;
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

/// Safe to transfer between threads: shared, immutable, non-copiable
template IsSafeToTransfer(Value)
{
    enum IsCopyable(Value) = __traits(compiles, { Value x, y = x; });
    enum IsSafeToTransfer = !hasUnsharedAliasing!Value || !IsCopyable!Value;
}

/// Bidirection : start , put*2 , take
unittest
{
    import jin.go;

    static void summing(Output!int sums, Input!int feed)
    {
        sums.put(feed.next + feed.next);
    }

    Output!int feed;
    Input!int sums;
    go!summing(sums.pair, feed.pair);

    feed.put(3);
    feed.put(4);
    sums.next.assertEq(3 + 4);
}

/// Bidirection : put*2 , start , take
unittest
{
    import jin.go;

    static void summing(Output!int sums, Input!int feed)
    {
        sums.put(feed.next + feed.next);
    }

    Output!int feed;
    auto ifeed = feed.pair;
    feed.put(3);
    feed.put(4);
    feed.destroy();

    Input!int sums;
    go!summing(sums.pair, ifeed);

    sums.next.assertEq(3 + 4);
}

/// Round robin : start*2 , put*4 , take*2
unittest
{
    import jin.go;

    Output!int feed;
    Input!int sums;

    static void summing(Output!int sums, Input!int feed)
    {
        sums.put(feed.next + feed.next);
    }

    go!summing(sums.pair, feed.pair);
    go!summing(sums.pair, feed.pair);

    feed.put(3); // 1
    feed.put(4); // 2
    feed.put(5); // 1
    feed.put(6); // 2

    sums[].sort().assertEq([3 + 5, 4 + 6]);
}

/// Event loop on multiple queues
unittest
{
    import jin.go;

    static void generating1(Output!int numbs)
    {
        numbs.put(2);
        numbs.put(3);
    }

    static void generating2(Output!long numbs)
    {
        numbs.put(4);
        numbs.put(5);
    }

    auto numbs1 = go!generating1;
    auto numbs2 = go!generating2;

    int[] results1;
    long[] results2;

    while (!numbs1.empty || !numbs2.empty)
    {
        if (numbs1.pending > 0)
        {
            results1 ~= numbs1.next;
        }
        if (numbs2.pending > 0)
        {
            results2 ~= numbs2.next;
            continue;
        }
    }

    results1.assertEq([2, 3]);
    results2.assertEq([4, 5]);
}

/// Blocking on buffer overflow
unittest
{
    import core.time;
    import jin.go;

    static auto generating()
    {
        return 1.repeat.take(200);
    }

    auto numbs = go!generating;
    10.msecs.sleep;

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

    Input!string log;

    static void saying(Output!string log, string message)
    {
        foreach (_; 3.iota)
        {
            200.msecs.sleep;
            log.put(message);
        }
    }

    go!saying(log.pair, "hello");
    saying(log.pair, "world");

    log[].length.assertEq(6);
}

/// https://tour.golang.org/concurrency/3
/// Queue is one-consumer-one-provider wait-free typed queue with InputRange and OutputRange interfaces support.
/// Use "next" property to send and receive messages;
unittest
{
    import jin.go;

    Output!int output;
    auto input = output.pair;
    output.put(1);
    output.put(2);
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
        sums.put(numbers.sum);
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
            numbers.put(x);
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

        foreach (num; range)
        {
            numbers.put(num);

            if (numbers.available == -1)
            {
                break;
            }
        }

    }

    static void printing(Output!bool controls, Input!int numbers)
    {
        foreach (i; 10.iota)
        {
            log ~= numbers.next;
        }
    }

    Output!int numbers;
    Input!bool controls;

    go!printing(controls.pair(1), numbers.pair(1));
    go!fibonacci(numbers);

    controls.pending.await;

    log.assertEq([0, 1, 1, 2, 3, 5, 8, 13, 21, 34]);
}

/// https://tour.golang.org/concurrency/6
/// You can ommit first argument of Queue type, and it will be autogenerated and returned.
unittest
{
    import core.time;
    import jin.go;

    static void after(Output!bool signals, Duration dur)
    {
        dur.sleep;
        signals.put(true);
    }

    static auto tick(Output!bool signals, Duration dur)
    {
        while (signals.available >= 0)
        {
            dur.sleep;
            signals.put(true);
        }
    }

    auto ticks = go!tick(100.msecs);
    auto booms = go!after(490.msecs);

    string log;

    for (;;)
    {
        if (ticks.pending > 0)
        {
            log ~= "tick,";
            ticks.popFront;
            continue;
        }
        if (booms.pending > 0)
        {
            log ~= "BOOM!";
            break;
        }
        10.msecs.sleep;
    }

    log.assertEq("tick,tick,tick,tick,BOOM!");
}
