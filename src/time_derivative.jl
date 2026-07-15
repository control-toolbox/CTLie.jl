"""
$(TYPEDEF)

Callable struct for `∂ₜ(f::Function)` — time derivative of a generic callable.

Replaces the outer closure `(t, args...) -> Differentiation.derivative(b, s -> f(s, args...), t)`.
"""
struct TimeDeriv_F{F,B<:Differentiation.AbstractADBackend} <: Function
    f::F
    b::B
end
function (dtd::TimeDeriv_F{F,B})(t, args...) where {F,B<:Differentiation.AbstractADBackend}
    return Differentiation.differentiate(dtd.b, dtd.f, Val(1), t, args...)
end

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a function.

Returns a [`TimeDeriv_F`](@ref) callable representing the partial derivative with respect to time.
The input function must accept time as its first argument.

# Arguments
- `f::Function`: Function that takes time as the first argument.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- A [`TimeDeriv_F`](@ref) callable `(t, args...) -> ∂f/∂t(t, args...)`.

# Example
```julia
using CTLie

f = (t, x) -> t * x[1] + x[2]^2
df_dt = ∂ₜ(f)

df_dt(2.0, [1.0, 3.0])  # Returns 1.0
```

See also: [`CTLie.∂ₜ`](@ref)
"""
function ∂ₜ(
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
)
    backend = _resolve_backend(ad_backend)
    return TimeDeriv_F{typeof(f),typeof(backend)}(f, backend)
end

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a Hamiltonian vector field.

Returns a new [`Data.HamiltonianVectorField`](@extref CTBase CTBase.Data.HamiltonianVectorField) with `NonAutonomous` time dependence.
For autonomous vector fields, the derivative is zero.

# Arguments
- `X::Data.AbstractHamiltonianVectorField{TD, VD, MD}`: Hamiltonian vector field.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- `Data.HamiltonianVectorField{Traits.NonAutonomous, VD, Traits.OutOfPlace}`: Time derivative.

# Throws
- `Exceptions.NotImplemented`: If the vector field has `InPlace` mutability.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

X = HamiltonianVectorField((t, x, p) -> t * p, Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace)
dX_dt = ∂ₜ(X)

dX_dt(2.0, [1.0], [0.5])  # Returns 0.5
```

See also: [`CTLie.∂ₜ`](@ref)
"""
function ∂ₜ(
    X::Data.AbstractHamiltonianVectorField{TD,VD,MD};
    ad_backend::Union{ADTypes.AbstractADType,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_hvf(X, backend, TD, VD)
    return Data.HamiltonianVectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# HVF returns a tuple (ẋ, ṗ); DI.derivative does not extract derivatives from tuple-of-array
# outputs, so we project onto each component before differentiating.

"""
$(TYPEDEF)

Component projector for the first output (ẋ) of a HamiltonianVectorField.

Used to differentiate tuple-valued outputs slot-by-slot, since
`Differentiation.differentiate` does not extract derivatives from tuple-of-array outputs.

See also: [`CTLie.TimeDeriv_HVF`](@ref), [`CTLie._HVFComp2`](@ref)
"""
struct _HVFComp1{F} <: Function
    ;
    X::F;
end

"""
$(TYPEDEF)

Component projector for the second output (ṗ) of a HamiltonianVectorField.

Used to differentiate tuple-valued outputs slot-by-slot, since
`Differentiation.differentiate` does not extract derivatives from tuple-of-array outputs.

See also: [`CTLie.TimeDeriv_HVF`](@ref), [`CTLie._HVFComp1`](@ref)
"""
struct _HVFComp2{F} <: Function
    ;
    X::F;
end

(_c::_HVFComp1)(args...) = _c.X(args...)[1]
(_c::_HVFComp2)(args...) = _c.X(args...)[2]

"""
$(TYPEDEF)

Callable struct for `∂ₜ(X::AbstractHamiltonianVectorField)`.

- **Autonomous** (TD=Autonomous): `∂X/∂t = 0`; evaluates `X` once to get the zero shape.
- **NonAutonomous** (TD=NonAutonomous): differentiates `X` w.r.t. slot 1 (time) via
  `Differentiation.differentiate`, eliminating the inner `s -> X(s,...)` closure.
"""
struct TimeDeriv_HVF{FX,B<:Differentiation.AbstractADBackend,TD,VD} <: Function
    X::FX
    b::B
end

function (dtd::TimeDeriv_HVF{FX,B,Traits.Autonomous,Traits.Fixed})(
    _, x, p
) where {FX,B<:Differentiation.AbstractADBackend}
    return zero.(dtd.X(x, p))
end
function (dtd::TimeDeriv_HVF{FX,B,Traits.Autonomous,Traits.NonFixed})(
    _, x, p, v
) where {FX,B<:Differentiation.AbstractADBackend}
    return zero.(dtd.X(x, p, v))
end
function (dtd::TimeDeriv_HVF{FX,B,Traits.NonAutonomous,Traits.Fixed})(
    t, x, p
) where {FX,B<:Differentiation.AbstractADBackend}
    return (
        Differentiation.differentiate(dtd.b, _HVFComp1(dtd.X), Val(1), t, x, p),
        Differentiation.differentiate(dtd.b, _HVFComp2(dtd.X), Val(1), t, x, p),
    )
end
function (dtd::TimeDeriv_HVF{FX,B,Traits.NonAutonomous,Traits.NonFixed})(
    t, x, p, v
) where {FX,B<:Differentiation.AbstractADBackend}
    return (
        Differentiation.differentiate(dtd.b, _HVFComp1(dtd.X), Val(1), t, x, p, v),
        Differentiation.differentiate(dtd.b, _HVFComp2(dtd.X), Val(1), t, x, p, v),
    )
end

"""
$(TYPEDSIGNATURES)

Internal constructor for [`TimeDeriv_HVF`](@ref) with compile-time `TD`/`VD` trait parameters.

See also: [`CTLie.TimeDeriv_HVF`](@ref), [`CTLie.∂ₜ`](@ref)
"""
function _∂ₜ_hvf(
    X, b::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}
) where {TD,VD}
    return TimeDeriv_HVF{typeof(X),typeof(b),TD,VD}(X, b)
end

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a vector field.

Returns a new [`Data.VectorField`](@extref CTBase CTBase.Data.VectorField) with `NonAutonomous` time dependence.
For autonomous vector fields, the derivative is zero.

# Arguments
- `X::Data.AbstractVectorField{TD, VD, MD}`: Vector field.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- `Data.VectorField{Traits.NonAutonomous, VD, Traits.OutOfPlace}`: Time derivative.

# Throws
- `Exceptions.NotImplemented`: If the vector field has `InPlace` mutability.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

X = VectorField((t, x) -> t * x, Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace)
dX_dt = ∂ₜ(X)

dX_dt(2.0, [1.0, 2.0])  # Returns [1.0, 2.0]
```

See also: [`CTLie.∂ₜ`](@ref)
"""
function ∂ₜ(
    X::Data.AbstractVectorField{TD,VD,MD};
    ad_backend::Union{ADTypes.AbstractADType,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    MD<:Traits.AbstractMutabilityTrait,
}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_vf(X, backend, TD, VD)
    return Data.VectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

"""
$(TYPEDEF)

Callable struct for `∂ₜ(X::AbstractVectorField)`.

- **Autonomous**: `∂X/∂t = 0`; returns `zero.(X(...))` without AD.
- **NonAutonomous**: differentiates `X` w.r.t. slot 1 (time) via `Differentiation.differentiate`.
"""
struct TimeDeriv_VF{FX,B<:Differentiation.AbstractADBackend,TD,VD} <: Function
    X::FX
    b::B
end

function (dtd::TimeDeriv_VF{FX,B,Traits.Autonomous,Traits.Fixed})(
    _, x
) where {FX,B<:Differentiation.AbstractADBackend}
    return zero.(dtd.X(x))
end
function (dtd::TimeDeriv_VF{FX,B,Traits.Autonomous,Traits.NonFixed})(
    _, x, v
) where {FX,B<:Differentiation.AbstractADBackend}
    return zero.(dtd.X(x, v))
end
function (dtd::TimeDeriv_VF{FX,B,Traits.NonAutonomous,Traits.Fixed})(
    t, x
) where {FX,B<:Differentiation.AbstractADBackend}
    return Differentiation.differentiate(dtd.b, dtd.X, Val(1), t, x)
end
function (dtd::TimeDeriv_VF{FX,B,Traits.NonAutonomous,Traits.NonFixed})(
    t, x, v
) where {FX,B<:Differentiation.AbstractADBackend}
    return Differentiation.differentiate(dtd.b, dtd.X, Val(1), t, x, v)
end

"""
$(TYPEDSIGNATURES)

Internal constructor for [`TimeDeriv_VF`](@ref) with compile-time `TD`/`VD` trait parameters.

See also: [`CTLie.TimeDeriv_VF`](@ref), [`CTLie.∂ₜ`](@ref)
"""
function _∂ₜ_vf(
    X, b::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}
) where {TD,VD}
    return TimeDeriv_VF{typeof(X),typeof(b),TD,VD}(X, b)
end

"""
$(TYPEDSIGNATURES)

Compute the time derivative of a Hamiltonian.

Returns a new [`Data.Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) with `NonAutonomous` time dependence.
For autonomous Hamiltonians, the derivative is zero.

