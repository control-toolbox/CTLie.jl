# InPlace guard: dispatches on the MD *type* (captured from the where clause — fully static)
"""
Check that mutability type is OutOfPlace (static dispatch on type parameter).

# Arguments
- `::Type{Traits.OutOfPlace}`: OutOfPlace mutability type.

# Returns
- `nothing`
"""
_check_outofplace(::Type{Traits.OutOfPlace}) = nothing

"""
Throw NotImplemented if mutability type is not OutOfPlace.

# Arguments
- `::Type{MD}`: Mutability type (must be OutOfPlace).

# Throws
- `Exceptions.NotImplemented`: If mutability is not OutOfPlace.
"""
function _check_outofplace(::Type{MD}) where {MD <: Traits.AbstractMutabilityTrait}
    throw(Exceptions.NotImplemented(
        "ad is not implemented for InPlace vector fields",
        required_method = "Use an OutOfPlace VectorField",
        suggestion      = "Reconstruct the VectorField without in-place flag",
        context         = "ad on AbstractVectorField",
    ))
end

# HVF guard: dispatch on type hierarchy (runtime — MD params don't encode HVF vs plain VF)
"""
Check that vector field is not a HamiltonianVectorField (runtime check).

# Arguments
- `::Data.AbstractVectorField`: Plain vector field (allowed).

# Returns
- `nothing`
"""
_check_not_hvf(::Data.AbstractVectorField)            = nothing

"""
Throw NotImplemented if vector field is a HamiltonianVectorField.

HamiltonianVectorFields have signature (x, p) not (x), so they cannot be used
with the Lie bracket operations on plain vector fields.

# Arguments
- `X::Data.AbstractHamiltonianVectorField`: Hamiltonian vector field (not allowed).

# Throws
- `Exceptions.NotImplemented`: Always thrown for HamiltonianVectorFields.
"""
function _check_not_hvf(X::Data.AbstractHamiltonianVectorField)
    throw(Exceptions.NotImplemented(
        "ad on AbstractHamiltonianVectorField is not implemented (signature is (x,p), not (x))",
        suggestion = "Use ad on a plain VectorField",
        context    = "ad on AbstractVectorField",
    ))
end

"""
$(TYPEDSIGNATURES)

Compute the Lie bracket of two vector fields.

Returns a new [`Data.VectorField`](@ref) representing the Lie bracket `[X, Y] = J_Y(x)*X(x) - J_X(x)*Y(x)`.
Both vector fields must share the same time dependence and variable dependence.

# Arguments
- `X::Data.AbstractVectorField{TD, VD, MDX}`: First vector field.
- `Y::Data.AbstractVectorField{TD, VD, MDY}`: Second vector field.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- `Data.VectorField{TD, VD, Traits.OutOfPlace}`: The Lie bracket as a vector field.

# Throws
- `Exceptions.NotImplemented`: If either vector field is an `AbstractHamiltonianVectorField`.
- `Exceptions.NotImplemented`: If either vector field has `InPlace` mutability.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

X = VectorField(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)
Y = VectorField(x -> [-x[2], x[1]], Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)

Z = ad(X, Y)
Z([1.0, 2.0])  # Returns [0.0, 0.0]
```

See also: [`CTLie.ad`](@ref)
"""
function ad(
    X::Data.AbstractVectorField{TD, VD, MDX},
    Y::Data.AbstractVectorField{TD, VD, MDY};
    ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType} = __dg_ad_backend(),
) where {TD, VD, MDX, MDY}
    _check_not_hvf(X); _check_not_hvf(Y)
    _check_outofplace(MDX)    # static dispatch on type parameter — no runtime call
    _check_outofplace(MDY)
    backend  = _resolve_backend(ad_backend)
    closure  = _ad(X, Y, backend, TD, VD)
    return Data.VectorField(closure, TD, VD, Traits.OutOfPlace)  # typed constructor, explicit mutability
end

