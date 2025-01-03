module jin.go.input;

import jin.go.channel;
import jin.go.output;
import jin.go.await;

import std.range;

/// Round robin input channel.
/// Implements InputRange.
struct Input(Message)
{
    alias Pair = Output;

    mixin Channel!Message;

    /// Minimum count of pending messages.
    /// Negative value - new messages will never provided.
    ptrdiff_t pending()
    {
        ptrdiff_t pending = -1;
        if (this.queues.length == 0)
            return pending;

        foreach (i; this.queues.length.iota)
        {
            const queue = this.queues[this.current];

            auto pending2 = queue.pending;
            if (pending2 > 0)
            {
                return pending2;
            }

            if (pending2 < 0)
            {
                this.currentUnlink();
                continue;
            }

            pending = 0;
            this.current = (this.current + 1) % this.queues.length;

        }

        return pending;
    }

    /// True when no more messages will be consumed.
    bool empty()
    {
        return this.pending == -1;
    }

    /// Get message from current non empty Queue or wait.
    /// `pending` must be checked before.
    Message front()
    {
        const pending = this.pending.await;
        assert(pending != -1, "Message will never be provided");

        return this.queues[this.current].front;
    }

    /// Consume current pending message and switch to another Queue.
    /// `pending` must be checked before.
    void popFront()
    {
        assert(this.pending > 0, "Channel is empty");

        const current = this.current;
        this.queues[current].popFront;
        this.current = (current + 1) % this.queues.length;
    }

    /// Consumes current message;
    Message next()
    {
        auto value = this.front;
        this.popFront;
        return value;
    }

    /// Iterates over all messages.
    /// Example: `foreach(msg : chan) {...}`
    int opApply(int delegate(Message) proceed)
    {
        for (;;)
        {
            const pending = this.pending.await;
            if (pending == -1)
                return 0;

            auto queue = this.queues[this.current];
            foreach (i; pending.iota)
            {
                auto result = proceed(queue.front);
                queue.popFront;

                if (result)
                    return result;
            }

        }
    }

    /// Collects all messages to array.
    /// Example: `chan[]`
    Message[] opSlice()
    {
        Message[] list;
        foreach (msg; this)
            list ~= msg;
        return list;
    }

    /// Fix all cursors on destroy.
    ~this()
    {
        if (this.immortal)
            return;

        foreach (queue; this.queues)
            queue.consumer.finalize();
    }

}
