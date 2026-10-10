# Argument guards shared by `ad`, `Lift` and `∂ₜ`.
# Each guard takes the calling operation `op` so that the error names the operation
# the user actually called.

# --- InPlace guard: dispatches on the MD *type* (captured from the where clause — fully static)
_check_outofplace(::Type{Traits.OutOfPlace}, op::Symbol) = nothing

function _check_outofplace(::Type{MD}, op::Symbol) where {MD<:Traits.AbstractMutabilityTrait}
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
_check_not_hvf(::Data.AbstractVectorField, op::Symbol) = nothing

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

# Operation-specific advice for the HVF guard.
_hvf_suggestion(::Val{:Lift}) =
    "A HamiltonianVectorField already lives on the cotangent space: there is nothing to lift"
_hvf_suggestion(::Val) = "Use a plain VectorField"