"""
$(TYPEDSIGNATURES)

Compute the Lie derivative of a scalar function along a vector field.

Returns a plain function representing the directional derivative `∇f(x)'*X(x)`.

# Arguments
- `X::Data.AbstractVectorField{TD, VD, MDX}`: Vector field.
- `f::Function`: Scalar function.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- A function with signature depending on TD/VD that returns a scalar.

# Throws
- `Exceptions.NotImplemented`: If the vector field is an `AbstractHamiltonianVectorField`.
- `Exceptions.NotImplemented`: If the vector field has `InPlace` mutability.

# Example
```julia
using CTLie
using CTBase.Data
using CTBase.Traits

X = VectorField(x -> [x[2], -x[1]], Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace)
f = x -> x[1]^2 + x[2]^2

L = ad(X, f)
L([1.0, 2.0])  # Returns 0.0
```

See also: [`CTLie.ad`](@ref)
"""
function ad(
    X::Data.AbstractVectorField{TD, VD, MDX},
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType} = __dg_ad_backend(),
) where {TD, VD, MDX}
    _check_not_hvf(X)
    _check_outofplace(MDX)    # static dispatch
    backend = _resolve_backend(ad_backend)
    return _ad(X, f, backend, TD, VD)  # scalar output → returns a plain Function
end

"""
$(TYPEDSIGNATURES)

Error method for mismatched time/variable dependence in vector field Lie bracket.

This method is called when two vector fields have different time dependence or variable
dependence types, which is not allowed for the Lie bracket operation.

# Arguments
- `X::Data.AbstractVectorField{TD1, VD1, MDX}`: First vector field.
- `Y::Data.AbstractVectorField{TD2, VD2, MDY}`: Second vector field with mismatched TD/VD.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend (unused).

# Throws
- `Exceptions.PreconditionError`: Always thrown with details about the TD/VD mismatch.

# Notes
This is a fallback error method that provides a clear error message when the types do not
match. Use the matching TD/VD version for valid operations.

See also: [`CTLie.ad`](@ref)
"""
function ad(
    X::Data.AbstractVectorField{TD1, VD1, MDX},
    Y::Data.AbstractVectorField{TD2, VD2, MDY};
    ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType} = __dg_ad_backend(),
) where {TD1, VD1, MDX, TD2, VD2, MDY}
    throw(Exceptions.PreconditionError(
        "ad: TD/VD mismatch between X and Y";
        reason     = "X: $(TD1)/$(VD1) ≠ Y: $(TD2)/$(VD2) — both arguments must share the same TimeDependence and VariableDependence",
        suggestion = "Ensure both vector fields have the same time and variable dependence traits",
        context    = "ad on AbstractVectorField",
    ))
end

"""
$(TYPEDSIGNATURES)

Disambiguator error method for two Hamiltonian operands in Lie bracket.

This overload resolves the ambiguity between the one-sided error methods when both
arguments are `AbstractHamiltonian`. It is always an error; use `Poisson(H, G)` instead.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Poisson bracket.

See also: [`CTLie.Poisson`](@ref)
"""
function ad(
    ::Data.AbstractHamiltonian, ::Data.AbstractHamiltonian;
    ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType} = __dg_ad_backend(),
)
    throw(Exceptions.IncorrectArgument(
        "ad is not defined for AbstractHamiltonian operands";
        suggestion = "Use Poisson(H, G) for the Poisson bracket of Hamiltonians",
        context    = "ad on AbstractHamiltonian",
    ))
end

"""
$(TYPEDSIGNATURES)

Error method for Hamiltonian as first operand in Lie bracket.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Poisson bracket.
"""
function ad(
    ::Data.AbstractHamiltonian, ::Any;
    ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType} = __dg_ad_backend(),
)
    throw(Exceptions.IncorrectArgument(
        "ad is not defined for AbstractHamiltonian operands";
        suggestion = "Use Poisson(H, G) for the Poisson bracket of Hamiltonians",
        context    = "ad on AbstractHamiltonian",
    ))
end

"""
$(TYPEDSIGNATURES)

Error method for Hamiltonian as second operand in Lie bracket.

This is a symmetric companion to `ad(::AbstractHamiltonian, ::Any)`, handling the case
where the second argument is a Hamiltonian and the first is some other type.

# Arguments
- `::Any`: First operand.
- `::Data.AbstractHamiltonian`: Hamiltonian second operand (not allowed in Lie bracket).
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend (unused).

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Poisson bracket.

See also: [`CTLie.Poisson`](@ref)
"""
function ad(
    ::Any, ::Data.AbstractHamiltonian;
    ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType} = __dg_ad_backend(),
)
    throw(Exceptions.IncorrectArgument(
        "ad is not defined for AbstractHamiltonian operands";
        suggestion = "Use Poisson(H, G) for the Poisson bracket of Hamiltonians",
        context    = "ad on AbstractHamiltonian",
    ))
end
