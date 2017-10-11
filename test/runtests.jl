module Test

  include("./../src/Promisables.jl");
    
  using Base.Test

  @testset "A promise" begin
    @testset "must resolve when fullfilled" begin
      chan = Channel{Any}(32) 
      p = Promisables.Promise(chan);
      Promisables.Fulfill(p, "foo");
      result = take!(chan);
      @test result == "foo";
      @test typeof(p.status) == Promisables.Fulfilled;
      @test p.value == "foo";
    end

    @testset "must reject when rejected" begin
      chan = Channel{Any}(32) 
      p = Promisables.Promise(chan);
      Promisables.Reject(p, ErrorException("Basic Error"));
      result = take!(chan);
      @test typeof(result) == ErrorException;
      @test typeof(p.status) == Promisables.Rejected;
      @test p.value == nothing;
    end

    @testset "when resolved with another promise" begin
      @testset "should chain promises" begin
        p1 = Promisables.Promise();
        p2 = Promisables.Promise();
        Promisables.Fulfill(p1, p2);
        @async Promisables.Fulfill(p2, "a successful value");
        result = take!(p1.channel);
        @test p1.value ==  p2.value;
      end
    end

    @testset "after then is called" begin
      @testset "when fullfilled" begin
        @testset "must call the then's next function" begin
          chan = Channel{Any}(32);
          p = Promisables.Promise();
          p1 = Promisables.Then((k) -> put!(chan, k), p);
          Promisables.Fulfill(p, "foo");
          result = take!(chan);
          @test result == "foo";
          @test typeof(p.status) == Promisables.Fulfilled;
          @test typeof(p1.status) == Promisables.Fulfilled;
          @test p.value == "foo";
        end

      end

      @testset "when rejected" begin
        @testset "must call the error handler if one exists with the given error" begin
          chan = Channel{Any}(32);
          tE = () -> error("failed");
          errorH = (err) -> put!(chan, err);
          p = Promisables.Promise();
          p1 = Promisables.Then(tE, errorH, p);
          givenError = ErrorException("Blank");
          Promisables.Reject(p, givenError);
          result = take!(chan);
          @test typeof(p.status) == Promisables.Rejected;
          @test typeof(p1.status) == Promisables.Rejected;
          @test result == givenError;
        end
        @testset "if no error handler is present" begin
          @testset "it should not continue" begin
            chan = Channel{Any}(32);
            tE = () -> error("failed");
            p = Promisables.Promise();
            p1 = Promisables.Then(tE, p);
            givenError = ErrorException("Blank");
            Promisables.Reject(p, givenError);
            result = take!(p1.channel);
            @test typeof(p.status) == Promisables.Rejected;
            @test typeof(p1.status) == Promisables.Rejected;
            @test result == givenError;
          end
        end
        @testset "error handler" begin
          @testset "when returning a promise" begin
            @testset "should continue with the promise chain" begin
              chan = Channel{Any}(32);
              tE = () -> error("failed"); # Should throw if called
              p = Promisables.Promise();
              handler = (err) -> Promisables.Resolve("solved");
              p1 = Promisables.Then(tE, handler, p);
              givenError = ErrorException("Blank");
              Promisables.Reject(p, givenError);
              result = take!(p1.channel);
              @test typeof(p.status) == Promisables.Rejected;
              @test typeof(p1.status) == Promisables.Fulfilled;
              @test result == "solved";
            end
          end
          @testset "when returning anything else" begin
            @testset "should not continue with the promise chain" begin
              chan = Channel{Any}(32);
              tE = () -> error("failed"); # Should throw if called
              p = Promisables.Promise();
              handler = (err) -> Promisables.Reject(ErrorException("Blank"));
              p1 = Promisables.Then(tE, handler, p);
              givenError = ErrorException("Blank");
              Promisables.Reject(p, givenError);
              result = take!(p1.channel);
              @test typeof(p.status) == Promisables.Rejected;
              @test typeof(p1.status) == Promisables.Rejected;
            end
          end
        end
      end
    end
  end

end