# Arguments
- `H::Data.AbstractHamiltonian{TD, VD}`: Hamiltonian.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- `Data.Hamiltonian{Traits.NonAutonomous, VD}`: Time derivative.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

H = Hamiltonian((t, x, p) -> t * p[1] + x[1]^2, Traits.NonAutonomous, Traits.Fixed)
dH_dt = ∂ₜ(H)

dH_dt(2.0, [1.0], [0.5])  # Returns 0.5
```

See also: [`CTLie.∂ₜ`](@ref)
"""
function ∂ₜ(
    H::Data.AbstractHamiltonian{TD,VD};
    ad_backend::Union{ADTypes.AbstractADType,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_ham(H, backend, TD, VD)
    return Data.Hamiltonian(closure, Traits.NonAutonomous, VD)
end

"""
$(TYPEDEF)

Callable struct for `∂ₜ(H::AbstractHamiltonian)`.

- **Autonomous**: `∂H/∂t = 0`; returns `zero(H(...))` without AD.
- **NonAutonomous**: differentiates `H` w.r.t. slot 1 (time) via `Differentiation.differentiate`.
"""
struct TimeDeriv_Ham{FH,B<:Differentiation.AbstractADBackend,TD,VD} <: Function
    H::FH
    b::B
end

function (dtd::TimeDeriv_Ham{FH,B,Traits.Autonomous,Traits.Fixed})(
    _, x, p
) where {FH,B<:Differentiation.AbstractADBackend}
    return zero(dtd.H(x, p))
end
function (dtd::TimeDeriv_Ham{FH,B,Traits.Autonomous,Traits.NonFixed})(
    _, x, p, v
) where {FH,B<:Differentiation.AbstractADBackend}
    return zero(dtd.H(x, p, v))
end
function (dtd::TimeDeriv_Ham{FH,B,Traits.NonAutonomous,Traits.Fixed})(
    t, x, p
) where {FH,B<:Differentiation.AbstractADBackend}
    return Differentiation.differentiate(dtd.b, dtd.H, Val(1), t, x, p)
end
function (dtd::TimeDeriv_Ham{FH,B,Traits.NonAutonomous,Traits.NonFixed})(
    t, x, p, v
) where {FH,B<:Differentiation.AbstractADBackend}
    return Differentiation.differentiate(dtd.b, dtd.H, Val(1), t, x, p, v)
end

"""
$(TYPEDSIGNATURES)

Internal constructor for [`TimeDeriv_Ham`](@ref) with compile-time `TD`/`VD` trait parameters.

See also: [`CTLie.TimeDeriv_Ham`](@ref), [`CTLie.∂ₜ`](@ref)
"""
function _∂ₜ_ham(
    H, b::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}
) where {TD,VD}
    return TimeDeriv_Ham{typeof(H),typeof(b),TD,VD}(H, b)
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `TimeDeriv_F` callable (time derivative of a generic function).

# Arguments
- `io::IO`: The IO stream.
- `dtd::TimeDeriv_F`: The time derivative object.

# Example
```julia-repl
julia> df = ∂ₜ((t, x) -> t * x[1])
∂ₜ (generic function)
  backend: ForwardDiffBackend
  cache: not prepared
