module TestLiftDG

using Test: Test
import CTBase.Exceptions
import CTBase.Traits: Traits
import CTBase.Data: Data
import CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_lift_dg()
    Test.@testset "Lift() - Function → Function" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = [x[2], -x[1]]
        H2 = CTLie.Lift(F)
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0]
        # H2(x,p) = p' * F(x) = [3,4]·[2,-1] = 6-4 = 2
        Test.@test H2(x0, p0) ≈ 2.0 atol=1e-10

        # Non-autonomous
        F_na(t, x) = [t * x[2], -x[1]]
        H_na = CTLie.Lift(F_na; is_autonomous=false)
        Test.@test H_na isa Function
        # H_na(t,x,p) = p' * F_na(t,x) = [3,4]·[2*2,-1] = 12-4 = 8 (t=2)
        Test.@test H_na(2.0, x0, p0) ≈ 8.0 atol=1e-10
    end

    Test.@testset "Lift() - concrete type LiftedHamiltonianFunction" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = [x[2], -x[1]]
        H = CTLie.Lift(F)
        Test.@test H isa CTLie.LiftedHamiltonianFunction
        Test.@test H isa
            CTLie.LiftedHamiltonianFunction{typeof(F),Traits.Autonomous,Traits.Fixed}
    end

    Test.@testset "Lift() - @inferred type-stability" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = [x[2], -x[1]]
        H = CTLie.Lift(F)
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0]
        Test.@test_nowarn Test.@inferred H(x0, p0)
    end

    Test.@testset "Lift() - @inferred type-stability (NonAutonomous/Fixed)" verbose=VERBOSE showtiming=SHOWTIMING begin
        F_na(t, x) = [t * x[2], -x[1]]
        H_na = CTLie.Lift(F_na; is_autonomous=false)
        t0 = 2.0
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0]
        Test.@test_nowarn Test.@inferred H_na(t0, x0, p0)
    end

    Test.@testset "Lift() - field .f preserved" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = [x[2], -x[1]]
        H = CTLie.Lift(F)
        Test.@test H.f === F
    end

    Test.@testset "Lift() - typed API cohérent avec kwargs" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = [x[2], -x[1]]
        H_kw = CTLie.Lift(F; is_autonomous=true, is_variable=false)
        H_typed = CTLie.Lift(F, Traits.Autonomous, Traits.Fixed)
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0]
        Test.@test H_kw(x0, p0) ≈ H_typed(x0, p0) atol=1e-10
    end

    Test.@testset "Lift() - VectorField → Data.Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        H = CTLie.Lift(X)

        # Check return type
        Test.@test H isa Data.Hamiltonian
        Test.@test H isa Data.AbstractHamiltonian{Traits.Autonomous,Traits.Fixed}

        # Check that internal functor is LiftedHamiltonianFunction
        Test.@test H.f isa CTLie.LiftedHamiltonianFunction

        # Check correctness
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0]
        # H(x,p) = p'*X(x) = [3,4]·[2,-1] = 6-4 = 2
        Test.@test H(x0, p0) ≈ 2.0 atol=1e-10
    end

    Test.@testset "Lift() - HVF guard → NotImplemented" verbose=VERBOSE showtiming=SHOWTIMING begin
        hvf = Data.HamiltonianVectorField(
            (x, p) -> (x, -p); is_autonomous=true, is_variable=false
        )
        Test.@test_throws Exceptions.NotImplemented CTLie.Lift(hvf)
    end

    Test.@testset "Lift() - Autonomous NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x, v) = [v[1] * x[2], -x[1]]
        H = CTLie.Lift(F; is_autonomous=true, is_variable=true)
        Test.@test H isa Function
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0];
        v0 = [2.0]
        # H(x,p,v) = p' * F(x,v) = [3,4]·[2*2,-1] = 12-4 = 8
        Test.@test H(x0, p0, v0) ≈ 8.0 atol=1e-10
    end

    Test.@testset "Lift() - NonAutonomous NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(t, x, v) = [t * v[1] * x[2], -x[1]]
        H = CTLie.Lift(F; is_autonomous=false, is_variable=true)
        Test.@test H isa Function
        t0 = 2.0;
        x0 = [1.0, 2.0];
        p0 = [3.0, 4.0];
        v0 = [2.0]
        # H(t,x,p,v) = p' * F(t,x,v) = [3,4]·[2*2*2,-1] = 24-4 = 20
        Test.@test H(t0, x0, p0, v0) ≈ 20.0 atol=1e-10
    end

    Test.@testset "Lift() - scalar case" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = -2 * x  # returns scalar (treated as 1D vector)
        H = CTLie.Lift(F)
        x0 = 2.0;
        p0 = 3.0
        # H(x,p) = p * F(x) = 3 * (-4) = -12
        Test.@test H(x0, p0) ≈ -12.0 atol=1e-10
    end
end

end # module TestLiftDG

test_lift_dg() = TestLiftDG.test_lift_dg()
