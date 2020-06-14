module jin.go.channel;

import des.ts;

public import jin.go.output;
public import jin.go.input;

/// Common `Queue` collections implementation.
mixin template Channel(Message)
{

    import std.algorithm;
    import std.container;

    import jin.go.queue;

    alias Self = typeof(this);

    /// Allow transferring between tasks
    static __isIsolatedType = true;

    /// All registered Queues.
    Array!(Queue!Message) queues;

    /// Index of current Queue.
    private size_t current;

    /// Makes new registered `Queue` and returns `Complement` channel.
    /// Maximum count of messages in a buffer can be provided.
    Complement!Message pair(Args...)(Args args)
    {
        auto queue = new Queue!Message(args);
        this.queues ~= queue;

        Complement!Message complement;
        complement.queues ~= queue;

        return complement;
    }

    /// Moves queues to movable channel of same type.
    Self move()
    {
        auto movable = Self();
        this.move(movable);
        return movable;
    }

    /// Moves queues to another channel.
    void move(ref Self target)
    {
        target.queues = this.queues.move;
        target.current = this.current.move;
    }

    /// Prevent copy, only move.
    @disable this(this);
}

/// Autofinalize and take all.
unittest
{
    auto ii = Input!int();

    {
        auto oo = ii.pair(5);

        oo.put(7);
        oo.put(77);
    }

    ii[].assertEq([7, 77]);
}

/// Movement.
unittest
{
    import std.algorithm;

    auto i1 = Input!int();
    auto o1 = i1.pair(5);

    auto i2 = i1.move;
    auto o2 = o1.move;

    o2.put(7);
    o2.put(77);
    o2.destroy();

    i1[].assertEq([]);
    i2[].assertEq([7, 77]);
}

/// Round robin input
unittest
{
    auto ii = Input!int();

    auto o1 = ii.pair(5);
    auto o2 = ii.pair(5);

    o1.put(7);
    o1.put(777);
    o1.destroy();

    o2.put(13);
    o2.put(666);
    o2.destroy();

    ii[].assertEq([7, 13, 777, 666]);
}

/// Round robin output
unittest
{
    auto oo = Output!int();

    auto i1 = oo.pair(5);
    auto i2 = oo.pair(5);

    oo.put(7);
    oo.put(13);
    oo.put(777);
    oo.put(666);
    oo.destroy();

    i1[].assertEq([7, 777]);
    i2[].assertEq([13, 666]);
}
