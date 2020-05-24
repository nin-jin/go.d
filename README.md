# Go.d

Thread-pooled coroutines with [wait-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Wait-freedom) staticaly typed communication channels

# Features

* Static typed channels (but you can use Algebraic to transfer various data).
* Minimal message size (no additional memory cost).
* Wait free channels (but if you don't check for avalability you wil be spinlocked).
* Static check for message transition safety (allowed only shared, immutable and non-copiable).
* Every goroutine runs on thread poll.

# ToDo

* Fibers support (Should be used Fiber.yield instead of spinlock).
* Main thread usage (It is spinlocking now).

# Benchmarks

```
> .\compare.cmd

>go run app.go --release
Workers Result          Time
4       499500000       27.9226ms

>dub --quiet --build=release
Workers Result          Time
3       499500000       64 ms
```

# Usage

dub.json:
```json
{
	"dependencies": {
		"jin-go": "~>1.0.0"
	}
}
```

[Actual examples in unit tests](./source/jin/go.d)

## Import
```d
import jin.go;
```

## Create channels
```d
auto ints = new Channel!int;

struct Data { int val }
struct End {}
alias Algebraic!(Data,End) Message 
Input!Message messages_input;
auto messages_output = messages_input.pair;
auto messages_input2 = messages_output.pair;

Inputs!int ints_in;
Outputs!int ints_out;
```

## Start coroutines
```d
void incrementing( Output!int ints_out , Input!int ints_in ) {
	while( ints_out.available >= 0 ) {
		ints_out.next = ints_in.next + 1;
	}
}

go!incrementing( ints_in.pair , ints_out.pair );
auto ints_in = go!incrementing( ints_out.pair ); // ditto

auto squaring( int limit ) {
	return limit.iota.map( i => i^^2 );
}
auto squares_in = go!squaring( 10 );
```

## Send messages
waits while outbox/outboxes is full
```d
ints.next = 123; // send message
ints.next!Data = 123; // make and send message
ints.put( 123 ); // OutputRange style
```

## Receive messages
waits for any message in inbox/inboxes
```d
writeln( results.next ); // get one message
writeln( results.next.get!Data ); // get value from one Message

// visit one Message
results.next.visit!(
	( Data data ) { writeln( data ); } ,
	( End end ) { } ,
);

// handle messages in cycle
while( !results.empty ) {
	if( results.pending > 0 ) writeln( results.next );
};

// handle messages from multiple channels in cycle
while( !one.empty || !two.empty ) {
	if( one.pending > 0 ) writeln( one.next );
	if( two.pending > 0 ) writeln( two.next );
}
```
 
# Complete example

**currently broken**

```d
import core.time;
import std.stdio;
import jin.go;

static auto after( Channel!bool channel , Duration dur )
{
	sleep( dur );
	if( !channel.closed ) channel.next = true;
}

static auto tick( Channel!bool channel , Duration dur )
{
	while( !channel.closed ) after( channel , dur );
}

void main(){
	auto ticks = go!tick( 101.msecs );
	auto booms = go!after( 501.msecs );

	string log;

	while( booms.clear )
	{
		while( !ticks.clear ) {
			writeln( "tick" );
			ticks.popFront;
		}
		writeln( "." );
		sleep( 51.msecs );
	}
	writeln( "BOOM!" );
}
```