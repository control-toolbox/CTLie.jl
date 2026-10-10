module TestMacroHelpersDG

using Test: Test
using ForwardDiff: ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
using CTBase: CTBase
using CTBase: Exceptions
using CTBase: Traits
using CTBase: Data
using CTLie: CTLie
using MacroTools: @capture
using DifferentiationInterface: DifferentiationInterface  # triggers CTBaseDifferentiationInterface — required for ad/Poisson in _lie_mac/_poisson_mac

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ─── Shared fixtures ───────────────────────────────────────────────────────

const _f1 = x -> [x[2], 0.0]
const _f2 = x -> [0.0, x[1]]
const _f_naut = (t, x) -> [x[2], 0.0]   # NonAutonomous
const _h1 = (x, p) -> p[1]^2 / 2
const _h2 = (x, p) -> x[1]

_vf(f, td, vd) = Data.VectorField(f, td, vd, Traits.OutOfPlace)
_ham(h, td, vd) = Data.Hamiltonian(h, td, vd)

# Strip LineNumberNodes from a :block expression to get the meaningful expressions
_exprs(blk) = filter(x -> !(x isa LineNumberNode), blk.args)

function test_macro_helpers_dg()

    # =========================================================================
    Test.@testset "__parse_lie_opts" verbose=VERBOSE showtiming=SHOWTIMING begin

        # Defaults
        opts, err = CTLie.__parse_lie_opts()
        Test.@test err === nothing
        Test.@test opts.TD === :Autonomous
        Test.@test opts.VD === :Fixed
        Test.@test opts.has_aut === false
        Test.@test opts.has_var === false
        # default backend: a call through a GlobalRef, not through the name `CTLie`
        Test.@test opts.backend == Expr(:call, GlobalRef(CTLie, :__dg_ad_backend))

        # is_autonomous = true
        opts, err = CTLie.__parse_lie_opts(Expr(:kw, :is_autonomous, true))
        Test.@test err === nothing
        Test.@test opts.TD === :Autonomous
        Test.@test opts.has_aut === true

        # is_autonomous = false
        opts, err = CTLie.__parse_lie_opts(Expr(:kw, :is_autonomous, false))
        Test.@test err === nothing
        Test.@test opts.TD === :NonAutonomous
        Test.@test opts.has_aut === true

        # is_variable = true
        opts, err = CTLie.__parse_lie_opts(Expr(:kw, :is_variable, true))
        Test.@test err === nothing
        Test.@test opts.VD === :NonFixed
        Test.@test opts.has_var === true

        # is_variable = false
        opts, err = CTLie.__parse_lie_opts(Expr(:kw, :is_variable, false))
        Test.@test err === nothing
        Test.@test opts.VD === :Fixed
        Test.@test opts.has_var === true

        # ad_backend
        opts, err = CTLie.__parse_lie_opts(Expr(:kw, :ad_backend, :MyBackend))
        Test.@test err === nothing
        Test.@test opts.backend === :MyBackend

        # Unknown kwarg → opts===nothing, err≠nothing
        opts, err = CTLie.__parse_lie_opts(Expr(:kw, :bad_kwarg, 42))
        Test.@test opts === nothing
        Test.@test err !== nothing

        # Valid combination: is_autonomous + is_variable
        opts, err = CTLie.__parse_lie_opts(
            Expr(:kw, :is_autonomous, true), Expr(:kw, :is_variable, true)
        )
        Test.@test err === nothing
        Test.@test opts.TD === :Autonomous
        Test.@test opts.VD === :NonFixed

        # Valid combination: is_autonomous=false + ad_backend
        opts, err = CTLie.__parse_lie_opts(
            Expr(:kw, :is_autonomous, false), Expr(:kw, :ad_backend, :Zygote)
        )
        Test.@test err === nothing
        Test.@test opts.TD === :NonAutonomous
        Test.@test opts.backend === :Zygote

        # One valid kwarg + one invalid → err≠nothing
        opts, err = CTLie.__parse_lie_opts(
            Expr(:kw, :is_autonomous, true), Expr(:kw, :nope, 0)
        )
        Test.@test opts === nothing
        Test.@test err !== nothing
    end

    # =========================================================================
    Test.@testset "__lie_error" verbose=VERBOSE showtiming=SHOWTIMING begin
        ex = CTLie.__lie_error("msg", "got", "expected", "ctx")
        # `throw` and the exception type are referenced by GlobalRef, never by name
        Test.@test ex.args[1] == GlobalRef(Base, :throw)
        Test.@test ex.args[2].args[1] == GlobalRef(Exceptions, :IncorrectArgument)

        e = Test.@test_throws Exceptions.IncorrectArgument Core.eval(@__MODULE__, ex)
        Test.@test e.value.msg == "msg"
        Test.@test e.value.got == "got"
        Test.@test e.value.expected == "expected"
        Test.@test e.value.context == "ctx"
    end

    # =========================================================================
    Test.@testset "__transform_brackets" verbose=VERBOSE showtiming=SHOWTIMING begin
        opts = (
            TD=:Autonomous,
            VD=:Fixed,
            has_aut=false,
            has_var=false,
            backend=Expr(:call, :__dg_ad_backend),
        )
        lie_ref = GlobalRef(CTLie, :_lie_mac)
        poisson_ref = GlobalRef(CTLie, :_poisson_mac)

        # [a,b] → _lie_mac call, referenced by GlobalRef (not by name), with traits and checks
        result = CTLie.__transform_brackets(quote
            [a, b]
        end, opts)
        call = only(_exprs(result))
        Test.@test call.head === :call
        Test.@test call.args[1] == lie_ref
        Test.@test call.args[2:3] == [:a, :b]
        Test.@test call.args[4] == GlobalRef(Traits, :Autonomous)
        Test.@test call.args[5] == GlobalRef(Traits, :Fixed)
        Test.@test call.args[6] === Val(false)
        Test.@test call.args[7] === Val(false)
        Test.@test call.args[8] == Expr(:call, :__dg_ad_backend)   # user-provided backend kept as is

        # {a,b} → _poisson_mac call
        result = CTLie.__transform_brackets(quote
            {a, b}
        end, opts)
        call = only(_exprs(result))
        Test.@test call.args[1] == poisson_ref
        Test.@test call.args[2:3] == [:a, :b]
        Test.@test call.args[4] == GlobalRef(Traits, :Autonomous)
        Test.@test call.args[5] == GlobalRef(Traits, :Fixed)

        # [[a,b], c] → outer _lie_mac whose first operand is an inner _lie_mac
        result = CTLie.__transform_brackets(quote
            [[a, b], c]
        end, opts)
        outer = only(_exprs(result))
        Test.@test outer.args[1] == lie_ref
        Test.@test outer.args[3] == :c
        inner = outer.args[2]
        Test.@test inner.args[1] == lie_ref
        Test.@test inner.args[2:3] == [:a, :b]

        # Expression without brackets → returned unchanged
        expr = quote
            a + b
        end
        result = CTLie.__transform_brackets(expr, opts)
        Test.@test result == expr

        # opts with NonAutonomous/NonFixed and checks on: propagated into the call
        opts2 = (
            TD=:NonAutonomous,
            VD=:NonFixed,
            has_aut=true,
            has_var=true,
            backend=Expr(:call, :__dg_ad_backend),
        )
        result2 = CTLie.__transform_brackets(quote
            [a, b]
        end, opts2)
        call2 = only(_exprs(result2))
        Test.@test call2.args[4] == GlobalRef(Traits, :NonAutonomous)
        Test.@test call2.args[5] == GlobalRef(Traits, :NonFixed)
        Test.@test call2.args[6] === Val(true)
        Test.@test call2.args[7] === Val(true)
    end

    # =========================================================================
    Test.@testset "_as_vf" verbose=VERBOSE showtiming=SHOWTIMING begin

        # Function → VectorField with correct traits
        vf = CTLie._as_vf(_f1, Traits.Autonomous, Traits.Fixed)
        Test.@test vf isa Data.VectorField
        Test.@test Traits.time_dependence(vf) === Traits.Autonomous
        Test.@test Traits.variable_dependence(vf) === Traits.Fixed

        # Function + NonAutonomous/NonFixed
        vf2 = CTLie._as_vf(_f_naut, Traits.NonAutonomous, Traits.NonFixed)
        Test.@test Traits.time_dependence(vf2) === Traits.NonAutonomous
        Test.@test Traits.variable_dependence(vf2) === Traits.NonFixed

        # Pass-through: an AbstractVectorField is returned identical (===)
        vf3 = _vf(_f1, Traits.NonAutonomous, Traits.Fixed)
        Test.@test CTLie._as_vf(vf3, Traits.Autonomous, Traits.Fixed) === vf3
    end

    # =========================================================================
    Test.@testset "_as_ham" verbose=VERBOSE showtiming=SHOWTIMING begin

        # Function → Hamiltonian with correct traits
        h = CTLie._as_ham(_h1, Traits.Autonomous, Traits.Fixed)
        Test.@test h isa Data.Hamiltonian
        Test.@test Traits.time_dependence(h) === Traits.Autonomous
        Test.@test Traits.variable_dependence(h) === Traits.Fixed

        # Function + NonAutonomous
        h2 = CTLie._as_ham(_h1, Traits.NonAutonomous, Traits.Fixed)
        Test.@test Traits.time_dependence(h2) === Traits.NonAutonomous

        # Pass-through: an AbstractHamiltonian is returned identical (===)
        ham = _ham(_h1, Traits.NonAutonomous, Traits.Fixed)
        Test.@test CTLie._as_ham(ham, Traits.Autonomous, Traits.Fixed) === ham
    end

    # =========================================================================
    Test.@testset "_check_td" verbose=VERBOSE showtiming=SHOWTIMING begin
        vf_auto = _vf(_f1, Traits.Autonomous, Traits.Fixed)
        vf_nonaut = _vf(_f_naut, Traits.NonAutonomous, Traits.Fixed)

        # Function → always nothing (Val{true} or Val{false})
        Test.@test CTLie._check_td(_f1, Traits.Autonomous, Val{false}()) === nothing
        Test.@test CTLie._check_td(_f1, Traits.NonAutonomous, Val{true}()) === nothing

        # Val{false} (no override) → always nothing, regardless of declared TD
        Test.@test CTLie._check_td(vf_auto, Traits.Autonomous, Val{false}()) === nothing
        Test.@test CTLie._check_td(vf_auto, Traits.NonAutonomous, Val{false}()) === nothing
        Test.@test CTLie._check_td(vf_nonaut, Traits.Autonomous, Val{false}()) === nothing

        # Val{true} + consistent TD → nothing
        Test.@test CTLie._check_td(vf_auto, Traits.Autonomous, Val{true}()) === nothing
        Test.@test CTLie._check_td(vf_nonaut, Traits.NonAutonomous, Val{true}()) === nothing

        # Val{true} + inconsistent TD → PreconditionError
        Test.@test_throws Exceptions.PreconditionError CTLie._check_td(
            vf_auto, Traits.NonAutonomous, Val{true}()
        )
        Test.@test_throws Exceptions.PreconditionError CTLie._check_td(
            vf_nonaut, Traits.Autonomous, Val{true}()
        )
    end

    # =========================================================================
    Test.@testset "_check_vd" verbose=VERBOSE showtiming=SHOWTIMING begin
        vf_fixed = _vf(_f1, Traits.Autonomous, Traits.Fixed)
        vf_nonfixed = _vf((x, v) -> _f1(x), Traits.Autonomous, Traits.NonFixed)

        # Function → always nothing
        Test.@test CTLie._check_vd(_f1, Traits.Fixed, Val{false}()) === nothing
        Test.@test CTLie._check_vd(_f1, Traits.NonFixed, Val{true}()) === nothing

        # Val{false} → always nothing
        Test.@test CTLie._check_vd(vf_fixed, Traits.Fixed, Val{false}()) === nothing
        Test.@test CTLie._check_vd(vf_fixed, Traits.NonFixed, Val{false}()) === nothing
        Test.@test CTLie._check_vd(vf_nonfixed, Traits.Fixed, Val{false}()) === nothing

        # Val{true} + consistent VD → nothing
        Test.@test CTLie._check_vd(vf_fixed, Traits.Fixed, Val{true}()) === nothing
        Test.@test CTLie._check_vd(vf_nonfixed, Traits.NonFixed, Val{true}()) === nothing

        # Val{true} + inconsistent VD → PreconditionError
        Test.@test_throws Exceptions.PreconditionError CTLie._check_vd(
            vf_fixed, Traits.NonFixed, Val{true}()
        )
        Test.@test_throws Exceptions.PreconditionError CTLie._check_vd(
            vf_nonfixed, Traits.Fixed, Val{true}()
        )
    end

    # =========================================================================
    Test.@testset "_lie_mac" verbose=VERBOSE showtiming=SHOWTIMING begin
        vf1 = _vf(_f1, Traits.Autonomous, Traits.Fixed)
        vf2 = _vf(_f2, Traits.Autonomous, Traits.Fixed)
        backend = CTBase.Core.NotProvided

        # Function + Function → VectorField
        r = CTLie._lie_mac(
            _f1, _f2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r isa Data.VectorField

        # VectorField + VectorField (no override) → VectorField
        r = CTLie._lie_mac(
            vf1, vf2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r isa Data.VectorField

        # VectorField + VectorField with consistent override
        r = CTLie._lie_mac(
            vf1, vf2, Traits.Autonomous, Traits.Fixed, Val{true}(), Val{false}(), backend
        )
        Test.@test r isa Data.VectorField

        # Function + VectorField (mixed types)
        r = CTLie._lie_mac(
            _f1, vf2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r isa Data.VectorField

        # Inconsistent override on TD → PreconditionError
        Test.@test_throws Exceptions.PreconditionError CTLie._lie_mac(
            vf1, vf2, Traits.NonAutonomous, Traits.Fixed, Val{true}(), Val{false}(), backend
        )

        # Inconsistent override on VD → PreconditionError
        Test.@test_throws Exceptions.PreconditionError CTLie._lie_mac(
            vf1, vf2, Traits.Autonomous, Traits.NonFixed, Val{false}(), Val{true}(), backend
        )

        # Antisymmetry: [f1, f2] = -[f2, f1] at a test point
        r12 = CTLie._lie_mac(
            _f1, _f2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        r21 = CTLie._lie_mac(
            _f2, _f1, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        x0 = [1.0, 2.0]
        Test.@test r12(x0) ≈ -r21(x0)

        # Error: Hamiltonian in Lie bracket (both positions)
        ham = _ham(_h1, Traits.Autonomous, Traits.Fixed)
        Test.@test_throws Exceptions.IncorrectArgument CTLie._lie_mac(
            ham, ham, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test_throws Exceptions.IncorrectArgument CTLie._lie_mac(
            ham, _f1, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test_throws Exceptions.IncorrectArgument CTLie._lie_mac(
            _f1, ham, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )

        # Fallback: data literals reconstruct vector
        r = CTLie._lie_mac(
            1, 2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r == [1, 2]
    end

    # =========================================================================
    Test.@testset "_poisson_mac" verbose=VERBOSE showtiming=SHOWTIMING begin
        ham1 = _ham(_h1, Traits.Autonomous, Traits.Fixed)
        ham2 = _ham(_h2, Traits.Autonomous, Traits.Fixed)
        backend = CTBase.Core.NotProvided

        # Function + Function → Hamiltonian
        r = CTLie._poisson_mac(
            _h1, _h2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r isa Data.Hamiltonian

        # Hamiltonian + Hamiltonian (no override)
        r = CTLie._poisson_mac(
            ham1, ham2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r isa Data.Hamiltonian

        # Hamiltonian + Hamiltonian with consistent override
        r = CTLie._poisson_mac(
            ham1, ham2, Traits.Autonomous, Traits.Fixed, Val{true}(), Val{false}(), backend
        )
        Test.@test r isa Data.Hamiltonian

        # Function + Hamiltonian (mixed types)
        r = CTLie._poisson_mac(
            _h1, ham2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test r isa Data.Hamiltonian

        # Inconsistent override on TD → PreconditionError
        Test.@test_throws Exceptions.PreconditionError CTLie._poisson_mac(
            ham1,
            ham2,
            Traits.NonAutonomous,
            Traits.Fixed,
            Val{true}(),
            Val{false}(),
            backend,
        )

        # Inconsistent override on VD → PreconditionError
        Test.@test_throws Exceptions.PreconditionError CTLie._poisson_mac(
            ham1,
            ham2,
            Traits.Autonomous,
            Traits.NonFixed,
            Val{false}(),
            Val{true}(),
            backend,
        )

        # Antisymmetry: {h1, h2} = -{h2, h1} at a test point
        r12 = CTLie._poisson_mac(
            _h1, _h2, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        r21 = CTLie._poisson_mac(
            _h2, _h1, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        x0, p0 = [1.0, 2.0], [0.5, 1.5]
        Test.@test r12(x0, p0) ≈ -r21(x0, p0)

        # Error: VectorField in Poisson bracket (both positions)
        vf = _vf(_f1, Traits.Autonomous, Traits.Fixed)
        Test.@test_throws Exceptions.IncorrectArgument CTLie._poisson_mac(
            vf, vf, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test_throws Exceptions.IncorrectArgument CTLie._poisson_mac(
            vf, _h1, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
        Test.@test_throws Exceptions.IncorrectArgument CTLie._poisson_mac(
            _h1, vf, Traits.Autonomous, Traits.Fixed, Val{false}(), Val{false}(), backend
        )
    end
end # function

end # module

test_macro_helpers_dg() = TestMacroHelpersDG.test_macro_helpers_dg()
