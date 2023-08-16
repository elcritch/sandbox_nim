
import std/os

var threads: array[2,Thread[int]]

var
  # create a channel to send/recv strings
  ch: Channel[seq[char]]


proc thread1(val: int) {.thread.} =
  echo "thread1: sending"
  var myBytes: seq[char] = @"Hello world"
  ch.send(move myBytes)
  echo "thread1: sent, left over: ", myBytes


proc thread2(val: int) {.thread.} =
  echo "thread2: wait"
  let msg: seq[char] = ch.recv()
  echo "thread2: received: " & $msg


proc main() =
  echo "running"

  ch.open()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)


when isMainModule:
  main()
