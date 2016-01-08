import core.thread;
import std.stdio;
import std.parallelism;
import std.concurrency;
import std.conv;
import std.typecons;
import std.datetime;
import std.variant;
import std.range;
import std.functional;
import jin.go;

const int iterations = 10000;
const int writersCount = 64;
const int readersCount = writersCount;

struct Data {
	int val;
}

struct End {}

alias Algebraic!( Data , End ) Msg;


/*synchronized class SyncQ {
	private Msg[] data;
	void push( Value , Args... )( Args args ) {
		data ~= Msg( Value( args ) );
	}
	auto take( ) {
		auto v = data[0];
		data = data[ 1 .. $ ];
		return v;
	}
}

shared SyncQ sq;

void one() {
	StopWatch timer;
	timer.start();

	sq = new SyncQ;

	for( int j = writersCount ; j > 0 ; --j ) {
		spawn({
			try {
				for( int i = iterations - 1 ; i >= 0 ; --i ) {
					sq.push!Data( i );
				}
				sq.push!End;
			} catch( Throwable error ) {
				stderr.writeln( error );
			}
		});
	}

	for( int j = readersCount ; j > 0 ; --j ) {
		spawn({
			try {
				auto doing = true;
				while( doing ) {
					if( !sq.take.visit!(
						( Data val ) => true ,
						( End val ) => false ,
					) ) break;
				}
				ownerTid.send( End() );
			} catch( Throwable error ) {
				stderr.writeln( error );
			}
		});
	}

	for( int j = readersCount ; j > 0 ; --j ) {
		receiveOnly!End;
	}

	timer.stop();

	writeln( "std.concurency milliseconds=" , timer.peek.msecs );
}*/

/*void two1()
{
	StopWatch timer;
	timer.start();

	Queues!Msg writes;
	Queues!Msg reades;

	void writing( Queue!Msg reader )
	{
		for( int i = iterations ; i > 0 ; --i )
		{
			reader.push!Data( i );
		}
		reader.push!End;
	}

	void reading( Queue!Msg writer )
	{
		writer.handle(( msg ){
			msg.visit!(
				( Data val ){ } , 
				( End val ){ throw new EOC; } ,
			);
		}).cycle;
	}

	for( int j = writersCount ; j > 0 ; --j )
	{
		go!writing( writes.make() );
	}

	for( int j = readersCount ; j > 0 ; --j )
	{
		go!reading( reades.make() );
	}

	for( int j = readersCount ; j > 0 ; --j )
	{
		writes.handle( ( msg ) {
			if( msg.type == typeid( End ) ) throw new EOC;
			reades.push( msg );
		} ).cycle;
	}

	for( int j = readersCount ; j > 0 ; --j )
	{
		reades.push!End;
	}

	timer.stop();

	writeln( "jin.go milliseconds=" , timer.peek.msecs );
}*/


void one2() {
	StopWatch timer;
	timer.start();

	for( int j = writersCount ; j > 0 ; --j ) {
		spawn({
			for( int i = iterations ; i > 0 ; --i ) {
				ownerTid.send( Data( i ) );
			}
			ownerTid.send( End() );
		});
	}

	for( int j = writersCount ; j > 0 ; --j ) {
		auto doing = true;
		while( doing ) {
			receive(
				( Data val ) {} ,
				( End val ) { doing = false; } ,
			);
		}
	}

	timer.stop();

	writeln( "std.concurency milliseconds=" , timer.peek.msecs );
}

void two2() {
	StopWatch timer;
	timer.start();

	Queues!Msg writes;
	
	void write( Queue!Msg reader ) {
		for( int i = iterations ; i > 0 ; --i ) {
			reader.push!Data( i );
		}
		reader.push!End;
	}

	for( int j = writersCount ; j > 0 ; --j ) {
		go!write( writes.make() );
	}

	for( int j = writersCount ; j > 0 ; --j ) {
		writes.handle( ( msg ) {
			msg.visit!(
				( Data val ) { } ,
				( End end ) { throw new EOC; } ,
			);
		} ).cycle;
	}

	timer.stop();

	writeln( "jin.go milliseconds=" , timer.peek.msecs );
}

void main() {
	writeln( "iterations=" , iterations );
	writeln( "writers =" , writersCount );
	writeln( "readers =" , readersCount );
	one2();
	Thread.sleep( 1.dur!"seconds" );
	two2();
}
