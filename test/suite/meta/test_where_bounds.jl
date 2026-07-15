"""
Regression guard for the `where`-clause bound-dropping pitfall (see
`.reports/2026-07-12_alias-where-bounds-audit.md` and the Handbook rule in
`philosophy/types-traits-interfaces.md#aliases-and-where`).

A `where {X}` clause that names a type parameter without repeating the bound the
struct (or the CTBase abstract type) already declares for it silently widens it
to `<:Any`. This is invisible via `isa` on concrete instances, but it breaks
Julia's method-specificity ranking the moment a competing method exists — either
mis-dispatching silently or throwing `MethodError: ... is ambiguous`.

CTLie has no parametric aliases, so the CTFlows-style `Alias <: Parent` guard
does not apply. Instead, for each method whose `where`-clause was tightened, this
test asserts that the induced `TypeVar`'s upper bound is the intended bound and
not `Any`. Two families are covered:

- Pattern A — the AD-backend parameter `B<:Differentiation.AbstractADBackend`
  carried by the six callable structs (call operators + `Base.show`).
- Pattern B — the CTBase trait bounds `TD<:TimeDependence`,
  `VD<:VariableDependence`, `MD<:AbstractMutabilityTrait` on the methods of
  `ad`, `Poisson`, `Lift`, `∂ₜ` that dispatch over CTBase abstract types.

A future edit that drops one of these bounds again fails loudly here.
"""

module TestWhereBounds

using Test: Test
using ForwardDiff: ForwardDiff  # load the DI ForwardDiff extension so the default backend builds
using DifferentiationInterface: DifferentiationInterface
import CTBase.Traits: Traits
import CTBase.Data: Data
import CTBase.Differentiation
import CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Upper bound of the `where`-var named `name` in method `m`'s signature. Returns
# `nothing` when no such var exists, which fails the `=== expected` assertions
# below just as a widened (`Any`) bound would.
function _where_ub(m::Method, name::Symbol)
    sig = m.sig
    while sig isa UnionAll
        sig.var.name === name && return sig.var.ub
        sig = sig.body
    end
    return nothing
end

