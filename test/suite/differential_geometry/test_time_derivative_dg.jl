module TestTimeDerivativeDG

import Test
import ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
import CTBase.Exceptions
import DifferentiationInterface
import ADTypes: ADTypes
import CTBase.Traits: Traits
import CTBase.Data: Data
import CTLie: CTLie

const VERBOSE    = isdefined(Main, :TestData) ? Main.TestData.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_time_derivative_dg()

    # ====================================================================
    # Plain Function
    # ====================================================================

    Test.@testset "∂ₜ() - Function: TimeDeriv_F + value" verbose=VERBOSE showtiming=SHOWTIMING begin
        f(t, x) = t^2 + x[1]
        df = CTLie.∂ₜ(f)
        Test.@test df isa CTLie.TimeDeriv_F
        # ∂f/∂t = 2t → at t=3, x=[1,2]: 6.0
        Test.@test df(3.0, [1.0, 2.0]) ≈ 6.0 atol=1e-6
    end

    # ====================================================================
    # VectorField — 4 combinations TD×VD
    # ====================================================================

    Test.@testset "∂ₜ() - NonAutonomous Fixed VectorField: functor + value + @inferred" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((t, x) -> [t * x[2], -t * x[1]]; is_autonomous=false, is_variable=false)
        dX = CTLie.∂ₜ(X)
        # return type
        Test.@test dX isa Data.VectorField
        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        # internal functor (callable struct, not closure)
        Test.@test dX.f isa CTLie.TimeDeriv_VF
        # ∂/∂t [t*x2, -t*x1] = [x2, -x1]
        t0 = 2.0; x0 = [1.0, 2.0]
        Test.@test isapprox(dX(t0, x0), [x0[2], -x0[1]]; atol=1e-6)
        dX(t0, x0)  # warm-up
        Test.@test_nowarn Test.@inferred dX(t0, x0)
    end

    Test.@testset "∂ₜ() - Autonomous Fixed VectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        dX = CTLie.∂ₜ(X)
        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        Test.@test isapprox(dX(1.0, [1.0, 2.0]), [0.0, 0.0]; atol=1e-10)
    end

    Test.@testset "∂ₜ() - Autonomous NonFixed VectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((x, v) -> [v[1] * x[2], -x[1]]; is_autonomous=true, is_variable=true)
        dX = CTLie.∂ₜ(X)
        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.NonFixed, Traits.OutOfPlace}
        Test.@test isapprox(dX(1.0, [1.0, 2.0], [3.0]), [0.0, 0.0]; atol=1e-10)
    end

    Test.@testset "∂ₜ() - NonAutonomous NonFixed VectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        # X(t, x, v) = [t*v[1]*x[2], -x[1]]  →  ∂X/∂t = [v[1]*x[2], 0]
        X = Data.VectorField((t, x, v) -> [t * v[1] * x[2], -x[1]]; is_autonomous=false, is_variable=true)
        dX = CTLie.∂ₜ(X)
        t0 = 2.0; x0 = [1.0, 2.0]; v0 = [3.0]
        Test.@test isapprox(dX(t0, x0, v0), [v0[1] * x0[2], 0.0]; atol=1e-6)
    end

    # ====================================================================
    # Hamiltonian — 4 combinations TD×VD
    # ====================================================================

    Test.@testset "∂ₜ() - NonAutonomous Fixed Hamiltonian → correct value" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((t, x, p) -> t * (p' * x); is_autonomous=false, is_variable=false)
        dH = CTLie.∂ₜ(H)
        Test.@test dH isa Data.Hamiltonian
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.Fixed}
        # ∂/∂t [t * p'x] = p'x
        x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
        Test.@test dH(2.0, x0, p0) ≈ p0' * x0 atol=1e-6
    end

    Test.@testset "∂ₜ() - Autonomous Fixed Hamiltonian → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p) -> p' * x; is_autonomous=true, is_variable=false)
        dH = CTLie.∂ₜ(H)
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.Fixed}
        Test.@test dH(1.0, [1.0, 2.0], [3.0, 4.0]) ≈ 0.0 atol=1e-10
    end

    Test.@testset "∂ₜ() - Autonomous NonFixed Hamiltonian → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p, v) -> v[1] * p' * x; is_autonomous=true, is_variable=true)
        dH = CTLie.∂ₜ(H)
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.NonFixed}
        Test.@test dH(1.0, [1.0, 2.0], [3.0, 4.0], [2.0]) ≈ 0.0 atol=1e-10
    end

    Test.@testset "∂ₜ() - NonAutonomous NonFixed Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        # H(t, x, p, v) = t * v[1] * p[1]  →  ∂H/∂t = v[1]*p[1]
        H = Data.Hamiltonian((t, x, p, v) -> t * v[1] * p[1]; is_autonomous=false, is_variable=true)
        dH = CTLie.∂ₜ(H)
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]; v0 = [4.0]
        Test.@test dH(t0, x0, p0, v0) ≈ v0[1] * p0[1] atol=1e-6
    end

    # ====================================================================
    # HamiltonianVectorField — 4 combinations TD×VD
    # ====================================================================

    Test.@testset "∂ₜ() - NonAutonomous Fixed HamiltonianVectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        # X(t,x,p) = (t*p, -t*x)  →  ∂X/∂t = (p, -x)
        X = Data.HamiltonianVectorField((t, x, p) -> (t * p, -t * x);
            is_autonomous=false, is_variable=false)
        dX = CTLie.∂ₜ(X)
        Test.@test dX isa Data.HamiltonianVectorField
        Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]
        dx, dp = dX(t0, x0, p0)
        Test.@test dx ≈ p0 atol=1e-6
        Test.@test dp ≈ -x0 atol=1e-6
    end

    Test.@testset "∂ₜ() - Autonomous Fixed HamiltonianVectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
        dX = CTLie.∂ₜ(X)
        Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        dx, dp = dX(1.0, [1.0], [3.0])
        Test.@test dx ≈ [0.0] atol=1e-10
        Test.@test dp ≈ [0.0] atol=1e-10
    end

    Test.@testset "∂ₜ() - Autonomous NonFixed HamiltonianVectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.HamiltonianVectorField((x, p, v) -> (v[1] * p, -x); is_autonomous=true, is_variable=true)
        dX = CTLie.∂ₜ(X)
        Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.NonFixed, Traits.OutOfPlace}
        dx, dp = dX(1.0, [1.0], [3.0], [2.0])
        Test.@test dx ≈ [0.0] atol=1e-10
        Test.@test dp ≈ [0.0] atol=1e-10
    end

    Test.@testset "∂ₜ() - NonAutonomous NonFixed HamiltonianVectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        # X(t,x,p,v) = (t*v[1]*p, -x)  →  ∂X/∂t = (v[1]*p, 0)
        X = Data.HamiltonianVectorField((t, x, p, v) -> (t * v[1] * p, -x);
            is_autonomous=false, is_variable=true)
        dX = CTLie.∂ₜ(X)
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]; v0 = [4.0]
        dx, dp = dX(t0, x0, p0, v0)
        Test.@test dx ≈ v0[1] .* p0 atol=1e-6
        Test.@test dp ≈ zeros(length(x0)) atol=1e-10
    end

    Test.@testset "∂ₜ() - HamiltonianVectorField @inferred" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.HamiltonianVectorField((t, x, p) -> (t * p, -t * x);
            is_autonomous=false, is_variable=false)
        dX = CTLie.∂ₜ(X)
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]
        dX(t0, x0, p0)  # warm-up
        Test.@test_nowarn Test.@inferred dX(t0, x0, p0)
    end

    # ====================================================================
    # Error guards
    # ====================================================================

    Test.@testset "∂ₜ() - InPlace guard → NotImplemented" verbose=VERBOSE showtiming=SHOWTIMING begin
        ip_vf = Data.VectorField((dx, x) -> (dx .= x); is_autonomous=true, is_inplace=true)
        Test.@test_throws Exceptions.NotImplemented CTLie.∂ₜ(ip_vf)
    end

end

end # module TestTimeDerivativeDG

test_time_derivative_dg() = TestTimeDerivativeDG.test_time_derivative_dg()
