# Go.d

Wait free thread communication

[![Build Status](https://travis-ci.org/nin-jin/go.d.svg?branch=master)](https://travis-ci.org/nin-jin/go.d)
[![Join the chat at https://gitter.im/nin-jin/go.d](https://badges.gitter.im/nin-jin/go.d.svg)](https://gitter.im/nin-jin/go.d?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Features

* Non blocking message transfer between threads
* Static typed channels for threads communication
* Minimal message size
* Low memory cost

# ToDo

 * Blocking thread instead sleeping
 * Fibers multiplexing

# Current results

```sh
> dub --build=release                                          
iterations=1000000
writers =2
readers =1
std.concurency milliseconds=1891
jin.go milliseconds=1344

iterations=100000
writers =16
readers =1
std.concurency milliseconds=1912
jin.go milliseconds=561

iterations=10000
writers =64
readers =1
std.concurency milliseconds=1241
jin.go milliseconds=238

iterations=1000
writers =256
readers =1
std.concurency milliseconds=2855
jin.go milliseconds=73

iterations=100
writers =512
readers =1
std.concurency milliseconds=1313
jin.go milliseconds=113
```

* std.concurency - [mutex](https://en.wikipedia.org/wiki/Lock_(computer_science))
* jin.go - [wait-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Wait-freedom)

# Usage

Import:
```d
import jin.go
```

Create channels:
```d
auto ints = new Queue!int;

struct Data { int val }
struct End {}
alias Algebraic!(Data,End) Message 
auto messages = new Queue!Message;

Queues!int ints;
auto queue = ints.make();
```

Start native threads:
```d
void incrementor( Queue!int ints , Queue!int res ) {
	while( true ) {
		res.push( ints.take + 1 );
	}
}

go!incrementor( ints.make() , results.make() );
```

Send messages (waits while outbox/outboxes is full):
```d
ints.push( 123 ); // send message
ints.push!Data( 123 ); // make and send message
```

Receive messages (waits for any message in inbox/inboxes):
```d
writeln( results.take ); // get one message
writeln( results.take.get!Data ); // get value from one Message

// visit one Message
results.take.visit!(
	( Data data ) { writeln( data ); } ,
	( End end ) { } ,
);

// handle messages in cycle
results.handle( ( res ) {
	writeln( res );
	if( res == 0 ) throw new EOC; // exit from cycle
} ).cycle;

// handle messages from multiple channels in cycle
cycle(
	ints.handle( ( val ) {
		res.push( val + 1 );
	} ,
	ends.handle( ( end ) {
		throw new EOC;
	}
);
```
 
