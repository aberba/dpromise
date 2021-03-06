module dpromise.async;

import dpromise.promise;

import core.thread : Fiber;
import std.concurrency : Generator, yield;
import std.traits;

Promise!T async(T)(T delegate() dg) nothrow if(!is(Unqual!T : Exception) && !is(Unqual!T : Promise!K, K))
in {
  assert(dg !is null);
}body { return promise!T((res, rej) {
  static if(!is(T == void)) T value;

  auto gen = new Generator!Awaiter({
    static if(!is(T == void)) {
      value = dg();
    }else {
      dg();
    }
  });

  void inner() {
    if(gen.empty) {
      static if(!is(T == void)) {
        res(value);
      }else {
        res();
      }
    }else {
      gen.front.then(() {
        gen.popFront;
        inner();
      }, (e){
        rej(e);
      });
    }
  }
  inner();
});}


T await(T)(Promise!T promise)
in {
  bool inAsyncFunction() {
    return (cast(Generator!Awaiter)Fiber.getThis) !is null;
  }
  assert(inAsyncFunction);
}body {

  yield(cast(Awaiter)promise);

  if(promise.isFulfilled) {
    static if(!is(T == void)) return promise.value;
  }else if(promise.isRejected) {
    throw promise.exception;
  }else {
    assert(0);
  }
}
