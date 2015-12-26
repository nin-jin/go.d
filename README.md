# Go.d

Wait free thread communication

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
readers =2
std.concurency milliseconds=1851
jin.go milliseconds=145

iterations=100000
writers =16
readers =16
std.concurency milliseconds=1967
jin.go milliseconds=130

iterations=10000
writers =128
readers =128
std.concurency milliseconds=4383
jin.go milliseconds=116
```

* std.concurency - [mutex](https://en.wikipedia.org/wiki/Lock_(computer_science))
* jin.go - [wait-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Wait-freedom)

# Usage

Import:
```d
import jin.go
```

Start new thread:
```d
// child is channel to communicate with created thread
auto child = go!( int /*message to child*/ , Algebraic!(int,Throwable) /*message from child*/ )( ( owner ) {
    // owner is channel to communicate with owner thread
} );
```

Send messages (waits while outbox is full):
```d
channel.push( 123 ); // send int
channel.push( "abc" ); // send string
channel.push( new Exception( "error" ) ); // send error

var ouput = Output([ channel1.outbox , channel2.outbox ]); // merge channels
writeln( input.push( 123 ) ); // push to any free output channel (roundrobin)
```

Receive messages (waits for any message in inbox/inboxes):
```d
writeln( channel.take ); // get message
writeln( channel.take.get!string ); // get string from Algebraic!(int,Throwable)

var input = Input([ channel1.inbox , channel2.inbox ]); // merge channels
writeln( input.take ); // take from any channel (roundrobin)
```
 
