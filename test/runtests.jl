module Test
    
  using Base.Test;
  using Promisables;

  @testset "await macro" begin
    @testset "must wait for a promise to resolve" begin
      p0 = Promise();
      p1 = x -> x + 2;
      p2 = x -> Resolve(x * 2);
      p3 = x -> begin
        x ^ 2;
        return x^2;
      end

      final = foldl((prev, next) -> Then(next, prev), p0, [p1, p2, p3]);

      Timer((t) -> begin
        Fulfill(p0, 0)
        close(t)
      end, 2);

      b = @pawait final;
      @test b == 1;
      @test final.value == 16;
    end
  end

  @testset "A promise" begin
    @testset "when already resolved and given to a then" begin
      @testset "must call with the given function" begin
        p1 = Promise();
        Fulfill(p1, 2);
        handler = (value) -> value + 2;
        p2 = Then(handler, p1);
        @pawait p2;
        @test p2.value === 4;
      end
    end
    @testset "when already rejected and given to a then" begin
      @testset "must call with the given error handler function" begin
        p1 = Promise();
        Reject(p1, ErrorException("foo"));
        handler = (value) -> error("failed"); ## This should not be called
        errHandler = (err) -> Resolve(2);
        p2 = Then(handler, errHandler, p1);
        @pawait p2;
        @test p2.value === 2;
      end
    end
    @testset "must resolve when fullfilled" begin
      chan = Channel{Any}(32) 
      p = Promise(chan);
      Fulfill(p, "foo");
      result = take!(chan);
      @test result == "foo";
      @test typeof(p.status) == Fulfilled;
      @test p.value == "foo";
    end

    @testset "must reject when rejected" begin
      chan = Channel{Any}(32) 
      p = Promise(chan);
      Reject(p, ErrorException("Basic Error"));
      result = take!(chan);
      @test typeof(result) == ErrorException;
      @test typeof(p.status) == Rejected;
      @test p.value == nothing;
    end

    @testset "when resolved with another promise" begin
      @testset "should chain promises" begin
        p1 = Promise();
        p2 = Promise();
        Fulfill(p1, p2);
        @async Fulfill(p2, "a successful value");
        result = take!(p1.channel);
        @test p1.value ==  p2.value;
      end
    end

    @testset "after then is called" begin
      @testset "when fullfilled" begin
        @testset "must call the then's next function" begin
          chan = Channel{Any}(32);
          p = Promise();
          p1 = Then((k) -> put!(chan, k), p);
          Fulfill(p, "foo");
          result = take!(chan);
          @test result == "foo";
          @test typeof(p.status) == Fulfilled;
          @test typeof(p1.status) == Fulfilled;
          @test p.value == "foo";
        end

      end

      @testset "when rejected" begin
        @testset "must call the error handler if one exists with the given error" begin
          chan = Channel{Any}(32);
          tE = () -> error("failed");
          errorH = (err) -> put!(chan, err);
          p = Promise();
          p1 = Then(tE, errorH, p);
          givenError = ErrorException("Blank");
          Reject(p, givenError);
          result = take!(chan);
          @test typeof(p.status) == Rejected;
          @test typeof(p1.status) == Rejected;
          @test result == givenError;
        end
        @testset "if no error handler is present" begin
          @testset "it should not continue" begin
            chan = Channel{Any}(32);
            tE = () -> error("failed");
            p = Promise();
            p1 = Then(tE, p);
            givenError = ErrorException("Blank");
            Reject(p, givenError);
            result = take!(p1.channel);
            @test typeof(p.status) == Rejected;
            @test typeof(p1.status) == Rejected;
            @test result == givenError;
          end
        end
        @testset "error handler" begin
          @testset "when returning a promise" begin
            @testset "should continue with the promise chain" begin
              chan = Channel{Any}(32);
              tE = () -> error("failed"); # Should throw if called
              p = Promise();
              handler = (err) -> Resolve("solved");
              p1 = Then(tE, handler, p);
              givenError = ErrorException("Blank");
              Reject(p, givenError);
              result = take!(p1.channel);
              @test typeof(p.status) == Rejected;
              @test typeof(p1.status) == Fulfilled;
              @test result == "solved";
            end
          end
          @testset "when returning anything else" begin
            @testset "should not continue with the promise chain" begin
              chan = Channel{Any}(32);
              tE = () -> error("failed"); # Should throw if called
              p = Promise();
              handler = (err) -> Reject(ErrorException("Blank"));
              p1 = Then(tE, handler, p);
              givenError = ErrorException("Blank");
              Reject(p, givenError);
              result = take!(p1.channel);
              @test typeof(p.status) == Rejected;
              @test typeof(p1.status) == Rejected;
            end
          end
        end
      end
    end
  end
end
