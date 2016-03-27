# Go.d

Thread-pooled coroutines with lock-free staticaly typed communication channels

[![Build Status](https://travis-ci.org/nin-jin/go.d.svg?branch=master)](https://travis-ci.org/nin-jin/go.d)
[![Join the chat at https://gitter.im/nin-jin/go.d](https://badges.gitter.im/nin-jin/go.d.svg)](https://gitter.im/nin-jin/go.d?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Features

* Static typed channels
* Lock free channels
* Minimal message size

# ToDo

 * Allow only one input and output link
 * Autoclose channels

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

dub.json:
```json
{
	...
	"dependencies": {
		"jin-go": "~>1.0.0"
	}
}
```

Import:
```d
import jin.go;
```

Create channels:
```d
auto ints = new Channel!int;

struct Data { int val }
struct End {}
alias Algebraic!(Data,End) Message 
auto messages = new Channel!Message;

Inputs!int ints;
auto queue = ints.make;

Outputs!int ints;
auto queue = ints.make;
```

Start coroutine:
```d
void incrementing( Channel!int results , Channel!int inputs ) {
	while( true ) {
		results.next = inputs.next + 1;
	}
}

go!incrementing( results.make , ints.make );
auto results = go!incrementing( ints.make );

void squaring( int limit ) {
	return limit.iota.map( i => i^^2 );
}
auto squares = go!squaring( 10 );
```

Send messages (waits while outbox/outboxes is full):
```d
ints.next = 123; // send message
ints.next!Data = 123; // make and send message
ints.put( 123 ); // OutputRange style
```

Receive messages (waits for any message in inbox/inboxes):
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
	if( !results.clear ) writeln( results.next );
} ).cycle;

// handle messages from multiple channels in cycle
while( !one.empty || !two.empty ) {
	if( !one.clear ) writeln( one.next );
	if( !two.clear ) writeln( two.next );
}
```
 
[More examples in tests](./blob/master/source/jin/go.d)