function test_where_bounds()
    Test.@testset "where-clause bound-dropping regression guard" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ---------------------------------------------------------------------
        # Pattern A — B<:Differentiation.AbstractADBackend on the callable structs
        # ---------------------------------------------------------------------
        # One representative instance per struct; check the `B` upper bound on the
        # applicable call operator *and* on the two-argument `Base.show` method.
        bk = CTLie.dg_ad_backend()
        ad_inst = CTLie.ad(x -> [x[1]], x -> x[1]^2)                 # Ad{…,Autonomous,Fixed}
        pb_inst = CTLie.Poisson((x, p) -> x[1] * p[1], (x, p) -> x[1])  # PoissonBracket{…,Autonomous,Fixed}
        tdf_inst = CTLie.∂ₜ((t, x) -> t * x[1])                     # TimeDeriv_F
        hvf_inst = CTLie._∂ₜ_hvf(
            (t, x, p) -> (x, p), bk, Traits.NonAutonomous, Traits.Fixed
        )  # TimeDeriv_HVF
        vf_inst = CTLie._∂ₜ_vf((t, x) -> x, bk, Traits.NonAutonomous, Traits.Fixed)            # TimeDeriv_VF
        ham_inst = CTLie._∂ₜ_ham((t, x, p) -> t, bk, Traits.NonAutonomous, Traits.Fixed)       # TimeDeriv_Ham

        # (instance, argument-type tuple selecting its call operator)
        pattern_a = [
            ("Ad", ad_inst, Tuple{Vector{Float64}}),
            ("PoissonBracket", pb_inst, Tuple{Vector{Float64},Vector{Float64}}),
            ("TimeDeriv_F", tdf_inst, Tuple{Float64,Vector{Float64}}),
            ("TimeDeriv_HVF", hvf_inst, Tuple{Float64,Vector{Float64},Vector{Float64}}),
            ("TimeDeriv_VF", vf_inst, Tuple{Float64,Vector{Float64}}),
            ("TimeDeriv_Ham", ham_inst, Tuple{Float64,Vector{Float64},Vector{Float64}}),
        ]

        Test.@testset "Pattern A — B<:AbstractADBackend ($name)" for (name, inst, argt) in
                                                                     pattern_a
            # call operator
            Test.@test _where_ub(which(inst, argt), :B) ===
                Differentiation.AbstractADBackend
            # Base.show(io, ::Struct)
            Test.@test _where_ub(which(Base.show, Tuple{IO,typeof(inst)}), :B) ===
                Differentiation.AbstractADBackend
        end

        # ---------------------------------------------------------------------
        # Pattern B — CTBase trait bounds on ad / Poisson / Lift / ∂ₜ
        # ---------------------------------------------------------------------
        Vf = Data.VectorField(x -> [x[1]]; is_autonomous=true, is_variable=false)
        Hm = Data.Hamiltonian((x, p) -> x[1] * p[1], Traits.Autonomous, Traits.Fixed)

        Test.@testset "Pattern B — Lift(::AbstractVectorField)" begin
            m = which(CTLie.Lift, Tuple{Data.AbstractVectorField})
            Test.@test _where_ub(m, :TD) === Traits.TimeDependence
            Test.@test _where_ub(m, :VD) === Traits.VariableDependence
        end

        Test.@testset "Pattern B — ∂ₜ over CTBase abstract types" begin
            mh = which(CTLie.∂ₜ, Tuple{Data.AbstractHamiltonian})
            Test.@test _where_ub(mh, :TD) === Traits.TimeDependence
            Test.@test _where_ub(mh, :VD) === Traits.VariableDependence

            mv = which(CTLie.∂ₜ, Tuple{Data.AbstractVectorField})
            Test.@test _where_ub(mv, :TD) === Traits.TimeDependence
            Test.@test _where_ub(mv, :VD) === Traits.VariableDependence
            Test.@test _where_ub(mv, :MD) === Traits.AbstractMutabilityTrait

            mhvf = which(CTLie.∂ₜ, Tuple{Data.AbstractHamiltonianVectorField})
            Test.@test _where_ub(mhvf, :TD) === Traits.TimeDependence
            Test.@test _where_ub(mhvf, :VD) === Traits.VariableDependence
            Test.@test _where_ub(mhvf, :MD) === Traits.AbstractMutabilityTrait
        end

        Test.@testset "Pattern B — ad over AbstractVectorField" begin
            # matched TD/VD (diagonal) method — selected by two identically-typed operands
            mm = which(CTLie.ad, Tuple{typeof(Vf),typeof(Vf)})
            Test.@test _where_ub(mm, :TD) === Traits.TimeDependence
            Test.@test _where_ub(mm, :VD) === Traits.VariableDependence
            Test.@test _where_ub(mm, :MDX) === Traits.AbstractMutabilityTrait
            Test.@test _where_ub(mm, :MDY) === Traits.AbstractMutabilityTrait

            # Lie derivative method (vector field, scalar function)
            ms = which(CTLie.ad, Tuple{Data.AbstractVectorField,typeof(sin)})
            Test.@test _where_ub(ms, :TD) === Traits.TimeDependence
            Test.@test _where_ub(ms, :VD) === Traits.VariableDependence
            Test.@test _where_ub(ms, :MDX) === Traits.AbstractMutabilityTrait

            # mismatch (independent TD/VD) error method — selected by two general operands
            me = which(CTLie.ad, Tuple{Data.AbstractVectorField,Data.AbstractVectorField})
            Test.@test _where_ub(me, :TD1) === Traits.TimeDependence
            Test.@test _where_ub(me, :VD1) === Traits.VariableDependence
            Test.@test _where_ub(me, :MDX) === Traits.AbstractMutabilityTrait
            Test.@test _where_ub(me, :TD2) === Traits.TimeDependence
            Test.@test _where_ub(me, :VD2) === Traits.VariableDependence
            Test.@test _where_ub(me, :MDY) === Traits.AbstractMutabilityTrait
        end

        Test.@testset "Pattern B — Poisson over AbstractHamiltonian" begin
            # matched TD/VD (diagonal) method
            mm = which(CTLie.Poisson, Tuple{typeof(Hm),typeof(Hm)})
            Test.@test _where_ub(mm, :TD) === Traits.TimeDependence
            Test.@test _where_ub(mm, :VD) === Traits.VariableDependence

            # mismatch (independent TD/VD) error method
            me = which(
                CTLie.Poisson, Tuple{Data.AbstractHamiltonian,Data.AbstractHamiltonian}
            )
            Test.@test _where_ub(me, :TD1) === Traits.TimeDependence
            Test.@test _where_ub(me, :VD1) === Traits.VariableDependence
            Test.@test _where_ub(me, :TD2) === Traits.TimeDependence
            Test.@test _where_ub(me, :VD2) === Traits.VariableDependence
        end

        # Consistency: typed `::Type{TD}, ::Type{VD}` entry points now match `ad`.
        Test.@testset "Consistency — typed entry points of Poisson / Lift" begin
            mp = which(
                CTLie.Poisson,
                Tuple{typeof(sin),typeof(sin),Type{Traits.Autonomous},Type{Traits.Fixed}},
            )
            Test.@test _where_ub(mp, :TD) === Traits.TimeDependence
            Test.@test _where_ub(mp, :VD) === Traits.VariableDependence

            ml = which(
                CTLie.Lift, Tuple{typeof(sin),Type{Traits.Autonomous},Type{Traits.Fixed}}
            )
            Test.@test _where_ub(ml, :TD) === Traits.TimeDependence
            Test.@test _where_ub(ml, :VD) === Traits.VariableDependence
        end
    end
end

end # module

# CRITICAL: redefine in outer scope for TestRunner
test_where_bounds() = TestWhereBounds.test_where_bounds()
