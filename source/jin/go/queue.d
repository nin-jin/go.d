module jin.go.queue;

import std.container;

import des.ts;

import jin.go.mem;
import jin.go.aligned;
import jin.go.cursor;

/// Wait-free one input one output queue.
/// Buffer fits to one memory page by default.
align(Line) class Queue(Message, size_t Size)
{
	static assert(Size >= 0, "Queue size must be greater then 0");

	// Ring buffer uses one additional element to defferentiate empty and full.
	enum Capacity = Size > 0 ? Size + 1 : (Page - 2 * Line) / Aligned!Message.sizeof - 1;

	static assert(Queue!(int,0).Capacity == 61);
	static assert(Queue!(long,0).Capacity == 61);
	
	pragma(msg,Size);
	pragma(msg,Message.sizeof);
	pragma(msg,Aligned!Message.sizeof);
	pragma(msg,Capacity);

	/// Cursor to next free slot for message.
	align(Line) Cursor provider;

	/// Cursor to next not received message.
	align(Line) Cursor consumer;

	/// Size of buffer 
	align(Line) size_t capacity = Capacity;

	/// Ring buffer of transferring messages.
	align(Line) Aligned!Message[Capacity] messages;

	this(size_t size = 0) {
	}

	/// Maximum count of transferring messages.
	@property size_t size()
	{
		return this.capacity - 1;
	}

	/// Count of provided messages.
	/// Negative value - new messages will never provided.
	ptrdiff_t pending() const
	{
		const len = this.capacity;
		const pending = (len - this.consumer.offset + this.provider.offset) % len;

		if (pending > 0)
		{
			return pending;
		}

		return this.provider.finalized;
	}

	/// Count of messages to fulfill buffer.
	/// Negative value - new messages will never provided.
	ptrdiff_t available() const
	{
		const len = this.capacity;
		const available = (len - this.provider.offset + this.consumer.offset - 1) % len;

		if (available > 0)
		{
			return available;
		}

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
		const len = this.capacity;

		this.messages[offset] = value;

		this.provider.offset = (offset + 1) % len;
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

		const offset = (this.consumer.offset + 1) % this.capacity;
		this.consumer.offset = offset;
	}
}

/// Pending and available.
unittest
{
	auto q = new Queue!(int,3);
	q.pending.assertEq(0);
	q.available.assertEq(3);

	q.put(7);
	q.pending.assertEq(1);
	q.available.assertEq(2);

	q.put(77);
	q.pending.assertEq(2);
	q.available.assertEq(1);

	q.put(777);
	q.pending.assertEq(3);
	q.available.assertEq(0);

	q.front.assertEq(7);
	q.popFront;
	q.pending.assertEq(2);
	q.available.assertEq(1);

	q.front.assertEq(77);
	q.popFront;
	q.pending.assertEq(1);
	q.available.assertEq(2);

	q.front.assertEq(777);
	q.popFront;
	q.pending.assertEq(0);
	q.available.assertEq(3);
}

/// Consume from empty is forbidden.
unittest
{
	import core.exception;

	auto q = new Queue!int(1);
	q.provider.finalize();

	q.front.assertThrown!AssertError;
	q.popFront.assertThrown!AssertError;
}

/// Provide to full is forbidden.
unittest
{
	import core.exception;

	auto q = new Queue!(int,1);
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

	q.front.assertEq(Foo(7, 13));
}
