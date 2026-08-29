"""
GPU **execution** tests: re-run CTLie's differential-geometry operators (`ad`, `Poisson`,
`Lift`, `∂ₜ`, `@Lie`) on a CUDA device and assert against analytic references derived the
same way as the CPU suite (`test_ad_dg.jl`, `test_poisson_dg.jl`, `test_lift_dg.jl`,
`test_time_derivative_dg.jl`, `test_macro_dg.jl`).

The whole suite self-gates on `Main.TestCapabilities.CUDA_FUNCTIONAL`: on a machine
without a functional device (dev laptops, CPU CI runners) it skips cleanly via
`Test.@test_skip` (shows as `Broken`, never a silent `Pass 0`). The real run is the
`test-gpu-occidata` job on the `occidata` self-hosted NVIDIA runner (PR label
`run ci occidata-runner`).

GPU backend: `Differentiation.DifferentiationInterface{Strategies.GPU}()`, which
defaults to `AutoMooncake` (CTBase `Differentiation/default.jl`). `Mooncake` is only
needed at evaluation time — `using Mooncake: Mooncake` below arms it.

GPU-friendly test fields use matrix multiplication, `sum`, and broadcasts — never
literal scalar indexing (`x[1]`, `x[2]`). A read like `x[2]` on a `CuArray` triggers a
device scalar-index, which `CUDA.allowscalar(false)` rejects outright, and which
Mooncake additionally refuses to differentiate through even when scalar indexing is
allowed ("scalar indexing of CuArray is not differentiable"). Component selection is
expressed instead as a fixed matrix/vector applied via `*`/`sum`/broadcast, all of which
lower to GPU kernels. The one exception is the last testset below, which deliberately
keeps literal indexing to demonstrate that the *default* (non-GPU) backend fails on a
device array — see its comment.

Known limitation (`Test.@test_broken` below, not a test bug): a Lie **bracket**
(vector-output `ad`, and `@Lie` which expands to one) chains two pushforwards where the
second one's tangent direction is itself a CuArray — this trips Mooncake's CUDA
extension (`ValueAndPullbackReturnTypeError` on an embedded stream pointer). The Lie
**derivative** (scalar output, a single pushforward) is unaffected, as are `Poisson`,
`Lift`, and `∂ₜ`. See the two `ad() Lie bracket on device` / `@Lie macro on device`
testsets for the full explanation.
"""

module TestGPUDG

using Test: Test
using CUDA: CUDA
using Mooncake: Mooncake   # backs AutoMooncake, the GPU-strategy default
using CTBase: CTBase       # bare import — @Lie expands to CTBase.Traits.* at the call site
using CTBase: Data
using CTBase: Differentiation
using CTBase: Strategies
using CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Device predicate and GPU-runner detection both come from Main.TestCapabilities
# (`CUDA_FUNCTIONAL` / `ON_GPU_RUNNER`, defined once in runtests.jl) — never a local
# `is_cuda_on()` / `_cuda_on()` copy, see test_environment_contract.jl's anti-pattern check.
_dev(x) = CUDA.CuArray(x)

const GPU_BACKEND = Differentiation.DifferentiationInterface{Strategies.GPU}()

# Fixed 2×2 matrices used to build GPU-safe vector fields via `M * x` instead of
# literal indexing. Plain CPU matrices — only ever moved to the device via `_dev`
# inside a testset, never at module load time (loaded regardless of CUDA availability).
const _ROT = [0.0 1.0; -1.0 0.0]   # x ↦ [x2, -x1]
const _SEL1 = [0.0 1.0; 0.0 0.0]   # x ↦ [x2, 0]
const _SEL2 = [0.0 0.0; 1.0 0.0]   # x ↦ [0, x1]

