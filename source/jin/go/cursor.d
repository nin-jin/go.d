module jin.go.cursor;

import core.atomic;
alias acquire = MemoryOrder.acq;
alias release = MemoryOrder.rel;

import jin.go.mem;

/// Atomic buffer cursor.
align(Line) struct Cursor
{
    /// Offset in buffer.
    align(Line) private shared size_t _offset;

    /// Offset in buffer.
    size_t offset() const
    {
        return this._offset.atomicLoad!acquire;
    }

    /// Offset in buffer. Can't be changed when finalized.
    void offset(size_t next)
    {
        assert(this._finalized == 0, "Change offset of finalized cursor");
        this._offset.atomicStore!release(next);
    }

    /// Finalized cursor shall never change offset.
    align(Line) private shared ptrdiff_t _finalized;

    /// Finalized cursor shall never change offset.
    ptrdiff_t finalized() const
    {
        return this._finalized.atomicLoad!acquire;
    }

    /// Finalize cursor to prevent offset changes.
    void finalize()
    {
        this._finalized.atomicStore!release(ptrdiff_t(-1));
    }
}