```
"""
function Base.show(
    io::IO, dtd::TimeDeriv_F{F,B}
) where {F,B<:Differentiation.AbstractADBackend}
    println(io, "∂ₜ (generic function)")
    return print(io, "  backend: ", nameof(typeof(dtd.b)))
end

"""
$(TYPEDSIGNATURES)

Display a `TimeDeriv_F` in the REPL with the same format as `Base.show(io, dtd)`.

See also: [`CTLie.∂ₜ`](@ref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", dtd::TimeDeriv_F{F,B}
) where {F,B<:Differentiation.AbstractADBackend}
    return show(io, dtd)
end

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `TimeDeriv_HVF` callable (time derivative of a HamiltonianVectorField).

# Arguments
- `io::IO`: The IO stream.
- `dtd::TimeDeriv_HVF`: The time derivative object.

# Example
```julia-repl
julia> dX = ∂ₜ(HamiltonianVectorField((t, x, p) -> (t * p, -x), Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace))
∂ₜ (HamiltonianVectorField): non-autonomous, fixed (no variable)
  backend: ForwardDiffBackend
  cache: not prepared
```
"""
function Base.show(
    io::IO, dtd::TimeDeriv_HVF{FX,B,TD,VD}
) where {FX,B<:Differentiation.AbstractADBackend,TD,VD}
    println(io, "∂ₜ (HamiltonianVectorField): $(Data._td_label(TD)), $(Data._vd_label(VD))")
    return print(io, "  backend: ", nameof(typeof(dtd.b)))
end

"""
$(TYPEDSIGNATURES)

Display a `TimeDeriv_HVF` in the REPL with the same format as `Base.show(io, dtd)`.

See also: [`CTLie.∂ₜ`](@ref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", dtd::TimeDeriv_HVF{FX,B,TD,VD}
) where {FX,B<:Differentiation.AbstractADBackend,TD,VD}
    return show(io, dtd)
end

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `TimeDeriv_VF` callable (time derivative of a VectorField).

# Arguments
- `io::IO`: The IO stream.
- `dtd::TimeDeriv_VF`: The time derivative object.

# Example
```julia-repl
julia> dX = ∂ₜ(VectorField((t, x) -> t * x, Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace))
∂ₜ (VectorField): non-autonomous, fixed (no variable)
  backend: ForwardDiffBackend
  cache: not prepared
