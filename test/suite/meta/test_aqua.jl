module TestAqua

import Aqua
import Test
import CTLie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_aqua()
    Test.@testset "Aqua Quality Checks" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@testset "Aqua" begin
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
    end
end

end # module TestAqua

test_aqua() = TestAqua.test_aqua()
