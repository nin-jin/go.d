module jin.go.queue;

import std.container;

import des.ts;

import jin.go.mem;
import jin.go.cursor;

/// Wait-free one input one output queue.
align(Line) class Queue(Message)
{
	/// Cursor to next free slot for message.
	align(Line) Cursor provider;

	/// Cursor to next not received message.
	align(Line) Cursor consumer;

	/// Ring buffer of transferring messages.
	align(Line) Array!Message messages;

	/// Buffer fits to one memory page by default.
	this(size_t size = Page / Message.sizeof - 1)
	{
		enforce(size > 0, "Queue size must be greater then 0");

		// Ring buffer uses one additional element to defferentiate empty and full.
		this.messages.length = size + 1;
	}

	/// Maximum count of transferring messages.
	@property size_t size()
	{
		return this.messages.length - 1;
	}

	/// Count of provided messages.
	/// Negative value - new messages will never provided.
	ptrdiff_t pending() const
	{
		const len = this.messages.length;
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
		const len = this.messages.length;
		const available = (len - this.provider.offset + this.consumer.offset - 1) % len;

		if (available > 0)
		{
			return available;
		}

		return this.consumer.finalized;
	}

	/// True when no more messages will be consumed.
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
		const len = this.messages.length;

		this.messages[offset] = value;

		this.provider.offset = (offset + 1) % len;
	}

	/// Create and put message.
	/// `available` must be checked before.
	void put(Value, Args...)(Args args)
	{
		this.put(Value(args));
	}

	/// True when no more messages will be consumed.
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

		const offset = (this.consumer.offset + 1) % this.messages.length;
		this.consumer.offset = offset;
	}
}

/// Automatic fit buffer size to memory page size.
unittest
{
	auto q1 = new Queue!int;
	q1.size.assertEq(1023);

	auto q2 = new Queue!long;
	q2.size.assertEq(511);
}

/// Pending and available.
unittest
{
	auto q = new Queue!int(3);
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

	auto q = new Queue!int(1);
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
