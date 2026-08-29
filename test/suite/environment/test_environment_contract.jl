module TestEnvironmentContract

using Test: Test
using CTBase: CTBase

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# CTLie has no extension of its own: all differentiation runs through CTBase's
# CTBaseDifferentiationInterface extension (armed when DifferentiationInterface is
# loaded). GPU execution depends on it exactly as much as CPU execution does.
const _DiffExt = Base.get_extension(CTBase, :CTBaseDifferentiationInterface)

"""
    _silent_cuda_guard_offenders()

Recursively find, under `test/suite/` (located via `@__DIR__`, not `pwd()`), source lines
that either define a local CUDA-device predicate (`is_cuda_on()` / `_cuda_on()`) or open an
`if` block directly on one (`if is_cuda_on()`, `if _cuda_on()`, `if CUDA.functional()`) —
the anti-pattern consolidated into `Main.TestCapabilities.CUDA_FUNCTIONAL` by this fix (see
issue #21 / CTSolvers.jl#189-190 / CTFlows.jl#375). A bare device `if` makes a
correctly-skipped run (no device, as expected on a dev machine) and a silently-broken run
(device *should* be present but isn't) produce the same output: a green testset with zero
assertions.

The fix is `if Main.TestCapabilities.CUDA_FUNCTIONAL ... else Test.@test_skip ... end`, with
the device tier made *required* on the GPU runners centrally, in the testset below.

This file is excluded from the walk: it necessarily spells out the very patterns it searches
for (regex source, comments).
"""
function _silent_cuda_guard_offenders()
    suite_dir = joinpath(@__DIR__, "..")
    offenders = Tuple{String,Int}[]
    # Assembled from string literals so this line does not match itself.
    def_pattern = r"(is_cuda_on|_cuda_on)\(\)\s*="
    if_pattern = Regex("if\\s+(is_cuda_on\\(\\)|_cuda_on\\(\\)|CUDA" * "\\.functional\\(\\))")
    this_file = basename(@__FILE__)
    for (root, _, files) in walkdir(suite_dir)
        for f in files
            (endswith(f, ".jl") && f != this_file) || continue
            path = joinpath(root, f)
            for (lineno, line) in enumerate(eachline(path))
                if occursin(def_pattern, line) || match(if_pattern, line) !== nothing
                    push!(offenders, (relpath(path, suite_dir), lineno))
                end
            end
        end
    end
    return offenders
end

function test_environment_contract()
    Test.@testset "Test-environment contract" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "CTBaseDifferentiationInterface extension armed" begin
            Test.@test !isnothing(_DiffExt)
        end

        Test.@testset "GPU driver required on the GPU runner" begin
            # Central enforcement of the Handbook's capability-gated-test contract: on a
            # machine that is supposed to have a GPU, a missing/broken device fails loudly
            # here rather than being silently skipped everywhere else.
            #
            # Heuristic: RUNNER_NAME is set automatically by the GitHub Actions runner agent
            # itself (no .github/workflows/CI.yml or CTActions change needed) to the runner's
            # registered name — `kkt-runner` / `occidata-runner` for our self-hosted GPU
            # runners (the CI.yml `runs_on` label is the bare `kkt`/`occidata`, a different
            # string). `ON_GPU_RUNNER` (test/runtests.jl) matches the `kkt`/`occidata`
            # substring, so it survives the `-runner` suffix; if a runner is renamed past
            # that, the check stops firing silently rather than failing loudly.
            if Main.TestCapabilities.ON_GPU_RUNNER
                Test.@test Main.TestCapabilities.CUDA_FUNCTIONAL
            end
        end

        Test.@testset "silent CUDA-guard anti-pattern has not returned" begin
            offenders = _silent_cuda_guard_offenders()
            Test.@test isempty(offenders)
            for (file, lineno) in offenders
                @warn "silent CUDA guard at $file:$lineno — use Main.TestCapabilities.CUDA_FUNCTIONAL with a Test.@test_skip else branch"
            end
        end
    end
end

end # module

test_environment_contract() = TestEnvironmentContract.test_environment_contract()
