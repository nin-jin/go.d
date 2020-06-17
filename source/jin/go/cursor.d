module jin.go.cursor;

import core.atomic;

import jin.go.mem;

/// Atomic buffer cursor.
align(Line) struct Cursor
{
    /// Offset in buffer.
    align(Line) private shared size_t _offset;

    /// Offset in buffer.
    size_t offset() const
    {
        return this._offset.atomicLoad!(MemoryOrder.acq);
    }

    /// Offset in buffer. Can't be changed when finalized.
    void offset(size_t next)
    {
        assert(this._finalized == 0, "Change offset of finalized cursor");
        this._offset.atomicStore!(MemoryOrder.rel)(next);
    }

    /// Finalized cursor shall never change offset.
    align(Line) private shared ptrdiff_t _finalized;

    /// Finalized cursor shall never change offset.
    ptrdiff_t finalized() const
    {
        return this._finalized.atomicLoad!(MemoryOrder.acq);
    }

    /// Finalize cursor to prevent offset changes.
    void finalize()
    {
        this._finalized.atomicStore!(MemoryOrder.rel)(ptrdiff_t(-1));
    }
}
