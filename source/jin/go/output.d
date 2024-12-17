module jin.go.output;

import jin.go.channel;
import jin.go.input;
import jin.go.await;

import std.range;

/// Round robin output channel.
/// Implements OutputRange.
struct Output(Message)
{
    alias Complement = Input;

    mixin Channel!Message;

    /// Count of messages that can be privided now.
    /// Negative value - new messages will never provided.
    ptrdiff_t available()
    {
        ptrdiff_t available = -1;

        if (this.queues.length == 0)
            return available;

        foreach (i; this.queues.length.iota)
        {
            const queue = this.queues[this.current];

            const available2 = queue.available;
            if (available2 > 0)
            {
                return available2;
            }

            // skip full queue
            if (available2 < 0)
            {
                this.currentUnlink();
                continue;
            }

            available = 0;
            this.current = (this.current + 1) % this.queues.length;

        }

        return available;
    }

    /// True when no more messages will be consumed.
    bool ignore()
    {
        return this.available == -1;
    }

    /// Put message to current non full Queue and switch Queue
    /// `available` must be checked before.
    void put(Value)(Value value)
    {
        const available = this.available.await;
        assert(available != -1, "Message will never consumed");

        const current = this.current;
        this.queues[current].put(value);
        this.current = (current + 1) % this.queues.length;
    }

    /// Create and put message.
    /// `available` must be checked before.
    void put(Value, Args...)(Args args)
    {
        this.put(Value(args));
    }

    /// Finalizes all cursors on destroy.
    ~this()
    {
        foreach (queue; this.queues)
        {
            queue.provider.finalize();
        }
    }

}
