# Argument guards shared by `ad`, `Lift` and `∂ₜ`.
# Each guard takes the calling operation `op` so that the error names the operation
# the user actually called.

# --- InPlace guard: dispatches on the MD *type* (captured from the where clause — fully static)
"""
Check that the mutability type is `OutOfPlace` (static dispatch on the type parameter).

# Arguments
- `::Type{Traits.OutOfPlace}`: Out-of-place mutability type (allowed).
- `op::Symbol`: Name of the calling operation (e.g. `:ad`, `:∂ₜ`), used in the error.

# Returns
- `nothing`
"""
_check_outofplace(::Type{Traits.OutOfPlace}, op::Symbol) = nothing

"""
Throw `IncorrectArgument` if the mutability type is not `OutOfPlace`.

# Arguments
- `::Type{MD}`: Mutability type (must be `OutOfPlace`).
- `op::Symbol`: Name of the calling operation, used in the message and context.

# Throws
- `Exceptions.IncorrectArgument`: If the mutability is `InPlace`.
"""
function _check_outofplace(
    ::Type{MD}, op::Symbol
) where {MD<:Traits.AbstractMutabilityTrait}
    return throw(
        Exceptions.IncorrectArgument(
            "$op does not support InPlace vector fields";
            got="InPlace vector field",
            expected="OutOfPlace vector field",
            suggestion="Reconstruct the VectorField without the in-place flag",
            context="$op on AbstractVectorField",
        ),
    )
end

# --- HVF guard: dispatch on type hierarchy (runtime — MD params don't encode HVF vs plain VF)
"""
Check that the vector field is not a `HamiltonianVectorField` (runtime check).

# Arguments
- `::Data.AbstractVectorField`: Plain vector field (allowed).
- `op::Symbol`: Name of the calling operation (e.g. `:ad`, `:Lift`), used in the error.

# Returns
- `nothing`
"""
_check_not_hvf(::Data.AbstractVectorField, op::Symbol) = nothing

"""
Throw `IncorrectArgument` if the vector field is a `HamiltonianVectorField`.

A `HamiltonianVectorField` has signature `(x, p)` rather than `(x)`, so it cannot be used
as an operand of operations defined on plain vector fields.

# Arguments
- `::Data.AbstractHamiltonianVectorField`: Hamiltonian vector field (not allowed).
- `op::Symbol`: Name of the calling operation, used in the message, context and suggestion.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown for HamiltonianVectorFields.
"""
function _check_not_hvf(::Data.AbstractHamiltonianVectorField, op::Symbol)
    return throw(
        Exceptions.IncorrectArgument(
            "$op does not support HamiltonianVectorField (signature is (x, p), not (x))";
            got="HamiltonianVectorField",
            expected="plain VectorField",
            suggestion=_hvf_suggestion(Val(op)),
            context="$op on AbstractVectorField",
        ),
    )
end

"""
Operation-specific suggestion for the `HamiltonianVectorField` guard.

Falls back to a generic hint; `Lift` explains that there is nothing to lift.
"""
function _hvf_suggestion(::Val{:Lift})
    return "A HamiltonianVectorField already lives on the cotangent space: there is nothing to lift"
end
_hvf_suggestion(::Val) = "Use a plain VectorField"