```
"""
function Base.show(
    io::IO, dtd::TimeDeriv_VF{FX,B,TD,VD}
) where {FX,B<:Differentiation.AbstractADBackend,TD,VD}
    println(io, "∂ₜ (VectorField): $(Data._td_label(TD)), $(Data._vd_label(VD))")
    return print(io, "  backend: ", nameof(typeof(dtd.b)))
end

"""
$(TYPEDSIGNATURES)

Display a `TimeDeriv_VF` in the REPL with the same format as `Base.show(io, dtd)`.

See also: [`CTLie.∂ₜ`](@ref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", dtd::TimeDeriv_VF{FX,B,TD,VD}
) where {FX,B<:Differentiation.AbstractADBackend,TD,VD}
    return show(io, dtd)
end

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `TimeDeriv_Ham` callable (time derivative of a Hamiltonian).

# Arguments
- `io::IO`: The IO stream.
- `dtd::TimeDeriv_Ham`: The time derivative object.

# Example
```julia-repl
julia> dH = ∂ₜ(Hamiltonian((t, x, p) -> t * p[1] + x[1]^2, Traits.NonAutonomous, Traits.Fixed))
∂ₜ (Hamiltonian): non-autonomous, fixed (no variable)
  backend: ForwardDiffBackend
  cache: not prepared
```
"""
function Base.show(
    io::IO, dtd::TimeDeriv_Ham{FH,B,TD,VD}
) where {FH,B<:Differentiation.AbstractADBackend,TD,VD}
    println(io, "∂ₜ (Hamiltonian): $(Data._td_label(TD)), $(Data._vd_label(VD))")
    return print(io, "  backend: ", nameof(typeof(dtd.b)))
end

"""
$(TYPEDSIGNATURES)

Display a `TimeDeriv_Ham` in the REPL with the same format as `Base.show(io, dtd)`.

See also: [`CTLie.∂ₜ`](@ref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", dtd::TimeDeriv_Ham{FH,B,TD,VD}
) where {FH,B<:Differentiation.AbstractADBackend,TD,VD}
    return show(io, dtd)
end
