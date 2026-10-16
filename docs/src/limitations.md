# Limitations & configuration

```@meta
CurrentModule = CTLie
```

This page collects the constraints of the CTLie operators and the knobs available to
configure them.

```@example limits
using CTLie          # Lift, ad, Poisson, ∂ₜ, @Lie
using CTBase: Data   # Data.VectorField, Data.Hamiltonian, …
# AD backend: CTBase's DifferentiationInterface extension + ForwardDiff
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff
nothing # hide
```

## Limitations

### No in-place support

The operators are defined for **out-of-place** objects only. A field built with
`is_inplace=true` (mutability [`InPlace`](@extref CTBase CTBase.Traits.InPlace)) is rejected by
[`ad`](@ref CTLie.ad) and [`∂ₜ`](@ref CTLie.∂ₜ) with a
[`CTBase.Exceptions.IncorrectArgument`](@extref CTBase) error. Reconstruct the field
out-of-place before taking brackets or time derivatives:

```@repl limits
Xip = Data.VectorField((dx, x) -> (dx .= (x[2], -x[1])); is_inplace=true);
ad(Xip, Xip)
```

### No Lie operations on a Hamiltonian vector field

A [`HamiltonianVectorField`](@extref CTBase CTBase.Data.HamiltonianVectorField) lives on phase
space with signature `(x, p)`, not `(x)`, so it is **not** a valid operand for the Lie
bracket / Lie derivative, nor for the [`Lift`](@ref CTLie.Lift).
Both raise [`CTBase.Exceptions.IncorrectArgument`](@extref CTBase):

```@repl limits
Z = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true);
ad(Z, Z)
Lift(Z)
```

Use the underlying plain [`VectorField`](@extref CTBase CTBase.Data.VectorField) instead.

### Operands must share traits

[`ad`](@ref CTLie.ad) (on two vector fields) and
[`Poisson`](@ref CTLie.Poisson) (on two Hamiltonians) require their
operands to have the **same** time- and variable-dependence. Each operand is valid on
its own — it is their combination that is rejected — so a mismatch raises
[`CTBase.Exceptions.PreconditionError`](@extref CTBase):

```@repl limits
Xa = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true);
Xt = Data.VectorField((t, x) -> [x[2], -x[1]]; is_autonomous=false);
ad(Xa, Xt)
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

`ad`, `Poisson` and `∂ₜ` differentiate through a pluggable backend. The default
backend runs `ForwardDiff` through `DifferentiationInterface.jl`, and **both packages
must be loaded** for derivatives to be available:

```julia
using DifferentiationInterface: DifferentiationInterface  # AD extension
using ForwardDiff: ForwardDiff  # default AD engine
```

Loading `DifferentiationInterface` alone is not enough: the first evaluation then
raises a [`CTBase.Exceptions.ExtensionError`](@extref CTBase) naming the missing
`ForwardDiff`. A non-default engine (e.g. `Mooncake` for the GPU backend below) must
likewise be loaded before a derivative is evaluated. The documentation build loads every
extension, so the error is rendered from a fresh Julia process where only CTLie is loaded:

```@eval
using CTBase: CTBase
CTBase.DevTools.repl_without_extensions(
    :CTLie,
    "using CTBase: Data",
    "X = Data.VectorField(x -> [x[2], -x[1]]);",
    "CTLie.ad(X, X)([1.0, 0.0])",
)
```

`ad_backend` takes a [`CTBase.Differentiation.AbstractADBackend`](@extref CTBase) — never a raw
`ADTypes.AbstractADType` — so that the choice of execution device (CPU or GPU) and the
choice of underlying AD implementation are both explicit and swappable without
touching CTLie itself:

```julia
using CTBase: CTBase, Differentiation

# CPU (default device): AutoForwardDiff
cpu_backend = Differentiation.DifferentiationInterface()

# GPU: AutoMooncake (Mooncake must be loaded to differentiate)
gpu_backend =
    Differentiation.DifferentiationInterface{CTBase.Strategies.GPU}()
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

- [Overview](index.md)
- [`ad`](@ref CTLie.ad), [`Poisson`](@ref CTLie.Poisson),
  [`Lift`](@ref CTLie.Lift), [`∂ₜ`](@ref CTLie.∂ₜ),
  [`@Lie`](@ref CTLie.@Lie)
