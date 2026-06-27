module TestPoissonDG

import Test
import ForwardDiff  # ensure DI ForwardDiff extension is loaded (AutoForwardDiff backend)
import CTBase.Exceptions
import DifferentiationInterface
import ADTypes: ADTypes
import CTBase.Traits: Traits
import CTBase.Data: Data
import CTLie: CTLie
import CTBase.Differentiation

const VERBOSE    = isdefined(Main, :TestData) ? Main.TestData.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_poisson_dg()
    Test.@testset "Poisson() - anticommutativité" verbose=VERBOSE showtiming=SHOWTIMING begin
        # {H, G} = -{G, H}
        H(x, p) = p[1]^2 / 2 + x[1]
        G(x, p) = p[2]^2 / 2 + x[2]
        PH = CTLie.Poisson(H, G)
        PG = CTLie.Poisson(G, H)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test PH(x0, p0) ≈ -PG(x0, p0) atol=1e-6
    end

    Test.@testset "Poisson() - correctness" verbose=VERBOSE showtiming=SHOWTIMING begin
        # {x1, p1} = 1, {x1, x2} = 0
        H(x, p) = x[1]   # ∇pH = 0, ∇xH = [1,0]
        G(x, p) = p[1]   # ∇pG = [1,0], ∇xG = 0
        # {H,G} = ∇pH · ∇xG - ∇xH · ∇pG = 0·0 - [1,0]·[1,0] = -1
        PB = CTLie.Poisson(H, G)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test PB(x0, p0) ≈ -1.0 atol=1e-6
    end

    Test.@testset "Poisson() - concrete type PoissonBracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = p[1]^2 / 2 + x[1]
        G(x, p) = p[2]^2 / 2 + x[2]
        PB = CTLie.Poisson(H, G)
        Test.@test PB isa CTLie.PoissonBracket
        Test.@test PB isa CTLie.PoissonBracket{typeof(H), typeof(G), <:Differentiation.AbstractADBackend, Traits.Autonomous, Traits.Fixed}
    end

    Test.@testset "Poisson() - valeur correcte NonAutonomous/Fixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        # {H,G} with H(t,x,p)=t*p[1], G(t,x,p)=x[1]
        # ∂H/∂p=[t,0], ∂H/∂x=0, ∂G/∂p=0, ∂G/∂x=[1,0]
        # {H,G} = ∂H/∂p · ∂G/∂x - ∂H/∂x · ∂G/∂p = t*1 - 0 = t
        H(t, x, p) = t * p[1]
        G(t, x, p) = x[1]
        PB = CTLie.Poisson(H, G; is_autonomous=false, is_variable=false)
        t0 = 3.0; x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test PB(t0, x0, p0) ≈ t0 atol=1e-6
    end

    Test.@testset "Poisson() - valeur correcte Autonomous/NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        # H(x,p,v)=v[1]*p[1], G(x,p,v)=x[1]
        # {H,G} = v[1]
        H(x, p, v) = v[1] * p[1]
        G(x, p, v) = x[1]
        PB = CTLie.Poisson(H, G; is_autonomous=true, is_variable=true)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]; v0 = [2.0]
        Test.@test PB(x0, p0, v0) ≈ v0[1] atol=1e-6
    end

    Test.@testset "Poisson() - valeur correcte NonAutonomous/NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        # H(t,x,p,v)=t*v[1]*p[1], G(t,x,p,v)=x[1]
        # {H,G} = t*v[1]
        H(t, x, p, v) = t * v[1] * p[1]
        G(t, x, p, v) = x[1]
        PB = CTLie.Poisson(H, G; is_autonomous=false, is_variable=true)
        t0 = 3.0; x0 = [1.0, 2.0]; p0 = [0.5, 1.0]; v0 = [2.0]
        Test.@test PB(t0, x0, p0, v0) ≈ t0 * v0[1] atol=1e-6
    end

    Test.@testset "Poisson() - AbstractHamiltonian → Data.Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p) -> p[1]^2 / 2; is_autonomous=true, is_variable=false)
        G = Data.Hamiltonian((x, p) -> x[1]; is_autonomous=true, is_variable=false)
        PB = CTLie.Poisson(H, G)

        Test.@test PB isa Data.Hamiltonian
        Test.@test PB isa Data.AbstractHamiltonian{Traits.Autonomous, Traits.Fixed}
    end

    Test.@testset "Poisson() - TD/VD mismatch → PreconditionError" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p) -> p[1]^2; is_autonomous=true, is_variable=false)
        G = Data.Hamiltonian((t, x, p) -> x[1]; is_autonomous=false, is_variable=false)
        Test.@test_throws Exceptions.PreconditionError CTLie.Poisson(H, G)
    end

    Test.@testset "Poisson() - type stability (Autonomous/Fixed)" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = p[1]^2 / 2 + x[1]^2
        G(x, p) = x[1] * p[1]
        PB = CTLie.Poisson(H, G)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test (Test.@inferred PB(x0, p0)) isa Float64
    end

    Test.@testset "Poisson() - type stability (Autonomous/NonFixed)" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p, v) = v[1] * p[1]^2 / 2 + x[1]^2
        G(x, p, v) = x[1] * p[1]
        PB = CTLie.Poisson(H, G; is_autonomous=true, is_variable=true)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]; v0 = [2.0]
        Test.@test (Test.@inferred PB(x0, p0, v0)) isa Float64
    end

    Test.@testset "Poisson() - ad_backend parameter" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = p[1]^2 / 2 + x[1]
        G(x, p) = p[2]^2 / 2 + x[2]
        backend = ADTypes.AutoForwardDiff()
        PB = CTLie.Poisson(H, G; ad_backend=backend)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        val = PB(x0, p0)
        Test.@test val isa Number
    end

    Test.@testset "Poisson() - Type-Based API" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = p[1]^2 / 2 + x[1]
        G(x, p) = p[2]^2 / 2 + x[2]

        # Autonomous, Fixed
        PB_af_typed = CTLie.Poisson(H, G, Traits.Autonomous, Traits.Fixed)
        PB_af_kwargs = CTLie.Poisson(H, G; is_autonomous=true, is_variable=false)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test PB_af_typed(x0, p0) ≈ PB_af_kwargs(x0, p0) atol=1e-6

        # NonAutonomous, Fixed
        H_na(t, x, p) = t + p[1]^2 / 2 + x[1]
        G_na(t, x, p) = p[2]^2 / 2 + x[2]
        PB_naf_typed = CTLie.Poisson(H_na, G_na, Traits.NonAutonomous, Traits.Fixed)
        PB_naf_kwargs = CTLie.Poisson(H_na, G_na; is_autonomous=false, is_variable=false)
        t0 = 2.0
        Test.@test PB_naf_typed(t0, x0, p0) ≈ PB_naf_kwargs(t0, x0, p0) atol=1e-6

        # Autonomous, NonFixed
        H_anf(x, p, v) = v[1] * p[1]^2 / 2 + x[1]
        G_anf(x, p, v) = v[1] * p[2]^2 / 2 + x[2]
        PB_anf_typed = CTLie.Poisson(H_anf, G_anf, Traits.Autonomous, Traits.NonFixed)
        PB_anf_kwargs = CTLie.Poisson(H_anf, G_anf; is_autonomous=true, is_variable=true)
        v0 = [2.0]
        Test.@test PB_anf_typed(x0, p0, v0) ≈ PB_anf_kwargs(x0, p0, v0) atol=1e-6

        # NonAutonomous, NonFixed
        H_nanf(t, x, p, v) = t * v[1] * p[1]^2 / 2 + x[1]
        G_nanf(t, x, p, v) = t * v[1] * p[2]^2 / 2 + x[2]
        PB_nanf_typed = CTLie.Poisson(H_nanf, G_nanf, Traits.NonAutonomous, Traits.NonFixed)
        PB_nanf_kwargs = CTLie.Poisson(H_nanf, G_nanf; is_autonomous=false, is_variable=true)
        Test.@test PB_nanf_typed(t0, x0, p0, v0) ≈ PB_nanf_kwargs(t0, x0, p0, v0) atol=1e-6
    end

    Test.@testset "Poisson() - scalar case" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = 0.5 * (p^2 + x^2)
        G(x, p) = x
        PB = CTLie.Poisson(H, G)
        x0 = 1.0; p0 = 3.0
        # {H, G} = ∂H/∂p * ∂G/∂x - ∂H/∂x * ∂G/∂p = p * 1 - x * 0 = p
        Test.@test PB(x0, p0) ≈ 3.0 atol=1e-6
    end

    Test.@testset "Poisson() - Mathematical Properties" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Setup test functions
        f(x, p) = x[2]^2 + 2x[1]^2 + p[1]^2
        g(x, p) = 3x[2]^2 + -x[1]^2 + p[2]^2 + p[1]
        h(x, p) = x[2]^2 + -2x[1]^2 + p[1]^2 - 2p[2]^2
        f_plus_g(x, p) = f(x, p) + g(x, p)
        f_times_g(x, p) = f(x, p) * g(x, p)
        const_42(x, p) = 42.0

        x_test = [1.0, 2.0]
        p_test = [2.0, 1.0]

        # Property 1: Constant function has zero Poisson bracket
        Test.@test CTLie.Poisson(f, const_42)(x_test, p_test) ≈ 0.0 atol=1e-10

        # Property 2: Anticommutativity - {F, G} = -{G, F}
        PB_fg = CTLie.Poisson(f, g)(x_test, p_test)
        PB_gf = CTLie.Poisson(g, f)(x_test, p_test)
        Test.@test PB_fg ≈ -PB_gf atol=1e-10

        # Property 3: Bilinearity (left) - {F+G, H} = {F, H} + {G, H}
        PB_fpg_h = CTLie.Poisson(f_plus_g, h)(x_test, p_test)
        PB_f_h = CTLie.Poisson(f, h)(x_test, p_test)
        PB_g_h = CTLie.Poisson(g, h)(x_test, p_test)
        Test.@test PB_fpg_h ≈ PB_f_h + PB_g_h atol=1e-10

        # Property 4: Bilinearity (right) - {H, F+G} = {H, F} + {H, G}
        PB_h_fpg = CTLie.Poisson(h, f_plus_g)(x_test, p_test)
        PB_h_f = CTLie.Poisson(h, f)(x_test, p_test)
        PB_h_g = CTLie.Poisson(h, g)(x_test, p_test)
        Test.@test PB_h_fpg ≈ PB_h_f + PB_h_g atol=1e-10

        # Property 5: Leibniz's rule - {FG, H} = {F, H}·G + F·{G, H}
        PB_ftg_h = CTLie.Poisson(f_times_g, h)(x_test, p_test)
        leibniz_rhs = PB_f_h * g(x_test, p_test) + f(x_test, p_test) * PB_g_h
        Test.@test PB_ftg_h ≈ leibniz_rhs atol=1e-10

        # Property 6: Jacobi identity - {F, {G, H}} + {G, {H, F}} + {H, {F, G}} = 0
        PB_gh = CTLie.Poisson(g, h)
        PB_hf = CTLie.Poisson(h, f)
        PB_fg_func = CTLie.Poisson(f, g)

        PB_f_gh = CTLie.Poisson(f, PB_gh)(x_test, p_test)
        PB_g_hf = CTLie.Poisson(g, PB_hf)(x_test, p_test)
        PB_h_fg = CTLie.Poisson(h, PB_fg_func)(x_test, p_test)

        jacobi_sum = PB_f_gh + PB_g_hf + PB_h_fg
        Test.@test abs(jacobi_sum) < 1e-10
    end

    Test.@testset "Poisson() - Composition Lift" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test that Poisson(Lift(f), Lift(g)) gives correct results
        f(x) = [x[1] + x[2]^2, x[1], 0]
        g(x) = [0, x[2], x[1]^2 + 4 * x[2]]

        # Create Lifts
        F = CTLie.Lift(f)
        G = CTLie.Lift(g)

        # Explicit Hamiltonians
        F_explicit(x, p) = p' * f(x)
        G_explicit(x, p) = p' * g(x)

        x_test = [1.0, 2.0, 3.0]
        p_test = [4.0, 0.0, 4.0]

        # Poisson of Lifts should equal Poisson of explicit Hamiltonians
        Test.@test CTLie.Poisson(F, G)(x_test, p_test) ≈
              CTLie.Poisson(F_explicit, G_explicit)(x_test, p_test) atol=1e-6

        # Mixed case: Lift + explicit
        Test.@test CTLie.Poisson(F, G_explicit)(x_test, p_test) ≈
              CTLie.Poisson(F_explicit, G)(x_test, p_test) atol=1e-6

        # Non-autonomous case
        f_na(t, x) = [t * x[1] + x[2]^2, x[1], 0]
        g_na(t, x) = [0, x[2], t * x[1]^2 + 4 * x[2]]

        F_na = CTLie.Lift(f_na; is_autonomous=false)
        G_na = CTLie.Lift(g_na; is_autonomous=false)
        F_na_explicit(t, x, p) = p' * f_na(t, x)
        G_na_explicit(t, x, p) = p' * g_na(t, x)

        t_test = 2.0
        Test.@test CTLie.Poisson(F_na, G_na; is_autonomous=false)(t_test, x_test, p_test) ≈
              CTLie.Poisson(F_na_explicit, G_na_explicit; is_autonomous=false)(t_test, x_test, p_test) atol=1e-6
    end

end

end # module TestPoissonDG

test_poisson_dg() = TestPoissonDG.test_poisson_dg()
