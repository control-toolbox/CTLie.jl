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
