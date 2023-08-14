
import std/locks
export locks

type
  Event* = tuple[cond: Cond, lock: Lock]

proc initEvent*(): Event =
  result.lock.initLock()
  result.cond.initCond()

template trigger*(evt: var Event, blk: untyped) =
  withLock(evt.lock):
    `blk`
    signal(evt.cond)

template wait*(evt: var Event, blk: untyped) =
  withLock(evt.lock):
    wait(evt.cond, evt.lock)
    `blk`
