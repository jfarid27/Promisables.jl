module Promisables

  export Promise, Then, Pending,
  Rejected, Fulfilled, Resolve;

  abstract type Status end;
  type Fulfilled <: Status end;
  type Pending <: Status end;
  type Rejected <: Status end;

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
      success = (x) -> Fullfill(p, x);
      error = (err) -> Reject(p, err);
      Then(success, error, value);
    else
      p.value = value;
      p.status = Fulfilled();
      put!(p.channel, value);
    end
  end

  function Reject(p::Promise, err::Exception)
    put!(p.channel, err);
    p.status = Rejected();
  end

  T1 = T where T<:Function
  T2 = T where T<:Function

  function Then(f::T1, p::Promise)::Promise
    Then(f, identity, p);
  end

  function Then(f::T1, err::T2, p::Promise)::Promise
    newChan = Channel{Any}(32) 
    np = Promise(newChan);
    @schedule begin
      value = take!(p.channel);
      if (typeof(value) <: Exception)
        value = err(value);
        if (typeof(value) == Promise)
          success = (x) -> Fullfill(np, x);
          error = (nerr) -> Reject(np, nerr);
          Then(success, error, value);
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
    @async Fulfill(np, value);
    return np;
  end
end
