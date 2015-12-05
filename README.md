# threa.d
Lock free thread communication

Current results:
```sh
dub --build=release                                          
iterations=1000000
writers=2
messages=2000000
send/receiveOnly milliseconds=2021
push/take milliseconds=460
```

Import:
```d
import jin.go
```

Start new thread:
```d
// child is channel to communicate created thread
auto child = go!( ( owner ) {
    // owner is channel to communicate with owner thread
} );

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