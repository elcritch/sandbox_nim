
#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## C++11 like smart pointers. They always use the shared allocator.
import std/isolation
import threading/atomics
from typetraits import supportsCopyMem

proc raiseNilAccess() {.noinline.} =
  raise newException(NilAccessDefect, "dereferencing nil smart pointer")

template checkNotNil(p: typed) =
  when compileOption("boundChecks"):
    {.line.}:
      if p.isNil:
        raiseNilAccess()

#------------------------------------------------------------------------------

type
  SharedPtr*[T] = object
    ## Shared ownership reference counting pointer.
    val: ptr tuple[value: T, counter: Atomic[int]]

template cntStr(p): string =
  if p.val == nil: "" else: $load(p.val.counter, Acquire)

proc `=destroy`*[T](p: var SharedPtr[T]) =
  echo "smartptr: destroy: ", p.val.pointer.repr, " ", cntStr(p)
  if p.val != nil:
    if fetchSub(p.val.counter, 1, Acquire) == 0:
      echo "smartptr: destroy: free"
      `=destroy`(p.val.value)
      deallocShared(p.val)

proc `=dup`*[T](src: SharedPtr[T]): SharedPtr[T] =
  if src.val != nil:
    discard fetchAdd(src.val.counter, 1, Relaxed)
  result.val = src.val
  echo "dup: ", src.val.pointer.repr, cntStr(src)

proc `=copy`*[T](dest: var SharedPtr[T], src: SharedPtr[T]) =
  if src.val != nil:
    discard fetchAdd(src.val.counter, 1, Relaxed)
  `=destroy`(dest)
  dest.val = src.val
  echo "copy: ", src.val.pointer.repr, " ", cntStr(src)

proc newSharedPtr*[T](val: sink Isolated[T]): SharedPtr[T] {.nodestroy.} =
  ## Returns a shared pointer which shares
  ## ownership of the object by reference counting.
  result.val = cast[typeof(result.val)](allocShared(sizeof(result.val[])))
  int(result.val.counter) = 0
  result.val.value = extract val

template newSharedPtr*[T](val: T): SharedPtr[T] =
  newSharedPtr(isolate(val))

proc newSharedPtr*[T](t: typedesc[T]): SharedPtr[T] =
  ## Returns a shared pointer. It is not initialized,
  ## so reading from it before writing to it is undefined behaviour!
  when not supportsCopyMem(T):
    result.val = cast[typeof(result.val)](allocShared0(sizeof(result.val[])))
  else:
    result.val = cast[typeof(result.val)](allocShared(sizeof(result.val[])))
  int(result.val.counter) = 0

proc isNil*[T](p: SharedPtr[T]): bool {.inline.} =
  p.val == nil

proc `[]`*[T](p: SharedPtr[T]): var T {.inline.} =
  checkNotNil(p)
  p.val.value

template `[]=`*[T](p: SharedPtr[T]; val: T) =
  `[]=`(p, val)

proc `$`*[T](p: SharedPtr[T]): string {.inline.} =
  echo "dollar"
  if p.val == nil: "nil"
  else: "(val: " & $p.val.value & ")"
