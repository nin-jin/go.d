# go.d
Wait free thread communication

Current results:
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

var ouput = Output([ channel1 , channel2 ]); // merge channels
writeln( input.push( 123 ) ); // push to any free output channel (roundrobin)
```

Receive messages (waits for any message in inbox/inboxes):
```d
writeln( channel.take.get!int ); // get int
writeln( channel.take.get!string ); // get string

var input = Input([ channel1 , channel2 ]); // merge channels
writeln( input.take.get!int ); // take from any channel (roundrobin)
```

ToDo:

 * Blocking thread instead sleeping
 * Fibers multiplexing
 * Prevent data sharing
