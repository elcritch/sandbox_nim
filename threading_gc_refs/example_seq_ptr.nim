
import std/os
import std/locks
import std/atomics

import events

type
  Buffer*[T: SomeInteger | char] = object
    cnt: ptr int
    buf: ptr UncheckedArray[T]
    size: int

var threads: array[2,Thread[int]]

#[
proc doTaskPool()
  doCompute(blkPtr[]) # --> thread b

proc handleRequest*() {.async.} =
  doSetup()
  let blk: Block

  let blkPtr = addr blk
  await sendTaskPool(blkPtr)

  return success Ok
]#

proc `$`*[T](data: Buffer[T]): string =
  if data.buf.isNil:
    result = "nil"
  else:
    result = newString(data.size + 2)
    copyMem(addr result[1], data.buf, data.size)
    result[0] = '<'
    result[^1] = '>'

proc `=destroy`*[T](x: var Buffer[T]) =
  if x.buf != nil and x.cnt != nil:
    let res = atomicSubFetch(x.cnt, 1, ATOMIC_ACQUIRE)
    if res == 0:
      # for i in 0..<x.len: `=destroy`(x.data[i])
      echo "buffer: Free: ", repr x.buf.pointer, " ", x.cnt[]
      deallocShared(x.buf)
      deallocShared(x.cnt)
    else:
      echo "buffer: decr: ", repr x.buf.pointer, " ", x.cnt[]

proc `=copy`*[T](a: var Buffer[T]; b: Buffer[T]) =
  # do nothing for self-assignments:
  if a.buf == b.buf: return
  `=destroy`(a)
  discard atomicAddFetch(b.cnt, 1, ATOMIC_RELAXED)
  a.size = b.size
  a.buf = b.buf
  a.cnt = b.cnt
  echo "buffer: Copy: repr: ", b.cnt[],
          " ", repr a.buf.pointer, 
          " ", repr b.buf.pointer

proc `incr`*[T](a: Buffer[T]) =
  echo "buffer: incr: ", atomicAddFetch(a.cnt, 1, ATOMIC_RELAXED)

proc newBuffer*[T](data: openArray[T]): Buffer[T] =
  echo "ALLOCATE!"
  result.cnt = cast[ptr int](allocShared0(sizeof(result.cnt)))
  result.buf = cast[typeof result.buf](allocShared0(data.len))
  result.cnt[] = 1
  result.size = data.len
  copyMem(result.buf, unsafeAddr data[0], data.len)

var
  # create a channel to send/recv strings
  shareVal: Buffer[char]
  event: Event

proc thread1(val: int) {.thread.} =
  echo "thread1"
  {.cast(gcsafe).}:
    os.sleep(100)
    var myBytes2: Buffer[char]
    var myBytes = newBuffer(@"hello")
    myBytes2 = myBytes

    echo "thread1: sending: ", myBytes
    echo "mybytes2: ", myBytes2

    shareVal = myBytes
    echo "thread1: sent, left over: ", $myBytes
    signal(event)
    os.sleep(100)

proc thread2(val: int) {.thread.} =
  echo "thread2"
  {.cast(gcsafe).}:
    wait(event)
    echo "thread2: receiving "
    let msg: Buffer[char] = shareVal
    echo "thread2: received: ", msg
    # os.sleep(100)

proc main() =
  echo "running"

  event = initEvent()
  createThread(threads[0], thread1, 0)
  createThread(threads[1], thread2, 1)

  joinThreads(threads)


when isMainModule:
  main()
