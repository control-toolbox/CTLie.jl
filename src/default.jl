# Default AD backend sentinel — uses global DG_AD_BACKEND when not overridden
"""
$(TYPEDSIGNATURES)

Return the sentinel value indicating no AD backend was explicitly provided.

This function is used as the default value for the `ad_backend` keyword argument
in CTLie operations. When returned, the global backend
`DG_AD_BACKEND` is used instead.

# Returns
- `CTBase.Core.NotProvided` (singleton `CTBase.Core.NotProvidedType`): sentinel indicating backend should use global default.

# Notes
- This is an internal function used by [`CTLie._resolve_backend`](@ref).
- Users should use [`CTLie.dg_ad_backend`](@ref) to get the current backend.

See also: [`CTLie.DG_AD_BACKEND`](@ref), [`CTLie._resolve_backend`](@ref).
"""
__dg_ad_backend()::CTBase.Core.NotProvidedType = CTBase.Core.NotProvided

# Global default backend ref — built once at module load
"""
$(TYPEDEF)

Global reference to the automatic differentiation backend used by CTLie operations.

This `Ref` holds the current AD backend that is used by [`CTLie.ad`](@ref),
[`CTLie.Poisson`](@ref), and [`CTLie.∂ₜ`](@ref) when no explicit
`ad_backend` keyword argument is provided.

# Type
- `Ref{Differentiation.AbstractADBackend}`: Mutable reference to an AD backend.

# Notes
- Initialized at module load time with `AutoForwardDiff` via [`CTBase.Differentiation.build_ad_backend`](@extref CTBase).
- Modified via [`CTLie.dg_ad_backend!`](@ref).
- Accessed via [`CTLie.dg_ad_backend`](@ref).

See also: [`CTLie.dg_ad_backend`](@ref), [`CTLie.dg_ad_backend!`](@ref), [`CTLie.__dg_ad_backend`](@ref).
"""
const DG_AD_BACKEND = Ref{Differentiation.AbstractADBackend}(
    Differentiation.build_ad_backend(),   # AutoForwardDiff via CTBase.Differentiation.__ad_backend()
)

"""
$(TYPEDSIGNATURES)

Return the current global automatic differentiation backend used by CTLie operations.

The backend is used by [`CTLie.ad`](@ref), [`CTLie.Poisson`](@ref), and [`CTLie.∂ₜ`](@ref) when no explicit
`ad_backend` keyword argument is provided.

# Returns
- `Differentiation.AbstractADBackend`: The current AD backend.

# Example
```julia
using CTLie

backend = dg_ad_backend()
```

See also: [`CTLie.dg_ad_backend!`](@ref), [`CTLie.ad`](@ref), [`CTLie.Poisson`](@ref), [`CTLie.∂ₜ`](@ref)
"""
dg_ad_backend() = DG_AD_BACKEND[]

"""
$(TYPEDSIGNATURES)

Set the global automatic differentiation backend used by CTLie operations.

This function rebuilds the backend from an ADTypes backend type. The new backend will be
used by [`CTLie.ad`](@ref), [`CTLie.Poisson`](@ref), and [`CTLie.∂ₜ`](@ref) when no explicit `ad_backend`
keyword argument is provided.

# Arguments
- `ad_backend::ADTypes.AbstractADType`: The ADTypes backend type to use (e.g., `AutoForwardDiff()`).

# Returns
- `nothing`

# Example
```julia
using CTLie
using ADTypes

dg_ad_backend!(AutoForwardDiff())
```

See also: [`CTLie.dg_ad_backend`](@ref), [`CTLie.ad`](@ref), [`CTLie.Poisson`](@ref), [`CTLie.∂ₜ`](@ref)
"""
function dg_ad_backend!(ad_backend::ADTypes.AbstractADType)
    DG_AD_BACKEND[] = Differentiation.build_ad_backend(; ad_backend=ad_backend)
    return nothing
end

# Resolution: NotProvided → global ref; ADTypes.AbstractADType → build fresh backend
"""
Resolve the AD backend from a keyword argument.

If `NotProvided`, returns the global backend. If an ADTypes backend,
builds a fresh backend from the ADType.

# Arguments
- `::CTBase.Core.NotProvidedType`: Sentinel value indicating no backend specified.
- `ad_backend::ADTypes.AbstractADType`: ADTypes backend type to build.

# Returns
- `Differentiation.AbstractADBackend`: The resolved backend.
"""
_resolve_backend(::CTBase.Core.NotProvidedType) = DG_AD_BACKEND[]
function _resolve_backend(ad_backend::ADTypes.AbstractADType)
    return Differentiation.build_ad_backend(; ad_backend=ad_backend)
end
