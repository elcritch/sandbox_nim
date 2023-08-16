
import std/os
import std/locks

import events

var threads: array[2,Thread[int]]

type
  Buffer = object
    data: int

var
  # create a channel to send/recv strings
  shareSeq: ptr Buffer
  event: Event

proc thread1(val: int) {.thread.} =
  echo "thread1: sending"
  {.cast(gcsafe).}:
    os.sleep(100)
    var myBytes: ptr Buffer
    myBytes = cast[ptr Buffer](alloc0(sizeof(Buffer)))
    myBytes.data = 22
    shareSeq = myBytes
    echo "thread1: sent, left over: ", repr myBytes

    signal(event)

    wait(event)
    echo "thread1: free: ", repr myBytes.data

proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  {.cast(gcsafe).}:
    wait(event)
    
    echo "thread2: receiving ", cast[pointer](shareSeq).repr
    let msg = shareSeq
    if msg != nil:
      echo "thread2: received: ", cast[pointer](msg).repr
      echo "thread2: received: ", msg.data
      dealloc(msg)
      echo "thread2: done: ", cast[pointer](msg).repr
    signal(event)

proc main() =
  echo "running"

  event = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)


when isMainModule:
  main()
