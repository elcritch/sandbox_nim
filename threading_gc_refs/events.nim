
import std/locks
import std/atomics
export locks, atomics

type
  Event* = tuple[cond: Cond, lock: Lock]

proc initEvent*(): Event =
  result.lock.initLock()
  result.cond.initCond()

template signal*(evt: var Event) =
  withLock(evt.lock):
    signal(evt.cond)

template wait*(evt: var Event) =
  withLock(evt.lock):
    wait(evt.cond, evt.lock)

type
  AtomicFreed* = ptr int

proc newFreedValue*(val = 0): ptr int =
  result = cast[ptr int](alloc0(sizeof(int)))
  result[] = val

proc getFreedValue*(x: ptr int): int =
  atomicLoad(x, addr result, ATOMIC_ACQUIRE)

proc incrFreedValue*(x: ptr int): int =
  atomicAddFetch(x, 1, ATOMIC_ACQUIRE)

proc decrFreedValue*(x: ptr int): int =
  atomicSubFetch(x, 1, ATOMIC_ACQUIRE)
