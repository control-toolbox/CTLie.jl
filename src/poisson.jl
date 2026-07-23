"""
$(TYPEDSIGNATURES)

Compute the Poisson bracket of two Hamiltonian functions using keyword arguments.

Returns a function representing the Poisson bracket `{H, G} = ∇ₚH' * ∇ₓG - ∇ₓH' * ∇ₚG`.
The time dependence and variable dependence are inferred from the `is_autonomous` and
`is_variable` keyword arguments.

# Arguments
- `H::Function`: First Hamiltonian function (returns a scalar).
- `G::Function`: Second Hamiltonian function (returns a scalar).
- `ad_backend::Union{Differentiation.AbstractADBackend, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).
- `is_autonomous::Bool`: Whether the functions are time-independent (default: from global config).
- `is_variable::Bool`: Whether the functions depend on a variable parameter (default: from global config).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x, p) -> result`
  - NonAutonomous/Fixed: `(t, x, p) -> result`
  - Autonomous/NonFixed: `(x, p, v) -> result`
  - NonAutonomous/NonFixed: `(t, x, p, v) -> result`

# Example
```julia
using CTLie

H = (x, p) -> p[1]^2 / 2 + x[1]^2
G = (x, p) -> x[1] * p[1]

B = Poisson(H, G)
B([1.0, 2.0], [0.5, 1.0])  # Returns 1.0
```

See also: [`CTLie.Poisson`](@ref), [`CTLie.ad`](@ref), [`CTLie.Lift`](@ref)
"""
function Poisson(
    H::Function,
    G::Function;
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
    is_autonomous::Bool=Data.__is_autonomous(),
    is_variable::Bool=Data.__is_variable(),
)
    TD = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD = is_variable ? Traits.NonFixed : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Compute the Poisson bracket of two Hamiltonian functions with explicit type parameters.

Returns a function representing the Poisson bracket `{H, G} = ∇ₚH' * ∇ₓG - ∇ₓH' * ∇ₚG`.
This typed entry point is used by the [`@Lie`](@ref) macro for compile-time dispatch.

# Arguments
- `H::Function`: First Hamiltonian function (returns a scalar).
- `G::Function`: Second Hamiltonian function (returns a scalar).
- `::Type{TD}`: Time dependence type (`Autonomous` or `NonAutonomous`).
- `::Type{VD}`: Variable dependence type ([`CTBase.Traits.Fixed`](@extref CTBase) or [`CTBase.Traits.NonFixed`](@extref CTBase)).
- `ad_backend::Union{Differentiation.AbstractADBackend, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- A function with signature depending on TD/VD.

# Example
```julia
using CTLie
using CTBase.Traits

H = (x, p) -> p[1]^2 / 2 + x[1]^2
G = (x, p) -> x[1] * p[1]

