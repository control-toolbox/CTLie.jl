module TestPerformance

# ==============================================================================
# Performance contract — deterministic allocation guards
# ==============================================================================
#
# Type stability is guarded separately by `Test.@inferred`, next to each
# fixture in the testset that owns it (test_ad_dg.jl, test_lift_dg.jl,
# test_poisson_dg.jl, test_time_derivative_dg.jl) — see the Handbook's
# philosophy/performance.md. This file guards the complementary, independent
# property: a call can stay fully inferable yet start allocating (a stray
# `collect`, a boxed closure, an abstract field). Allocation counts are
# DETERMINISTIC (no run-to-run noise, no machine dependence), so `== 0` /
# wrapper-vs-raw equality are robust assertions — never assert wall-clock time.
#
# CTLie's operators split into two families (see
# `.reports/2026-07-15_performance-verification-adoption.md` §5):
#   - Algebraic operators (`Lift`, autonomous `∂ₜ`) never call AD — they must
#     add ZERO overhead over the equivalent raw hand-written computation.
#   - AD operators (`ad`, `Poisson`, non-autonomous `∂ₜ`) allocate their
#     derivative buffers by necessity — the invariant here is
#     "wrapper allocates exactly what the equivalent raw AD call does", not
#     `== 0`. Comparing against a magic byte constant would be Julia-version-
#     and word-size-dependent; comparing wrapper-vs-raw is not.
#
# Raw comparators are hand-specialized CALLABLE STRUCTS with concrete fields,
# not generic free functions taking `X`/`foo`/`backend` as arguments (verified
# at the REPL on 2026-07-15): passing a function as a generic argument to a
# free comparator function measurably changes allocation behaviour relative to
# a concrete struct field access — an artifact of the comparison, not of the
# wrapper. Mirroring the wrapper's own field-storage shape is what makes the
# comparison honest (same pattern as `test_where_bounds.jl`'s emphasis on
# concrete struct fields for inference).
# ==============================================================================

using Test: Test
using BenchmarkTools: BenchmarkTools
using ForwardDiff: ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
using DifferentiationInterface: DifferentiationInterface
import CTBase.Data: Data
import CTBase.Differentiation
import CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# TOP-LEVEL: raw functions/computations to compare against (never define these
# inside the test function — see philosophy/performance.md).
_X_raw(x) = [x[2], -x[1]]
_Y_raw(x) = [x[1], x[2]]
_f_raw(x) = x[1]^2 + x[2]^2
_H_raw(x, p) = p[1]^2 / 2 + x[1]^2
_G_raw(x, p) = x[1] * p[1]
_dtf_raw(t, x) = t^2 + x[1]
_X_na_raw(t, x) = [t * x[2], -x[1]]

_lift_raw(x, p) = p' * _X_raw(x)

# Hand-specialized mirror of `Ad`'s Autonomous/Fixed scalar-`foo` call operator
# (ad.jl): a single pushforward `J_foo(x)·X(x)`, without the general
# `_ad_bracket`/`Val(Slot)`/`ntuple` machinery (that machinery only matters
# once `foo` returns a vector — see the bracket comment below).
struct _LieDerivMirror{TX,TF,B}
    X::TX
    foo::TF
    backend::B
end
function (m::_LieDerivMirror)(x)
    return Differentiation.pushforward(m.backend, m.foo, Val(1), x, m.X(x))
end

# Hand-specialized mirror of `Ad`'s Autonomous/Fixed vector-`foo` call operator
# (ad.jl), i.e. the Lie *bracket*: two pushforwards + subtraction, written
# straight-line without the general `_ad_bracket`/`Val(Slot)`/`ntuple`
# machinery. The wrapper must allocate exactly this much — this guard is what
# caught (and now locks in the fix for) the pass-through-function
# specialization gap in `_ad_bracket` (`X::TX where {TX}`, see ad.jl).
struct _LieBracketMirror{TX,TY,B}
    X::TX
    Y::TY
    backend::B
end
function (m::_LieBracketMirror)(x)
    Xx = m.X(x)
    dfoo = Differentiation.pushforward(m.backend, m.Y, Val(1), x, Xx)
    Yx = m.Y(x)
    dX = Differentiation.pushforward(m.backend, m.X, Val(1), x, Yx)
    return dfoo - dX
end

# Hand-specialized mirror of `PoissonBracket`'s Autonomous/Fixed call operator
# (poisson.jl): four partial derivatives via `Differentiation.differentiate`.
struct _PoissonMirror{FH,FG,B}
    H::FH
    G::FG
    backend::B
end
function (m::_PoissonMirror)(x, p)
    gxH = Differentiation.differentiate(m.backend, m.H, Val(1), x, p)
    gpH = Differentiation.differentiate(m.backend, m.H, Val(2), p, x)
    gxG = Differentiation.differentiate(m.backend, m.G, Val(1), x, p)
    gpG = Differentiation.differentiate(m.backend, m.G, Val(2), p, x)
    return gpH' * gxG - gxH' * gpG
