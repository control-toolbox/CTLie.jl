module TestAdDG

using Test: Test
using ForwardDiff: ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
import CTBase.Exceptions
using DifferentiationInterface: DifferentiationInterface
using ADTypes: ADTypes
import CTBase.Traits: Traits
import CTBase.Data: Data
import CTBase.Differentiation
import CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_ad_dg()
    Test.@testset "ad() - Lie Derivative" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2
        Lf = CTLie.ad(X, f)
        Test.@test Lf([1.0, 2.0]) ≈ 0.0 atol = 1e-6

        # Non-autonomous
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        Lf_na = CTLie.ad(X_na, f_na; is_autonomous=false)
        # ∂f/∂x = [2x1, 0]
        # X = [t*x2, -x1]
        # dot = 2x1*t*x2
        # t=2, x=[1, 2] -> 2*1*2*2 = 8
        Test.@test Lf_na(2.0, [1.0, 2.0]) ≈ 8.0 atol = 1e-6
    end

    Test.@testset "ad() - Lie Bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        # [X, Y] = J_Y*X - J_X*Y
        # J_Y = [0 0; 1 0], X = [x2, 0] -> J_Y*X = [0, x2]
        # J_X = [0 1; 0 0], Y = [0, x1] -> J_X*Y = [x1, 0]
        # [X, Y] = [0, x2] - [x1, 0] = [-x1, x2]
        XY = CTLie.ad(X, Y)
        Test.@test isapprox(XY([1.0, 2.0]), [-1.0, 2.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/VectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        Y = Data.VectorField(x -> [x[1], x[2]]; is_autonomous=true, is_variable=false)
        Z = CTLie.ad(X, Y)

        # Check return type
        Test.@test Z isa Data.VectorField
        Test.@test Z isa Data.AbstractVectorField{
            Traits.Autonomous,Traits.Fixed,Traits.OutOfPlace
        }

        # Check correctness
        # J_X = [0 1; -1 0], J_Y = [1 0; 0 1]
        # J_Y*X = [x2, -x1], J_X*Y = [x2, -x1]
        # [X,Y] = [0, 0]
        x0 = [1.0, 2.0]
        Test.@test isapprox(Z(x0), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/Function (Lie derivative)" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        f(x) = x[1]^2 + x[2]^2
        Xf = CTLie.ad(X, f)

        # Check return type (should be Function)
        Test.@test Xf isa Function

        # Check correctness
        x0 = [1.0, 2.0]
        Test.@test Xf(x0) ≈ 0.0 atol = 1e-6
    end

    Test.@testset "ad() - Errors: HVF guard" verbose=VERBOSE showtiming=SHOWTIMING begin
        hvf = Data.HamiltonianVectorField(
            (x, p) -> (x, -p); is_autonomous=true, is_variable=false
        )
        Y = Data.VectorField(x -> [x[1], x[2]]; is_autonomous=true, is_variable=false)

        Test.@test_throws Exceptions.NotImplemented CTLie.ad(hvf, Y)
    end

    Test.@testset "ad() - Errors: InPlace guard" verbose=VERBOSE showtiming=SHOWTIMING begin
        ip_vf = Data.VectorField(
            (dx, x) -> (dx .= [x[2], -x[1]]); is_autonomous=true, is_inplace=true
        )
        Y = Data.VectorField(x -> [x[1], x[2]]; is_autonomous=true, is_variable=false)

        Test.@test_throws Exceptions.NotImplemented CTLie.ad(ip_vf, Y)
    end

    Test.@testset "ad() - Errors: TD/VD mismatch" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        Y = Data.VectorField((t, x) -> [x[1], x[2]]; is_autonomous=false, is_variable=false)

        Test.@test_throws Exceptions.PreconditionError CTLie.ad(X, Y)
    end

    Test.@testset "ad() - Backend: custom ad_backend kwarg" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2

        # With default backend
        Xf1 = CTLie.ad(X, f)

        # With custom backend (should give same result)
        Xf2 = CTLie.ad(X, f; ad_backend=Differentiation.ad_backend(CTLie.dg_ad_backend()))

        x0 = [1.0, 2.0]
        Test.@test isapprox(Xf1(x0), Xf2(x0); atol=1e-5)
    end

    Test.@testset "ad() - Backend: dg_ad_backend! global" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], -x[1]]
        Y(x) = [x[1], x[2]]

        # Save original backend
        original_backend = CTLie.dg_ad_backend()

        try
            # Change global backend
            CTLie.dg_ad_backend!(Differentiation.ad_backend(original_backend))

            # Call without explicit backend kwarg — should use global
            Z = CTLie.ad(X, Y)

            x0 = [1.0, 2.0]
            # [X,Y] = [0, 0] (même calcul que VectorField/VectorField)
            Test.@test isapprox(Z(x0), [0.0, 0.0]; atol=1e-6)
        finally
            # Restore original backend
            CTLie.dg_ad_backend!(Differentiation.ad_backend(original_backend))
        end
    end

    Test.@testset "ad() - Type-Based API" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous, Fixed
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2
        Lf_typed = CTLie.ad(X, f, Traits.Autonomous, Traits.Fixed)
        Lf_kwargs = CTLie.ad(X, f; is_autonomous=true, is_variable=false)
        Test.@test Lf_typed([1.0, 2.0]) ≈ Lf_kwargs([1.0, 2.0]) atol = 1e-6

        # NonAutonomous, Fixed
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        Lf_na_typed = CTLie.ad(X_na, f_na, Traits.NonAutonomous, Traits.Fixed)
        Lf_na_kwargs = CTLie.ad(X_na, f_na; is_autonomous=false, is_variable=false)
        Test.@test Lf_na_typed(2.0, [1.0, 2.0]) ≈ Lf_na_kwargs(2.0, [1.0, 2.0]) atol = 1e-6
    end

    Test.@testset "ad() - Scalar x (Float64)" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous, scalar x
        X_s(x) = 2.0 * x
        f_s(x) = x^2
        Lf_s = CTLie.ad(X_s, f_s)
        # ∇f = 2x, X = 2x, Lf = 2x * 2x = 4x^2
        # x=3 -> 4*9 = 36
        Test.@test Lf_s(3.0) ≈ 36.0 atol = 1e-6

        # NonAutonomous, scalar x
        X_na_s(t, x) = t * x
        f_na_s(t, x) = t + x^2
        Lf_na_s = CTLie.ad(X_na_s, f_na_s; is_autonomous=false)
        # ∇x f = 2x, X = t*x, dot = 2x * t*x = 2tx^2
        # t=2, x=3 -> 2*2*9 = 36
        Test.@test Lf_na_s(2.0, 3.0) ≈ 36.0 atol = 1e-6
    end

    Test.@testset "ad() - NonFixed (is_variable=true)" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous, NonFixed
        X_nf(x, v) = [x[2] * v, -x[1]]
        f_nf(x, v) = x[1]^2 + x[2]^2 + v
        Lf_nf = CTLie.ad(X_nf, f_nf; is_variable=true)
        # ∇x f = [2x1, 2x2], X = [x2*v, -x1]
        # dot = 2x1*x2*v + 2x2*(-x1) = 2x1*x2*v - 2x1*x2 = 2x1*x2*(v-1)
        # x=[1,2], v=3 -> 2*1*2*(3-1) = 8
        Test.@test Lf_nf([1.0, 2.0], 3.0) ≈ 8.0 atol = 1e-6

        # NonAutonomous, NonFixed
        X_na_nf(t, x, v) = [t * x[2] * v, -x[1]]
        f_na_nf(t, x, v) = t + x[1]^2 + v
        Lf_na_nf = CTLie.ad(X_na_nf, f_na_nf; is_autonomous=false, is_variable=true)
        # ∇x f = [2x1, 0], X = [t*x2*v, -x1]
        # dot = 2x1 * t*x2*v
        # t=2, x=[1,2], v=3 -> 2*1*2*2*3 = 24
        Test.@test Lf_na_nf(2.0, [1.0, 2.0], 3.0) ≈ 24.0 atol = 1e-6
    end

    Test.@testset "ad() - VectorField/VectorField NonAutonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(
            (t, x) -> [t * x[2], -x[1]]; is_autonomous=false, is_variable=false
        )
        Y = Data.VectorField((t, x) -> [x[1], x[2]]; is_autonomous=false, is_variable=false)
        Z = CTLie.ad(X, Y)

        Test.@test Z isa Data.VectorField
        Test.@test Z isa Data.AbstractVectorField{
            Traits.NonAutonomous,Traits.Fixed,Traits.OutOfPlace
        }

        # Check correctness at t=2, x=[1,2]
        # J_X = [[0, t], [-1, 0]], J_Y = I
        # J_Y*X = [t*x2, -x1] = [4, -1]
        # J_X*Y = [t*x2, -x1] = [4, -1]
        # [X,Y] = [0, 0]
        Test.@test isapprox(Z(2.0, [1.0, 2.0]), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/Function NonAutonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(
            (t, x) -> [t * x[2], -x[1]]; is_autonomous=false, is_variable=false
        )
        f(t, x) = t + x[1]^2
        Xf = CTLie.ad(X, f)

        Test.@test Xf isa Function

        # ∇x f = [2x1, 0], X = [t*x2, -x1]
        # dot = 2x1 * t*x2
        # t=2, x=[1,2] -> 2*1*2*2 = 8
        Test.@test Xf(2.0, [1.0, 2.0]) ≈ 8.0 atol = 1e-6
    end

    Test.@testset "ad() - VectorField/VectorField NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(
            (x, v) -> [x[2] * v, -x[1]]; is_autonomous=true, is_variable=true
        )
        Y = Data.VectorField((x, v) -> [x[1], x[2]]; is_autonomous=true, is_variable=true)
        Z = CTLie.ad(X, Y)

        Test.@test Z isa Data.VectorField
        Test.@test Z isa Data.AbstractVectorField{
            Traits.Autonomous,Traits.NonFixed,Traits.OutOfPlace
        }

        # Check correctness at x=[1,2], v=3
        # J_X = [[0, v], [-1, 0]], J_Y = I
        # J_Y*X = [x2*v, -x1] = [6, -1]
        # J_X*Y = [x2*v, -x1] = [6, -1]
        # [X,Y] = [0, 0]
        Test.@test isapprox(Z([1.0, 2.0], 3.0), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/Function NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(
            (x, v) -> [x[2] * v, -x[1]]; is_autonomous=true, is_variable=true
        )
        f(x, v) = x[1]^2 + v
        Xf = CTLie.ad(X, f)

        Test.@test Xf isa Function

        # ∇x f = [2x1, 0], X = [x2*v, -x1]
        # dot = 2x1 * x2*v
        # x=[1,2], v=3 -> 2*1*2*3 = 12
        Test.@test Xf([1.0, 2.0], 3.0) ≈ 12.0 atol = 1e-6
    end

    Test.@testset "ad() - Backend: fake ADType" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Use AutoForwardDiff as a concrete ADType
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2

        # With default backend
        Xf1 = CTLie.ad(X, f)

        # With explicit fake backend (AutoForwardDiff)
        Xf2 = CTLie.ad(X, f; ad_backend=ADTypes.AutoForwardDiff())

        x0 = [1.0, 2.0]
        Test.@test isapprox(Xf1(x0), Xf2(x0); atol=1e-5)
    end

    Test.@testset "ad() - MRI Bloch Equations" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Physical constants for magnetic resonance imaging
        Γ = 2.0  # Relaxation rate
        γ = 1.0  # Gyromagnetic ratio
        δ = γ - Γ

        # Bloch equation vector fields
        F0(x) = [-Γ * x[1], -Γ * x[2], γ * (1 - x[3])]
        F1(x) = [0.0, -x[3], x[2]]
        F2(x) = [x[3], 0.0, -x[1]]

        # Compute Lie brackets
        F01 = CTLie.ad(F0, F1)
        F02 = CTLie.ad(F0, F2)
        F12 = CTLie.ad(F1, F2)

        x = [1.0, 2.0, 3.0]

        # Verify known analytical results for Bloch equations
        Test.@test F01(x) ≈ -[0.0, γ - δ * x[3], -δ * x[2]] atol=1e-6
        Test.@test F02(x) ≈ -[-γ + δ * x[3], 0.0, δ * x[1]] atol=1e-6
        Test.@test F12(x) ≈ -[-x[2], x[1], 0.0] atol=1e-6
    end

    Test.@testset "ad() - Lie Bracket Intrinsic Definition" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Verify intrinsic definition: [X, Y]·f = X·(Y·f) - Y·(X·f)
        X(x) = [x[2]^2, -2x[1] * x[2]]
        Y(x) = [x[1] * (1 + x[2]), 3x[2]^3]
        f(x) = x[1]^4 + 2x[2]^3

        x_test = [1.0, 2.0]

        # Method 1: Direct computation of [X,Y]·f
        XY = CTLie.ad(X, Y)
        XY_dot_f = CTLie.ad(XY, f)
        result_direct = XY_dot_f(x_test)

        # Method 2: Commutator of directional derivatives X·(Y·f) - Y·(X·f)
        Y_dot_f = CTLie.ad(Y, f)
        X_dot_f = CTLie.ad(X, f)
        X_dot_Yf = CTLie.ad(X, Y_dot_f)
        Y_dot_Xf = CTLie.ad(Y, X_dot_f)
        result_commutator = X_dot_Yf(x_test) - Y_dot_Xf(x_test)

        # Both methods should give the same result
        Test.@test result_direct ≈ result_commutator atol=1e-6
    end

    Test.@testset "ad() - Nested Brackets Jacobi Identity" verbose=VERBOSE showtiming=SHOWTIMING begin
        # [X, [Y, Z]] + [Y, [Z, X]] + [Z, [X, Y]] = 0
        X(x) = [0, x[3], -x[2]]
        Y(x) = [-x[3], 0, x[1]]
        Z(x) = [x[2], -x[1], 0]

        XYZ = CTLie.ad(X, CTLie.ad(Y, Z))
        YZX = CTLie.ad(Y, CTLie.ad(Z, X))
        ZXY = CTLie.ad(Z, CTLie.ad(X, Y))

        x0 = [1.0, 2.0, 3.0]
        sum_jacobi = XYZ(x0) + YZX(x0) + ZXY(x0)
        Test.@test isapprox(sum_jacobi, [0.0, 0.0, 0.0]; atol=1e-6)
    end

    # ====================================================================
    # Phase 5: Ad callable struct — concrete type + @inferred
    # ====================================================================

    Test.@testset "ad() - concrete type Ad (Lie derivative, Autonomous/Fixed)" verbose=VERBOSE showtiming=SHOWTIMING begin
        Xad(x) = [x[2], -x[1]]
        fad(x) = x[1]^2 + x[2]^2
        a = CTLie.ad(Xad, fad)
        Test.@test a isa CTLie.Ad
        Test.@test a isa CTLie.Ad{
            typeof(Xad),
            typeof(fad),
            <:Differentiation.AbstractADBackend,
            Traits.Autonomous,
            Traits.Fixed,
        }
    end

    Test.@testset "ad() - concrete type Ad (Lie bracket, Autonomous/Fixed)" verbose=VERBOSE showtiming=SHOWTIMING begin
        Xad(x) = [x[2], -x[1]]
        Yad(x) = [x[1], x[2]]
        a = CTLie.ad(Xad, Yad)
        Test.@test a isa CTLie.Ad
        Test.@test a isa CTLie.Ad{
            typeof(Xad),
            typeof(Yad),
            <:Differentiation.AbstractADBackend,
            Traits.Autonomous,
            Traits.Fixed,
        }
    end

    Test.@testset "ad() - @inferred scalar (Lie derivative)" verbose=VERBOSE showtiming=SHOWTIMING begin
        Xad(x) = [x[2], -x[1]]
        fad(x) = x[1]^2 + x[2]^2
        a = CTLie.ad(Xad, fad)
        x0 = [1.0, 2.0]
        a(x0)  # warm-up
        Test.@test_nowarn Test.@inferred a(x0)
    end

    Test.@testset "ad() - @inferred vector (Lie bracket)" verbose=VERBOSE showtiming=SHOWTIMING begin
        Xad(x) = [x[2], -x[1]]
        Yad(x) = [x[1], x[2]]
        a = CTLie.ad(Xad, Yad)
        x0 = [1.0, 2.0]
        a(x0)  # warm-up
        Test.@test_nowarn Test.@inferred a(x0)
    end

    Test.@testset "ad() - @inferred scalar (Lie derivative, NonAutonomous/Fixed)" verbose=VERBOSE showtiming=SHOWTIMING begin
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        a = CTLie.ad(X_na, f_na; is_autonomous=false)
        t0 = 2.0
        x0 = [1.0, 2.0]
        a(t0, x0)  # warm-up
        Test.@test_nowarn Test.@inferred a(t0, x0)
    end
end

end # module TestAdDG

# CRITICAL: Redefine in outer scope for TestRunner
test_ad_dg() = TestAdDG.test_ad_dg()
