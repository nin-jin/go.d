# go.d
Wait free thread communication

Current results:
```sh
> dub --build=release                                          
iterations=1000000
writers =2
readers =2
std.concurency milliseconds=1902
jin.go milliseconds=440

iterations=100000
writers =32
readers =32
std.concurency milliseconds=4240
jin.go milliseconds=761
```
```sh
> dub --build=release                                          
iterations=100000
writers=100
messages=10000000
std.concurency milliseconds=22485
jin.go milliseconds=2717
```

* std.concurency - [mutex](https://en.wikipedia.org/wiki/Lock_(computer_science))
* jin.go - [wait-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Wait-freedom)

Import:
```d
import jin.go
```

Start new thread:
```d
// child is channel to communicate with created thread
auto child = go!( ( owner ) {
    // owner is channel to communicate with owner thread
} );
```

Send messages (waits while outbox is full):
```d
channel.push( 123 ); // send int
channel.push( "abc" ); // send string
channel.push( new Exception( "error" ) ); // throw exception when receiver try to take message
```

Receive messages (waits for any message in inbox/inboxes):
```d
writeln( channel.take.get!int ); // get int
writeln( channel.take.get!string ); // get string

// merge channels
var input = Input([ channel1 , channel2 ]);
writeln( input.take.get!int );
```

ToDo:

 * Static typed channels
 * Blocking thread instead sleeping
 * Fibers multiplexing
 * Prevent data sharing