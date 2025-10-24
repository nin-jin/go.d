module jin.go.cursor;

// atomicLoad & atomicStore uses CAS-cycle in DMD now instead of mem bariers:
// https://github.com/dlang/dmd/blob/master/druntime/src/core/internal/atomic.d
// But this is still faster than memoryFence. But GDC uses intrinsics.
import core.atomic;

alias acquire = MemoryOrder.acq; // Load | *
alias release = MemoryOrder.rel; // * | Store

import jin.go.mem;

/// Atomic buffer cursor.
/// Aligned to prevent cores conflict.
/// Two lines (128B) because prefetching.
align(2*Line) struct Cursor
{
    /// Offset in buffer.
    private size_t _offset;

    /// Offset in buffer.
    size_t offset() const
    {
        return this._offset.atomicLoad!acquire;
    }

    /// Offset in buffer. Can't be changed when finalized.
    void offset(size_t next)
    {
        assert(this._finalized == 0, "Change offset of finalized cursor");
        this._offset.atomicStore!release = next;
    }

    /// Finalized cursor shall never change offset.
    private ptrdiff_t _finalized;

    /// Finalized cursor shall never change offset.
    ptrdiff_t finalized() const
    {
        return this._finalized;
    }

    /// Finalize cursor to prevent offset changes.
    void finalize()
    {
        this._finalized = -1;
    }
    
}
