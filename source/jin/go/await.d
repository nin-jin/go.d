module jin.go.await;

import core.thread;

/// Yields while condition is `0`.
auto await(Result)(lazy Result check)
{
    for (;;)
    {
        auto value = check;

        if (value != 0)
        {
            return value;
        }

        Thread.yield;
    }
}