B = Poisson(H, G, Traits.Autonomous, Traits.Fixed)
B([1.0, 2.0], [0.5, 1.0])  # Returns 1.0
```

See also: [`CTLie.Poisson(H::Function, G::Function)`](@ref), [`CTLie.@Lie`](@ref), [`CTLie.ad`](@ref)
"""
function Poisson(
    H::Function,
    G::Function,
    ::Type{TD},
    ::Type{VD};
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

"""
$(TYPEDEF)

Callable struct representing the Poisson bracket `{H, G} = ∇ₚH'∇ₓG - ∇ₓH'∇ₚG`.

Replaces the four closures previously returned by `_Poisson`. `TD` and `VD` are
compile-time trait parameters so the correct call method is resolved statically.
Partial derivatives are computed via `Differentiation.differentiate`.
"""
struct PoissonBracket{FH,FG,B<:Differentiation.AbstractADBackend,TD,VD} <: Function
    H::FH
    G::FG
    backend::B
end

# Autonomous/Fixed: H(x,p) — ∂/∂x = slot 1, ∂/∂p = slot 2
function (pb::PoissonBracket{FH,FG,B,Traits.Autonomous,Traits.Fixed})(
    x, p
) where {FH,FG,B<:Differentiation.AbstractADBackend}
    gxH = Differentiation.differentiate(pb.backend, pb.H, Val(1), x, p)
    gpH = Differentiation.differentiate(pb.backend, pb.H, Val(2), p, x)
    gxG = Differentiation.differentiate(pb.backend, pb.G, Val(1), x, p)
    gpG = Differentiation.differentiate(pb.backend, pb.G, Val(2), p, x)
    return (gpH' * gxG - gxH' * gpG)::promote_type(eltype(x), eltype(p))
end

# NonAutonomous/Fixed: H(t,x,p) — ∂/∂x = slot 2, ∂/∂p = slot 3
function (pb::PoissonBracket{FH,FG,B,Traits.NonAutonomous,Traits.Fixed})(
    t, x, p
) where {FH,FG,B<:Differentiation.AbstractADBackend}
    gxH = Differentiation.differentiate(pb.backend, pb.H, Val(2), x, t, p)
    gpH = Differentiation.differentiate(pb.backend, pb.H, Val(3), p, t, x)
    gxG = Differentiation.differentiate(pb.backend, pb.G, Val(2), x, t, p)
    gpG = Differentiation.differentiate(pb.backend, pb.G, Val(3), p, t, x)
    return (gpH' * gxG - gxH' * gpG)::promote_type(eltype(x), eltype(p))
end

# Autonomous/NonFixed: H(x,p,v) — ∂/∂x = slot 1, ∂/∂p = slot 2
function (pb::PoissonBracket{FH,FG,B,Traits.Autonomous,Traits.NonFixed})(
    x, p, v
) where {FH,FG,B<:Differentiation.AbstractADBackend}
    gxH = Differentiation.differentiate(pb.backend, pb.H, Val(1), x, p, v)
    gpH = Differentiation.differentiate(pb.backend, pb.H, Val(2), p, x, v)
    gxG = Differentiation.differentiate(pb.backend, pb.G, Val(1), x, p, v)
    gpG = Differentiation.differentiate(pb.backend, pb.G, Val(2), p, x, v)
    return (gpH' * gxG - gxH' * gpG)::promote_type(eltype(x), eltype(p))
end

# NonAutonomous/NonFixed: H(t,x,p,v) — ∂/∂x = slot 2, ∂/∂p = slot 3
function (pb::PoissonBracket{FH,FG,B,Traits.NonAutonomous,Traits.NonFixed})(
    t, x, p, v
) where {FH,FG,B<:Differentiation.AbstractADBackend}
    gxH = Differentiation.differentiate(pb.backend, pb.H, Val(2), x, t, p, v)
    gpH = Differentiation.differentiate(pb.backend, pb.H, Val(3), p, t, x, v)
    gxG = Differentiation.differentiate(pb.backend, pb.G, Val(2), x, t, p, v)
    gpG = Differentiation.differentiate(pb.backend, pb.G, Val(3), p, t, x, v)
    return (gpH' * gxG - gxH' * gpG)::promote_type(eltype(x), eltype(p))
end

"""
$(TYPEDSIGNATURES)

Internal constructor for [`PoissonBracket`](@ref) with compile-time `TD`/`VD` trait parameters.

See also: [`CTLie.PoissonBracket`](@ref), [`CTLie.Poisson`](@ref)
"""
function _Poisson(
    H, G, backend::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}
) where {TD,VD}
    return PoissonBracket{typeof(H),typeof(G),typeof(backend),TD,VD}(H, G, backend)
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `PoissonBracket` callable.

# Arguments
- `io::IO`: The IO stream.
- `pb::PoissonBracket`: The Poisson bracket object.

# Example
```julia-repl
julia> B = Poisson((x, p) -> p[1]^2 / 2 + x[1]^2, (x, p) -> x[1] * p[1])
PoissonBracket: autonomous, fixed (no variable)
  backend: ForwardDiffBackend
  cache: not prepared
```
"""
function Base.show(
    io::IO, pb::PoissonBracket{FH,FG,B,TD,VD}
) where {FH,FG,B<:Differentiation.AbstractADBackend,TD,VD}
    println(io, "PoissonBracket: $(Data._td_label(TD)), $(Data._vd_label(VD))")
    return print(io, "  backend: ", nameof(typeof(pb.backend)))
end

"""
$(TYPEDSIGNATURES)

Display a `PoissonBracket` in the REPL with the same format as `Base.show(io, pb)`.

See also: [`CTLie.PoissonBracket`](@ref).
"""
function Base.show(
    io::IO, ::MIME"text/plain", pb::PoissonBracket{FH,FG,B,TD,VD}
) where {FH,FG,B<:Differentiation.AbstractADBackend,TD,VD}
    return show(io, pb)
end

"""
$(TYPEDSIGNATURES)

Compute the Poisson bracket of two typed Hamiltonians.

Returns a new [`Data.Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) representing the Poisson bracket `{H, G}`.
Both Hamiltonians must share the same time dependence and variable dependence.

