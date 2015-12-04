# threa.d
Lock free thread communication

Current results:
```sh
dub --build=release                                          
std.concurrency.send messages=1000000 milliseconds=908 frequency=1100110     
jin.msg.feed messages=1000000 milliseconds=567 frequency=1760563            
```
