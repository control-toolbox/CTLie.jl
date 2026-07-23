"""
    CTLie

Differential geometry operations on vector fields and Hamiltonians: Lie derivatives,
Lie brackets, Poisson brackets, and partial time derivatives.

`CTLie` is a foundational package of the
[control-toolbox](https://control-toolbox.org) ecosystem. It provides:
- `ad(X, Y)` — Lie derivative and Lie bracket;
- `Lift(f)` — lift a function or vector field to a Hamiltonian;
- `Poisson(H, G)` — Poisson bracket;
- `∂ₜ(X)` — partial time derivative;
- `@Lie` — macro for typed, intrinsic bracket/Poisson notation.

All operations support automatic differentiation via a global backend
(`dg_ad_backend`/`dg_ad_backend!`). The actual differentiation is performed by the
`CTBaseDifferentiationInterface` extension, which activates when `DifferentiationInterface`
(and a concrete AD package such as `ForwardDiff`) is loaded.
"""
module CTLie

# ==============================================================================
# External-package imports (qualified, pollution-free)
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTBase: CTBase
import CTBase.Data
import CTBase.Differentiation
import CTBase.Exceptions
import CTBase.Traits
import MacroTools: postwalk, @capture

# ==============================================================================
# Include files (in dependency order)
# ==============================================================================

include("default.jl")
include("ad.jl")
include("ad_types.jl")
include("lift.jl")
include("poisson.jl")
include("time_derivative.jl")
include("lie_macro.jl")

# ==============================================================================
# Public API — exports
# ==============================================================================

export ad
export Lift
export LiftedHamiltonianFunction
export Poisson
export ∂ₜ
export @Lie
export dg_ad_backend, dg_ad_backend!

end # module CTLie
