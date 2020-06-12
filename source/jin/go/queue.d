module jin.go.queue;

import core.atomic;

import std.container;
import std.conv;

import des.ts;

/// Bytes in kilobyte.
enum KB = 1024;

/// Memory page size in bytes.
enum page_size = 8 * KB;

/// CPU cacheline size in bytes. 
enum cache_line_size = 64;

/// CPU word size in bytes.
enum word_size = 8;

alias release = MemoryOrder.rel;

/// Wait-free one input one output queue.
align(cache_line_size) class Queue(Message)
{
	/// Info of thread cursor.
	align(cache_line_size) struct Cursor
	{
		/// Offset in buffer.
		align(word_size) size_t offset = 0;

		/// Finalized cursor will never change offset.
		align(word_size) bool finalized = false;
	}

	/// Cursor to next free slot for message.
	align(cache_line_size) shared Cursor provider;

	/// Cursor to next not received message.
	align(cache_line_size) shared Cursor consumer;

	/// Ring buffer of transferring messages.
	align(word_size) Array!Message messages;

	/// Buffer fits to one memory page by default.
	this(size_t size = page_size / Message.sizeof - 1)
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

		return -this.provider.finalized.to!ptrdiff_t;
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

		return -(this.consumer.finalized.to!ptrdiff_t);
	}

	/// Put message without locking.
	/// `available` must be checked before.
	void put(Value)(Value value)
	{
		assert(this.available > 0, "Queue is full");

		const offset = this.provider.offset;
		const len = this.messages.length;

		this.messages[offset] = value;

		atomicStore!release(this.provider.offset, (offset + 1) % len);
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
        return this.pending == -1;
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
		atomicStore!release(this.consumer.offset, offset);
	}
}

/// Automatic fit buffer size to memory page size.
unittest
{
	auto q1 = new Queue!int;
	q1.size.assertEq(2047);

	auto q2 = new Queue!long;
	q2.size.assertEq(1023);
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
	q.provider.finalized = true;

	q.front.assertThrown!AssertError;
	q.popFront.assertThrown!AssertError;
}

/// Provide to full is forbidden.
unittest
{
	import core.exception;

	auto q = new Queue!int(1);
	q.consumer.finalized = true;
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
