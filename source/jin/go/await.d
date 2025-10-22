module jin.go.await;

import photon;

/// Yields while condition is `0`.
auto await(Result)(lazy Result check) {
    for (;;) {
        auto value = check;

        if (value)
            return value;
            
        enforce( Task.getThis(), "Await out of Task" );

        yield;
    }
}
