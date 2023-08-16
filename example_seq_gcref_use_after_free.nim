
import std/os
import std/locks

import events

var threads: array[2,Thread[int]]

type
  Buffer = object
    data: int

var
  # create a channel to send/recv strings
  shareData: ref Buffer
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
    shareData = myBytes
    echo "thread1: sent, left over: ", repr myBytes
    signal(event)
    wait(event)
    myBytes = nil
    echo "thread1: finishing: ", cast[pointer](myBytes).repr

    GC_fullCollect()
    signal(eventAfterGcFree)
    os.sleep(100)

proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  {.cast(gcsafe).}:
    wait(event)
    
    echo "thread2: receiving ", cast[pointer](shareData).repr
    var msg = shareData
    shareData = nil
    echo "thread2: shared moved: ", cast[pointer](shareData).repr
    if msg != nil:
      echo "thread2: received: ", repr msg
    signal(event)
    wait(eventAfterGcFree)
    echo "thread2: wait check: ", repr msg
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
