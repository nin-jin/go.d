module jin.go.queue;

import std.container;
import std.exception;
import std.conv;

import jin.go.mem;
import jin.go.cursor;

/// Wait-free one input one output queue.
class Queue(
	Message,
	size_t Length = ( Page - __traits(classInstanceSize,Queue!( Message, 0 )) ) / Message.sizeof
)
{
	/// Cursor to next free slot for message.
	Cursor provider;

	/// Cursor to next not received message.
	Cursor consumer;

	/// Ring buffer of transferring messages.
	Message[Length] messages;

	/// Maximum count of transferring messages.
	@property size_t size()
	{
		return Length - 1;
	}

	/// Count of provided messages.
	/// Negative value - new messages will never provided.
	ptrdiff_t pending() const
	{
		const pending = (Length - this.consumer.offset + this.provider.offset) % Length;

		if (pending > 0)
			return pending;

		return this.provider.finalized;
	}

	/// Count of messages to fulfill buffer.
	/// Negative value - new messages will never provided.
	ptrdiff_t available() const
	{
		const available = (Length - this.provider.offset + this.consumer.offset - 1) % Length;

		if (available > 0)
			return available;

		return this.consumer.finalized;
	}

	/// True when no more messages can never be provided.
	bool ignore()
	{
		return this.available < 0;
	}

	/// Put message without locking.
	/// `available` must be checked before.
	void put(Value)(Value value)
	{
		assert(this.available > 0, "Queue is full");

		const offset = this.provider.offset;

		this.messages[offset] = value;

		this.provider.offset = (offset + 1) % Length;
	}

	/// Create and put message.
	/// `available` must be checked before.
	void put(Value, Args...)(Args args)
	{
		this.put(Value(args));
	}

	/// True when no more messages can never be consumed.
	auto empty()
	{
		return this.pending < 0;
	}

	/// Get current pending message.
	/// `pending` must be checked before.
	Message front()
	{
		assert(this.pending > 0, "Queue is empty");

		return this.messages[this.consumer.offset];
	}

	/// Consume current pending message.
	/// `pending` must be checked before.
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
	assert(q1.size == 975);

	auto q2 = new Queue!long;
	assert(q2.size == 487);
}

/// Pending and available.
unittest
{
	auto q = new Queue!(int,4);
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
	q.provider.finalize();

	q.front.assertThrown!AssertError;
	q.popFront.assertThrown!AssertError;
}

/// Provide to full is forbidden.
unittest
{
	import core.exception;

	auto q = new Queue!(int,2);
	q.consumer.finalize();
	q.put(7);

	q.put(77).assertThrown!AssertError;
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
