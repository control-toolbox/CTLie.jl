# Limitations & configuration

```@meta
CurrentModule = CTLie
```

This page collects the constraints of the CTLie operators and the knobs available to
configure them.

```@example limits
using CTLie                        # Lift, ad, Poisson, ∂ₜ, @Lie
using CTBase: Data                 # VectorField, Hamiltonian, HamiltonianVectorField
using CTBase: Traits               # trait types (Autonomous, Variable, OutOfPlace, …)
using DifferentiationInterface: DifferentiationInterface  # activates the AD backend extension
nothing # hide
```

## Limitations

### No in-place support

The operators are defined for **out-of-place** objects only. A field built with
`is_inplace=true` (mutability [`InPlace`](@extref CTBase CTBase.Traits.InPlace)) is rejected by
[`ad`](@ref CTLie.ad) and [`∂ₜ`](@ref CTLie.∂ₜ) with a
[`CTBase.Exceptions.IncorrectArgument`](@extref CTBase) error. Reconstruct the field
out-of-place before taking brackets or time derivatives:

```julia
Xip = VectorField(x -> [x[2], -x[1]]; is_inplace=true)
ad(Xip, Xip)        # ❌ IncorrectArgument — ad does not support in-place fields
```

### No Lie operations on a Hamiltonian vector field

A [`HamiltonianVectorField`](@extref CTBase CTBase.Data.HamiltonianVectorField) lives on phase
space with signature `(x, p)`, not `(x)`, so it is **not** a valid operand for the Lie
bracket / Lie derivative, nor for the [`Lift`](@ref CTLie.Lift).
Both raise [`CTBase.Exceptions.IncorrectArgument`](@extref CTBase):

```julia
Z = HamiltonianVectorField((x, p) -> [x[1], -p[1]]; is_autonomous=true)
ad(Z, Z)            # ❌ IncorrectArgument — signature is (x, p), not (x)
Lift(Z)             # ❌ IncorrectArgument — Z already lives on phase space
```

Use the underlying plain [`VectorField`](@extref CTBase CTBase.Data.VectorField) instead.

### Operands must share traits

[`ad`](@ref CTLie.ad) (on two vector fields) and
[`Poisson`](@ref CTLie.Poisson) (on two Hamiltonians) require their
operands to have the **same** time- and variable-dependence. A mismatch raises
[`CTBase.Exceptions.IncorrectArgument`](@extref CTBase):

```julia
Xa = VectorField(x -> [x[2], -x[1]];      is_autonomous=true)
Xt = VectorField((t, x) -> [x[2], -x[1]]; is_autonomous=false)
ad(Xa, Xt)          # ❌ IncorrectArgument — TD/VD mismatch between X and Y
```

The same rule is enforced by [`@Lie`](@ref CTLie.@Lie); see
[The `@Lie` macro](lie_macro.md#Error-cases).

### Plain functions default to autonomous & fixed

A bare Julia `Function` carries no traits, so the operators assume it is autonomous and
fixed unless told otherwise via `is_autonomous` / `is_variable` (for `ad`, `Poisson`,
`Lift`) or the matching keywords of `@Lie`. When in doubt, wrap the function in a typed
[`VectorField`](@extref CTBase CTBase.Data.VectorField) /
[`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) so the traits are explicit and checked.

## Configuration

### AD backend

`ad`, `Poisson` and `∂ₜ` differentiate through a pluggable backend. The default is built
on `DifferentiationInterface.jl` (with `ForwardDiff` under the hood) and **must be
loaded** for gradients/derivatives to be available:

```julia
using DifferentiationInterface: DifferentiationInterface  # activates the CTBaseDifferentiationInterface extension
```

`ad_backend` takes a [`CTBase.Differentiation.AbstractADBackend`](@extref CTBase) — never a raw
`ADTypes.AbstractADType` — so that the choice of execution device (CPU or GPU) and the
choice of underlying AD implementation are both explicit and swappable without
touching CTLie itself:

```julia
using CTBase: Differentiation

cpu_backend = Differentiation.DifferentiationInterface()                       # CPU, AutoForwardDiff
gpu_backend = Differentiation.DifferentiationInterface{CTBase.Strategies.GPU}() # GPU, AutoMooncake
```

The global default backend is read and set with
[`dg_ad_backend`](@ref CTLie.dg_ad_backend) /
[`dg_ad_backend!`](@ref CTLie.dg_ad_backend!):

```julia
dg_ad_backend!(cpu_backend)   # set global default
dg_ad_backend()               # query it
```

Every operator also accepts a per-call `ad_backend` keyword that overrides the global
default for that call only — including [`@Lie`](@ref CTLie.@Lie)
via `ad_backend=…`:

```julia
ad(X, Y; ad_backend=cpu_backend)
@Lie [X, Y] ad_backend=cpu_backend
```

### Code generation by `@Lie`

The [`@Lie`](@ref CTLie.@Lie) macro is **hygienic**: its expansion refers to the CTLie
internals, the trait types and the exception type through module-qualified references, not
through names looked up in the caller's module. It therefore works from any module, whatever
the caller imported — `using CTLie: @Lie` alone is enough, and a caller that defines its own
`CTLie` or `CTBase` binding is not affected.

The operands and the `ad_backend` expression are the caller's own code and are resolved in
the caller's module, as usual. The AD backend extension must still be loaded (see above).

## See also

- [Differential geometry overview](index.md)
- [`ad`](@ref CTLie.ad), [`Poisson`](@ref CTLie.Poisson),
  [`Lift`](@ref CTLie.Lift), [`∂ₜ`](@ref CTLie.∂ₜ),
  [`@Lie`](@ref CTLie.@Lie)
