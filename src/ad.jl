"""
$(TYPEDSIGNATURES)

Compute the Lie derivative or Lie bracket of two functions using keyword arguments.

- If `foo` returns a scalar, returns the Lie derivative (directional derivative): `∇foo(x)'*X(x)`
- If `foo` returns a vector, returns the Lie bracket: `J_foo(x)*X(x) - J_X(x)*foo(x)`

The time dependence and variable dependence are inferred from the `is_autonomous` and
`is_variable` keyword arguments.

# Arguments
- `X::Function`: Vector field function (returns a vector).
- `foo::Function`: Scalar or vector field function.
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).
- `is_autonomous::Bool`: Whether the functions are time-independent (default: from global config).
- `is_variable::Bool`: Whether the functions depend on a variable parameter (default: from global config).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x) -> result`
  - NonAutonomous/Fixed: `(t, x) -> result`
  - Autonomous/NonFixed: `(x, v) -> result`
  - NonAutonomous/NonFixed: `(t, x, v) -> result`

# Example
```julia
using CTLie

X = x -> [x[2], -x[1]]
f = x -> x[1]^2 + x[2]^2

# Lie derivative (scalar output)
L = ad(X, f)
L([1.0, 2.0])  # Returns 0.0
```

See also: [`CTLie.ad`](@ref), [`CTLie.Poisson`](@ref), [`CTLie.Lift`](@ref)
"""
function ad(
    X::Function,
    foo::Function;
    ad_backend::Union{ADTypes.AbstractADType,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
    is_autonomous::Bool=Data.__is_autonomous(),
    is_variable::Bool=Data.__is_variable(),
)
    TD = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD = is_variable ? Traits.NonFixed : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Compute the Lie derivative or Lie bracket of two functions with explicit type parameters.

- If `foo` returns a scalar, returns the Lie derivative (directional derivative): `∇foo(x)'*X(x)`
- If `foo` returns a vector, returns the Lie bracket: `J_foo(x)*X(x) - J_X(x)*foo(x)`

This typed entry point is used by the [`@Lie`](@ref) macro for compile-time dispatch.

# Arguments
- `X::Function`: Vector field function (returns a vector).
- `foo::Function`: Scalar or vector field function.
- `::Type{TD}`: Time dependence type (`Autonomous` or `NonAutonomous`).
- `::Type{VD}`: Variable dependence type ([`CTBase.Traits.Fixed`](@extref CTBase) or [`CTBase.Traits.NonFixed`](@extref CTBase)).
- `ad_backend::Union{ADTypes.AbstractADType, CTBase.Core.NotProvidedType}`: AD backend to use (default: global backend).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x) -> result`
  - NonAutonomous/Fixed: `(t, x) -> result`
  - Autonomous/NonFixed: `(x, v) -> result`
  - NonAutonomous/NonFixed: `(t, x, v) -> result`

# Example
```julia
using CTLie
using CTBase.Traits

X = x -> [x[2], -x[1]]
f = x -> x[1]^2 + x[2]^2

# Lie derivative with explicit types
L = ad(X, f, Traits.Autonomous, Traits.Fixed)
L([1.0, 2.0])  # Returns 0.0
```

See also: [`CTLie.ad(X::Function, foo::Function)`](@ref), [`CTLie.@Lie`](@ref), [`CTLie.Poisson`](@ref)
"""
function ad(
    X::Function,
    foo::Function,
    ::Type{TD},
    ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType,CTBase.Core.NotProvidedType}=__dg_ad_backend(),
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Internal — X/foo unannotés pour accepter AbstractVectorField callables (via ad_types.jl)

"""
$(TYPEDEF)

Callable struct representing the Lie derivative or Lie bracket of `foo` along `X`.

- **Scalar `foo`**: Lie derivative `∇foo(x)'·X(x)` — first JVP, no second pass.
- **Vector `foo`**: Lie bracket `J_foo(x)·X(x) - J_X(x)·foo(x)` — two JVPs via
  `Differentiation.pushforward`, eliminating the per-call inner closures
  (`X̂ = x_->X(x_)`, `f̂ = x_->foo(x_)`, `g(s) = f̂(x+s·X_x)`) that the old
  closure-based `_ad` created on every evaluation.

