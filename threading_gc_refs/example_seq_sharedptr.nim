
import std/os
import std/locks
# import threading/smartptrs
import smartptrs_local

import events

var threads: array[2,Thread[int]]

var
  # create a channel to send/recv strings
  shareVal: SharedPtr[int]
  event: Event

proc thread1(val: int) {.thread.} =
  echo "thread1"
  {.cast(gcsafe).}:
    os.sleep(100)
    # var myBytes = newSharedPtr(@"hello")
    var myBytes = newSharedPtr(22)
    echo "thread1: sending: ", myBytes

    shareVal = myBytes
    echo "thread1: sent over: ", myBytes
    echo "thread1: sent, left over: ", repr shareVal
    signal(event)
    # os.sleep(500)

proc thread2(val: int) {.thread.} =
  echo "thread2"
  {.cast(gcsafe).}:
    wait(event)
    echo "thread2: receiving"
    var msg = shareVal
    echo "thread2: received: ", repr msg[]
    # echo "msg: ", msg[].len()
    # os.sleep(100)

proc main() =
  echo "running"

  event = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)


when isMainModule:
  main()
