module TestMacroHygieneDG

using Test: Test
using ForwardDiff: ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
using CTBase: Exceptions
using CTBase: Traits
using CTBase: Data
using CTLie: CTLie
using DifferentiationInterface: DifferentiationInterface  # triggers CTBaseDifferentiationInterface extension

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ─── Fake caller modules (top-level, never inside the test function) ────────
#
# `@Lie` must expand to code that does not depend on any name bound in the caller's
# module. These modules play the caller; neither binds `CTLie` nor `CTBase`.

const _OPERANDS = quote
    X(x) = [x[2], -x[1]]
    Y(x) = [x[1]^2, x[2]^2]
    Xn(t, x) = [t * x[2], -x[1]]
    Yn(t, x) = [x[1]^2, t * x[2]^2]
    H(x, p) = p[1]^2 / 2 + x[1]^2
    G(x, p) = x[1] * p[1]
end

# Callers: `HygieneBare` imports only the macro; `HygieneDecoy` also defines decoys for
# every name a non-hygienic expansion would resolve in the caller (CTLie, CTBase, Val, throw).
for (name, decoys) in (
    (:HygieneBare, :(nothing)),
    (
        :HygieneDecoy,
        quote
            const CTLie = "not the CTLie module"
            const CTBase = "not the CTBase module"
            const Val = x -> error("shadowed Val must not be called by @Lie")
            const throw = x -> error("shadowed throw must not be called by @Lie")
        end,
    ),
)
    @eval module $name
        using CTLie: @Lie
        $decoys
        $(_OPERANDS.args...)

        lie_xy() = @Lie [X, Y]
        lie_nested() = @Lie [[X, Y], X]
        lie_naut() = @Lie [Xn, Yn] is_autonomous=false
        poisson_hg() = @Lie {H, G}
        unknown_kw() = @Lie [X, Y] bad_kw=1
        bad_arg() = @Lie [X, Y] oops
    end
end

# All bare symbols of an expression (GlobalRefs, literals and line numbers are skipped)
_symbols(ex) = _symbols!(Set{Symbol}(), ex)
_symbols!(names, s::Symbol) = push!(names, s)
_symbols!(names, e::Expr) = (foreach(a -> _symbols!(names, a), e.args); names)
_symbols!(names, ::Any) = names

function test_macro_hygiene_dg()
    x0 = [1.0, 2.0]
    p0 = [3.0, 4.0]
    t0 = 0.5

    vf(f) = Data.VectorField(f, Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)
    vfn(f) = Data.VectorField(f, Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace)
    ham(f) = Data.Hamiltonian(f, Traits.Autonomous, Traits.Fixed)

    for M in (HygieneBare, HygieneDecoy)
        # =====================================================================
        Test.@testset "$(nameof(M)) — caller binds neither CTLie nor CTBase correctly" verbose=VERBOSE showtiming=SHOWTIMING begin
            if M === HygieneBare
                Test.@test !isdefined(M, :CTLie)
                Test.@test !isdefined(M, :CTBase)
            else
                Test.@test M.CTLie isa String
                Test.@test M.CTBase isa String
            end
        end

        # =====================================================================
        Test.@testset "$(nameof(M)) — Lie bracket [X, Y]" verbose=VERBOSE showtiming=SHOWTIMING begin
            ref = CTLie.ad(vf(M.X), vf(M.Y))
            Test.@test M.lie_xy()(x0) ≈ ref(x0) atol=1e-6
        end

        Test.@testset "$(nameof(M)) — nested Lie bracket [[X, Y], X]" verbose=VERBOSE showtiming=SHOWTIMING begin
            ref = CTLie.ad(CTLie.ad(vf(M.X), vf(M.Y)), vf(M.X))
            Test.@test M.lie_nested()(x0) ≈ ref(x0) atol=1e-6
        end

        Test.@testset "$(nameof(M)) — Lie bracket with is_autonomous=false" verbose=VERBOSE showtiming=SHOWTIMING begin
            ref = CTLie.ad(vfn(M.Xn), vfn(M.Yn))
            Test.@test M.lie_naut()(t0, x0) ≈ ref(t0, x0) atol=1e-6
        end

        Test.@testset "$(nameof(M)) — Poisson bracket {H, G}" verbose=VERBOSE showtiming=SHOWTIMING begin
            ref = CTLie.Poisson(ham(M.H), ham(M.G))
            Test.@test M.poisson_hg()(x0, p0) ≈ ref(x0, p0) atol=1e-6
        end

        # =====================================================================
        Test.@testset "$(nameof(M)) — error paths do not need CTBase" verbose=VERBOSE showtiming=SHOWTIMING begin
            e = Test.@test_throws Exceptions.IncorrectArgument M.unknown_kw()
            Test.@test e.value.got == "bad_kw"
            e = Test.@test_throws Exceptions.IncorrectArgument M.bad_arg()
            Test.@test e.value.got == "oops"
        end

        # =====================================================================
        Test.@testset "$(nameof(M)) — expansion holds no bare caller-resolved name" verbose=VERBOSE showtiming=SHOWTIMING begin
            for ex in (
                :(@Lie [X, Y]),
                :(@Lie {H, G}),
                :(@Lie [X, Y] is_autonomous=false is_variable=true),
                :(@Lie [X, Y] bad_kw=1),
                :(@Lie [X, Y] oops),
            )
                names = _symbols(macroexpand(M, ex))
                for forbidden in (:CTLie, :CTBase, :Val, :throw)
                    Test.@test forbidden ∉ names
                end
            end
        end
    end
end

end # module TestMacroHygieneDG

test_macro_hygiene_dg() = TestMacroHygieneDG.test_macro_hygiene_dg()
