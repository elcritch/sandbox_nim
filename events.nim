
import std/locks
export locks

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
