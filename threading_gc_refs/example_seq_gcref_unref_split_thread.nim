
import std/os
import std/locks
import std/atomics

import events

var threads: array[2,Thread[int]]

type
  Buffer = object
    data: int

var
  shareDataIsFreed: AtomicFreed
  shareData: ref Buffer
  event: Event
  eventAfterGcFree: Event

proc getFreedValue*(x: ptr int): int =
  atomicLoad(x, addr result, ATOMIC_ACQUIRE)

proc `=destroy`*(x: var Buffer) =
  echo "Buffer: destroy: ", cast[pointer](addr(x)).repr

proc thread1(val: int) {.thread.} =
  echo "thread1: sending"
  {.cast(gcsafe).}:
    os.sleep(100)

    var myBytes: ref Buffer
    myBytes.new:
      proc (x: ref Buffer) =
        echo "thread1: FREEING: ", cast[pointer](x).repr
        discard shareDataIsFreed.incrFreedValue()
    myBytes.data = 10

    shareData = myBytes
    GC_ref(shareData)
    echo "thread1: sent, left over: ", repr myBytes
    signal(event)

    wait(event)
    myBytes = nil
    echo "thread1: post send: ", cast[pointer](myBytes).repr

    GC_fullCollect()
    signal(eventAfterGcFree)

    wait(eventAfterGcFree)
    echo "thread1: gc_unref and gc_collect"

    GC_fullCollect()
    os.sleep(100)
    echo "thread1: finish"
    assert getFreedValue(shareDataIsFreed) == 1, "shareData should be freed by now"
    echo "thread1: done"

proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  {.cast(gcsafe).}:
    wait(event)
    
    echo "thread2: receiving ", cast[pointer](shareData).repr
    var msg = shareData
    echo "thread2: received: ", repr msg, "; shareData: ", cast[pointer](shareData).repr

    echo "thread2: deref: "

    signal(event)
    wait(eventAfterGcFree)
    echo "thread2: after gc_collect: ", repr msg
    assert getFreedValue(shareDataIsFreed) == 0

    GC_unref(shareData)
    shareData = nil
    msg = nil
    signal(eventAfterGcFree)
    echo "thread2: done"

proc main() =
  echo "running"

  event = initEvent()
  eventAfterGcFree = initEvent()
  shareDataIsFreed = newFreedValue(0)
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)
  os.sleep(100)


when isMainModule:
  main()
