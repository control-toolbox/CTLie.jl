# ==============================================================================
# CTLie Test Runner
# ==============================================================================
#
# ## Running tests
#
# ### All tests
#   julia --project -e 'using Pkg; Pkg.test("CTLie")'
#
# ### Specific test(s) — glob patterns matched against test file paths/names
#   julia --project -e 'using Pkg; Pkg.test("CTLie"; test_args=["test_ad_dg"])'
#   julia --project -e 'using Pkg; Pkg.test("CTLie"; test_args=["*macro*"])'
#   julia --project -e 'using Pkg; Pkg.test("CTLie"; test_args=["-n"])'  # dry run
#
# Test layout: `suite/<group>/test_<name>.jl` each defining `test_<name>()`.
# ==============================================================================

using Test
using CTBase
using CTLie

# Capability constants computed once, here, where a top-level `using` is guaranteed
# to bind into Main. Suite files read Main.TestCapabilities.* instead of redefining
# is_cuda_on() locally (see issue #21 / CTSolvers.jl#189-190 / CTFlows.jl#375).
#
# `CUDA_FUNCTIONAL` is the suite's single CUDA-device predicate — never define a local
# `is_cuda_on()` / `_cuda_on()` in a test file (duplicated copies drift).
# `ON_GPU_RUNNER` turns the device tier from *skipped* into *required* on the self-hosted
# GPU runners: `RUNNER_NAME` is set by the GitHub Actions runner agent itself (no CI.yml
# or CTActions change needed) to the runner's *registered name*. Our self-hosted GPU
# runners register as `kkt-runner` / `occidata-runner` (the CI.yml `runs_on` label is the
# bare `kkt`/`occidata`, a different string), so match on the `kkt` / `occidata` substring
# to stay robust to the `-runner` suffix. Enforcement lives centrally in
# test/suite/environment/test_environment_contract.jl.
using CUDA
module TestCapabilities
using CUDA: CUDA
const CUDA_FUNCTIONAL = CUDA.functional()
const ON_GPU_RUNNER = any(
    gpu -> occursin(gpu, get(ENV, "RUNNER_NAME", "")), ("kkt", "occidata")
)
end

if Main.TestCapabilities.CUDA_FUNCTIONAL
    println("✓ CUDA functional, GPU tests enabled")
else
    println("⚠️  CUDA not functional, GPU tests will be skipped")
end

# Trigger loading of optional extensions
const TestRunner = Base.get_extension(CTBase, :TestRunner)

# Controls nested testset output formatting (used by individual test files)
module TestData
const VERBOSE = true
const SHOWTIMING = true
end

using .TestData: VERBOSE, SHOWTIMING

# Run tests using the TestRunner extension
CTBase.run_tests(;
    args=String.(ARGS),
    testset_name="CTLie tests",
    available_tests=("suite/*/test_*",),
    filename_builder=name -> Symbol(:test_, name),
    funcname_builder=name -> Symbol(:test_, name),
    verbose=VERBOSE,
    showtiming=SHOWTIMING,
    test_dir=@__DIR__,
    progress_bar_threshold=100,
    show_progress_bar=false,
)
