module TestEnvironmentContract

using Test: Test
using CTBase: CTBase

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# CTLie has no extension of its own: all differentiation runs through CTBase's
# CTBaseDifferentiationInterface extension (armed when DifferentiationInterface is
# loaded). GPU execution depends on it exactly as much as CPU execution does.
const _DiffExt = Base.get_extension(CTBase, :CTBaseDifferentiationInterface)

# Both self-hosted GPU runners in the fleet (see ../../../.github/workflows/CI.yml and
# Handbook/WORKFLOWS.md §2). CTFlows.jl's own environment-contract test only checks
# "kkt" — occidata was added there on 2026-08-24 without updating that check. Checking
# both here from the start avoids reproducing that gap.
const _GPU_RUNNERS = ("kkt", "occidata")

"""
    _local_is_cuda_on_offenders()

Recursively find, under `test/suite/`, source lines defining a local `is_cuda_on()`
function — the anti-pattern consolidated into Main.TestCapabilities by this fix
(see issue #21 / CTSolvers.jl#189-190 / CTFlows.jl#375).
"""
function _local_is_cuda_on_offenders()
    suite_dir = joinpath(@__DIR__, "..")
    offenders = Tuple{String,Int}[]
    for (root, _, files) in walkdir(suite_dir)
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(root, f)
            for (lineno, line) in enumerate(eachline(path))
                if occursin(r"is_cuda_on\(\)\s*=", line)
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
            if get(ENV, "RUNNER_NAME", "") in _GPU_RUNNERS
                Test.@test Main.TestCapabilities.CUDA_FUNCTIONAL
            end
        end

        Test.@testset "local is_cuda_on() anti-pattern has not returned" begin
            offenders = _local_is_cuda_on_offenders()
            Test.@test isempty(offenders)
            for (file, lineno) in offenders
                @warn "local is_cuda_on() at $file:$lineno — use Main.TestCapabilities instead"
            end
        end
    end
end

end # module

test_environment_contract() = TestEnvironmentContract.test_environment_contract()
