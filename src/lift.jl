"""
$(TYPEDEF)

Callable struct representing the lifted Hamiltonian `H(…) = p' * f(…)`.

Replaces the four argument-reordering closures previously returned by `_Lift`.
`TD` and `VD` are compile-time trait parameters, so dispatch to the correct
call method is resolved at compile time — no allocation per call.

Inherits from `Function` so that it satisfies the `F<:Function` constraint of
`Data.Hamiltonian` and passes existing `isa Function` checks.
"""
struct LiftedHamiltonianFunction{F, TD, VD} <: Function
    f::F
end

(h::LiftedHamiltonianFunction{F, Traits.Autonomous,    Traits.Fixed})(x, p)       where {F} = p' * h.f(x)
(h::LiftedHamiltonianFunction{F, Traits.Autonomous,    Traits.NonFixed})(x, p, v) where {F} = p' * h.f(x, v)
(h::LiftedHamiltonianFunction{F, Traits.NonAutonomous, Traits.Fixed})(t, x, p)    where {F} = p' * h.f(t, x)
(h::LiftedHamiltonianFunction{F, Traits.NonAutonomous, Traits.NonFixed})(t, x, p, v) where {F} = p' * h.f(t, x, v)

"""
$(TYPEDSIGNATURES)

Lift a function to a Hamiltonian via the canonical symplectic structure.

Returns a [`LiftedHamiltonianFunction`](@ref) representing `H(x, p) = p' * f(x)`. This is an
algebraic operation that does not use automatic differentiation.

# Arguments
- `f::Function`: Vector field function (returns a vector).
- `is_autonomous::Bool`: Whether the function is time-independent (default: from global config).
- `is_variable::Bool`: Whether the function depends on a variable parameter (default: from global config).

# Returns
- A [`LiftedHamiltonianFunction`](@ref) with signature depending on TD/VD:
  - Autonomous/Fixed: `(x, p) -> p' * f(x)`
  - NonAutonomous/Fixed: `(t, x, p) -> p' * f(t, x)`
  - Autonomous/NonFixed: `(x, p, v) -> p' * f(x, v)`
  - NonAutonomous/NonFixed: `(t, x, p, v) -> p' * f(t, x, v)`

# Example
```julia
using CTLie

f = x -> [x[2], -x[1]]
H = Lift(f)

H([1.0, 2.0], [0.5, 1.0])  # Returns -1.5
```

See also: [`CTLie.Lift`](@ref), [`CTLie.Poisson`](@ref)
"""
function Lift(
    f::Function;
    is_autonomous::Bool = Data.__is_autonomous(),
    is_variable::Bool   = Data.__is_variable(),
)
    TD = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD = is_variable   ? Traits.NonFixed   : Traits.Fixed
    return Lift(f, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Lift a function to a Hamiltonian with explicit type parameters.

Returns a [`LiftedHamiltonianFunction`](@ref) representing `H(x, p) = p' * f(x)`. This typed entry
point is used by the [`@Lie`](@ref) macro for compile-time dispatch.

# Arguments
- `f::Function`: Vector field function (returns a vector).
- `::Type{TD}`: Time dependence type (`Autonomous` or `NonAutonomous`).
- `::Type{VD}`: Variable dependence type ([`CTBase.Traits.Fixed`](@extref CTBase) or [`CTBase.Traits.NonFixed`](@extref CTBase)).

# Returns
- A [`LiftedHamiltonianFunction{typeof(f), TD, VD}`](@ref).

# Example
```julia
using CTLie
using CTBase.Traits

f = x -> [x[2], -x[1]]
H = Lift(f, Traits.Autonomous, Traits.Fixed)

H([1.0, 2.0], [0.5, 1.0])  # Returns -1.5
```

See also: [`CTLie.Lift(f::Function)`](@ref), [`CTLie.@Lie`](@ref)
"""
function Lift(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD}
    return LiftedHamiltonianFunction{typeof(f), TD, VD}(f)
end

"""
$(TYPEDSIGNATURES)

Lift a vector field to a Hamiltonian via the canonical symplectic structure.

Returns a [`Data.Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) representing `H(x, p) = p' * X(x)`. This overload
allows lifting typed vector fields directly to Hamiltonians.

# Arguments
- `X::Data.AbstractVectorField{TD, VD}`: Vector field to lift.

# Returns
- `Data.Hamiltonian{TD, VD}`: The lifted Hamiltonian.

# Throws
- `Exceptions.NotImplemented`: If the vector field is an `AbstractHamiltonianVectorField`.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

X = VectorField(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)
H = Lift(X)

H([1.0, 2.0], [0.5, 1.0])  # Returns -1.5
```

See also: [`CTLie.Lift(f::Function)`](@ref), [`CTLie.Poisson`](@ref)
"""
function Lift(X::Data.AbstractVectorField{TD, VD}) where {TD, VD}
    _check_not_hvf(X)   # guard from ad_types.jl
    lh = LiftedHamiltonianFunction{typeof(X), TD, VD}(X)
    return Data.Hamiltonian(lh, TD, VD)   # typed constructor (no MD param)
end

# =============================================================================
# Base.show
# =============================================================================

_lh_call_sig(::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = "h(x, p) = p' * f(x)"
_lh_call_sig(::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = "h(x, p, v) = p' * f(x, v)"
_lh_call_sig(::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = "h(t, x, p) = p' * f(t, x)"
_lh_call_sig(::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = "h(t, x, p, v) = p' * f(t, x, v)"

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `LiftedHamiltonianFunction` showing its traits and call signature.

# Arguments
- `io::IO`: The IO stream.
- `h::LiftedHamiltonianFunction`: The lifted Hamiltonian object.

# Example
```julia-repl
julia> H = Lift(x -> [x[2], -x[1]])
LiftedHamiltonianFunction: autonomous, fixed (no variable)
  call: h(x, p) = p' * f(x)
```
"""
function Base.show(io::IO, ::LiftedHamiltonianFunction{F, TD, VD}) where {F, TD, VD}
    println(io, "LiftedHamiltonianFunction: $(Data._td_label(TD)), $(Data._vd_label(VD))")
    print(io, "  call: ", _lh_call_sig(TD, VD))
end

"""
$(TYPEDSIGNATURES)

Display a `LiftedHamiltonianFunction` in the REPL with the same format as `Base.show(io, h)`.

See also: [`CTLie.LiftedHamiltonianFunction`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", h::LiftedHamiltonianFunction{F, TD, VD}) where {F, TD, VD}
    show(io, h)
end