function test_gpu_dg()
    Test.@testset "GPU differential geometry (device execution)" verbose=VERBOSE showtiming=SHOWTIMING begin
        if Main.TestCapabilities.ON_GPU_RUNNER
            Test.@test Main.TestCapabilities.CUDA_FUNCTIONAL   # fails loudly if the GPU runner lost its device
        elseif !Main.TestCapabilities.CUDA_FUNCTIONAL
            @info "CUDA not functional — GPU differential-geometry tests skipped (run on a self-hosted GPU runner)"
            Test.@test_skip false   # shows as Broken, not Pass 0
            return nothing
        end

        CUDA.allowscalar(false)   # every ✓ below is genuinely scalar-index-free

        # ================================================================
        # ad() — Lie derivative (scalar foo) and Lie bracket (vector foo)
        # X(x) = Rx (skew ⇒ x'Xx = 0 for any quadratic f), f(x) = ‖x‖²
        # ================================================================

        Test.@testset "ad() Lie derivative on device" begin
            Rg = _dev(_ROT)
            X(x) = Rg * x
            f(x) = sum(abs2, x)
            Lf = CTLie.ad(X, f; ad_backend=GPU_BACKEND)
            Test.@test Lf(_dev([1.0, 2.0])) ≈ 0.0 atol = 1e-6
        end

        Test.@testset "ad() Lie bracket on device" begin
            Bg = _dev(_SEL1)
            Cg = _dev(_SEL2)
            X(x) = Bg * x   # [x2, 0]
            Y(x) = Cg * x   # [0, x1]
            # [X, Y] = J_Y*X - J_X*Y = (C*B - B*C)*x = [-x1, x2] (hand-checked)
            XY = CTLie.ad(X, Y; ad_backend=GPU_BACKEND)
            # Known limitation: a Lie bracket chains two pushforwards, and the second
            # one's tangent direction is itself a CuArray produced by the first. On
            # Mooncake's CUDA extension this throws `ValueAndPullbackReturnTypeError:
            # Found a value of type Ptr{CUDACore.CUstream_st} in output` — it walks a
            # CuArray's internal memory-management struct and refuses the embedded
            # stream pointer. The scalar-output case (Lie derivative, testset above)
            # is unaffected — only one pushforward, no CuArray-valued tangent.
            # Upstream: Mooncake.jl / DifferentiationInterface.jl.
            Test.@test_broken begin
                r = XY(_dev([1.0, 2.0]))
                Array(r) ≈ [-1.0, 2.0]
            end
        end

        # ================================================================
        # Poisson() — H(x,p) = sum(x), G(x,p) = sum(p)
        # ∇xH=[1,1], ∇pH=0, ∇xG=0, ∇pG=[1,1] ⇒ {H,G} = gpH'gxG - gxH'gpG = -2
        # ================================================================

        Test.@testset "Poisson() on device" begin
            H(x, p) = sum(x)
            G(x, p) = sum(p)
            PB = CTLie.Poisson(H, G; ad_backend=GPU_BACKEND)
            Test.@test PB(_dev([1.0, 2.0]), _dev([0.5, 1.0])) ≈ -2.0 atol = 1e-6
        end

        # ================================================================
        # Lift() — AD-free: H(x,p) = p'F(x), F(x) = Rx = [x2,-x1]
        # F([1,2]) = [2,-1] ⇒ H = [3,4]·[2,-1] = 2.0
        # ================================================================

        Test.@testset "Lift() on device" begin
            Rg = _dev(_ROT)
            F(x) = Rg * x
            Hlift = CTLie.Lift(F)
            Test.@test Hlift(_dev([1.0, 2.0]), _dev([3.0, 4.0])) ≈ 2.0 atol = 1e-10
        end

        # ================================================================
        # ∂ₜ() — f(t,x) = t² + sum(x): x is held constant w.r.t. t, so its exact
        # value doesn't affect ∂f/∂t = 2t ⇒ 6.0 at t=3, regardless of x.
        # ================================================================

        Test.@testset "∂ₜ() on device" begin
            f(t, x) = t^2 + sum(x)
            df = CTLie.∂ₜ(f; ad_backend=GPU_BACKEND)
            Test.@test df(3.0, _dev([1.0, 2.0])) ≈ 6.0 atol = 1e-6
        end

        # ================================================================
        # @Lie macro — same bracket as above, through the typed VectorField path.
        # ================================================================

        Test.@testset "@Lie macro on device" begin
            Bg = _dev(_SEL1)
            Cg = _dev(_SEL2)
            X = Data.VectorField(x -> Bg * x; is_autonomous=true, is_variable=false)
            Y = Data.VectorField(x -> Cg * x; is_autonomous=true, is_variable=false)
            mac = CTLie.@Lie [X, Y] ad_backend=GPU_BACKEND
            # @Lie expands to a Lie bracket internally — same Mooncake/CuArray
            # pushforward limitation as "ad() Lie bracket on device" above.
            Test.@test_broken begin
                r = mac(_dev([1.0, 2.0]))
                Array(r) ≈ [-1.0, 2.0]
            end
        end

        # ================================================================
        # Default (CPU) backend on device: documents the architecture gate that makes
        # an explicit GPU backend necessary. Deliberately keeps literal scalar
        # indexing (unlike every testset above) — the point here specifically is
        # that ordinary, unadapted vector-field code fails under the default
        # backend on a device array; mirrors CTFlows.jl's equivalent row.
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
