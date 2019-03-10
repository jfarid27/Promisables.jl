module Promisables

  export Promise, Then;
  export Pending, Rejected, Fulfilled;
  export Resolve, Fulfill, Reject;
  export @pawait;

  abstract type Status end;
  struct Fulfilled <: Status end;
  struct Pending <: Status end;
  struct Rejected <: Status end;
  struct PromisableException <: Exception
    exc::Any
  end;

  pmsg = "An uncaught Promise message has occurred.";

  """
  A blocking macro to wrap wait for a given Promise.
  """
  macro pawait(body)
    return quote
        resultingPromise = $(esc(body));
        c = Channel{Any}(1);
        function fin(v)
          put!(c, 1); 
          return v;
        end
        err = (x) -> throw(PromisableException(x), pmsg);
        Then(fin, err, resultingPromise);
        yield();
        value = take!(c);
        close(c);
        return value;
    end
  end

  mutable struct Promise 
    status::Status
    channel::Channel{Any}
    value::Any
    Promise() = begin
      c = Channel{Any}(1)
      new(Pending(), c, nothing)
    end
    Promise(c::Channel{Any}) = begin
      new(Pending(), c, nothing)
    end
  end;

  function Fulfill(p::Promise, value::Any)
    p.value = value;
    p.status = Fulfilled();
    put!(p.channel, value);
    close(p.channel);
  end

  function Reject(err::Exception)
    p = Promise();
    Reject(p, err);
    return p;
  end

  function Reject(p::Promise, err::Exception)
    p.status = Rejected();
    put!(p.channel, err);
    close(p.channel);
  end

  function Resolve(value)::Promise
    np = Promise();
    Fulfill(np, value);
    return np;
  end

  T1 = T where T<:Function
  T2 = T where T<:Function

  function Then(f::T1, p::Promise)::Promise
    Then(f, (x) -> throw(PromisableException(x), pmsg), p);
  end

  """
  Return a new promise computed from f given the resolved p's
  value.

  The new promise np is returned and a task is scheduled to compute
  when p has a resolution state using f.

  If p
     - Eventually is a rejected Promise with value v:
       Compute err(v)
         If err(v) is
           - A good resolution:
             resolve np with err(v)'s value.
           - A resolution that throws an Exception:
             Reject np with the thrown Exception.
     - Eventually is a resolved Promise with value v:
       Compute f(v)
         If f(v) is
           - A promise:
             Return np that resolves when f(v) resolves.
           - A value:
             Resolve np.
           - Throws an Exception:
             Reject np with the thrown Exception.
  """
  function Then(f::T1, err::T2, p::Promise)::Promise
    newChan = Channel{Any}(1) 
    np = Promise(newChan);
    runable = @task begin 
      value = fetch(p.channel);
      if (typeof(p.status) <: Rejected)
        try
          resolution = err(value);
          return Fullfill(np, resolution);
        catch resolution_error
          return Reject(np, resolution_error);
        end
      end
      try
        resolved = f(value);
        if (typeof(resolved) <: Promise)
          success = (x) -> Fulfill(np, x);
          error = (nerr) -> Reject(np, nerr);
          return Then(success, error, resolved);
        end
        return Fulfill(np, resolved);
      catch cerr
        return Reject(np, cerr);
      end
    end
    schedule(runable);
    yield();
    return np;
  end
end
