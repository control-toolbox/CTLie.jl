"""
GPU **execution** tests: re-run CTLie's differential-geometry operators (`ad`, `Poisson`,
`Lift`, `∂ₜ`, `@Lie`) on a CUDA device and assert against the same analytic references
already cross-checked by the CPU suite (`test_ad_dg.jl`, `test_poisson_dg.jl`,
`test_lift_dg.jl`, `test_time_derivative_dg.jl`, `test_macro_dg.jl`).

The whole suite self-gates on CUDA availability: on a machine without a functional
device (dev laptops, CPU CI runners) it skips cleanly via `Test.@test_skip` (shows as
`Broken`, never a silent `Pass 0`). The real runs are the `test-gpu-kkt` /
`test-gpu-occidata` jobs (PR labels `run ci kkt-runner` / `run ci occidata-runner`).

GPU backend: `Differentiation.DifferentiationInterface{Strategies.GPU}()`, which
defaults to `AutoMooncake` (CTBase `Differentiation/default.jl`). `Mooncake` is only
needed at evaluation time — `using Mooncake: Mooncake` below arms it.
"""

module TestGPUDG

using Test: Test
using CUDA: CUDA
using Mooncake: Mooncake   # backs AutoMooncake, the GPU-strategy default
using CTBase: Data
using CTBase: Differentiation
using CTBase: Strategies
using CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Reads Main.TestCapabilities (defined once in runtests.jl) rather than redefining
# is_cuda_on() locally — see test_environment_contract.jl's anti-pattern check.
function _cuda_on()
    return if isdefined(Main, :TestCapabilities)
        Main.TestCapabilities.CUDA_FUNCTIONAL
    else
        false
    end
end
_dev(x) = CUDA.CuArray(x)

const GPU_BACKEND = Differentiation.DifferentiationInterface{Strategies.GPU}()

function test_gpu_dg()
    Test.@testset "GPU differential geometry (device execution)" verbose=VERBOSE showtiming=SHOWTIMING begin
        on_gpu_runner() = get(ENV, "RUNNER_NAME", "") in ("kkt", "occidata")

        if on_gpu_runner()
            Test.@test _cuda_on()   # fails loudly if the GPU runner lost its device
        elseif !_cuda_on()
            @info "CUDA not functional — GPU differential-geometry tests skipped (run on kkt/occidata)"
            Test.@test_skip false   # shows as Broken, not Pass 0
            return nothing
        end

        CUDA.allowscalar(false)   # every ✓ below is genuinely scalar-index-free

        # ================================================================
        # ad() — Lie derivative (scalar foo) and Lie bracket (vector foo)
        # Reference: test_ad_dg.jl
        # ================================================================

        Test.@testset "ad() Lie derivative on device" begin
            X(x) = [x[2], -x[1]]
            f(x) = x[1]^2 + x[2]^2
            Lf = CTLie.ad(X, f; ad_backend=GPU_BACKEND)
            Test.@test Lf(_dev([1.0, 2.0])) ≈ 0.0 atol = 1e-6
        end

        Test.@testset "ad() Lie bracket on device" begin
            X(x) = [x[2], 0.0]
            Y(x) = [0.0, x[1]]
            # [X, Y] = J_Y*X - J_X*Y = [-x1, x2]
            XY = CTLie.ad(X, Y; ad_backend=GPU_BACKEND)
            r = XY(_dev([1.0, 2.0]))
            Test.@test r isa CUDA.CuArray
            Test.@test Array(r) ≈ [-1.0, 2.0] atol = 1e-6
        end

        # ================================================================
        # Poisson() — reference: test_poisson_dg.jl
        # {H, G} = ∇pH·∇xG - ∇xH·∇pG, H(x,p)=x1, G(x,p)=p1 ⇒ {H,G} = -1
        # ================================================================

        Test.@testset "Poisson() on device" begin
            H(x, p) = x[1]
            G(x, p) = p[1]
            PB = CTLie.Poisson(H, G; ad_backend=GPU_BACKEND)
            Test.@test PB(_dev([1.0, 2.0]), _dev([0.5, 1.0])) ≈ -1.0 atol = 1e-6
        end

        # ================================================================
        # Lift() — AD-free, reference: test_lift_dg.jl
        # F(x) = [x2, -x1], H(x,p) = p'F(x) = p1*x2 - p2*x1
        # ================================================================

        Test.@testset "Lift() on device" begin
            F(x) = [x[2], -x[1]]
            Hlift = CTLie.Lift(F)
            Test.@test Hlift(_dev([1.0, 2.0]), _dev([3.0, 4.0])) ≈ 2.0 atol = 1e-10
        end

        # ================================================================
        # ∂ₜ() — reference: test_time_derivative_dg.jl
        # f(t,x) = t^2 + x1 ⇒ ∂f/∂t = 2t ⇒ 6.0 at t=3
        # ================================================================

        Test.@testset "∂ₜ() on device" begin
            f(t, x) = t^2 + x[1]
            df = CTLie.∂ₜ(f; ad_backend=GPU_BACKEND)
            Test.@test df(3.0, _dev([1.0, 2.0])) ≈ 6.0 atol = 1e-6
        end

        # ================================================================
        # @Lie macro — same bracket as above, through the typed VectorField path.
        # Reference: test_macro_dg.jl
        # ================================================================

        Test.@testset "@Lie macro on device" begin
            X = Data.VectorField(x -> [x[2], 0.0]; is_autonomous=true, is_variable=false)
            Y = Data.VectorField(x -> [0.0, x[1]]; is_autonomous=true, is_variable=false)
            mac = CTLie.@Lie [X, Y] ad_backend=GPU_BACKEND
            r = mac(_dev([1.0, 2.0]))
            Test.@test Array(r) ≈ [-1.0, 2.0] atol = 1e-6
        end

        # ================================================================
        # Default (CPU) backend on device: documents the architecture gate that makes
        # an explicit GPU backend necessary — mirrors CTFlows.jl's equivalent row.
        # ================================================================

        Test.@testset "default (CPU) backend fails on device" begin
            X(x) = [x[2], -x[1]]
            f(x) = x[1]^2 + x[2]^2
            Lf = CTLie.ad(X, f)   # default backend = AutoForwardDiff, not GPU-safe
            Test.@test_throws Exception Lf(_dev([1.0, 2.0]))
        end
    end
    return nothing
end

end # module

# CRITICAL: redefine in the outer scope so the runner can call it
test_gpu_dg() = TestGPUDG.test_gpu_dg()
