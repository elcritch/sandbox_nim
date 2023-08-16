
import std/os
import std/locks

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


when defined(gcArc) or defined(gcOrc):
  {.error: "this example only blows up with refc".}

var threads: array[2,Thread[int]]

type
  Buffer = object
    data: int

var
  shared: ptr Buffer
  event: Event

proc thread1(val: int) {.thread.} =
  echo "thread1: sending"
  {.cast(gcsafe).}:
    os.sleep(100)
    var myBytes: ptr Buffer
    myBytes = cast[ptr Buffer](alloc0(sizeof(Buffer)))
    myBytes.data = 22
    shared = myBytes
    echo "thread1: sent, left over: ", repr myBytes

    signal(event)
    echo "thread1: wait"

    wait(event)
    echo "thread1: free: ", repr myBytes.data

proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  {.cast(gcsafe).}:

    wait(event)
    echo "thread2: receiving: ", cast[pointer](shared).repr
    let msg = shared
    echo "thread2: received: ", cast[pointer](msg).repr

    if msg != nil:
      echo "thread2: received: ", msg.data
      dealloc(msg)

    signal(event)
    echo "thread2: done: ", cast[pointer](msg).repr

proc main() =
  echo "running"
  event = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)
  joinThreads(threads)

main()
