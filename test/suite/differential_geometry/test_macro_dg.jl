module TestMacroDG

using Test: Test
using ForwardDiff: ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
import CTBase: CTBase  # for Exceptions prefix in @Lie macro
import CTBase.Exceptions
import CTBase.Traits: Traits
import CTBase.Data: Data
import CTLie: CTLie
using DifferentiationInterface: DifferentiationInterface  # triggers CTBaseDifferentiationInterface extension

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ─── Shared constants used across many testsets ────────────────────────────
const _Γ = 2;
const _γ = 1;
const _δ = _γ - _Γ  # δ = -1
const _t = 1.0
const _x3 = [1.0, 2.0, 3.0]
const _x2 = [1.0, 2.0]
const _p3 = [1.0, 0.0, 7.0]
const _p2 = [2.0, 1.0]
const _v = 1.0

_VF(f, td, vd) = Data.VectorField(f, td, vd, Traits.OutOfPlace)
_H(f, td, vd) = Data.Hamiltonian(f, td, vd)

function test_macro_dg()

    # =========================================================================
    Test.@testset "lie macro — VectorFields, autonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = x -> [x[2], 2x[1]]
        g = x -> [3x[2], -x[1]]
        X = _VF(f, Traits.Autonomous, Traits.Fixed)
        Y = _VF(g, Traits.Autonomous, Traits.Fixed)
        ref = CTLie.ad(X, Y)
        mac = CTLie.@Lie [X, Y]
        Test.@test mac isa Data.VectorField
        Test.@test mac(_x2) ≈ ref(_x2) atol=1e-6
        Test.@test mac(_x2) ≈ [7.0, -14.0] atol=1e-6

        # Nested: [[X, Y], Y]
        ref2 = CTLie.ad(ref, Y)
        mac2 = CTLie.@Lie [[X, Y], Y]
        Test.@test mac2(_x2) ≈ ref2(_x2) atol=1e-6

        # get_X() — function call as operand
        get_X = () -> X
        mac3 = CTLie.@Lie [[get_X(), Y], Y]
        Test.@test mac3(_x2) ≈ ref2(_x2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — VectorFields, nonautonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (t, x) -> [t + x[2], -2x[1]]
        g = (t, x) -> [t + 3x[2], -x[1]]
        X = _VF(f, Traits.NonAutonomous, Traits.Fixed)
        Y = _VF(g, Traits.NonAutonomous, Traits.Fixed)
        ref = CTLie.ad(X, Y)
        mac = CTLie.@Lie [X, Y]
        Test.@test mac isa Data.VectorField
        Test.@test mac(_t, _x2) ≈ ref(_t, _x2) atol=1e-6
        Test.@test mac(_t, _x2) ≈ [-5.0, 11.0] atol=1e-6

        ref2 = CTLie.ad(ref, Y)
        mac2 = CTLie.@Lie [[X, Y], Y]
        Test.@test mac2(_t, _x2) ≈ ref2(_t, _x2) atol=1e-6

        get_X = () -> X
        mac3 = CTLie.@Lie [[get_X(), Y], Y]
        Test.@test mac3(_t, _x2) ≈ ref2(_t, _x2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — VectorFields, nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (x, v) -> [x[2] + v, 2x[1]]
        g = (x, v) -> [3x[2], v - x[1]]
        X = _VF(f, Traits.Autonomous, Traits.NonFixed)
        Y = _VF(g, Traits.Autonomous, Traits.NonFixed)
        ref = CTLie.ad(X, Y)
        mac = CTLie.@Lie [X, Y]
        Test.@test mac isa Data.VectorField
        Test.@test mac(_x2, _v) ≈ ref(_x2, _v) atol=1e-6
        Test.@test mac(_x2, _v) ≈ [6.0, -15.0] atol=1e-6

        ref2 = CTLie.ad(ref, Y)
        mac2 = CTLie.@Lie [[X, Y], Y]
        Test.@test mac2(_x2, _v) ≈ ref2(_x2, _v) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — VectorFields, nonautonomous nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (t, x, v) -> [t + x[2] + v, -2x[1] - v]
        g = (t, x, v) -> [t + 3x[2] + v, -x[1] - v]
        X = _VF(f, Traits.NonAutonomous, Traits.NonFixed)
        Y = _VF(g, Traits.NonAutonomous, Traits.NonFixed)
        ref = CTLie.ad(X, Y)
        mac = CTLie.@Lie [X, Y]
        Test.@test mac isa Data.VectorField
        Test.@test mac(_t, _x2, _v) ≈ ref(_t, _x2, _v) atol=1e-6
        Test.@test mac(_t, _x2, _v) ≈ [-7.0, 12.0] atol=1e-6

        ref2 = CTLie.ad(ref, Y)
        mac2 = CTLie.@Lie [[X, Y], Y]
        Test.@test mac2(_t, _x2, _v) ≈ ref2(_t, _x2, _v) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — plain functions, autonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = x -> [x[2], 2x[1]]
        g = x -> [3x[2], -x[1]]
        X = _VF(f, Traits.Autonomous, Traits.Fixed)
        Y = _VF(g, Traits.Autonomous, Traits.Fixed)
        ref = CTLie.ad(X, Y)

        mac = CTLie.@Lie [f, g]
        mac2 = CTLie.@Lie [[f, g], g]
        Test.@test mac(_x2) ≈ ref(_x2) atol=1e-6
        Test.@test mac2(_x2) ≈ CTLie.ad(ref, Y)(_x2) atol=1e-6

        get_f = () -> f
        mac3 = CTLie.@Lie [[get_f(), g], g]
        Test.@test mac3(_x2) ≈ CTLie.ad(ref, Y)(_x2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — plain functions, nonautonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (t, x) -> [t + x[2], -2x[1]]
        g = (t, x) -> [t + 3x[2], -x[1]]
        X = _VF(f, Traits.NonAutonomous, Traits.Fixed)
        Y = _VF(g, Traits.NonAutonomous, Traits.Fixed)
        ref = CTLie.ad(X, Y)

        mac = CTLie.@Lie [f, g] is_autonomous=false
        mac_val = CTLie.@Lie [f, g](_t, _x2) is_autonomous=false
        mac2 = CTLie.@Lie [[f, g], g] is_autonomous=false
        Test.@test mac(_t, _x2) ≈ ref(_t, _x2) atol=1e-6
        Test.@test mac_val ≈ ref(_t, _x2) atol=1e-6
        Test.@test mac2(_t, _x2) ≈ CTLie.ad(ref, Y)(_t, _x2) atol=1e-6

        get_f = () -> f
        mac3 = CTLie.@Lie [[get_f(), g], g] is_autonomous=false is_variable=false
        Test.@test mac3(_t, _x2) ≈ CTLie.ad(ref, Y)(_t, _x2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — plain functions, nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (x, v) -> [x[2] + v, 2x[1]]
        g = (x, v) -> [3x[2], v - x[1]]
        X = _VF(f, Traits.Autonomous, Traits.NonFixed)
        Y = _VF(g, Traits.Autonomous, Traits.NonFixed)
        ref = CTLie.ad(X, Y)

        mac = CTLie.@Lie [f, g] is_variable=true
        mac2 = CTLie.@Lie [[f, g], g] is_variable=true
        Test.@test mac(_x2, _v) ≈ ref(_x2, _v) atol=1e-6
        Test.@test mac2(_x2, _v) ≈ CTLie.ad(ref, Y)(_x2, _v) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — plain functions, nonautonomous nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (t, x, v) -> [t + x[2] + v, -2x[1] - v]
        g = (t, x, v) -> [t + 3x[2] + v, -x[1] - v]
        X = _VF(f, Traits.NonAutonomous, Traits.NonFixed)
        Y = _VF(g, Traits.NonAutonomous, Traits.NonFixed)
        ref = CTLie.ad(X, Y)

        mac = CTLie.@Lie [f, g] is_autonomous=false is_variable=true
        mac2 = CTLie.@Lie [[f, g], g] is_autonomous=false is_variable=true
        Test.@test mac(_t, _x2, _v) ≈ ref(_t, _x2, _v) atol=1e-6
        Test.@test mac2(_t, _x2, _v) ≈ CTLie.ad(ref, Y)(_t, _x2, _v) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — mixed Function + VectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        f0 = x -> [x[2], -x[1], 0.0]
        F1 = _VF(x -> [0.0, -x[3], x[2]], Traits.Autonomous, Traits.Fixed)
        F0 = _VF(x -> [x[2], -x[1], 0.0], Traits.Autonomous, Traits.Fixed)
        f1 = x -> [0.0, -x[3], x[2]]

        mac1 = CTLie.@Lie [f0, F1]
        mac2 = CTLie.@Lie [F0, f1]
        ref = CTLie.ad(F0, F1)
        Test.@test mac1(_x3) ≈ ref(_x3) atol=1e-6
        Test.@test mac2(_x3) ≈ ref(_x3) atol=1e-6

        # Nonautonomous
        f0_na = (t, x) -> [t + x[2], -x[1], 0.0]
        F1_na = _VF((t, x) -> [0.0, -x[3], x[2]], Traits.NonAutonomous, Traits.Fixed)
        mac3 = CTLie.@Lie [f0_na, F1_na] is_autonomous=false
        ref3 = CTLie.ad(_VF(f0_na, Traits.NonAutonomous, Traits.Fixed), F1_na)
        Test.@test mac3(_t, _x3) ≈ ref3(_t, _x3) atol=1e-6

        # VF + Function, nonautonomous
        F0_na = _VF((t, x) -> [t + x[2], -x[1], 0.0], Traits.NonAutonomous, Traits.Fixed)
        f1_na = (t, x) -> [0.0, -x[3], x[2]]
        mac5 = CTLie.@Lie [F0_na, f1_na] is_autonomous=false
        ref5 = CTLie.ad(F0_na, _VF(f1_na, Traits.NonAutonomous, Traits.Fixed))
        Test.@test mac5(_t, _x3) ≈ ref5(_t, _x3) atol=1e-6

        # Nonfixed
        f0_v = (x, v) -> [v + x[2], -x[1], 0.0]
        F1_v = _VF((x, v) -> [0.0, -x[3], x[2]], Traits.Autonomous, Traits.NonFixed)
        mac4 = CTLie.@Lie [f0_v, F1_v] is_variable=true
        ref4 = CTLie.ad(_VF(f0_v, Traits.Autonomous, Traits.NonFixed), F1_v)
        Test.@test mac4(_x3, _v) ≈ ref4(_x3, _v) atol=1e-6

        # VF + Function, nonfixed
        F0_v = _VF((x, v) -> [v + x[2], -x[1], 0.0], Traits.Autonomous, Traits.NonFixed)
        f1_v = (x, v) -> [0.0, -x[3], x[2]]
        mac6 = CTLie.@Lie [F0_v, f1_v] is_variable=true
        ref6 = CTLie.ad(F0_v, _VF(f1_v, Traits.Autonomous, Traits.NonFixed))
        Test.@test mac6(_x3, _v) ≈ ref6(_x3, _v) atol=1e-6

        # Function + VF and VF + Function, nonautonomous nonfixed
        f0_tv = (t, x, v) -> [t + v + x[2], -x[1], 0.0]
        F1_tv = _VF((t, x, v) -> [0.0, -x[3], x[2]], Traits.NonAutonomous, Traits.NonFixed)
        F0_tv = _VF(
            (t, x, v) -> [t + v + x[2], -x[1], 0.0], Traits.NonAutonomous, Traits.NonFixed
        )
        f1_tv = (t, x, v) -> [0.0, -x[3], x[2]]
        mac7 = CTLie.@Lie [f0_tv, F1_tv] is_autonomous=false is_variable=true
        mac8 = CTLie.@Lie [F0_tv, f1_tv] is_autonomous=false is_variable=true
        ref7 = CTLie.ad(F0_tv, F1_tv)
        Test.@test mac7(_t, _x3, _v) ≈ ref7(_t, _x3, _v) atol=1e-6
        Test.@test mac8(_t, _x3, _v) ≈ ref7(_t, _x3, _v) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — MRI Bloch equations" verbose=VERBOSE showtiming=SHOWTIMING begin
        F0 = _VF(x -> [-_Γ*x[1], -_Γ*x[2], _γ*(1-x[3])], Traits.Autonomous, Traits.Fixed)
        F1 = _VF(x -> [0.0, -x[3], x[2]], Traits.Autonomous, Traits.Fixed)
        F2 = _VF(x -> [x[3], 0.0, -x[1]], Traits.Autonomous, Traits.Fixed)

        F01 = CTLie.ad(F0, F1)
        F02 = CTLie.ad(F0, F2)
        F12 = CTLie.ad(F1, F2)

        F01_mac = CTLie.@Lie [F0, F1]
        F02_mac = CTLie.@Lie [F0, F2]
        F12_mac = CTLie.@Lie [F1, F2]

        Test.@test F01_mac(_x3) ≈ F01(_x3) atol=1e-6
        Test.@test F02_mac(_x3) ≈ F02(_x3) atol=1e-6
        Test.@test F12_mac(_x3) ≈ F12(_x3) atol=1e-6
        Test.@test F01_mac(_x3) ≈ -[0.0, _γ - _δ*_x3[3], -_δ*_x3[2]] atol=1e-6
        Test.@test F02_mac(_x3) ≈ -[-_γ + _δ*_x3[3], 0.0, _δ*_x3[1]] atol=1e-6
        Test.@test F12_mac(_x3) ≈ -[-_x3[2], _x3[1], 0.0] atol=1e-6

        # Nested: [[F0,F1], F1]
        F011 = CTLie.ad(F01, F1)
        mac2 = CTLie.@Lie [[F0, F1], F1]
        Test.@test mac2(_x3) ≈ F011(_x3) atol=1e-6

        # get_F0() as operand
        get_F0 = () -> F0
        mac3 = CTLie.@Lie [[get_F0(), F1], F1]
        Test.@test mac3(_x3) ≈ F011(_x3) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — intrinsic definition [X,Y]" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = _VF(x -> [x[2]^2, -2x[1]*x[2]], Traits.Autonomous, Traits.Fixed)
        Y = _VF(x -> [x[1]*(1+x[2]), 3x[2]^3], Traits.Autonomous, Traits.Fixed)
        XY = CTLie.@Lie [X, Y]
        XY_ref = CTLie.ad(X, Y)
        x0 = [1.0, 2.0]
        Test.@test XY(x0) ≈ XY_ref(x0) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — Hamiltonians, autonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
        g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
        h = (x, p) -> x[2]^2 - 2x[1]^2 + p[1]^2 - 2p[2]^2
        F = _H(f, Traits.Autonomous, Traits.Fixed)
        G = _H(g, Traits.Autonomous, Traits.Fixed)
        H = _H(h, Traits.Autonomous, Traits.Fixed)
        Fph = _H((x, p) -> f(x, p)+g(x, p), Traits.Autonomous, Traits.Fixed)
        FG = _H((x, p) -> f(x, p)*g(x, p), Traits.Autonomous, Traits.Fixed)

        ref = CTLie.Poisson(F, G)
        mac = CTLie.@Lie {F, G}
        Test.@test mac isa Data.Hamiltonian
        Test.@test mac(_x2, _p2) ≈ ref(_x2, _p2) atol=1e-6
        Test.@test mac(_x2, _p2) ≈ -20.0 atol=1e-6

        # Anticommutativity
        Test.@test CTLie.Poisson(F, G)(_x2, _p2) ≈ -CTLie.Poisson(G, F)(_x2, _p2) atol=1e-6
        # Bilinearity
        Test.@test CTLie.Poisson(Fph, H)(_x2, _p2) ≈
            CTLie.Poisson(F, H)(_x2, _p2) + CTLie.Poisson(G, H)(_x2, _p2) atol=1e-6
        # Leibniz rule
        Test.@test CTLie.Poisson(FG, H)(_x2, _p2) ≈
            CTLie.Poisson(F, H)(_x2, _p2)*G(_x2, _p2) +
                   F(_x2, _p2)*CTLie.Poisson(G, H)(_x2, _p2) atol=1e-6
        # Jacobi identity
        Test.@test CTLie.Poisson(F, CTLie.Poisson(G, H))(_x2, _p2) +
                   CTLie.Poisson(G, CTLie.Poisson(H, F))(_x2, _p2) +
                   CTLie.Poisson(H, CTLie.Poisson(F, G))(_x2, _p2) ≈ 0.0 atol=1e-6

        # Nested: {{F,G},G}
        mac2 = CTLie.@Lie {{F, G}, G}
        ref2 = CTLie.Poisson(ref, G)
        Test.@test mac2(_x2, _p2) ≈ ref2(_x2, _p2) atol=1e-6

        get_F = () -> F
        mac3 = CTLie.@Lie {{get_F(), G}, G}
        Test.@test mac3(_x2, _p2) ≈ ref2(_x2, _p2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — Hamiltonians, nonautonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (t, x, p) -> t*x[2]^2 + 2x[1]^2 + p[1]^2 + t
        g = (t, x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] - t
        F = _H(f, Traits.NonAutonomous, Traits.Fixed)
        G = _H(g, Traits.NonAutonomous, Traits.Fixed)
        t2 = 2.0

        ref = CTLie.Poisson(F, G)
        mac = CTLie.@Lie {F, G}
        Test.@test mac isa Data.Hamiltonian
        Test.@test mac(t2, _x2, _p2) ≈ ref(t2, _x2, _p2) atol=1e-6
        Test.@test mac(t2, _x2, _p2) ≈ -28.0 atol=1e-6

        # Anticommutativity
        Test.@test CTLie.Poisson(F, G)(t2, _x2, _p2) ≈ -CTLie.Poisson(G, F)(t2, _x2, _p2) atol=1e-6

        # Nested
        mac2 = CTLie.@Lie {{F, G}, G}
        ref2 = CTLie.Poisson(ref, G)
        Test.@test mac2(t2, _x2, _p2) ≈ ref2(t2, _x2, _p2) atol=1e-6

        get_F = () -> F
        mac3 = CTLie.@Lie {{get_F(), G}, G}
        Test.@test mac3(t2, _x2, _p2) ≈ ref2(t2, _x2, _p2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — Hamiltonians, nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        vv = [4.0, 4.0]
        f = (x, p, v) -> v[1]*x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
        g = (x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] - v[2]
        F = _H(f, Traits.Autonomous, Traits.NonFixed)
        G = _H(g, Traits.Autonomous, Traits.NonFixed)

        ref = CTLie.Poisson(F, G)
        mac = CTLie.@Lie {F, G}
        Test.@test mac isa Data.Hamiltonian
        Test.@test mac(_x2, _p2, vv) ≈ ref(_x2, _p2, vv) atol=1e-6
        Test.@test mac(_x2, _p2, vv) ≈ -44.0 atol=1e-6

        # Anticommutativity
        Test.@test CTLie.Poisson(F, G)(_x2, _p2, vv) ≈ -CTLie.Poisson(G, F)(_x2, _p2, vv) atol=1e-6

        # Nested
        mac2 = CTLie.@Lie {{F, G}, G}
        ref2 = CTLie.Poisson(ref, G)
        Test.@test mac2(_x2, _p2, vv) ≈ ref2(_x2, _p2, vv) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — Hamiltonians, nonautonomous nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        t2 = 2.0;
        vv = [4.0, 4.0]
        f = (t, x, p, v) -> t*v[1]*x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
        g = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] + t - v[2]
        F = _H(f, Traits.NonAutonomous, Traits.NonFixed)
        G = _H(g, Traits.NonAutonomous, Traits.NonFixed)

        ref = CTLie.Poisson(F, G)
        mac = CTLie.@Lie {F, G}
        Test.@test mac isa Data.Hamiltonian
        Test.@test mac(t2, _x2, _p2, vv) ≈ ref(t2, _x2, _p2, vv) atol=1e-6
        Test.@test mac(t2, _x2, _p2, vv) ≈ -76.0 atol=1e-6

        # Anticommutativity
        Test.@test CTLie.Poisson(F, G)(t2, _x2, _p2, vv) ≈
            -CTLie.Poisson(G, F)(t2, _x2, _p2, vv) atol=1e-6

        # Nested + get_F()
        mac2 = CTLie.@Lie {{F, G}, G}
        ref2 = CTLie.Poisson(ref, G)
        Test.@test mac2(t2, _x2, _p2, vv) ≈ ref2(t2, _x2, _p2, vv) atol=1e-6
        get_F = () -> F
        mac3 = CTLie.@Lie {{get_F(), G}, G}
        Test.@test mac3(t2, _x2, _p2, vv) ≈ ref2(t2, _x2, _p2, vv) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — plain functions, autonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
        g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
        F = _H(f, Traits.Autonomous, Traits.Fixed)
        G = _H(g, Traits.Autonomous, Traits.Fixed)
        ref = CTLie.Poisson(F, G)

        mac = CTLie.@Lie {f, g}
        mac2 = CTLie.@Lie {{f, g}, g}
        Test.@test mac(_x2, _p2) ≈ ref(_x2, _p2) atol=1e-6
        Test.@test mac2(_x2, _p2) ≈ CTLie.Poisson(ref, G)(_x2, _p2) atol=1e-6

        get_f = () -> f
        mac3 = CTLie.@Lie {{get_f(), g}, g}
        Test.@test mac3(_x2, _p2) ≈ CTLie.Poisson(ref, G)(_x2, _p2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — plain functions, nonautonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        t2 = 2.0
        f = (t, x, p) -> t*x[2]^2 + 2x[1]^2 + p[1]^2
        g = (t, x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
        F = _H(f, Traits.NonAutonomous, Traits.Fixed)
        G = _H(g, Traits.NonAutonomous, Traits.Fixed)
        ref = CTLie.Poisson(F, G)

        mac = CTLie.@Lie {f, g} is_autonomous=false
        mac_val = CTLie.@Lie {f, g}(t2, _x2, _p2) is_autonomous=false
        mac2 = CTLie.@Lie {{f, g}, g} is_autonomous=false
        Test.@test mac(t2, _x2, _p2) ≈ ref(t2, _x2, _p2) atol=1e-6
        Test.@test mac_val ≈ ref(t2, _x2, _p2) atol=1e-6
        Test.@test mac2(t2, _x2, _p2) ≈ CTLie.Poisson(ref, G)(t2, _x2, _p2) atol=1e-6

        get_f = () -> f
        mac3 = CTLie.@Lie {{get_f(), g}, g} is_autonomous=false is_variable=false
        Test.@test mac3(t2, _x2, _p2) ≈ CTLie.Poisson(ref, G)(t2, _x2, _p2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — plain functions, nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        vv = 2.0
        f = (x, p, v) -> 0.5*(x[1]^2 + x[2]^2 + p[1]^2 + v)
        g = (x, p, v) -> 0.5*(x[1]^2 + x[2]^2 + p[2]^2 + v)
        F = _H(f, Traits.Autonomous, Traits.NonFixed)
        G = _H(g, Traits.Autonomous, Traits.NonFixed)
        ref = CTLie.Poisson(F, G)

        mac = CTLie.@Lie {f, g} is_variable=true
        mac2 = CTLie.@Lie {{f, g}, g} is_variable=true
        Test.@test mac(_x2, _p2, vv) ≈ ref(_x2, _p2, vv) atol=1e-6
        Test.@test mac2(_x2, _p2, vv) ≈ CTLie.Poisson(ref, G)(_x2, _p2, vv) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — plain functions, nonautonomous nonfixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        t2 = 2.0;
        vv = 2.0
        f = (t, x, p, v) -> 0.5*(x[1]^2 + x[2]^2 + p[1]^2 + v)
        g = (t, x, p, v) -> 0.5*(x[1]^2 + x[2]^2 + p[2]^2 + v)
        F = _H(f, Traits.NonAutonomous, Traits.NonFixed)
        G = _H(g, Traits.NonAutonomous, Traits.NonFixed)
        ref = CTLie.Poisson(F, G)

        mac = CTLie.@Lie {f, g} is_autonomous=false is_variable=true
        mac2 = CTLie.@Lie {{f, g}, g} is_autonomous=false is_variable=true
        Test.@test mac(t2, _x2, _p2, vv) ≈ ref(t2, _x2, _p2, vv) atol=1e-6
        Test.@test mac2(t2, _x2, _p2, vv) ≈ CTLie.Poisson(ref, G)(t2, _x2, _p2, vv) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — mixed Function + Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        h0 = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
        g0 = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
        F0 = _H(h0, Traits.Autonomous, Traits.Fixed)
        G0 = _H(g0, Traits.Autonomous, Traits.Fixed)
        ref0 = CTLie.Poisson(F0, G0)

        # Function + Hamiltonian, autonomous
        mac_fH = CTLie.@Lie {h0, G0}
        mac_Hf = CTLie.@Lie {F0, g0}
        Test.@test mac_fH isa Data.Hamiltonian
        Test.@test mac_Hf isa Data.Hamiltonian
        Test.@test mac_fH(_x2, _p2) ≈ ref0(_x2, _p2) atol=1e-6
        Test.@test mac_Hf(_x2, _p2) ≈ ref0(_x2, _p2) atol=1e-6

        # Function + Hamiltonian, nonautonomous
        t2 = 2.0
        h_na = (t, x, p) -> t*x[2]^2 + 2x[1]^2 + p[1]^2
        g_na = (t, x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
        F_na = _H(h_na, Traits.NonAutonomous, Traits.Fixed)
        G_na = _H(g_na, Traits.NonAutonomous, Traits.Fixed)
        ref_na = CTLie.Poisson(F_na, G_na)

        mac_fH_na = CTLie.@Lie {h_na, G_na} is_autonomous=false
        mac_Hf_na = CTLie.@Lie {F_na, g_na} is_autonomous=false
        Test.@test mac_fH_na(t2, _x2, _p2) ≈ ref_na(t2, _x2, _p2) atol=1e-6
        Test.@test mac_Hf_na(t2, _x2, _p2) ≈ ref_na(t2, _x2, _p2) atol=1e-6

        # Function + Hamiltonian, nonfixed
        vv = 2.0
        h_v = (x, p, v) -> x[2]^2 + 2x[1]^2 + p[1]^2 + v
        g_v = (x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + v
        F_v = _H(h_v, Traits.Autonomous, Traits.NonFixed)
        G_v = _H(g_v, Traits.Autonomous, Traits.NonFixed)
        ref_v = CTLie.Poisson(F_v, G_v)

        mac_fH_v = CTLie.@Lie {h_v, G_v} is_variable=true
        mac_Hf_v = CTLie.@Lie {F_v, g_v} is_variable=true
        Test.@test mac_fH_v(_x2, _p2, vv) ≈ ref_v(_x2, _p2, vv) atol=1e-6
        Test.@test mac_Hf_v(_x2, _p2, vv) ≈ ref_v(_x2, _p2, vv) atol=1e-6

        # Function + Hamiltonian, nonautonomous nonfixed
        t2 = 2.0;
        vv = 2.0
        h_tv = (t, x, p, v) -> t*x[2]^2 + 2x[1]^2 + p[1]^2 + v
        g_tv = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + v
        F_tv = _H(h_tv, Traits.NonAutonomous, Traits.NonFixed)
        G_tv = _H(g_tv, Traits.NonAutonomous, Traits.NonFixed)
        ref_tv = CTLie.Poisson(F_tv, G_tv)

        mac_fH_tv = CTLie.@Lie {h_tv, G_tv} is_autonomous=false is_variable=true
        mac_Hf_tv = CTLie.@Lie {F_tv, g_tv} is_autonomous=false is_variable=true
        Test.@test mac_fH_tv(t2, _x2, _p2, vv) ≈ ref_tv(t2, _x2, _p2, vv) atol=1e-6
        Test.@test mac_Hf_tv(t2, _x2, _p2, vv) ≈ ref_tv(t2, _x2, _p2, vv) atol=1e-6

        # Nested: {h, {F, G}} and {{h, G}, K} (use a third distinct Hamiltonian K0)
        k0 = (x, p) -> x[1]*p[2] - x[2]*p[1]
        K0 = _H(k0, Traits.Autonomous, Traits.Fixed)
        mac_nested1 = CTLie.@Lie {h0, {F0, G0}}
        mac_nested2 = CTLie.@Lie {{h0, G0}, K0}
        ref_n1 = CTLie.Poisson(F0, ref0)
        ref_n2 = CTLie.Poisson(ref0, K0)
        Test.@test mac_nested1(_x2, _p2) ≈ ref_n1(_x2, _p2) atol=1e-6
        Test.@test mac_nested2(_x2, _p2) ≈ ref_n2(_x2, _p2) atol=1e-6
    end

    # =========================================================================
    Test.@testset "lie macro — Jacobi identity" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = _VF(x -> [0.0, x[3], -x[2]], Traits.Autonomous, Traits.Fixed)
        Y = _VF(x -> [-x[3], 0.0, x[1]], Traits.Autonomous, Traits.Fixed)
        Z = _VF(x -> [x[2], -x[1], 0.0], Traits.Autonomous, Traits.Fixed)

        XYZ = CTLie.@Lie [X, [Y, Z]]
        YZX = CTLie.@Lie [Y, [Z, X]]
        ZXY = CTLie.@Lie [Z, [X, Y]]

        Test.@test XYZ(_x3) + YZX(_x3) + ZXY(_x3) ≈ [0.0, 0.0, 0.0] atol=1e-6

        # Trivial cases: commuting (constant) fields have zero bracket
        C1 = _VF(x -> [1.0, 0.0], Traits.Autonomous, Traits.Fixed)
        C2 = _VF(x -> [0.0, 1.0], Traits.Autonomous, Traits.Fixed)
        zero_mac = CTLie.@Lie [C1, C2]
        Test.@test zero_mac(_x2) ≈ [0.0, 0.0] atol=1e-10
    end

    # =========================================================================
    Test.@testset "lie and poisson macro — arithmetic operations" verbose=VERBOSE showtiming=SHOWTIMING begin
        F0 = _VF(x -> [-_Γ*x[1], -_Γ*x[2], _γ*(1-x[3])], Traits.Autonomous, Traits.Fixed)
        F1 = _VF(x -> [0.0, -x[3], x[2]], Traits.Autonomous, Traits.Fixed)
        F2 = _VF(x -> [x[3], 0.0, -x[1]], Traits.Autonomous, Traits.Fixed)

        # [F0,F1](_x3) = [0,-4,-2], [F1,F2](_x3) = [2,-1,0]
        Test.@test (CTLie.@Lie [F0, F1](_x3) + 4 * [F1, F2](_x3)) ≈ [8.0, -8.0, -2.0] atol=1e-6
        Test.@test (CTLie.@Lie [F0, F1](_x3) - [F1, F2](_x3)) ≈ [-2.0, -3.0, -2.0] atol=1e-6
        Test.@test (CTLie.@Lie [F0, F1](_x3) .* [F1, F2](_x3)) ≈ [0.0, 4.0, 0.0] atol=1e-6
        Test.@test (CTLie.@Lie [1.0, 1.0, 1.0] +
            ([[F0, F1], F1](_x3) + [F1, F2](_x3) + [1.0, 1.0, 1.0])) ≈ [4.0, 5.0, -5.0] atol=1e-6

        # Poisson operations — autonomous
        H0 = _H((x, p) -> 0.5*(2x[1]^2 + x[2]^2 + p[1]^2), Traits.Autonomous, Traits.Fixed)
        H1 = _H((x, p) -> 0.5*(3x[1]^2 + x[2]^2 + p[2]^2), Traits.Autonomous, Traits.Fixed)
        H2 = _H(
            (x, p) -> 0.5*(4x[1]^2 + x[2]^2 + p[1]^3 + p[2]^2),
            Traits.Autonomous,
            Traits.Fixed,
        )
        Test.@test (CTLie.@Lie {H0, H1}(_x2, _p2) + 4 * {H1, H2}(_x2, _p2)) ≈ -68.0 atol=1e-6
        Test.@test (CTLie.@Lie {H0, H1}(_x2, _p2) - {H1, H2}(_x2, _p2)) ≈ 22.0 atol=1e-6
        Test.@test (CTLie.@Lie {H0, H1}(_x2, _p2) * {H1, H2}(_x2, _p2)) ≈ -72.0 atol=1e-6
        Test.@test (CTLie.@Lie 4 +
            ({{H0, H1}, H1}(_x2, _p2) + -2*{H1, H2}(_x2, _p2) + 21)) ≈ 67.0 atol=1e-6
    end

    # =========================================================================
    Test.@testset "error — unknown keyword argument" verbose=VERBOSE showtiming=SHOWTIMING begin
        F0 = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        F1 = _VF(x -> [-x[2], x[1]], Traits.Autonomous, Traits.Fixed)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie [F0, F1] invalid_arg=true
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie [F0, F1] wrong_keyword=false
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie [F0, F1] something_else=42
    end

    # =========================================================================
    Test.@testset "lie macro — literal vector arguments in call, VectorFields" verbose=VERBOSE showtiming=SHOWTIMING begin
        F0 = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        F1 = _VF(x -> [-x[2], x[1]], Traits.Autonomous, Traits.Fixed)
        ref = CTLie.ad(F0, F1)
        # 2-element literal point (former source of the bug)
        Test.@test (CTLie.@Lie [F0, F1]([1.0, 2.0])) ≈ ref([1.0, 2.0]) atol=1e-6
        # 3-element literal point (already working, regression guard)
        F2 = _VF(x -> [x[2], x[3], -x[1]], Traits.Autonomous, Traits.Fixed)
        F3 = _VF(x -> [x[3], x[1], -x[2]], Traits.Autonomous, Traits.Fixed)
        ref3 = CTLie.ad(F2, F3)
        Test.@test (CTLie.@Lie [F2, F3]([1.0, 2.0, 3.0])) ≈ ref3([1.0, 2.0, 3.0]) atol=1e-6
    end

    # =========================================================================
    Test.@testset "poisson macro — literal vector arguments in call, Hamiltonians" verbose=VERBOSE showtiming=SHOWTIMING begin
        H0 = _H((x, p) -> 0.5*(2x[1]^2 + x[2]^2 + p[1]^2), Traits.Autonomous, Traits.Fixed)
        H1 = _H((x, p) -> 0.5*(3x[1]^2 + x[2]^2 + p[2]^2), Traits.Autonomous, Traits.Fixed)
        ref = CTLie.Poisson(H0, H1)
        # Two 2-element literal arguments (former source of the bug)
        Test.@test (CTLie.@Lie {H0, H1}([1.0, 2.0], [2.0, 1.0])) ≈
            ref([1.0, 2.0], [2.0, 1.0]) atol=1e-6
    end

    # =========================================================================
    Test.@testset "error — Hamiltonian in Lie bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = _H((x, p) -> p[1]*x[1], Traits.Autonomous, Traits.Fixed)
        F = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        # Both Hamiltonians
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie [H, H]
        # Mixed: Hamiltonian first, VectorField second
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie [H, F]
        # Mixed: VectorField first, Hamiltonian second
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie [F, H]
    end

    # =========================================================================
    Test.@testset "error — VectorField in Poisson bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        F = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        H = _H((x, p) -> p[1]*x[1], Traits.Autonomous, Traits.Fixed)
        # Both VectorFields
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie {F, F}
        # Mixed: VectorField first, Hamiltonian second
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie {F, H}
        # Mixed: Hamiltonian first, VectorField second
        Test.@test_throws Exceptions.IncorrectArgument CTLie.@Lie {H, F}
    end

    # =========================================================================
    Test.@testset "error — direct ad on Hamiltonians" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = _H((x, p) -> p[1]*x[1], Traits.Autonomous, Traits.Fixed)
        F = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.ad(H, H)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.ad(H, F)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.ad(F, H)
    end

    # =========================================================================
    Test.@testset "error — direct Poisson on VectorFields" verbose=VERBOSE showtiming=SHOWTIMING begin
        F = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        H = _H((x, p) -> p[1]*x[1], Traits.Autonomous, Traits.Fixed)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.Poisson(F, F)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.Poisson(F, H)
        Test.@test_throws Exceptions.IncorrectArgument CTLie.Poisson(H, F)
    end

    # =========================================================================
    Test.@testset "error — trait mismatches in Lie brackets" verbose=VERBOSE showtiming=SHOWTIMING begin
        F_aut = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        F_naut = _VF((t, x) -> [x[2], -x[1]], Traits.NonAutonomous, Traits.Fixed)
        F_fix = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        F_nfix = _VF((x, v) -> [x[2]+v, -x[1]], Traits.Autonomous, Traits.NonFixed)

        # Time-dependence mismatch between operands
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_aut, F_naut]
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_naut, F_aut]

        # Variable-dependence mismatch between operands
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_fix, F_nfix]
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_nfix, F_fix]

        # User flag conflicts with typed operands
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_aut, F_aut] is_autonomous=false
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_naut, F_naut] is_autonomous=true
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_fix, F_fix] is_variable=true
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [F_nfix, F_nfix] is_variable=false

        # Nested brackets — errors propagate
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [[F_aut, F_naut], F_aut]
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie [[F_aut, F_aut], F_naut]
    end

    # =========================================================================
    Test.@testset "error — trait mismatches in Poisson brackets" verbose=VERBOSE showtiming=SHOWTIMING begin
        H_aut = _H((x, p) -> x[1]^2+p[1]^2, Traits.Autonomous, Traits.Fixed)
        H_naut = _H((t, x, p) -> x[1]^2+p[1]^2, Traits.NonAutonomous, Traits.Fixed)
        H_fix = _H((x, p) -> x[1]^2+p[1]^2, Traits.Autonomous, Traits.Fixed)
        H_nfix = _H((x, p, v) -> x[1]^2+p[1]^2+v, Traits.Autonomous, Traits.NonFixed)

        # Time-dependence mismatch
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_aut, H_naut}
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_naut, H_aut}

        # Variable-dependence mismatch
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_fix, H_nfix}
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_nfix, H_fix}

        # User flag conflicts
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_aut, H_aut} is_autonomous=false
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_naut, H_naut} is_autonomous=true
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_fix, H_fix} is_variable=true
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {H_nfix, H_nfix} is_variable=false

        # Nested brackets — errors propagate
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {{H_aut, H_naut}, H_aut}
        Test.@test_throws Exceptions.PreconditionError CTLie.@Lie {{H_aut, H_aut}, H_naut}
    end

    # =========================================================================
    Test.@testset "valid cases — typed operands, consistent flags" verbose=VERBOSE showtiming=SHOWTIMING begin
        F_aut = _VF(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed)
        F_naut = _VF((t, x) -> [x[2], -x[1]], Traits.NonAutonomous, Traits.Fixed)
        F_nfix = _VF((x, v) -> [x[2]+v, -x[1]], Traits.Autonomous, Traits.NonFixed)
        H_aut = _H((x, p) -> x[1]^2+p[1]^2, Traits.Autonomous, Traits.Fixed)
        H_naut = _H((t, x, p) -> x[1]^2+p[1]^2, Traits.NonAutonomous, Traits.Fixed)

        f_func = x -> [x[2], -x[1]]
        h_func = (x, p) -> x[1]^2+p[1]^2

        Test.@test CTLie.@Lie [F_aut, F_aut] isa Data.VectorField
        Test.@test CTLie.@Lie [F_naut, F_naut] isa Data.VectorField
        Test.@test CTLie.@Lie [F_nfix, F_nfix] isa Data.VectorField

        # Consistent user flags accepted
        Test.@test (CTLie.@Lie [F_aut, F_aut] is_autonomous=true) isa Data.VectorField
        Test.@test (CTLie.@Lie [F_naut, F_naut] is_autonomous=false) isa Data.VectorField
        Test.@test (CTLie.@Lie [F_nfix, F_nfix] is_variable=true) isa Data.VectorField

        # Function + typed (function inherits trait from typed operand)
        Test.@test CTLie.@Lie [f_func, F_aut] isa Data.VectorField
        Test.@test CTLie.@Lie [F_aut, f_func] isa Data.VectorField
        Test.@test CTLie.@Lie [f_func, f_func] isa Data.VectorField

        # Poisson valid cases
        Test.@test CTLie.@Lie {H_aut, H_aut} isa Data.Hamiltonian
        Test.@test CTLie.@Lie {H_naut, H_naut} isa Data.Hamiltonian
        Test.@test CTLie.@Lie {h_func, H_aut} isa Data.Hamiltonian

        # Nested valid cases
        Test.@test CTLie.@Lie [[F_aut, F_aut], F_aut] isa Data.VectorField
        Test.@test CTLie.@Lie {{H_naut, H_naut}, H_naut} isa Data.Hamiltonian
    end

    # =========================================================================
    Test.@testset "@Lie ad_backend option" verbose=VERBOSE showtiming=SHOWTIMING begin
        f = x -> [x[2], 2x[1]]
        g = x -> [3x[2], -x[1]]
        X = _VF(f, Traits.Autonomous, Traits.Fixed)
        Y = _VF(g, Traits.Autonomous, Traits.Fixed)
        ref = CTLie.ad(X, Y)

        mac_fd = CTLie.@Lie [f, g] ad_backend=CTLie.__dg_ad_backend()
        Test.@test mac_fd(_x2) ≈ ref(_x2) atol=1e-6
    end
end

end # module TestMacroDG

test_macro_dg() = TestMacroDG.test_macro_dg()
