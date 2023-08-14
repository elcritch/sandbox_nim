
import std/os
import std/locks
import threading/smartptrs

import events

var threads: array[2,Thread[int]]

var
  # create a channel to send/recv strings
  shareVal: SharedPtr[seq[char]]
  event: Event

proc thread1(val: int) {.thread.} =
  echo "thread1"
  {.cast(gcsafe).}:
    os.sleep(100)
    withLock(event.lock):
      var myBytes = newSharedPtr(@"hello")
      echo "thread1: sending: ", myBytes

      shareVal = myBytes
      echo "thread1: sent over: ", myBytes
      echo "thread1: sent, left over: ", repr shareVal
      signal(event.cond)
      os.sleep(1000)

proc thread2(val: int) {.thread.} =
  echo "thread2"
  {.cast(gcsafe).}:
    withLock(event.lock):
      wait(event.cond, event.lock)
      echo "thread2: receiving "
      let msg = shareVal
      echo "thread2: received: ", repr msg

proc main() =
  echo "running"

  event = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)


when isMainModule:
  main()
