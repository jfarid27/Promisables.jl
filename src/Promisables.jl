module Promisables

  export Promise, Then;
  export Pending, Rejected, Fulfilled;
  export Resolve, Fulfill, Reject;
  export @pawait;

  abstract type Status end;
  type Fulfilled <: Status end;
  type Pending <: Status end;
  type Rejected <: Status end;

  macro pawait(body)
    return quote
      resultingPromise = $(esc(body));
      c = Channel{Any}(1)
      fin = (v) -> put!(c, 1);
      Then(fin, fin, resultingPromise);
      take!(c);
    end
  end

  mutable struct Promise 
    status::Status
    channel::Channel{Any}
    value::Any
    Promise() = begin
      c = Channel{Any}(32)
      new(Pending(), c, nothing)
    end
    Promise(c::Channel{Any}) = begin
      new(Pending(), c, nothing)
    end
  end;

  function Fulfill(p::Promise, value::Any)
    if (typeof(value) == Promise)
      success = (x) -> Fulfill(p, x);
      error = (err) -> Reject(p, err);
      return Then(success, error, value);
    else
      p.value = value;
      p.status = Fulfilled();
      put!(p.channel, value);
    end
    return p;
  end

  function Reject(err::Exception)
    p = Promise();
    Reject(p, err);
    return p;
  end

  function Reject(p::Promise, err::Exception)
    put!(p.channel, err);
    p.status = Rejected();
    return p;
  end

  T1 = T where T<:Function
  T2 = T where T<:Function

  function Then(f::T1, p::Promise)::Promise
    Then(f, identity, p);
  end

  function Then(f::T1, err::T2, p::Promise)::Promise
    if (typeof(p.status) == Fulfilled())
      return f(p.value);
    end
    if (typeof(p.status) == Rejected())
      return err(p.value);
    end
    newChan = Channel{Any}(32) 
    np = Promise(newChan);
    @schedule begin
      value = take!(p.channel);
      if (typeof(value) <: Exception)
        value = err(value);
        if (typeof(value) == Promise)
          success = (x) -> Fulfill(np, x);
          error = (nerr) -> Reject(np, nerr);
          Then(success, error, value);
          return;
        end
        Reject(np, value);
        return;
      end
      Fulfill(np, f(value));
    end
    return np;
  end

  function Resolve(value)::Promise
    np = Promise();
    Fulfill(np, value);
    return np;
  end

end

