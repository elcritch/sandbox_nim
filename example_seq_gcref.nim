
import std/os
import std/locks
import std/atomics

import events

var threads: array[2,Thread[int]]

type
  Buffer = object
    data: int

  TestScenario* = enum
    GCRefThread1
    GCRefThread2

var
  scenario = GCRefThread1

var
  # create a channel to send/recv strings
  shareSeq: ref Buffer
  event: Event
  eventAfterGcFree: Event

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
    myBytes.data = 10
    if scenario == GCRefThread1:
      GC_ref(myBytes)
    shareSeq = myBytes
    echo "thread1: sent, left over: ", repr myBytes
    signal(event)
    wait(event)
    myBytes = nil
    echo "thread1: post send: ", cast[pointer](myBytes).repr

    GC_fullCollect()
    signal(eventAfterGcFree)
    os.sleep(100)

proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  {.cast(gcsafe).}:
    wait(event)
    
    echo "thread2: receiving ", cast[pointer](shareSeq).repr
    var msg = move shareSeq
    if scenario == GCRefThread2:
      GC_ref(msg)
    echo "thread2: received: ", repr msg

    echo "thread2: deref: "
    # msg = nil
    GC_unref(msg)

    signal(event)
    wait(eventAfterGcFree)
    echo "thread2: after gc_collect: ", repr msg
    echo "thread2: done: "

proc main() =
  echo "running"

  event = initEvent()
  eventAfterGcFree = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)
  os.sleep(100)


when isMainModule:
  main()