# Arguments
- `H::Data.AbstractHamiltonian{TD, VD}`: First Hamiltonian.
- `G::Data.AbstractHamiltonian{TD, VD}`: Second Hamiltonian.
- `ad_backend::Union{Differentiation.AbstractADBackend, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- `Data.Hamiltonian{TD, VD}`: The Poisson bracket as a Hamiltonian.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

H = Hamiltonian((x, p) -> p[1]^2 / 2 + x[1]^2, Traits.Autonomous, Traits.Fixed)
G = Hamiltonian((x, p) -> x[1] * p[1], Traits.Autonomous, Traits.Fixed)

B = Poisson(H, G)
B([1.0, 2.0], [0.5, 1.0])  # Returns 1.0
```

See also: [`CTLie.Poisson(H::Function, G::Function)`](@ref), [`CTLie.ad`](@ref)
"""
function Poisson(
    H::Data.AbstractHamiltonian{TD,VD},
    G::Data.AbstractHamiltonian{TD,VD};
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    closure = _Poisson(H, G, backend, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Error method for mismatched time/variable dependence in Hamiltonian Poisson bracket.

This method is called when two Hamiltonians have different time dependence or variable
dependence types, which is not allowed for the Poisson bracket operation.

# Arguments
- `H::Data.AbstractHamiltonian{TD1, VD1}`: First Hamiltonian.
- `G::Data.AbstractHamiltonian{TD2, VD2}`: Second Hamiltonian with mismatched TD/VD.
- `ad_backend::Union{Differentiation.AbstractADBackend, CTBase.Core.NotProvidedType}`: AD backend (unused).

# Throws
- `Exceptions.PreconditionError`: Always thrown with details about the TD/VD mismatch.

# Notes
This is a fallback error method that provides a clear error message when the types do not
match. Use the matching TD/VD version for valid operations.

See also: [`CTLie.Poisson`](@ref)
"""
function Poisson(
    H::Data.AbstractHamiltonian{TD1,VD1},
    G::Data.AbstractHamiltonian{TD2,VD2};
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {
    TD1<:Traits.TimeDependence,
    VD1<:Traits.VariableDependence,
    TD2<:Traits.TimeDependence,
    VD2<:Traits.VariableDependence,
}
    return throw(
        Exceptions.PreconditionError(
            "Poisson: TD/VD mismatch between H and G";
            reason="H: $(TD1)/$(VD1) ≠ G: $(TD2)/$(VD2) — both Hamiltonians must share the same TimeDependence and VariableDependence",
            suggestion="Ensure both Hamiltonians have the same time and variable dependence traits",
            context="Poisson on AbstractHamiltonian",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Disambiguator error method for two VectorField operands in Poisson bracket.

This overload resolves the ambiguity between the one-sided error methods when both
arguments are `AbstractVectorField`. It is always an error; use `ad(X, Y)` instead.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Lie bracket.

See also: [`CTLie.ad`](@ref)
"""
function Poisson(
    ::Data.AbstractVectorField,
    ::Data.AbstractVectorField;
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
)
    return throw(
        Exceptions.IncorrectArgument(
            "Poisson is not defined for AbstractVectorField operands";
            suggestion="Use ad(X, Y) for the Lie bracket of VectorFields",
            context="Poisson on AbstractVectorField",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Error method for VectorField as first operand in Poisson bracket.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Lie bracket.
"""
function Poisson(
    ::Data.AbstractVectorField,
    ::Any;
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
)
    return throw(
        Exceptions.IncorrectArgument(
            "Poisson is not defined for AbstractVectorField operands";
            suggestion="Use ad(X, Y) for the Lie bracket of VectorFields",
            context="Poisson on AbstractVectorField",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Error method for VectorField as second operand in Poisson bracket.

This is a symmetric companion to `Poisson(::AbstractVectorField, ::Any)`, handling the case
where the second argument is a VectorField and the first is some other type.

# Arguments
- `::Any`: First operand.
- `::Data.AbstractVectorField`: VectorField second operand (not allowed in Poisson bracket).
- `ad_backend::Union{Differentiation.AbstractADBackend, CTBase.Core.NotProvidedType}`: AD backend (unused).

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Lie bracket.

See also: [`CTLie.ad`](@ref)
"""
function Poisson(
    ::Any,
    ::Data.AbstractVectorField;
    ad_backend::Union{Differentiation.AbstractADBackend,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
)
    return throw(
        Exceptions.IncorrectArgument(
            "Poisson is not defined for AbstractVectorField operands";
            suggestion="Use ad(X, Y) for the Lie bracket of VectorFields",
            context="Poisson on AbstractVectorField",
        ),
    )
end
