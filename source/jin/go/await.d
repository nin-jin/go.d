module jin.go.await;

import vibe.core.core;

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
        
        yield;
    }
}
