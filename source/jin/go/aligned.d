module jin.go.aligned;

import jin.go.mem;

/// Wrapper that aligns to cache line size.
align(Line) struct Aligned(Value) {
	Value value;
	alias value this;
}
