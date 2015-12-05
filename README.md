# threa.d
Lock free thread communication

Compared:
* std.concurency - [mutex](https://en.wikipedia.org/wiki/Lock_(computer_science))
* jin.go - [wait-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Wait-freedom)

Current results:
```sh
dub --build=release                                          
iterations=1000000
writers=2
messages=2000000
std.concurency milliseconds=1847
jin.go milliseconds=440
```

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
```

Receive messages (waits for any message in inbox/inboxes):
```d
writeln( channel.take.get!int ); // get int
writeln( channel.take.get!string ); // get string

// infinite loop by messages from channels
foreach( msg ; RoundRobin( [ channel1 , channel2 ] ) ) {
	writeln( msg.get!int );
}
```
