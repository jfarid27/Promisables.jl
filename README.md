# Promisables

[![Build Status](https://travis-ci.org/jfarid27/Promisables.jl.svg?branch=master)](https://travis-ci.org/jfarid27/Promisables.jl)

[![Coverage Status](https://coveralls.io/repos/jfarid27/Promisables.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/jfarid27/Promisables.jl?branch=master)

[![codecov.io](http://codecov.io/github/jfarid27/Promisables.jl/coverage.svg?branch=master)](http://codecov.io/github/jfarid27/Promisables.jl?branch=master)

This package implements a promise interface in Julia. For programmers not accustomed to web programming, Promises are
useful when dealing with asynchronous computation, enforcing a common pattern as well as guaranteed serializability. Many
programs must utilize some form asynchronous computation, whether it be IO or long running computations, but in many cases,
asynchronous computation does not need to block. By utilizing Promises, one can build programs that are non-blocking, removing
programmers from needing to manually control scheduling to do available work while other tasks operate.

## Types

### Then

```julia
  T1 = T where T<:Function
  T2 = T where T<:Function
  function Then(f::T1, err::T2, p::Promise)::Promise
  function Then(f::T1, p::Promise)::Promise
```

##### Resolved promises call f
Takes a function ```f``` that takes a resolved value, and a promise ```p```. When p 
is resolved, ```f``` is called with the resolved value. ```Then``` returns a new promise (call this ```afterPromise```).
to allow for Promise chaining. The resolution value of ```f```'s returned promise is resolved to ```afterPromise```.

##### Rejected promises call err
If p is rejected, ```err``` is called if it exists, where if it returns  a new promise that is resolved, the value will be resolved to ```afterPromise```.
This allows for a failure on p to be handled by err. If the promise is not resolved, ```afterPromise``` is rejected.

### @pawait

##### ```pawait``` macro to block when you really need to 

If one doesn't block on promises, the program will end before the promises are resolved.
For example, it's quite easy for a scheduler to exit the program before
a network request completes.
One needs a way to wait for a promise chain to complete, and keep the program running. @pawait is how one does it.
Simply call
```julia
@pawait myPromise
```
to block until the promise is complete.

### Fulfill, Reject (on Promises)


```julia
  function Reject(p::Promise, err::Exception)
  function Fulfill(p::Promise, value::Any)
```

After building promise chains, one needs to start resolving or rejecting. These actions
do this. Note these act on the promises they are given, and are not
intended to be used in promise chaining (don't expect the return values to be promises).

Also note, you can, like in life, resolve a promise with another promise...

```julia
  function Fulfill(p::Promise, value::Promise)
```

but **I advise against this**. This waits for the given ```value```
promise to resolve, then resolves ```p``` with the given value.

### Resolve, Reject (on values)

```julia
  function Reject(err::Exception)::Promise
  function Resolve(value::Any)::Primise
```

Sometimes you need to just return a basic promise with a value in it
that's already resolved or rejected. These functions do this. Note
these return actual Promises, representing a simple way to take
values and wrap them in Promises.

## Examples

See the [tests](https://github.com/jfarid27/Promisables.jl/blob/master/test/runtests.jl) for a few examples. Along with this, I have added an implementation in [Monads](https://github.com/pao/Monads.jl) for a cleaner syntax.
