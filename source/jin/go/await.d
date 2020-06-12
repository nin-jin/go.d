module jin.go.await;

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
        
        //Fiber.yield;
    }
}
