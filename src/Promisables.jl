module Promisables

  export Promise, Then, Pending, Rejected, Fulfilled;

  abstract type Status end;
  type Fulfilled <: Status end;
  type Pending <: Status end;
  type Rejected <: Status end;

  mutable struct Promise 
    status::Status
    channel::Channel{Any}
  end;

  function Fulfill(p::Promise, value::Any)
    if (typeof(value) == Promise)
      Then((x) -> Fulfill(p, x), value);
    else
      put!(p.channel, value);
      p.status = Fulfilled();
    end
  end

  function Reject(p::Promise)
    close(p.channel);
    p.status = Rejected();
  end

  T1 = T where T<:Function

  function Then(f::T1, p::Promise) 
    Then(f, () -> (), p);
  end

  function Then(f::T1, err::Function, p::Promise)
    newChan = Channel{Any}(32) 
    np = Promise(Pending(), newChan);
    @schedule begin
      value = take!(p.channel);
      try 
        result = f(value);
        Fulfill(np, result);
      catch y
        err(y);
        Reject(np); 
      end
    end
    return np;
  end
end
