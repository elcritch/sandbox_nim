
import std/os
import std/locks

import events

var threads: array[2,Thread[int]]

var
  # create a channel to send/recv strings
  shareSeq: seq[char]
  event: Event

proc thread1(val: int) {.thread.} =
  echo "thread1: sending"
  {.cast(gcsafe).}:
    os.sleep(100)
    withLock(event.lock):
      var myBytes: seq[char] = @"Hello"
      shareSeq = move myBytes
      echo "thread1: sent, left over: ", myBytes
      signal(event.cond)

proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  {.cast(gcsafe).}:
    withLock(event.lock):
      wait(event.cond, event.lock)
      echo "thread2: receiving "
      let msg: seq[char] = shareSeq
      echo "thread2: received: " & $msg

proc main() =
  echo "running"

  event = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)


when isMainModule:
  main()