`TD` and `VD` are compile-time trait parameters so the correct call method (and slot
numbering) is resolved statically.
"""
struct Ad{TX,TF,B<:Differentiation.AbstractADBackend,TD,VD} <: Function
    X::TX
    foo::TF
    backend::B
end

function (a::Ad{TX,TF,B,Traits.Autonomous,Traits.Fixed})(x) where {TX,TF,B}
    X_x = a.X(x)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(1), x, X_x)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(1), x)
end

function (a::Ad{TX,TF,B,Traits.NonAutonomous,Traits.Fixed})(t, x) where {TX,TF,B}
    X_x = a.X(t, x)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(2), x, X_x, t)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(2), x, t)
end

function (a::Ad{TX,TF,B,Traits.Autonomous,Traits.NonFixed})(x, v) where {TX,TF,B}
    X_x = a.X(x, v)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(1), x, X_x, v)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(1), x, v)
end

function (a::Ad{TX,TF,B,Traits.NonAutonomous,Traits.NonFixed})(t, x, v) where {TX,TF,B}
    X_x = a.X(t, x, v)
    dfoo = Differentiation.pushforward(a.backend, a.foo, Val(2), x, X_x, t, v)
    return _ad_bracket(a.X, a.foo, dfoo, a.backend, Val(2), x, t, v)
end

"""
$(TYPEDSIGNATURES)

Internal constructor for [`Ad`](@ref) with compile-time `TD`/`VD` trait parameters.

See also: [`CTLie.Ad`](@ref), [`CTLie.ad`](@ref)
"""
function _ad(
    X, foo, backend::Differentiation.AbstractADBackend, ::Type{TD}, ::Type{VD}
) where {TD,VD}
    return Ad{typeof(X),typeof(foo),typeof(backend),TD,VD}(X, foo, backend)
end

# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display a compact representation of an `Ad` callable (Lie derivative or Lie bracket).

# Arguments
- `io::IO`: The IO stream.
- `a::Ad`: The `Ad` object.

# Example
```julia-repl
julia> L = ad(x -> [x[2], -x[1]], x -> x[1]^2 + x[2]^2)
Ad: autonomous, fixed (no variable)
  backend: ForwardDiffBackend
  cache: not prepared
```
"""
function Base.show(io::IO, a::Ad{TX,TF,B,TD,VD}) where {TX,TF,B,TD,VD}
    println(io, "Ad: $(Data._td_label(TD)), $(Data._vd_label(VD))")
    return print(io, "  backend: ", nameof(typeof(a.backend)))
end

"""
$(TYPEDSIGNATURES)

Display an `Ad` callable in the REPL with the same format as `Base.show(io, a)`.

See also: [`CTLie.Ad`](@ref).
"""
function Base.show(io::IO, ::MIME"text/plain", a::Ad{TX,TF,B,TD,VD}) where {TX,TF,B,TD,VD}
    return show(io, a)
end

"""
$(TYPEDSIGNATURES)

Dispatch on the return type of `foo` to finalize the Lie derivative or Lie bracket.

- **Scalar `foo`** (Lie derivative): the directional derivative `dfoo` is already
  computed by the caller; return it directly.
- **Vector `foo`** (Lie bracket): compute the second pushforward
  `J_X(x)·foo(x)` and return `dfoo - dX = J_foo(x)·X(x) - J_X(x)·foo(x)`.

See also: [`CTLie.Ad`](@ref), [`CTLie.ad`](@ref)
"""
_ad_bracket(_, _, dfoo::Number, _, ::Val{Slot}, x, consts...) where {Slot} = dfoo

# Lie bracket (vector): J_foo(x)·X(x) - J_X(x)·foo(x)
function _ad_bracket(
    X, foo, dfoo::AbstractVector, backend, ::Val{Slot}, x, consts::Vararg{Any,N}
) where {Slot,N}
    Y_x = foo(ntuple(i -> i == Slot ? x : consts[i < Slot ? i : i - 1], Val(N + 1))...)
    dX = Differentiation.pushforward(backend, X, Val(Slot), x, Y_x, consts...)
    return dfoo - dX
end