end

# Hand-specialized mirror of `TimeDeriv_VF`'s NonAutonomous/Fixed call operator
# (time_derivative.jl): a single `differentiate` w.r.t. slot 1 (time).
struct _DtVFMirror{FX,B}
    X::FX
    b::B
end
(m::_DtVFMirror)(t, x) = Differentiation.differentiate(m.b, m.X, Val(1), t, x)

function test_performance()
    Test.@testset verbose = VERBOSE showtiming = SHOWTIMING "Performance contract" begin
        x0 = [1.0, 2.0]
        p0 = [0.5, 1.0]
        t0 = 3.0
        bk = CTLie.dg_ad_backend()

        # ======================================================================
        # 1. Zero-overhead algebraic wrappers (no AD): wrapper == raw
        # ======================================================================
        Test.@testset "Zero-overhead algebraic wrappers" begin
            # Lift(f)(x,p) = p' * f(x) — pure algebra, no AD.
            H = CTLie.Lift(_X_raw)
            Test.@test (BenchmarkTools.@ballocated $H($x0, $p0)) ==
                (BenchmarkTools.@ballocated _lift_raw($x0, $p0))

            # ∂ₜ of an Autonomous VectorField is `zero.(X(x))` — no AD.
            Xvf = Data.VectorField(_X_raw; is_autonomous=true, is_variable=false)
            dXvf = CTLie.∂ₜ(Xvf)
            Test.@test (BenchmarkTools.@ballocated $dXvf(0.0, $x0)) ==
                (BenchmarkTools.@ballocated zero.(_X_raw($x0)))

            # ∂ₜ of an Autonomous Hamiltonian is `zero(H(x,p))` — no AD.
            Hh = Data.Hamiltonian(_H_raw; is_autonomous=true, is_variable=false)
            dHh = CTLie.∂ₜ(Hh)
            Test.@test (BenchmarkTools.@ballocated $dHh(0.0, $x0, $p0)) ==
                (BenchmarkTools.@ballocated zero(_H_raw($x0, $p0)))
        end

        # ======================================================================
        # 2. Zero-allocation reads
        # ======================================================================
        Test.@testset "Zero-allocation reads" begin
            # ∂ₜ of a scalar-output generic function allocates nothing.
            df = CTLie.∂ₜ(_dtf_raw)
            Test.@test (BenchmarkTools.@ballocated $df($t0, $x0)) == 0
        end

        # ======================================================================
        # 3. AD operators: wrapper allocates exactly what the raw AD call does
        # ======================================================================
        Test.@testset "Wrapper-vs-raw AD allocations" begin
            # ad(X, f) — Lie derivative: one pushforward.
            L = CTLie.ad(_X_raw, _f_raw)
            mL = _LieDerivMirror(_X_raw, _f_raw, bk)
            Test.@test (BenchmarkTools.@ballocated $L($x0)) ==
                (BenchmarkTools.@ballocated $mL($x0))

            # ad(X, Y) — Lie bracket: two pushforwards + subtraction. This
            # equality holds because `_ad_bracket` forces specialization on its
            # pass-through `X` argument (`X::TX where {TX}`, ad.jl); without
            # that annotation Julia compiles it unspecialized on `typeof(X)`
            # and the wrapper allocates 32–48 B more than this raw floor.
            Bk = CTLie.ad(_X_raw, _Y_raw)
            mBk = _LieBracketMirror(_X_raw, _Y_raw, bk)
            Test.@test (BenchmarkTools.@ballocated $Bk($x0)) ==
                (BenchmarkTools.@ballocated $mBk($x0))

            # Poisson(H, G) — four partial derivatives.
            PB = CTLie.Poisson(_H_raw, _G_raw)
            mPB = _PoissonMirror(_H_raw, _G_raw, bk)
            Test.@test (BenchmarkTools.@ballocated $PB($x0, $p0)) ==
                (BenchmarkTools.@ballocated $mPB($x0, $p0))

            # ∂ₜ of a NonAutonomous VectorField — one `differentiate` call.
            Xvf_na = Data.VectorField(_X_na_raw; is_autonomous=false, is_variable=false)
            dXvf_na = CTLie.∂ₜ(Xvf_na)
            mDt = _DtVFMirror(_X_na_raw, bk)
            Test.@test (BenchmarkTools.@ballocated $dXvf_na($t0, $x0)) ==
                (BenchmarkTools.@ballocated $mDt($t0, $x0))
        end
    end
    return nothing
end

end # module TestPerformance

# CRITICAL: redefine in outer scope so the test runner can call it
test_performance() = TestPerformance.test_performance()
