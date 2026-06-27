# Partial time derivative

```@meta
CurrentModule = CTLie
```

The operator [`∂ₜ`](@ref CTLie.∂ₜ) (typed `\partial<tab>` then
`\_t<tab>`) computes the **partial derivative with respect to time** of a time-dependent
object:

```math
(\partial_t f)(t, \cdot) = \frac{\partial f}{\partial t}(t, \cdot).
```

It is the explicit-time part of the total derivative. For a quantity ``G`` evaluated along
the flow of a Hamiltonian ``H``, the chain rule gives the familiar decomposition

```math
\frac{\mathrm{d}}{\mathrm{d}t}\, G = \partial_t G + \{H, G\},
```

so ``\partial_t`` and the [Poisson bracket](poisson.md) together yield total time
derivatives — useful, for instance, to differentiate switching functions along
extremals.

`∂ₜ` is computed by automatic differentiation, so the AD backend extension must be
loaded.

```@setup dt
using CTLie
using CTBase.Data
using CTBase.Traits
import DifferentiationInterface
```

!!! note "The result is always non-autonomous"

    Differentiating with respect to ``t`` produces an object that is read at a time ``t``,
    so every typed result is `NonAutonomous` and its
    call signature begins with `t`. For an autonomous input the derivative is identically
    zero, but the returned object still takes `t` as its first argument.

## On plain functions

For a `Function`, the first argument is taken to be time, and `∂ₜ` returns a `Function`
with the same signature.

```@example dt
f = (t, x) -> t * x[1] + x[2]^2
df = ∂ₜ(f)
df(2.0, [1.0, 3.0])      # ∂/∂t (t*x₁ + x₂²) = x₁
```

## On typed vector fields

For a [`VectorField`](@extref CTBase CTBase.Data.VectorField), `∂ₜ` returns a new `VectorField`
that is `NonAutonomous` and `OutOfPlace`.

```@example dt
X  = VectorField((t, x) -> t .* x; is_autonomous=false)
dX = ∂ₜ(X)
dX(2.0, [1.0, 2.0])      # ∂/∂t (t·x) = x
```

An autonomous field has zero time derivative — but note the result is still read with a
leading `t`:

```@example dt
Xa  = VectorField(x -> [x[2], -x[1]]; is_autonomous=true)
dXa = ∂ₜ(Xa)
dXa(0.0, [1.0, 2.0])     # zero
```

## On typed Hamiltonians

For a [`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian), `∂ₜ` returns a `NonAutonomous`
`Hamiltonian`.

```@example dt
H  = Hamiltonian((t, x, p) -> t * p[1] + x[1]^2; is_autonomous=false)
dH = ∂ₜ(H)
dH(2.0, [1.0], [0.5])    # ∂/∂t (t·p₁ + x₁²) = p₁
```

## On typed Hamiltonian vector fields

For a [`HamiltonianVectorField`](@extref CTBase CTBase.Data.HamiltonianVectorField), `∂ₜ` returns a
`NonAutonomous` `HamiltonianVectorField`.

```@example dt
Z  = HamiltonianVectorField((t, x, p) -> t .* [p[1], -x[1]]; is_autonomous=false)
dZ = ∂ₜ(Z)
dZ(2.0, [1.0], [0.5])    # ∂/∂t t·[p₁, -x₁] = [p₁, -x₁]
```

!!! warning "Out-of-place only"

    `∂ₜ` on a typed object requires `OutOfPlace` mutability; an in-place field raises a
    `NotImplemented` error. See [Limitations & configuration](limitations.md).

## See also

- [`∂ₜ`](@ref CTLie.∂ₜ) — full docstring and method list.
- [Poisson bracket](poisson.md) — the other half of the total time derivative.
