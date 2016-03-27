# Go.d

Thread-pooled coroutines with [wait-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Wait-freedom) staticaly typed communication channels

[![Build Status](https://travis-ci.org/nin-jin/go.d.svg?branch=master)](https://travis-ci.org/nin-jin/go.d)
[![Join the chat at https://gitter.im/nin-jin/go.d](https://badges.gitter.im/nin-jin/go.d.svg)](https://gitter.im/nin-jin/go.d?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Features

* Static typed channels
* Lock free channels
* Minimal message size

# ToDo

* Allow only one input and output ref
* Autoclose channels

# Usage

dub.json:
```json
{
	"dependencies": {
		"jin-go": "~>1.0.0"
	}
}
```

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
auto messages = new Channel!Message;

Inputs!int ints;
auto queue = ints.make;

Outputs!int ints;
auto queue = ints.make;
```

## Start coroutines
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
	if( !results.clear ) writeln( results.next );
} ).cycle;

// handle messages from multiple channels in cycle
while( !one.empty || !two.empty ) {
	if( !one.clear ) writeln( one.next );
	if( !two.clear ) writeln( two.next );
}
```
 
# More examples

* [Unit tests](./blob/master/source/jin/go.d)
