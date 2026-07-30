"""
Regression guard for the Handbook rule "using, never import" (tenet 2,
`philosophy/modules.md#using-never-import`): flags any tracked `.jl` file that
still uses the `import` keyword.
"""

module TestNoImport

using Test: Test

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const IMPORT_RE = r"^\s*import\b"

function test_no_import()
    Test.@testset "No `import` keyword (Handbook tenet 2 — using, never import)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        repo_root = joinpath(@__DIR__, "..", "..", "..")
        jl_files = filter(
            f -> endswith(f, ".jl"), readlines(Cmd(`git ls-files`; dir=repo_root))
        )
        for relpath in jl_files
            path = joinpath(repo_root, relpath)
            offending = any(occursin(IMPORT_RE, line) for line in eachline(path))
            Test.@test !offending
        end
    end
end

end # module

test_no_import() = TestNoImport.test_no_import()
