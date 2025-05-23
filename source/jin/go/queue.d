module jin.go.queue;

import std.container;
import std.exception;
import std.conv;

import jin.go.mem;
import jin.go.cursor;

/// Wait-free 1-producer/1-concumer queue.
class Queue(
	Message,
	/// By default 1 Page size
	size_t Length = (Page - __traits(classInstanceSize, Queue!(Message, 0))) / Message.sizeof
) if( Message.sizeof < Page / 2 )
{
	/// Offset of next free slot.
	Cursor producer;

	/// Offset of next pending message.
	Cursor consumer;

	/// Ring buffer of transferring messages.
	Message[Length] messages;

	/// Maximum queue capacity.
	@property size_t size()
	{
		return Length - 1;
	}

	/// Count of pending messages.
	/// Negative value - no one message will be produced.
	ptrdiff_t pending() const
	{
		const fin = this.producer.finalized;
		const pending = (Length - this.consumer.offset + this.producer.offset) % Length;

		if (pending > 0)
			return pending;

		return fin;
	}

	/// Count of available free slots.
	/// Negative value - no one message will be consumed.
	ptrdiff_t available() const
	{
		if (this.consumer.finalized == -1)
			return -1;

		return (Length - this.producer.offset + this.consumer.offset - 1) % Length;

	}

	/// True when no more messages can be produced ever.
	bool ignore()
	{
		return this.available < 0;
	}

	/// Put message without locking.
	/// Check `available` before to prevent message loss.
	void put(Value)(Value value)
	{
		if (this.available <= 0)
			return;

		const offset = this.producer.offset;

		this.messages[offset] = value;

		this.producer.offset = (offset + 1) % Length;
	}

	/// Create and put message.
	/// Check `available` before to prevent message loss.
	void put(Value, Args...)(Args args)
	{
		this.put(Value(args));
	}

	/// True when no more messages can be consumed ever.
	auto empty()
	{
		return this.pending < 0;
	}

	/// Get current pending message.
	/// Check `pending` before to prevent lock.
	Message front()
	{
		assert(this.pending > 0, "Queue is empty");

		return this.messages[this.consumer.offset];
	}

	/// Consume current pending message.
	/// Check `pending` before to prevent lock.
	void popFront()
	{
		assert(this.pending > 0, "Queue is empty");

		const offset = (this.consumer.offset + 1) % Length;
		this.consumer.offset = offset;
	}

}

/// Automatic fit buffer size to memory page size.
unittest
{
	auto q1 = new Queue!int;
	assert(q1.size == 927);

	auto q2 = new Queue!long;
	assert(q2.size == 463);
}

/// Pending and available.
unittest
{
	auto q = new Queue!(int, 4);
	assert(q.pending == 0);
	assert(q.available == 3);

	q.put(7);
	assert(q.pending == 1);
	assert(q.available == 2);

	q.put(77);
	assert(q.pending == 2);
	assert(q.available == 1);

	q.put(777);
	assert(q.pending == 3);
	assert(q.available == 0);

	assert(q.front == 7);
	q.popFront;
	assert(q.pending == 2);
	assert(q.available == 1);

	assert(q.front == 77);
	q.popFront;
	assert(q.pending == 1);
	assert(q.available == 2);

	assert(q.front == 777);
	q.popFront;
	assert(q.pending == 0);
	assert(q.available == 3);
}

/// Consume from empty is forbidden.
unittest
{
	import core.exception;

	auto q = new Queue!int;
	q.producer.finalize();

	q.front.assertThrown!AssertError;
	q.popFront.assertThrown!AssertError;
}

/// Produce to full is ignored.
unittest
{
	import core.exception;
	import std.array;

	auto q = new Queue!(int, 2);
	q.put(1);
	q.put(2);
	q.put(3);
	q.producer.finalize;

	assert(q.array == [1], "Broken Queue after put to full");
}

/// Make struct inside put.
unittest
{
	struct Foo
	{
		int a;
		int b;
	}

	auto q = new Queue!Foo;
	q.put!Foo(7, 13);

	assert(q.front == Foo(7, 13));
}
