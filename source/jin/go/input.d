module jin.go.input;

import jin.go.channel;
import jin.go.output;
import jin.go.await;

/// Round robin input channel.
/// Implements InputRange.
struct Input(Message)
{
    alias Complement = Output;

    mixin Channel!Message;

    /// Minimum count of pending messages.
	/// Negative value - new messages will never provided.
    ptrdiff_t pending()
    {
        ptrdiff_t pending = -1;
        const ways = this.queues.length;

        if (ways == 0)
        {
            return pending;
        }

        const start = this.current;
        do
        {
            const queue = this.queues[this.current];

            auto pending2 = queue.pending;
            if (pending2 > 0)
            {
                return pending2;
            }

            if (pending2 == 0)
            {
                pending = 0;
            }

            this.current = (this.current + 1) % ways;
        }
        while (this.current != start);

        return pending;
    }

    /// True when no more messages will be consumed.
    bool empty()
    {
        return this.pending == -1;
    }

    /// Get message fromm current non clear Queue or wait.
    /// `pending` must be checked before.
    Message front()
    {
        const pending = this.pending.await;
        assert(pending != -1, "Message will never provided");

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

    /// Iterates over all messages.
    /// Example: `foreach(msg : chan) {...}`
    int opApply(int delegate(Message) proceed)
    {
        for (;;)
        {
            const pending = this.pending.await;
            if (pending == -1)
                return 0;

            auto result = proceed(this.front);
            this.popFront();

            if (result)
            {
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
        foreach (queue; this.queues)
        {
            queue.consumer.finalized = true;
        }
    }

}
