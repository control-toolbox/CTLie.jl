module TestCodeQuality

using Aqua: Aqua
using JET: JET
using Test: Test
using CTLie: CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Why a whole-package `JET.test_package` scan works here (unlike CTModels)
# ==============================================================================
#
# `JET.test_package` is a whole-package *correctness* scan: it statically visits
# every method signature. Some CT packages (e.g. CTModels' mutable `PreModel`
# builder, whose fields are `Union{SomeType,Nothing}` by design) get dozens of
# false positives from deliberately dynamic setup-path code, so those packages
# scope JET to `JET.@test_opt` on concrete hot-path calls instead (see the
# Handbook's performance guide, "hot path vs. setup path").
#
# CTLie has no such construction — every one-time constructor (`ad`, `Poisson`,
# `Lift`, `∂ₜ`) resolves a `Union{ADTypes.AbstractADType,NotProvidedType}` keyword
# once via `_resolve_backend` and captures a concrete backend into the returned
# callable struct's `B<:AbstractADBackend` field; nothing downstream stays a
# runtime union. A one-off `JET.report_package(CTLie; target_modules=(CTLie,))`
# scan (2026-07-15) confirmed this empirically: 0 reports, "No errors detected".
# So the whole-package scan is enabled directly, per
# `philosophy/performance.md`'s "Order of operations".
function test_code_quality()
    Test.@testset "Code quality" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@testset "Aqua Quality Checks" begin
            Aqua.test_all(
                CTLie;
                ambiguities=false,
                deps_compat=(ignore=[:LinearAlgebra, :Unicode],),
                piracies=true,
            )
        end

        Test.@testset "Ambiguities" begin
            Aqua.test_ambiguities(CTLie)
        end

        Test.@testset "JET" begin
            JET.test_package(CTLie; target_modules=(CTLie,))
        end
    end
end

end # module TestCodeQuality

test_code_quality() = TestCodeQuality.test_code_quality()
