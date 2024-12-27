module jin.go.channel;

public import jin.go.output;
public import jin.go.input;

/// Common `Queue` collections implementation.
mixin template Channel(Message)
{
    import jin.go.queue;

    alias Self = typeof(this);

    /// Allow transferring between tasks.
    enum __isIsolatedType = true;

    /// Destructor is disabled when `true`.
    bool immortal;

    /// All registered Queues.
    Queue!Message[] queues;

    /// Index of current Queue.
    private size_t current;

    /// O(1) Remove current queue.
    private void currentUnlink()
    {
        if (this.current + 1 < this.queues.length)
        {
            this.queues[this.current] = this.queues.back;
            this.queues.popBack;
            return;
        }

        this.queues.popBack;
        this.current = 0;

    }

    /// Makes new registered `Queue` and returns `Complement` channel.
    /// Maximum count of messages in a buffer can be provided.
    Complement!Message pair()
    {
        auto queue = new Queue!Message;
        this.queues ~= queue;

        Complement!Message complement;
        complement.queues ~= queue;

        return complement;
    }

    @disable this(this);

    this( ref Self source ) {
        this.queues ~= source.queues;
        source.queues.length = 0;
    }
    
    void opOpAssign(string op: "~")(Self source) {
        this.queues ~= source.queues;
        source.queues.length = 0;
    }

}

/// Autofinalize and take all.
unittest
{
    auto ii = Input!int();

    {
        auto oo = ii.pair;

        oo.put(7);
        oo.put(77);
    }

    assert(ii[] == [7, 77]);
}

/// Movement.
unittest
{
    import std.algorithm;

    auto i1 = Input!int();
    auto o1 = i1.pair;

    auto i2 = i1;
    auto o2 = o1;

    o2.put(7);
    o2.put(77);
    o2.destroy();

    assert(i1[] == []);
    assert(i2[] == [7, 77]);
}

/// Batched input
unittest
{
    auto ii = Input!int();

    auto o1 = ii.pair;
    auto o2 = ii.pair;

    o1.put(7);
    o1.put(777);
    o1.destroy();

    o2.put(13);
    o2.put(666);
    o2.destroy();

    assert(ii[] == [7, 777, 13, 666]);
}

/// Round robin output
unittest
{
    auto oo = Output!int();

    auto i1 = oo.pair;
    auto i2 = oo.pair;

    oo.put(7);
    oo.put(13);
    oo.put(777);
    oo.put(666);
    oo.destroy();

    assert(i1[] == [7, 777]);
    assert(i2[] == [13, 666]);
}
